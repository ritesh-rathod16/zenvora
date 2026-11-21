import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import os
import logging

BREVO_SMTP_SERVER = os.getenv("BREVO_SMTP_SERVER")
BREVO_SMTP_PORT = int(os.getenv("BREVO_SMTP_PORT", "587"))
BREVO_SMTP_LOGIN = os.getenv("BREVO_SMTP_LOGIN")
BREVO_SMTP_KEY = os.getenv("BREVO_SMTP_KEY")
logger = logging.getLogger(__name__)

def send_verification_email(email: str, token: str):
    if not BREVO_SMTP_LOGIN or not BREVO_SMTP_KEY:
        logger.error("Verification email delivery is unavailable because SMTP is not configured.")
        raise RuntimeError("Verification email delivery is not configured.")

    subject = "Verify your Zenvora Account"
    body = f"Click the link to verify your account: http://localhost:8000/auth/verify?token={token}"
    
    message = MIMEMultipart()
    message["From"] = BREVO_SMTP_LOGIN
    message["To"] = email
    message["Subject"] = subject
    message.attach(MIMEText(body, "plain"))

    try:
        with smtplib.SMTP(BREVO_SMTP_SERVER, BREVO_SMTP_PORT) as server:
            server.starttls()
            server.login(BREVO_SMTP_LOGIN, BREVO_SMTP_KEY)
            server.send_message(message)
    except Exception:
        logger.error("Verification email delivery failed.")
        raise
