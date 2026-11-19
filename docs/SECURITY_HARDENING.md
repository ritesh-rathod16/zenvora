# Zenvora — Security Hardening Documentation

This document summarizes the DevSecOps controls, network security configurations, and rate-limiting rules implemented in the Zenvora platform.

---

## 1. Android Network Security

- **Cleartext Prohibition:** Release builds strictly set `android:usesCleartextTraffic="false"` and enforce `network_security_config.xml`.
- **Debug Exceptions:** Isolated debug-only configuration (`android/app/src/debug/AndroidManifest.xml`) permits local HTTP connections strictly during development.
- **WSS & HTTPS:** All API calls and WebSocket connections must use encrypted protocols in production (`https://` and `wss://`).

---

## 2. API Rate Limiting & Anti-Spam Controls

Integrated `slowapi` rate limiting with Redis/Memory strategy:

| Route Path | Rate Limit | Protection Focus |
| :--- | :--- | :--- |
| `POST /auth/register` | `10/minute` | Account creation abuse |
| `POST /auth/login` | `10/minute` | Brute force password guessing |
| `POST /posts/create` | `5/minute` | Post spamming / DDoS |
| `POST /swipe` | `20/minute` | Automated swipe botting |
| `POST /posts/{id}/like` | `30/minute` | Like manipulation |

When limit is exceeded, server responds with `HTTP 429 Too Many Requests` and sets `Retry-After: 60`.

---

## 3. Secret Management & Production Validation

- **Startup Guardrails:** Centralized settings validation (`backend/models/app/core/config.py`) checks that mandatory variables (`SECRET_KEY`, `ADMIN_PASSWORD`, `MONGODB_URL`) are configured and fail-fast if default insecure values are detected in `ENVIRONMENT=production`.
- **Git Hygiene:** Credentials, `.env`, `key.properties`, and `upload-keystore.jks` are explicitly excluded in `.gitignore`.

---

## 4. LiveKit SFU Security

- **Server-Side Token Minting:** LiveKit API secrets (`LIVEKIT_API_SECRET`) remain strictly on the backend.
- **Short-Lived Room Tokens:** Tokens expire after 1 hour (`with_ttl(timedelta(hours=1))`).
- **Anonymized Identity:** Tokens use Ghost Identity aliases (`ghost_service`) rather than sensitive database IDs.
