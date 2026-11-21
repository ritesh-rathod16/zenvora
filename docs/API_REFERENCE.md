# API Reference: Zenvora Backend

Base URL: `http://<host>:8000`

---

## 1. System & Health

### `GET /`
Returns service status, version, and database provider.
- **Response:**
  ```json
  {
    "status": "online",
    "version": "1.6.1",
    "database": "MongoDB Atlas"
  }
  ```

### `GET /health`
Returns connection status of MongoDB Atlas and platform services.
- **Response:**
  ```json
  {
    "status": "healthy",
    "database": {
      "status": "healthy",
      "database": "zenvora"
    }
  }
  ```

---

## 2. Authentication & Users

### `POST /auth/register`
Creates a new anonymous user account in MongoDB Atlas.
- **Request:**
  ```json
  {
    "real_name": "John Doe",
    "email": "user@example.com",
    "password": "SecretPassword123",
    "age": 22,
    "country": "US",
    "interests": ["tech", "music"]
  }
  ```
- **Response:** `200 OK`

### `POST /auth/login`
Authenticates user and returns JWT bearer token.
- **Request:**
  ```json
  {
    "email": "user@example.com",
    "password": "SecretPassword123"
  }
  ```
- **Response:**
  ```json
  {
    "access_token": "eyJhbGciOi...",
    "token_type": "bearer",
    "user": { ... }
  }
  ```

---

## 3. Vibe Matching

All user endpoints require `Authorization: Bearer <token>`.

### `GET /vibes`
Returns active backend-configured vibe categories and the caller's own active vibe, if any. Categories are seeded by the backend and remain editable by administrators.

### `PUT /vibes/me`
Sets an active vibe for two hours or clears it. `preferred_vibes` is an optional allow-list of other active vibe IDs; an empty list uses the configured compatibility rules.

```json
{
  "vibe_id": "deep-conversations",
  "preferred_vibes": ["late-night-talks", "want-to-talk"]
}
```

To clear the active vibe, send `{"vibe_id": null, "preferred_vibes": []}`. The server applies age eligibility, including an adult-only rule for `flirting`, and cancels any waiting vibe queue entry when the selection changes.

### `POST /vibes/catalog` and `PATCH /vibes/catalog/{vibe_id}`
Administrator-only endpoints for adding categories and updating labels, compatibility, fallback groups, minimum ages, order, or active status. Existing category IDs are not renamed or deleted, so saved preferences remain valid.

## 4. Media & CDN

### `GET /media/imagekit-auth`
Generates HMAC-SHA1 client upload authentication parameters for direct ImageKit CDN uploads.
- **Response:**
  ```json
  {
    "enabled": true,
    "token": "496f0325-2451-400d-859d-b70407f5a031",
    "expire": 1773000000,
    "signature": "a1b2c3d4e5...",
    "publicKey": "your_imagekit_public_key",
    "urlEndpoint": "https://ik.imagekit.io/your_id"
  }
  ```

### `GET /media/profile/{file_id}`
Serves profile pictures from MongoDB GridFS fallback.

### `GET /media/stories/{file_id}`
Serves story media from MongoDB GridFS fallback.

---

## 5. Realtime Socket.IO Events

Mounted at `/socket.io`.

| Event (Client -> Server) | Payload | Description |
| :--- | :--- | :--- |
| `join_queue` | `{"match_mode": "random"}` or `{"match_mode": "vibe"}` | Enters the authenticated user into the corresponding MongoDB `match_queue`; vibe details are read from the server-side active selection |
| `leave_queue` | `{}` | Removes user from `match_queue` |
| `queue_heartbeat` | `{}` | Renews the short presence lease for a waiting vibe search |
| `offer` | `{"sdp": "...", "type": "offer"}` | WebRTC signaling offer |
| `answer` | `{"sdp": "...", "type": "answer"}` | WebRTC signaling answer |
| `ice_candidate` | `{"candidate": "..."}` | WebRTC ICE candidate exchange |
| `rematch` | `{}` | Re-enters user into match queue immediately |

| Event (Server -> Client) | Payload | Description |
| :--- | :--- | :--- |
| `match_found` | `{"partner_id": "...", "role": "caller|receiver", "match_mode": "random|vibe"}` | Emitted when atomic match is finalized |
| `matchmaking_error` | `{"message": "..."}` | Reports an invalid or unavailable matchmaking request |
| `partner_disconnected` | `{}` | Emitted when partner leaves or disconnects |
