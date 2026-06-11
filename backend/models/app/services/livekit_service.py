import os
import asyncio
import logging
from datetime import timedelta
from typing import Optional, List
from livekit import api
from dotenv import load_dotenv

# Setup logging for production-ready monitoring
logger = logging.getLogger(__name__)

load_dotenv()

class LiveKitService:
    def __init__(self):
        self.url = os.getenv("LIVEKIT_URL", "http://localhost:7880")
        self.api_key = os.getenv("LIVEKIT_API_KEY", "devkey")
        self.api_secret = os.getenv("LIVEKIT_API_SECRET", "secret")

    def create_token(
        self, 
        room_name: str, 
        participant_identity: str, 
        participant_name: Optional[str] = None,
        is_admin: bool = False,
        is_speaker: bool = True
    ) -> str:
        """
        Generates a secure JWT token for a participant to join a voice room.
        Fixed: Uses datetime.timedelta for TTL to prevent TypeError in livekit-api SDK.
        """
        try:
            # Plural VideoGrants is required for the latest livekit-api
            grants = api.VideoGrants(
                room_join=True,
                room=room_name,
                can_publish=is_speaker,
                can_subscribe=True,
                can_publish_data=True,
                room_admin=is_admin,
            )

            # CORRECT IMPLEMENTATION: ttl must be a timedelta object, not an integer.
            token = api.AccessToken(self.api_key, self.api_secret) \
                .with_identity(participant_identity) \
                .with_name(participant_name or participant_identity) \
                .with_grants(grants) \
                .with_ttl(timedelta(hours=1)) 

            generated_jwt = token.to_jwt()
            logger.info(f"LiveKit: Token generated for {participant_identity} in room {room_name}")
            return generated_jwt
            
        except Exception as e:
            logger.error(f"LiveKit Token Generation Failure: {str(e)}")
            raise Exception(f"Failed to generate LiveKit access token: {str(e)}")

    async def create_room(self, name: str, empty_timeout: int = 300, max_participants: int = 1000):
        """
        Explicitly creates a room via the LiveKit server API.
        """
        lk_api = api.LiveKitAPI(self.url, self.api_key, self.api_secret)
        try:
            room = await lk_api.room.create_room(
                api.CreateRoomRequest(
                    name=name,
                    empty_timeout=empty_timeout,
                    max_participants=max_participants
                )
            )
            logger.info(f"LiveKit: Room '{name}' successfully created.")
            return room
        except Exception as e:
            logger.error(f"LiveKit Room Creation Error: {str(e)}")
            raise e
        finally:
            await lk_api.aclose()

    async def list_rooms(self) -> List[api.Room]:
        """
        Lists all active rooms currently running on the SFU.
        """
        lk_api = api.LiveKitAPI(self.url, self.api_key, self.api_secret)
        try:
            res = await lk_api.room.list_rooms(api.ListRoomsRequest())
            return res.rooms
        except Exception as e:
            logger.error(f"LiveKit List Rooms Error: {str(e)}")
            return []
        finally:
            await lk_api.aclose()

    async def end_room(self, room_name: str):
        """
        Alias for delete_room - terminates a session immediately.
        """
        await self.delete_room(room_name)

    async def delete_room(self, room_name: str):
        """
        Deletes a room and kicks all participants.
        """
        lk_api = api.LiveKitAPI(self.url, self.api_key, self.api_secret)
        try:
            await lk_api.room.delete_room(api.DeleteRoomRequest(room=room_name))
            logger.info(f"LiveKit: Room '{room_name}' has been terminated by administrator.")
        except Exception as e:
            logger.error(f"LiveKit Room Deletion Error: {str(e)}")
            raise e
        finally:
            await lk_api.aclose()

    async def remove_participant(self, room_name: str, identity: str):
        """
        Removes a specific participant from a room.
        """
        lk_api = api.LiveKitAPI(self.url, self.api_key, self.api_secret)
        try:
            await lk_api.room.remove_participant(
                api.RoomParticipantIdentity(room=room_name, identity=identity)
            )
            logger.info(f"LiveKit: Kicked participant {identity} from room {room_name}")
        except Exception as e:
            logger.error(f"LiveKit Participant Removal Error: {str(e)}")
            raise e
        finally:
            await lk_api.aclose()

    async def mute_participant(self, room_name: str, identity: str, track_sid: str, muted: bool = True):
        """
        Forces a mute/unmute on a specific track for a participant.
        """
        lk_api = api.LiveKitAPI(self.url, self.api_key, self.api_secret)
        try:
            await lk_api.room.mute_published_track(
                api.MuteRoomTrackRequest(
                    room=room_name,
                    identity=identity,
                    track_sid=track_sid,
                    muted=muted
                )
            )
            logger.info(f"LiveKit: Admin {'muted' if muted else 'unmuted'} track {track_sid} for {identity}")
        except Exception as e:
            logger.error(f"LiveKit Track Mute Error: {str(e)}")
            raise e
        finally:
            await lk_api.aclose()

# Global service instance
livekit_service = LiveKitService()
