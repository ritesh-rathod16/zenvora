# Zenvora — Production Deployment Guide

This document outlines the step-by-step procedures for deploying the Zenvora FastAPI backend and MongoDB Atlas / Redis infrastructure in a production environment using 100% Free & Open-Source technologies.

---

## 1. Architecture Overview

- **Mobile Client:** Flutter Android (`com.zenvora.app`)
- **API Backend:** Python 3.12 + FastAPI + Uvicorn (ASGI) + Socket.IO
- **Database:** MongoDB Atlas (M0 Free Tier) with Beanie ODM connection pooling
- **Rate Limiting & Cache:** Redis 7 (Alpine) + `slowapi`
- **Voice Rooms:** LiveKit Open-Source SFU Server (Self-Hosted / Free tier)
- **CDN / Media Storage:** ImageKit (20GB Free Tier) with GridFS failover

---

## 2. Prerequisites

- Docker 24.0+ & Docker Compose 2.20+
- A MongoDB Atlas M0 cluster URI
- Domain name pointing to your production server (e.g., `api.zenvora.app`)
- SSL Certificate (e.g., via Let's Encrypt / Certbot)

---

## 3. Environment Setup

Create `/app/backend/.env` based on `.env.example`:

```env
ENVIRONMENT=production

# Database (MongoDB Atlas)
MONGODB_URL=mongodb+srv://<user>:<password>@cluster0.mongodb.net/zenvora?retryWrites=true&w=majority
DATABASE_NAME=zenvora

# Secrets (Generate using: python -c "import secrets; print(secrets.token_hex(32))")
SECRET_KEY=e83921...
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=1440

# Master Admin
ADMIN_EMAIL=admin@zenvora.app
ADMIN_PASSWORD=Complex_Admin_Password_2026!

# LiveKit SFU
LIVEKIT_URL=https://livekit.zenvora.app
LIVEKIT_API_KEY=your_livekit_api_key
LIVEKIT_API_SECRET=your_livekit_api_secret

# Redis Cache
REDIS_URL=redis://redis:6379

# CORS
CORS_ORIGINS=https://zenvora.app,https://admin.zenvora.app
```

---

## 4. Docker Deployment

To launch the backend and Redis services:

```bash
# Build and start containers in detached mode
docker-compose up -d --build

# Inspect container status
docker-compose ps

# Monitor logs
docker-compose logs -f backend
```

---

## 5. Health Check Verification

Verify system readiness:

```bash
# Liveness Check
curl http://localhost:8000/health

# Readiness Check (verifies DB connectivity)
curl http://localhost:8000/health/ready
```

Expected readiness output:
```json
{
  "status": "ready",
  "database": "connected"
}
```

---

## 6. Nginx Reverse Proxy with HTTPS & WSS

Deploy Nginx to handle SSL termination and proxy WebSockets:

```nginx
server {
    server_name api.zenvora.app;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /socket.io/ {
        proxy_pass http://127.0.0.1:8000/socket.io/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host $host;
    }
}
```
