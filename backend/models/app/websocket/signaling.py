import socketio
import logging
import time
from datetime import datetime, timezone
from jose import JWTError
from ..services.matchmaking import matchmaker
from ..core.security import decode_access_token
from ..models.user import User

logger = logging.getLogger(__name__)
sio = socketio.AsyncServer(async_mode='asgi')
sio_app = socketio.ASGIApp(sio)

# Key: sid, Value: partner_sid
pairings = {}

# Key: sid, Value: user profile dict
user_profiles = {}
socket_tokens = {}
last_socket_report = {}
last_queue_join = {}
last_queue_heartbeat = {}

async def _authenticated_user(sid: str, token: str = None):
    token = token or socket_tokens.get(sid)
    if not token:
        return None
    try:
        payload = decode_access_token(token)
        user = await User.find_one({"email": payload.get("sub")})
    except (JWTError, TypeError, ValueError):
        return None
    if (
        not user
        or not user.is_active
        or user.is_banned
        or user.shadow_banned
        or getattr(user, "age", None) is None
        or user.age < 13
        or payload.get("ver", 0) != getattr(user, "token_version", 0)
    ):
        return None
    socket_tokens[sid] = token
    return user

async def pair_is_eligible(sid1: str, sid2: str) -> bool:
    user1 = await _authenticated_user(sid1)
    if not user1:
        return False
    if sid1 == sid2:
        return True
    user2 = await _authenticated_user(sid2)
    if not user2:
        return False
    if (
        user1.age is None
        or user2.age is None
        or user2.age < (user1.age_min or 13)
        or user2.age > (user1.age_max or 120)
        or user1.age < (user2.age_min or 13)
        or user1.age > (user2.age_max or 120)
    ):
        return False
    preference1 = (user1.interested_in or "everyone").strip().lower()
    preference2 = (user2.interested_in or "everyone").strip().lower()
    if preference1 not in {"everyone", (user2.gender or "").lower()}:
        return False
    if preference2 not in {"everyone", (user1.gender or "").lower()}:
        return False
    return (
        user2.anonymous_username not in (user1.blocked_users or [])
        and user1.anonymous_username not in (user2.blocked_users or [])
    )

async def disconnect_user(user_id: str):
    """Remove a user's active matchmaking sessions after account restrictions change."""
    for sid, profile in list(user_profiles.items()):
        if profile.get("username") != user_id:
            continue
        partner_id = remove_pairing(sid)
        if partner_id:
            await sio.emit(
                "partner_disconnected",
                {"reason": "Stranger disconnected.", "was_disconnected": True},
                room=partner_id,
            )
        await matchmaker.remove_from_queue(sid)

async def _authorized_room(sid: str, data):
    user = await _authenticated_user(sid)
    room_id = (data or {}).get("room_id")
    if not user or not room_id:
        return None, None
    from ..models.voice_room import VoiceRoom
    room = await VoiceRoom.get(room_id)
    if (
        not room
        or not room.is_active
        or user.anonymous_username not in room.participants
    ):
        return None, None
    return user, room_id

def set_pairing(sid1: str, sid2: str):
    """Pair two sockets for bidirectional WebRTC and chat signaling."""
    pairings[sid1] = sid2
    pairings[sid2] = sid1
    logger.info("Socket pair established.")

def remove_pairing(sid: str):
    """Safely unlink a socket and return its partner ID if existed."""
    partner_id = pairings.pop(sid, None)
    if partner_id:
        pairings.pop(partner_id, None)
    return partner_id

def _get_common_interests(sid1: str, sid2: str):
    u1 = user_profiles.get(sid1, {})
    u2 = user_profiles.get(sid2, {})
    i1 = set(u1.get('interests', []))
    i2 = set(u2.get('interests', []))
    return list(i1 & i2)

@sio.event
async def connect(sid, environ):
    logger.info(f"Socket: Connected {sid}")

@sio.event
async def join_queue(sid, data=None):
    """Event triggered when user hits 'Start Video Chat' or skips to next stranger."""
    data = data if isinstance(data, dict) else {}
    now_monotonic = time.monotonic()
    if sid in pairings:
        await sio.emit("matchmaking_error", {"message": "End your current chat before searching again"}, room=sid)
        return False
    if now_monotonic - last_queue_join.get(sid, 0) < 2:
        return False
    last_queue_join[sid] = now_monotonic
    user = await _authenticated_user(sid, data.get("token"))
    if not user:
        await sio.emit("matchmaking_error", {"message": "Authentication required"}, room=sid)
        await matchmaker.remove_from_queue(sid)
        return False
    username = user.anonymous_username
    interests = user.interests or []
    trust_score = user.trust_score
    requested_mode = data.get("match_mode", "random")
    if requested_mode not in {"random", "vibe"}:
        await sio.emit("matchmaking_error", {"message": "Invalid matchmaking mode"}, room=sid)
        return False
    match_mode = requested_mode
    country = user.country or "Global"
    region = country
    vibe_id = None
    preferred_vibes = []
    vibe_expires_at = None
    if match_mode == "vibe":
        now = datetime.now(timezone.utc)
        active_vibe = await UserVibe.find_one({
            "user_id": username,
            "expires_at": {"$gt": now},
        })
        selected_vibe = await Vibe.find_one({
            "vibe_id": active_vibe.vibe_id,
            "is_active": True,
        }) if active_vibe else None
        if (
            not active_vibe
            or not selected_vibe
            or user.age is None
            or user.age < max(selected_vibe.minimum_age, 18 if selected_vibe.vibe_id == "flirting" else 13)
            or user.shadow_banned
        ):
            await matchmaker.remove_from_queue(sid)
            await sio.emit("matchmaking_error", {"message": "Choose an available vibe before searching"}, room=sid)
            return False
        vibe_id = selected_vibe.vibe_id
        preferred_vibes = active_vibe.preferred_vibes or []
        vibe_expires_at = active_vibe.expires_at
        # Vibe matching is global; the user's country is not sent to a match.
        country = "Global"
        region = "Global"
    avatar_url = user.profile_photo_url or user.avatar_url or ""

    # Cache user profile on socket connection
    user_profiles[sid] = {
        'username': username,
        'country': country,
        'interests': interests,
        'trust_score': trust_score,
        'avatar_url': avatar_url,
        'match_mode': match_mode,
        'vibe_id': vibe_id,
    }

    added = await matchmaker.add_to_queue(
        sid,
        interests,
        region,
        trust_score,
        owner_id=username,
        match_mode=match_mode,
        vibe_id=vibe_id,
        preferred_vibes=preferred_vibes,
        vibe_expires_at=vibe_expires_at,
    )
    if not added:
        await sio.emit("matchmaking_error", {"message": "Could not join the matchmaking queue"}, room=sid)
        return False

    # Attempt immediate matchmaking
    partner_id = await matchmaker.find_match(sid, eligibility_check=pair_is_eligible)

    if partner_id:
        set_pairing(sid, partner_id)

        common = _get_common_interests(sid, partner_id)
        u_caller = user_profiles.get(sid, {})
        u_receiver = user_profiles.get(partner_id, {})

        # Caller receives match info
        await sio.emit('match_found', {
            'partner_id': partner_id,
            'role': 'caller',
            'partner_username': u_receiver.get('username', 'Stranger'),
            'partner_country': u_receiver.get('country', 'Global'),
            'partner_avatar': u_receiver.get('avatar_url', ''),
            'common_interests': common,
            'match_mode': match_mode,
        }, room=sid)

        # Receiver receives match info
        await sio.emit('match_found', {
            'partner_id': sid,
            'role': 'receiver',
            'partner_username': u_caller.get('username', 'Stranger'),
            'partner_country': u_caller.get('country', 'Global'),
            'partner_avatar': u_caller.get('avatar_url', ''),
            'common_interests': common,
            'match_mode': match_mode,
        }, room=partner_id)
    else:
        logger.info("Socket joined the matchmaking queue.")
        await sio.emit('searching', {'status': 'waiting'}, room=sid)

@sio.event
async def leave_queue(sid, data=None):
    if not await _authenticated_user(sid):
        return False
    await matchmaker.remove_from_queue(sid)
    remove_pairing(sid)
    logger.info("Socket left the matchmaking queue.")

@sio.event
async def queue_heartbeat(sid, data=None):
    user = await _authenticated_user(sid)
    if user and user_profiles.get(sid, {}).get("match_mode") == "vibe":
        now = time.monotonic()
        if now - last_queue_heartbeat.get(sid, 0) < 10:
            return
        last_queue_heartbeat[sid] = now
        await matchmaker.heartbeat_vibe_queue(user.anonymous_username)

@sio.event
async def skip(sid, data=None):
    """Omegle-style Skip: disconnects current stranger and queues up for next partner immediately."""
    if not await _authenticated_user(sid):
        return False
    partner_id = remove_pairing(sid)
    if partner_id:
        # Inform the other stranger they were skipped
        await sio.emit('partner_disconnected', {
            'reason': 'Stranger skipped. Tap Skip to find someone new.',
            'was_skipped': True
        }, room=partner_id)
        logger.info(f"Socket: {sid} skipped partner {partner_id}")

    # Re-queue user immediately with cached metadata
    last_queue_join.pop(sid, None)
    await join_queue(sid, {"match_mode": user_profiles.get(sid, {}).get("match_mode", "random")})

@sio.event
async def chat_message(sid, data):
    """In-call real-time text chat between matched video chat partners."""
    partner_id = pairings.get(sid)
    if partner_id and await pair_is_eligible(sid, partner_id):
        text = str(data.get('text', '')).strip()
        if text:
            await sio.emit('chat_message', {
                'text': text,
                'sender': 'stranger',
                'timestamp': datetime.now(timezone.utc).isoformat()
            }, room=partner_id)

@sio.event
async def partner_typing(sid, data=None):
    """Relays typing indicator to video chat partner."""
    partner_id = pairings.get(sid)
    if partner_id and await pair_is_eligible(sid, partner_id):
        is_typing = data.get('is_typing', True) if data else True
        await sio.emit('partner_typing', {'is_typing': is_typing}, room=partner_id)

@sio.event
async def media_state(sid, data):
    """Relays camera/mic state changes (e.g. muted, camera off) to stranger."""
    partner_id = pairings.get(sid)
    if partner_id and data and await pair_is_eligible(sid, partner_id):
        await sio.emit('partner_media_state', data, room=partner_id)

@sio.event
async def report_partner(sid, data=None):
    """Reports stranger for misconduct, lowers trust score, and skips to next user."""
    data = data or {}
    reporter = await _authenticated_user(sid)
    if not reporter:
        return False
    now = time.monotonic()
    if now - last_socket_report.get(sid, 0) < 10:
        await sio.emit("report_confirmed", {"message": "Please wait before submitting another report."}, room=sid)
        return False
    last_socket_report[sid] = now
    reason = str(data.get('reason', 'Inappropriate behavior'))[:100]
    details = str(data.get('details', ''))[:500]
    partner_id = remove_pairing(sid)

    if partner_id:
        if not await pair_is_eligible(sid, partner_id):
            partner_id = None

    if partner_id:
        partner_meta = user_profiles.get(partner_id, {})

        try:
            from ..models.report import Report

            reported_username = partner_meta.get('username') or partner_id
            target = await User.find_one({"anonymous_username": reported_username})
            if target:
                duplicate = await Report.find_one({
                    "reporter_id": reporter.anonymous_username,
                    "reported_id": reported_username,
                    "content_id": None,
                    "status": "pending",
                })
                if not duplicate:
                    await Report(
                        reporter_id=reporter.anonymous_username,
                        reported_id=reported_username,
                        reason=f"Video chat: {reason}. {details}".strip(),
                    ).insert()
                logger.info("Video chat report registered.")
        except Exception:
            logger.error("Could not persist video chat report.")

        await sio.emit('partner_disconnected', {
            'reason': 'Stranger disconnected.',
            'was_reported': True
        }, room=partner_id)

    # Re-queue reporter immediately
    await sio.emit('report_confirmed', {
        'message': 'Report received. Searching for a new stranger...'
    }, room=sid)

    last_queue_join.pop(sid, None)
    await join_queue(sid, {"match_mode": user_profiles.get(sid, {}).get("match_mode", "random")})

@sio.event
async def offer(sid, data):
    partner_id = pairings.get(sid)
    if partner_id and await pair_is_eligible(sid, partner_id):
        await sio.emit('offer', data, room=partner_id)

@sio.event
async def answer(sid, data):
    partner_id = pairings.get(sid)
    if partner_id and await pair_is_eligible(sid, partner_id):
        await sio.emit('answer', data, room=partner_id)

@sio.event
async def ice_candidate(sid, data):
    partner_id = pairings.get(sid)
    if partner_id and await pair_is_eligible(sid, partner_id):
        await sio.emit('ice_candidate', data, room=partner_id)

@sio.event
async def end_call(sid, data=None):
    """Leaves active call completely."""
    if not await _authenticated_user(sid):
        return False
    partner_id = remove_pairing(sid)
    if partner_id:
        await sio.emit('partner_disconnected', {
            'reason': 'Stranger ended the call.',
            'was_ended': True
        }, room=partner_id)
    await matchmaker.remove_from_queue(sid)
    logger.info(f"Socket: {sid} ended call")

@sio.event
async def disconnect(sid):
    partner_id = remove_pairing(sid)
    if partner_id:
        await sio.emit('partner_disconnected', {
            'reason': 'Stranger disconnected.',
            'was_disconnected': True
        }, room=partner_id)
    await matchmaker.remove_from_queue(sid)
    user_profiles.pop(sid, None)
    socket_tokens.pop(sid, None)
    last_socket_report.pop(sid, None)
    last_queue_join.pop(sid, None)
    last_queue_heartbeat.pop(sid, None)
    logger.info(f"Socket: Disconnected {sid}")

# --- Voice Room Signaling ---

@sio.event
async def room_join(sid, data):
    user, room_id = await _authorized_room(sid, data)
    if user and room_id:
        await sio.enter_room(sid, room_id)
        await sio.emit('new_participant', {
            'user_id': sid,
            'username': user.anonymous_username,
        }, room=room_id, skip_sid=sid)
        logger.info(f"Socket: {sid} joined room {room_id}")

@sio.event
async def room_leave(sid, data):
    user, room_id = await _authorized_room(sid, data)
    if user and room_id:
        await sio.leave_room(sid, room_id)
        await sio.emit('participant_left', {'user_id': sid}, room=room_id)
        logger.info(f"Socket: {sid} left room {room_id}")

@sio.event
async def room_reaction(sid, data):
    user, room_id = await _authorized_room(sid, data)
    emoji = data.get('emoji')
    if user and room_id and emoji:
        await sio.emit('room_reaction', {
            'user_id': sid,
            'username': user.anonymous_username,
            'emoji': str(emoji)[:10],
        }, room=room_id)

@sio.event
async def hand_raised(sid, data):
    user, room_id = await _authorized_room(sid, data)
    raised = data.get('raised', False)
    if user and room_id:
        await sio.emit('hand_raised', {'user_id': sid, 'raised': raised}, room=room_id)

@sio.event
async def user_muted(sid, data):
    user, room_id = await _authorized_room(sid, data)
    muted = data.get('muted', False)
    if user and room_id:
        await sio.emit('user_muted', {'user_id': sid, 'muted': muted}, room=room_id)
