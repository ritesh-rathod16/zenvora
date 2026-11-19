# MongoDB Migration Plan: Supabase to MongoDB Atlas

**Project:** Zenvora - Anonymous Social Platform  
**Target:** Complete Elimination of Supabase Dependencies and Full Migration to MongoDB Atlas & ImageKit CDN  
**Status:** In Progress (Phase 1 Completed)

---

## 1. Existing Architecture Overview

Zenvora is an anonymous social platform with:
- **Mobile Client:** Flutter (Android, iOS, Web, Desktop) utilizing `http` for REST and `socket_io_client` for real-time WebSockets.
- **Backend Server:** Python FastAPI (version 1.6.1 in `models/app/main.py` and entry point `main.py`) running with Uvicorn.
- **Primary Database:** MongoDB Atlas via Motor and Beanie ODM for 16 models (`User`, `Chat`, `Message`, `Post`, `VoiceRoom`, `Report`, `Notification`, `AdminLog`, `PlatformSettings`, `Story`, `CallSession`, `GhostIdentity`, `Follow`, `FollowRequest`, `Swipe`, `Match`).
- **Legacy Secondary Database:** Supabase PostgreSQL used solely for a temporary `match_queue` table managed via `asyncpg` in `backend/models/app/core/supabase.py` and `matchmaking.py`.
- **Legacy Client Dependencies:** `supabase_flutter` initialized in `lib/main.dart` and URL inspection in `image_helper.dart` and `safe_avatar.dart`.
- **Media Storage:** MongoDB GridFS for file uploads (`/users/upload-profile-photo`, `/stories/upload`) with URL heuristics checking `supabase.co` for CDN transformations.

---

## 2. Complete Supabase Dependencies Audit

### 2.1 Backend Dependencies
| Location | Dep / Reference | Existing Usage | Replacement Strategy |
| :--- | :--- | :--- | :--- |
| `backend/.env` | `SUPABASE_DB_URL`, `SUPABASE_URL`, `SUPABASE_ANON_KEY` | Supabase PostgreSQL & API connection strings | Remove completely. Add ImageKit configuration. |
| `backend/requirements.txt` | `supabase==2.5.1`, `asyncpg==0.29.0`, `postgrest==...`, `storage3==...` | Direct Supabase & async PostgreSQL client | Remove all Supabase & PostgreSQL packages. Add `imagekitio`. |
| `backend/models/app/core/supabase.py` | `supabase-py`, `asyncpg` | Connects to PostgreSQL, runs DDL `CREATE TABLE match_queue` | Replace with native MongoDB `match_queue` collection and indexes in `backend/models/app/core/database.py`. Delete `supabase.py`. |
| `backend/models/app/services/matchmaking.py` | `asyncpg`, SQL queries (`SELECT ... FOR UPDATE SKIP LOCKED`, `INSERT ... ON CONFLICT`) | Transactional stranger matchmaking queue | Replace with atomic MongoDB `find_one_and_update`, leases, and optional multi-document transactions. |
| `backend/models/app/main.py` | `init_supabase_db`, `close_db_pool` | Startup & shutdown hooks for Supabase pool | Remove Supabase lifecycle hooks. Ensure MongoDB indexes and matchmaking worker initialize cleanly. |
| `backend/models/app/routers/admin.py` | `from ..services.matchmaking import matchmaker` | Unused import | Clean up import. |
| `backend/models/app/routers/media.py` | N/A | GridFS photo and story endpoints | Add ImageKit authentication endpoint (`/media/imagekit-auth`) and upload helper. |

### 2.2 Flutter Client Dependencies
| Location | Dep / Reference | Existing Usage | Replacement Strategy |
| :--- | :--- | :--- | :--- |
| `pubspec.yaml` | `supabase_flutter: ^2.5.6` | Client SDK dependency | Remove package completely from `pubspec.yaml`. |
| `lib/main.dart` | `Supabase.initialize(...)` | Startup initialization | Remove Supabase import and initialization. |
| `lib/core/utils/image_helper.dart` | `url.contains('supabase.co')` | Adds resizing/quality query parameters | Refactor to support ImageKit dynamic CDN transformations (`tr=w-...,q-...`), dicebear SVGs, and network fallbacks. |
| `lib/widgets/safe_avatar.dart` | `url.contains('supabase.co')` | Avatar URL query optimization | Delegate image URL optimization to `ImageHelper` with ImageKit transformations and caching. |

---

## 3. Database Schema Mapping & Architecture

### 3.1 Match Queue Entity (`match_queue` Collection)
Previously in PostgreSQL:
```sql
CREATE TABLE match_queue (
    user_id TEXT PRIMARY KEY,
    interests JSONB DEFAULT '[]'::jsonb,
    region TEXT DEFAULT 'Global',
    trust_score INT DEFAULT 100,
    status TEXT DEFAULT 'waiting',
    created_at TIMESTAMP DEFAULT now()
);
```

Migrated to MongoDB Document:
```json
{
  "_id": "ObjectId(...)",
  "user_id": "string (unique identifier / socket id)",
  "interests": ["string"],
  "region": "string (e.g. 'Global', 'US')",
  "trust_score": 100,
  "status": "waiting | claimed | matched | cancelled",
  "matched_with": "string | null",
  "matching_session_id": "string | null",
  "lease_expires_at": "ISODate | null",
  "created_at": "ISODate",
  "updated_at": "ISODate"
}
```

### 3.2 Required MongoDB Indexes
To support atomic matching with zero collection scans:
1. `{"user_id": 1}` — Unique constraint preventing duplicate user entries in queue.
2. `{"status": 1, "trust_score": -1, "created_at": 1}` — Compound index for fast candidate prioritization.
3. `{"status": 1, "region": 1, "interests": 1}` — Compound index for regional/interest matching.
4. `{"status": 1, "lease_expires_at": 1}` — Index for expired lease recovery worker.
5. `{"matching_session_id": 1}` — Index for atomic confirmation and claim rollback.

---

## 4. High-Concurrency Concurrency Strategy

### 4.1 Replacing `FOR UPDATE SKIP LOCKED`
MongoDB's `find_one_and_update` with filter conditions acts as an atomic row claim:
1. **Candidate Filter:**
   ```python
   {
       "user_id": {"$ne": user_id},
       "$or": [
           {"status": "waiting"},
           {"status": "claimed", "lease_expires_at": {"$lt": now}}
       ]
   }
   ```
2. **Atomic Claim Update:**
   ```python
   {
       "$set": {
           "status": "claimed",
           "matched_with": user_id,
           "matching_session_id": session_id,
           "lease_expires_at": now + timedelta(seconds=10),
           "updated_at": now
       }
   }
   ```
3. **Idempotency & Isolation:**
   - Both users are transitioned atomically to `"matched"`.
   - A `Match` record is recorded in MongoDB.
   - If candidate claiming or matching fails, the session releases the claim back to `"waiting"`.
   - Leases expire automatically after 10 seconds, guaranteeing no orphaned locks occur on process crash.

---

## 5. Image Storage & CDN Strategy (ImageKit)

- **Provider:** ImageKit (`ik.imagekit.io/<id>`).
- **Backend Authentication Endpoint:** `GET /media/imagekit-auth` returning HMAC-SHA1 signature, token, and expire timestamp for client-side uploads.
- **Backend Upload Fallback:** If ImageKit credentials are not yet entered in environment, backend gracefully persists to MongoDB GridFS.
- **Client CDN Transformations:**
  - Base ImageKit query parameters: `?tr=w-{width},q-{quality},f-auto`
  - WebP / AVIF format auto-negotiation via `f-auto`.
  - Fallback avatars: DiceBear avatar API with SVG / PNG rendering.

---

## 6. Migration Risks & Mitigations

| Risk | Impact | Mitigation |
| :--- | :--- | :--- |
| Concurrency race condition during matching | Duplicate or split matches | Atomic `find_one_and_update` with session ID claims and two-phase confirmation |
| Standalone MongoDB vs Replica Set | Transactions unavailable on unconfigured standalone DB | Implement two-phase atomic state machine that operates cleanly without requiring replica set transactions, with optional transaction support when replica set is detected |
| Stale matchmaking claims after worker restart | Users stuck in queue | Short lease expiration (10 seconds) with background claim recovery loop |
| Missing ImageKit keys in dev environment | Media uploads fail | Dual-mode backend storage: ImageKit when configured, MongoDB GridFS when keys are omitted |
| Flutter build break on package removal | App compilation errors | Remove `supabase_flutter` cleanly, update imports, run `flutter pub get` and static analysis |

---

## 7. Execution Phases

- [x] **Phase 1:** Complete codebase audit and migration plan documentation.
- [x] **Phase 2:** Design MongoDB models, schemas, and indexing routines.
- [x] **Phase 3:** Update MongoDB core database layer (`database.py`) and remove `supabase.py`.
- [x] **Phase 4:** Migrate matchmaking service (`matchmaking.py`) to native MongoDB atomic operations.
- [x] **Phase 5:** Implement ImageKit backend authentication and storage helper.
- [x] **Phase 6:** Refactor Flutter client (`image_helper.dart`, `safe_avatar.dart`, `main.dart`, `pubspec.yaml`).
- [x] **Phase 7:** Create data migration utility from Supabase to MongoDB (`scripts/migrate_supabase_to_mongo.py`).
- [x] **Phase 8:** Clean up environment configuration (`.env`, `.env.example`, `requirements.txt`).
- [x] **Phase 9:** Testing, verification, and benchmark validation.
- [x] **Phase 10:** Update architecture documentation and final migration report.
