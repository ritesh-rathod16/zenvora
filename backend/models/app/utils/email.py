import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import os
import logging
import random
from dotenv import load_dotenv

load_dotenv()

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

SMTP_SERVER = os.getenv("SMTP_SERVER")
SMTP_PORT = os.getenv("SMTP_PORT")
SMTP_LOGIN = os.getenv("SMTP_LOGIN")
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD")
EMAIL_FROM = os.getenv("EMAIL_FROM", SMTP_LOGIN)

# Check if configuration is loaded correctly
if all([SMTP_SERVER, SMTP_PORT, SMTP_LOGIN, SMTP_PASSWORD]):
    logger.info("SMTP configuration loaded successfully.")
    SMTP_PORT = int(SMTP_PORT)
else:
    logger.error("SMTP configuration is missing in environment variables.")

def generate_otp():
    return "".join([str(random.randint(0, 9)) for _ in range(6)])

async def send_otp_email(email: str, otp: str):
    if not all([SMTP_SERVER, SMTP_PORT, SMTP_LOGIN, SMTP_PASSWORD]):
        logger.error("Email not sent: SMTP credentials not configured.")
        return

    subject = f"{otp} is your Zenvora verification code"
    
    body = f"""
    <html>
        <body style="font-family: Arial, sans-serif; background-color: #0F0F1A; color: white; padding: 20px;">
            <div style="max-width: 600px; margin: auto; background-color: #1A1A2E; padding: 40px; border-radius: 10px; border: 1px solid #6C63FF;">
                <h2 style="color: #6C63FF; text-align: center;">Zenvora Verification</h2>
                <p>Hello,</p>
                <p>Use the following 6-digit code to verify your account. This code will expire soon.</p>
                <div style="text-align: center; margin: 30px 0;">
                    <span style="font-size: 32px; font-weight: bold; letter-spacing: 5px; color: #6C63FF; background: #0F0F1A; padding: 10px 20px; border-radius: 5px;">{otp}</span>
                </div>
                <p>If you didn't request this code, you can safely ignore this email.</p>
                <br>
                <p>Stay Anonymous. Stay Connected.</p>
            </div>
        </body>
    </html>
    """
    
    msg = MIMEMultipart()
    msg['From'] = EMAIL_FROM
    msg['To'] = email
    msg['Subject'] = subject
    msg.attach(MIMEText(body, 'html'))

    try:
        with smtplib.SMTP(SMTP_SERVER, SMTP_PORT) as server:
            server.starttls()
            server.login(SMTP_LOGIN, SMTP_PASSWORD)
            server.send_message(msg)
            logger.info(f"OTP email sent successfully to {email}")
    except Exception as e:
        logger.error(f"Failed to send OTP email to {email}: {str(e)}")
        raise e
