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

## 3. Media & CDN

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

## 4. Realtime Socket.IO Events

Mounted at `/socket.io`.

| Event (Client -> Server) | Payload | Description |
| :--- | :--- | :--- |
| `join_queue` | `{"interests": [...], "region": "US", "trust_score": 100}` | Enters user into MongoDB `match_queue` |
| `leave_queue` | `{}` | Removes user from `match_queue` |
| `offer` | `{"sdp": "...", "type": "offer"}` | WebRTC signaling offer |
| `answer` | `{"sdp": "...", "type": "answer"}` | WebRTC signaling answer |
| `ice_candidate` | `{"candidate": "..."}` | WebRTC ICE candidate exchange |
| `rematch` | `{}` | Re-enters user into match queue immediately |

| Event (Server -> Client) | Payload | Description |
| :--- | :--- | :--- |
| `match_found` | `{"partner_id": "...", "role": "caller|receiver"}` | Emitted when atomic match is finalized |
| `partner_disconnected` | `{}` | Emitted when partner leaves or disconnects |
