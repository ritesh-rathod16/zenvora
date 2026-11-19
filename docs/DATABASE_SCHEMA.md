# Database Schema Reference: MongoDB Atlas

This document outlines the collections, document structures, and indexes configured in MongoDB Atlas for Zenvora.

---

## 1. Collections Overview

| Collection | Model Class | Description |
| :--- | :--- | :--- |
| `users` | `User` | User profiles, authentication credentials, trust scores, roles, and settings |
| `match_queue` | `MatchQueue` | Real-time stranger matchmaking queue with atomic lease management |
| `matches` | `Match` | Persisted pairing history between matched anonymous users |
| `chats` | `Chat` | Direct conversation threads between paired users |
| `messages` | `Message` | Individual encrypted or ephemeral messages, view-once media |
| `posts` | `Post` | Ephemeral community posts with auto-expiration (24-hour TTL) |
| `voice_rooms` | `VoiceRoom` | Live audio rooms, participant status, and speaker permissions |
| `reports` | `Report` | User moderation reports, reason codes, and resolution status |
| `stories` | `Story` | 24-hour user stories and GridFS/CDN media identifiers |
| `admin_logs` | `AdminLog` | Audit trail for administrator actions, user bans, and broadcasts |
| `platform_settings` | `PlatformSettings` | Dynamic platform configuration and feature flags |
| `notifications` | `Notification` | In-app user notifications and alerts |
| `follows` | `Follow` | Social following relationships |
| `follow_requests` | `FollowRequest` | Pending follow requests for private profiles |
| `swipes` | `Swipe` | Discovery swipe history (likes, passes) |
| `call_sessions` | `CallSession` | WebRTC audio/video call metadata and timestamps |
| `ghost_identities` | `GhostIdentity` | Ephemeral anonymous identity masks and personas |

---

## 2. Match Queue Schema (`match_queue`)

```json
{
  "_id": { "$oid": "6640c4a17b2f6e91a01b9201" },
  "user_id": "sid_9812739123",
  "interests": ["anime", "gaming", "music"],
  "region": "US",
  "trust_score": 98,
  "status": "waiting",
  "matched_with": null,
  "matching_session_id": null,
  "lease_expires_at": null,
  "created_at": { "$date": "2026-11-10T23:50:00.000Z" },
  "updated_at": { "$date": "2026-11-10T23:50:00.000Z" }
}
```

### Indexes:
1. `{"user_id": 1}` — Unique constraint preventing duplicate active queue entries.
2. `{"status": 1, "trust_score": -1, "created_at": 1}` — Prioritized candidate pool scan.
3. `{"status": 1, "region": 1}` — Regional matching filter.
4. `{"status": 1, "lease_expires_at": 1}` — Expired lease recovery routine.
5. `{"matching_session_id": 1}` — Atomic claim resolution and rollback.

---

## 3. Matches Schema (`matches`)

```json
{
  "_id": { "$oid": "6640c5b37b2f6e91a01b9202" },
  "user1": "sim_user_0",
  "user2": "sim_user_8",
  "created_at": { "$date": "2026-11-10T23:51:00.000Z" }
}
```

---

## 4. Users Schema (`users`)

```json
{
  "_id": { "$oid": "6640c6c57b2f6e91a01b9203" },
  "real_name": "Anonymous User",
  "email": "user@example.com",
  "anonymous_username": "NeonPhantom",
  "password_hash": "$2b$12$...",
  "age": 24,
  "country": "Germany",
  "interests": ["tech", "philosophy"],
  "trust_score": 100,
  "role": "user",
  "is_admin": false,
  "is_active": true,
  "is_banned": false,
  "avatar_url": "https://ik.imagekit.io/zenvora/avatar123.jpg",
  "created_at": { "$date": "2026-11-01T12:00:00.000Z" }
}
```

### Indexes:
1. `{"email": 1}` — Unique index for account identity.
2. `{"anonymous_username": 1}` — Unique index for anonymous identity.
3. `{"role": 1, "is_banned": 1}` — Filter for discovery feed candidate pools.
