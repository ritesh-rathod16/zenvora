import os
import openai
from google.cloud import vision
import io
import logging

logger = logging.getLogger(__name__)

class ModerationService:
    def __init__(self):
        self.openai_client = openai.OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
        # self.vision_client = vision.ImageAnnotatorClient() # Uncomment when credentials set

    async def moderate_text(self, text: str) -> bool:
        """
        Returns True if text is safe, False if flagged.
        """
        try:
            response = self.openai_client.moderations.create(input=text)
            output = response.results[0]
            return not output.flagged
        except Exception:
            logger.warning("Text moderation provider failed.")
            return False

    async def moderate_image(self, image_bytes: bytes) -> bool:
        """
        Uses Google Vision SafeSearch to detect inappropriate content.
        """
        # Placeholder logic for when Google Vision is not fully configured
        return True 

moderator = ModerationService()
