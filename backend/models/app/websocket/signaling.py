import socketio
import logging
from ..services.matchmaking import matchmaker

logger = logging.getLogger(__name__)
sio = socketio.AsyncServer(async_mode='asgi', cors_allowed_origins='*')
sio_app = socketio.ASGIApp(sio)

# Key: sid, Value: partner_sid
pairings = {}

@sio.event
async def connect(sid, environ):
    logger.info(f"Socket: Connected {sid}")

@sio.event
async def join_queue(sid, data=None):
    """Event triggered when user hits 'Start Chat'"""
    interests = data.get('interests', []) if data else []
    region = data.get('region', 'Global') if data else 'Global'
    trust_score = data.get('trust_score', 0) if data else 0
    
    await matchmaker.add_to_queue(sid, interests, region, trust_score)
    
    # Attempt immediate matchmaking
    partner_id = await matchmaker.find_match(sid)
    
    if partner_id:
        pairings[sid] = partner_id
        pairings[partner_id] = sid
        
        # Signaling: Tell Caller to generate Offer, Receiver to wait
        await sio.emit('match_found', {'partner_id': partner_id, 'role': 'caller'}, room=sid)
        await sio.emit('match_found', {'partner_id': sid, 'role': 'receiver'}, room=partner_id)
    else:
        logger.info(f"Socket: {sid} is now waiting...")

@sio.event
async def leave_queue(sid, data=None):
    await matchmaker.remove_from_queue(sid)
    logger.info(f"Socket: {sid} left queue")

@sio.event
async def offer(sid, data):
    if sid in pairings:
        await sio.emit('offer', data, room=pairings[sid])

@sio.event
async def answer(sid, data):
    if sid in pairings:
        await sio.emit('answer', data, room=pairings[sid])

@sio.event
async def ice_candidate(sid, data):
    if sid in pairings:
        await sio.emit('ice_candidate', data, room=pairings[sid])

@sio.event
async def rematch(sid, data=None):
    """Fast recovery: if P2P fails, user can request a rematch immediately."""
    # Clean up old pairing
    if sid in pairings:
        partner_id = pairings[sid]
        await sio.emit('partner_disconnected', room=partner_id)
        if partner_id in pairings: del pairings[partner_id]
        del pairings[sid]
    
    # Re-join queue
    await join_queue(sid, data)

@sio.event
async def disconnect(sid):
    await matchmaker.remove_from_queue(sid)
    if sid in pairings:
        partner_id = pairings[sid]
        await sio.emit('partner_disconnected', room=partner_id)
        if partner_id in pairings:
            del pairings[partner_id]
        del pairings[sid]
    logger.info(f"Socket: Disconnected {sid}")

# --- Voice Room Signaling ---

@sio.event
async def room_join(sid, data):
    room_id = data.get('room_id')
    if room_id:
        sio.enter_room(sid, room_id)
        # Notify others in the room
        await sio.emit('new_participant', {'user_id': sid, 'username': data.get('username', 'Ghost')}, room=room_id, skip_sid=sid)
        logger.info(f"Socket: {sid} joined room {room_id}")

@sio.event
async def room_leave(sid, data):
    room_id = data.get('room_id')
    if room_id:
        sio.leave_room(sid, room_id)
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
