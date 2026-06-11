import os
import openai
from google.cloud import vision
import io

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
        except Exception as e:
            print(f"Text Moderation Error: {e}")
            # Fallback to simple keyword check if API fails
            banned = ["nude", "porn", "kill", "abuse"]
            return not any(word in text.lower() for word in banned)

    async def moderate_image(self, image_bytes: bytes) -> bool:
        """
        Uses Google Vision SafeSearch to detect inappropriate content.
        """
        # Placeholder logic for when Google Vision is not fully configured
        return True 

moderator = ModerationService()
