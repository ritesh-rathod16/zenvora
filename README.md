# ZENVORA – Next-Gen Social Networking, Stories, Reposts, Tinder-Style Discover & Disappearing DM Platform

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.110.0-009688?logo=fastapi)](https://fastapi.tiangolo.com)
[![MongoDB Atlas](https://img.shields.io/badge/MongoDB_Atlas-Beanie_ODM-47A248?logo=mongodb)](https://www.mongodb.com/cloud/atlas)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Build Status](https://img.shields.io/badge/CI-Passing-brightgreen.svg)](#testing)

**ZENVORA** is a full-stack, cross-platform social networking application built with **Flutter** (Android, iOS, Web, Desktop) and **Python FastAPI** backed by **MongoDB Atlas** and **Beanie ODM**. 

Zenvora combines the best features of modern social platforms:
- **Instagram-Style Stories & Advanced Privacy Settings** (Close Friends, Hide Story From, Replies/Reactions delivered to DMs, Viewers Tracking, 24h Expiration).
- **Instagram-Style Complete Repost System** (One-tap Reposting, Reposts Profile Tab, Reference-based MongoDB Storage, Original Author Attribution).
- **Tinder-Style Discover People Swipe System** (Real Profile Cards, Swipe Right = Follow Request / Immediate Follow, Swipe Left = Skip, "Show Me" Gender Filtering: Everyone | Boys | Girls, Fast Server-Side Pagination & Caching).
- **Snapchat-Style Disappearing Messages & Advanced Chat Controls** (Three Message Modes: *Immediately Delete*, *Delete After 24 Hours*, *Never Delete*, Server-Side Background Expiration Worker, Message Receipts, Emoji Reactions, Reply to Messages).
- **Omegle-Style 1-on-1 WebRTC Video Chat & Matchmaking** (Atomic Concurrency Claims, LiveKit/WebSockets Signaling).
- **Live Audio Voice Rooms** (Interactive Audio Group Lounges with Room Energy Engine).
- **AI Moderation & Trust Score System** (Automatic Content Safety, Trust Score Rating, Admin Safety Console).

---

## 📐 System Architecture

```mermaid
graph TD
    subgraph Client Layer [Flutter App - Android, iOS, Web, Desktop]
        UI[Material 3 UI & Custom Themes]
        Feed[Home Feed & Stories]
        Discover[Discover Swipe Cards]
        Chat[Direct Messages & Chat Info]
        Video[WebRTC Video Chat]
        Voice[Audio Voice Rooms]
    end

    subgraph API Layer [FastAPI Backend Server]
        AuthRouter[/auth - JWT Auth & Verification]
        UserRouter[/users - Profiles & Settings]
        StoryRouter[/stories - Advanced Story Management]
        PostRouter[/posts - Feed & Reposts]
        DiscoverRouter[/discovery & /swipe - Tinder Swipe Engine]
        ChatRouter[/chats - DMs & Disappearing Messages]
        SocialRouter[/social - Follows & Requests]
        MediaRouter[/media - GridFS & ImageKit CDN]
        Worker[Disappearing Messages Worker]
    end

    subgraph Storage Layer [Data & Media Services]
        MongoDB[(MongoDB Atlas - Beanie ODM)]
        GridFS[(GridFS Storage)]
        Redis[(Redis Queue & Cache)]
    end

    UI --> AuthRouter
    UI --> UserRouter
    UI --> StoryRouter
    UI --> PostRouter
    UI --> DiscoverRouter
    UI --> ChatRouter
    UI --> SocialRouter
    UI --> MediaRouter

    ChatRouter --> Worker
    Worker --> MongoDB
    API Layer --> MongoDB
    MediaRouter --> GridFS
```

---

## ✨ Feature Deep Dive

### 1. Instagram-Style Advanced Stories
- **Dedicated Story Settings**: Navigation via `Profile → Settings → Privacy → Story Settings`.
- **Close Friends & Hide Story From**:
  - Select specific friends for exclusive close friends stories (indicated with a vibrant green gradient ring).
  - Select users to hide your stories from without blocking them.
- **Interaction Rules**:
  - Controls for who can reply (`Everyone`, `People I Follow`, `Nobody`) or send emoji reactions and likes.
  - Story replies and quick emoji reactions deliver directly into the story owner's DM with original story thumbnail context.
- **Story Viewer & Expiration**:
  - Full-screen story viewing with horizontal progress indicators, tap left/right, hold-to-pause, and swipe down to close.
  - Owner viewing sheet displaying viewer real profile photos, usernames, and like status.
  - Automatic 24-hour expiration filter.

### 2. Complete Repost System
- **Repost Button**:
  - Add a repost button to every post beside Like, Comment, and Share.
  - One-tap reposting saves a reference in MongoDB, increments repost counts, and notifies the original author.
  - Full support for undoing reposts.
- **Profile Integration**:
  - Profile tabs: **Posts** and **Reposts**.
  - Reposts tab displays all posts reposted by the user, showing *"Reposted from @username"*, original author photo, and direct profile navigation links.

### 3. Tinder-Style Discover People Swipe Engine
- **Swipe Interaction Rules**:
  - **SWIPE RIGHT**:
    - **Public Accounts**: Instantly follows the user and notifies them (*"Following @username"*).
    - **Private Accounts**: Creates a pending follow request and sends a notification (*"Follow Request Sent"*).
  - **SWIPE LEFT**:
    - Skips profile and saves to discovery history without notifying the recipient.
- **Show Me Gender Filters**:
  - Segmented gender selection: **`[ Everyone ]` `[ Boys ]` `[ Girls ]`**.
  - Persists preference locally and on the server, filtering database queries at the MongoDB layer.
- **Real Profile Cards**:
  - Displays real uploaded profile photos, display name, username, bio, interests, location/country, age, and compatibility score. Never uses fake/random avatars.
  - Supports mobile touch gestures, desktop mouse drag, Undo last swipe, and Reset discovery history.

### 4. Snapchat-Style Disappearing Messages & Advanced Chat Settings
- **Three Selectable Message Deletion Modes**:
  1. **Immediately Delete**: Messages disappear from both chat views immediately after being delivered and viewed by the recipient.
  2. **Delete After 24 Hours**: Messages automatically expire 24 hours after sending (`expires_at = created_at + 24h`).
  3. **Never Delete**: Messages remain stored until manually deleted.
- **Server-Side Background Expiration Worker**:
  - `DisappearingMessagesWorker` runs continuously in the background on FastAPI server to purge viewed immediate messages and expired 24h content.
- **Chat Information Page**:
  - Disappearing messages selector, custom chat theme picker, mute notifications toggle, block user, report conversation, and delete conversation options.
- **Rich Message Interactions**:
  - Send text, images, videos, voice notes, emoji reactions, reply to specific messages, view delivery (`✓✓`) and seen status (`✓✓` in cyan), and share posts/stories.

### 5. WebRTC Video Chat & Audio Voice Rooms
- **Omegle-Style Stranger Video Matching**: Live WebRTC video pairing with atomic claim lease concurrency.
- **Audio Voice Rooms**: Interactive voice group lounges with energy engine analytics.

---

## 🛠 Tech Stack

### Frontend (Flutter)
- **Framework**: Flutter 3.x (Dart 3.x)
- **Platforms**: Android, iOS, Web, Desktop (Windows, macOS, Linux)
- **Networking**: `http`, `flutter_secure_storage`, `socket_io_client`
- **UI Components**: `flutter_card_swiper`, `cached_network_image`, `shimmer`, `percent_indicator`, `google_fonts`
- **Audio/Video**: `just_audio`, `flutter_webrtc`, `image_picker`

### Backend (Python FastAPI)
- **Framework**: FastAPI (v1.6.1)
- **Database**: MongoDB Atlas using `motor` & `beanie` ODM
- **Realtime**: WebSockets & `python-socketio` (SIO)
- **Security**: PyJWT (HMAC-SHA256), Passlib (Bcrypt password hashing)
- **Rate Limiting**: `slowapi`

---

## 📁 Repository Directory Structure

```
Zenvora/
├── android/                    # Android Native Gradle Project
├── assets/                     # App Icons, Animations, Branding
├── backend/                    # FastAPI Server Application
│   ├── main.py                 # Backend Entry Point
│   ├── models/app/             # Core Backend Application
│   │   ├── main.py             # FastAPI App & Lifespan Workers
│   │   ├── core/               # Database Config, Security, Rate Limiter
│   │   ├── models/             # Beanie ODM Document Schemas
│   │   ├── routers/            # REST API Routers (Auth, Users, Stories, Posts, Chats, Swipe, Discovery, Social)
│   │   ├── services/           # Disappearing Messages Worker, Matchmaker, AI Moderation
│   │   └── websocket/          # Socket.IO Realtime Signaling
│   ├── scripts/                # Database Seeding & Admin Maintenance
│   └── tests/                  # Pytest Sanity & Integration Test Suite
├── ios/                        # iOS Native Xcode Project
├── lib/                        # Flutter Application Source Code
│   ├── main.dart               # App Entry Point & Router Config
│   ├── core/                   # API Constants, Auth Services, Image Helpers
│   ├── features/               # Modular Feature Architecture
│   │   ├── auth/               # Login, Register, Onboarding
│   │   ├── chat/               # Chat Inbox, Chat Screen, Chat Info Page
│   │   ├── discover/           # Tinder-Style Discovery Screen
│   │   ├── feed/               # Feed Screen, Post Card, Story Viewer, Story Section
│   │   ├── notifications/      # Notifications & Follow Requests
│   │   ├── posts/              # Post Creation & Management
│   │   ├── profile/            # Profile Screen, User Profile Screen, Story Settings, Chat Settings, Close Friends
│   │   ├── random_chat/        # Omegle WebRTC Video Matchmaking
│   │   └── rooms/              # Audio Voice Rooms
│   └── widgets/                # Reusable UI Widgets (SafeAvatar, PremiumAvatar)
├── test/                       # Flutter Unit & Widget Tests
├── docker-compose.yml          # Containerized Environment Configuration
├── README.md                   # Project Overview & Quick Start
├── LICENSE                     # MIT Open Source License
├── CODE_OF_CONDUCT.md          # Contributor Covenant Code of Conduct
└── SECURITY.md                 # Security Policy & Vulnerability Disclosure
```

---

## 🚀 Quick Start Guide

### Prerequisites
- [Flutter SDK 3.x+](https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.19.0-stable.zip)
- [Python 3.10+](https://www.python.org/downloads/)
- [MongoDB Atlas Account](https://www.mongodb.com/cloud/atlas) or local MongoDB instance

---

### Backend Setup

1. **Navigate to the backend directory**:
   ```bash
   cd backend
   ```

2. **Set up Python Virtual Environment**:
   ```bash
   python -m venv venv
   
   # On Windows PowerShell:
   .\venv\Scripts\Activate.ps1
   
   # On Linux/macOS:
   source venv/bin/activate
   ```

3. **Install Dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

4. **Configure Environment Variables**:
   Copy `.env.example` to `.env` and populate your MongoDB URI:
   ```env
   MONGODB_URL=mongodb+srv://<username>:<password>@cluster0.mongodb.net/zenvora?retryWrites=true&w=majority
   DATABASE_NAME=zenvora
   JWT_SECRET=your_super_secret_key_change_in_production

   ```

5. **Seed Test Accounts & Initial Community Data**:
   ```bash
   python scripts/seed_data.py
   ```

6. **Start FastAPI Backend**:
   ```bash
python -m uvicorn models.app.main:app --host 0.0.0.0 --port 8000 --reload
   ```
   Backend will be running on `http://localhost:8000` (API docs available at `http://localhost:8000/docs`).

---

### Frontend Setup (Flutter)

1. **Navigate to project root directory**:
   ```bash
   cd Zenvora
   ```

2. **Fetch Packages**:
   ```bash
   flutter pub get
   ```

3. **Configure Host IP**:
   Check `lib/core/constants/api_constants.dart` for target host mapping (e.g., `10.0.2.2` for Android Emulator or your local Wi-Fi IP for real devices).

4. **Run Application**:
   ```bash
   flutter run
   ```

---

## 🧪 Testing

### Backend Integration Test Suite
Run the automated backend test suite covering Auth, Story Settings, Reposts, Swipe Discovery, Follow Requests, and Disappearing Messages:
```bash
python -m pytest backend/tests/test_new_features.py -v
```

### Flutter Code Health Analysis
Run the Flutter analyzer to verify type safety and zero static warnings:
```bash
flutter analyze
```

---

## 👥 Pre-configured Test Accounts

| Email | Username | Role | Gender | Features |
| :--- | :--- | :--- | :--- | :--- |
| `zenvora@gmail.com` | `@ZenvoraMaster` | Super Admin | Male | Admin Dashboard & Platform Controls |
| `luna@zenvora.com` | `@LunaEcho` | User | Female | Active Stories, Posts, Close Friends |
| `cipher@zenvora.com` | `@CyberShadow` | User | Male | Active Posts, Follow Requests |
| `aurora@zenvora.com` | `@AuroraBorealis` | User | Female | Stories, Posts, High Trust Score |
| `pixel@zenvora.com` | `@PixelKnight` | User | Male | Gaming Posts, Voice Rooms |
| `velvet@zenvora.com` | `@VelvetVibe` | User | Female | Vinyl & Design Posts, Stories |

*Default Password for test accounts*: `Password123!` (Master Admin password: `qwertyuiop`).

---

## 📄 License & Governance

- **License**: [MIT License](LICENSE)
- **Code of Conduct**: [Contributor Covenant v2.1](CODE_OF_CONDUCT.md)
- **Security Policy**: [SECURITY.md](SECURITY.md)

---

<p center="align">
  <b>ZENVORA</b> &copy; 2026 Zenvora Team. Built with ❤️ for seamless, privacy-first social connections.
</p>
