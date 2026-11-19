import socketio
import logging
from datetime import datetime, timezone
from ..services.matchmaking import matchmaker

logger = logging.getLogger(__name__)
sio = socketio.AsyncServer(async_mode='asgi', cors_allowed_origins='*')
sio_app = socketio.ASGIApp(sio)

# Key: sid, Value: partner_sid
pairings = {}

# Key: sid, Value: user profile dict
user_profiles = {}

def set_pairing(sid1: str, sid2: str):
    """Pair two sockets for bidirectional WebRTC and chat signaling."""
    pairings[sid1] = sid2
    pairings[sid2] = sid1
    logger.info(f"Socket Pair Established: {sid1} <-> {sid2}")

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
    data = data or {}
    interests = data.get('interests', [])
    region = data.get('region', 'Global')
    trust_score = data.get('trust_score', 100)
    username = data.get('username', 'Stranger')
    country = data.get('country', 'Global')
    avatar_url = data.get('avatar_url', '')

    # Cache user profile on socket connection
    user_profiles[sid] = {
        'username': username,
        'country': country,
        'interests': interests,
        'trust_score': trust_score,
        'avatar_url': avatar_url,
    }

    await matchmaker.add_to_queue(sid, interests, region, trust_score)

    # Attempt immediate matchmaking
    partner_id = await matchmaker.find_match(sid)

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
        }, room=sid)

        # Receiver receives match info
        await sio.emit('match_found', {
            'partner_id': sid,
            'role': 'receiver',
            'partner_username': u_caller.get('username', 'Stranger'),
            'partner_country': u_caller.get('country', 'Global'),
            'partner_avatar': u_caller.get('avatar_url', ''),
            'common_interests': common,
        }, room=partner_id)
    else:
        logger.info(f"Socket: {sid} ({username}) is now waiting in queue...")
        await sio.emit('searching', {'status': 'waiting'}, room=sid)

@sio.event
async def leave_queue(sid, data=None):
    await matchmaker.remove_from_queue(sid)
    remove_pairing(sid)
    logger.info(f"Socket: {sid} left queue")

@sio.event
async def skip(sid, data=None):
    """Omegle-style Skip: disconnects current stranger and queues up for next partner immediately."""
    partner_id = remove_pairing(sid)
    if partner_id:
        # Inform the other stranger they were skipped
        await sio.emit('partner_disconnected', {
            'reason': 'Stranger skipped. Tap Skip to find someone new.',
            'was_skipped': True
        }, room=partner_id)
        logger.info(f"Socket: {sid} skipped partner {partner_id}")

    # Re-queue user immediately with cached metadata
    cached = user_profiles.get(sid, {})
    await join_queue(sid, cached)

@sio.event
async def chat_message(sid, data):
    """In-call real-time text chat between matched video chat partners."""
    partner_id = pairings.get(sid)
    if partner_id:
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
    if partner_id:
        is_typing = data.get('is_typing', True) if data else True
        await sio.emit('partner_typing', {'is_typing': is_typing}, room=partner_id)

@sio.event
async def media_state(sid, data):
    """Relays camera/mic state changes (e.g. muted, camera off) to stranger."""
    partner_id = pairings.get(sid)
    if partner_id and data:
        await sio.emit('partner_media_state', data, room=partner_id)

@sio.event
async def report_partner(sid, data=None):
    """Reports stranger for misconduct, lowers trust score, and skips to next user."""
    data = data or {}
    reason = data.get('reason', 'Inappropriate behavior')
    details = data.get('details', '')
    partner_id = remove_pairing(sid)

    if partner_id:
        partner_meta = user_profiles.get(partner_id, {})
        reporter_meta = user_profiles.get(sid, {})

        try:
            from ..models.report import Report
            from ..models.user import User

            reported_username = partner_meta.get('username') or partner_id
            reporter_username = reporter_meta.get('username') or sid

            rep = Report(
                reporter_id=reporter_username,
                reported_id=reported_username,
                reason=f"Omegle VC Report: {reason}. {details}".strip()
            )
            await rep.insert()

            if reported_username and reported_username != partner_id:
                target = await User.find_one({"anonymous_username": reported_username})
                if target:
                    target.trust_score = max(0, target.trust_score - 15)
                    await target.save()

            logger.info(f"Video Chat Report registered against {reported_username} by {reporter_username}")
        except Exception as e:
            logger.error(f"Error persisting video chat report: {e}", exc_info=True)

        await sio.emit('partner_disconnected', {
            'reason': 'Stranger disconnected.',
            'was_reported': True
        }, room=partner_id)

    # Re-queue reporter immediately
    await sio.emit('report_confirmed', {
        'message': 'Report received. Searching for a new stranger...'
    }, room=sid)

    cached = user_profiles.get(sid, {})
    await join_queue(sid, cached)

@sio.event
async def offer(sid, data):
    partner_id = pairings.get(sid)
    if partner_id:
        await sio.emit('offer', data, room=partner_id)

@sio.event
async def answer(sid, data):
    partner_id = pairings.get(sid)
    if partner_id:
        await sio.emit('answer', data, room=partner_id)

@sio.event
async def ice_candidate(sid, data):
    partner_id = pairings.get(sid)
    if partner_id:
        await sio.emit('ice_candidate', data, room=partner_id)

@sio.event
async def end_call(sid, data=None):
    """Leaves active call completely."""
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
    logger.info(f"Socket: Disconnected {sid}")

# --- Voice Room Signaling ---

@sio.event
async def room_join(sid, data):
    room_id = data.get('room_id')
    if room_id:
        await sio.enter_room(sid, room_id)
        await sio.emit('new_participant', {'user_id': sid, 'username': data.get('username', 'Ghost')}, room=room_id, skip_sid=sid)
        logger.info(f"Socket: {sid} joined room {room_id}")

@sio.event
async def room_leave(sid, data):
    room_id = data.get('room_id')
    if room_id:
        await sio.leave_room(sid, room_id)
        await sio.emit('participant_left', {'user_id': sid}, room=room_id)
        logger.info(f"Socket: {sid} left room {room_id}")

@sio.event
async def room_reaction(sid, data):
    room_id = data.get('room_id')
    emoji = data.get('emoji')
    if room_id and emoji:
        await sio.emit('room_reaction', {'user_id': sid, 'emoji': emoji}, room=room_id)

@sio.event
async def hand_raised(sid, data):
    room_id = data.get('room_id')
    raised = data.get('raised', False)
    if room_id:
        await sio.emit('hand_raised', {'user_id': sid, 'raised': raised}, room=room_id)

@sio.event
async def user_muted(sid, data):
    room_id = data.get('room_id')
    muted = data.get('muted', False)
    if room_id:
        await sio.emit('user_muted', {'user_id': sid, 'muted': muted}, room=room_id)
