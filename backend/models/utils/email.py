import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import os

BREVO_SMTP_SERVER = os.getenv("BREVO_SMTP_SERVER")
BREVO_SMTP_PORT = int(os.getenv("BREVO_SMTP_PORT", "587"))
BREVO_SMTP_LOGIN = os.getenv("BREVO_SMTP_LOGIN")
BREVO_SMTP_KEY = os.getenv("BREVO_SMTP_KEY")

def send_verification_email(email: str, token: str):
    if not BREVO_SMTP_LOGIN or not BREVO_SMTP_KEY:
        print("SMTP settings not configured. Skipping email.")
        return

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
    except Exception as e:
        print(f"Failed to send email: {e}")
