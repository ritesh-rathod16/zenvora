# Zenvora - Anonymous Social Platform

Zenvora is a production-ready anonymous social platform built with Flutter and FastAPI. It focuses on privacy, ephemeral messaging, and safe stranger discovery.

## Features

- **Privacy-First**: No real names shown, random anonymous IDs, and AI-generated avatars.
- **Messaging**: End-to-end feel with "View Once" media and auto-delete timers.
- **Discovery**: Match with strangers based on interests or random swipes.
- **Voice Rooms**: Join anonymous audio group chats.
- **Anonymous Posts**: Share thoughts that disappear after 24 hours.
- **AI Moderation**: Automated detection of NSFW content and harassment.
- **Trust Score**: Users are rated based on their behavior to ensure a safe community.

## Tech Stack

- **Frontend**: Flutter
- **Backend**: Python FastAPI
- **Database**: MongoDB Atlas (with Beanie ODM)
- **Realtime**: WebSockets
- **Caching/Task Queue**: Redis & Celery
- **Email**: Brevo SMTP

## Setup Instructions

### Backend

1. Navigate to the `backend` directory.
2. Create a virtual environment: `python -m venv venv`.
3. Activate it: `source venv/bin/activate` (or `venv\Scripts\activate` on Windows).
4. Install dependencies: `pip install -r requirements.txt`.
5. Ensure Redis is running locally.
6. Start the server: `uvicorn main:app --reload`.

### Frontend (Flutter)

1. Navigate to the `zenvora` root directory.
2. Run `flutter pub get`.
3. Update `lib/core/constants/api_constants.dart` with your local IP or backend URL.
4. Run the app: `flutter run`.

## Admin Panel
- Access the Admin features by logging in with `zenvora@gmail.com` / `zenvora@2026`.
- Admin panel backend routes are prefixed with `/reports/admin`.

## Security
- JWT for Authentication.
- Bcrypt for Password Hashing.
- Content Moderation via automated filters.
