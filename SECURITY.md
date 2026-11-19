# Security Policy

## Reporting a Vulnerability

ZENVORA takes security and user privacy seriously. If you discover a security vulnerability within ZENVORA, please do NOT open a public issue on GitHub. Instead, follow our responsible disclosure protocol:

1. Send an email detailing the security issue to **zenvora@gmail.com**.
2. Include a description of the vulnerability, steps to reproduce, and any proof-of-concept code or screenshots.
3. Our security team will acknowledge receipt of your report within **24 hours** and provide periodic updates as we address the issue.

---

## Security Architecture & Best Practices in ZENVORA

### 1. Authentication & Session Management
- **Stateless JWT Tokens**: Signed using HMAC-SHA256 with expiration enforcement.
- **Password Protection**: Passwords hashed using `passlib` with strong Bcrypt work factors. Plaintext passwords are never logged or stored.
- **Secure Storage**: On mobile devices, authentication tokens are stored securely in `FlutterSecureStorage` (iOS Keychain & Android KeyStore/EncryptedSharedPreferences).

### 2. Disappearing Messages & Data Retention
- **Automated Server Cleanup**: The backend runs a dedicated background task (`DisappearingMessagesWorker`) that enforces server-side expiration for 24-hour and immediately deleted messages.
- **Receipt Isolation**: Once a message meets deletion criteria, content is purged from database queries and storage.

### 3. Rate Limiting & Abuse Prevention
- **API Protection**: Endpoints use `slowapi` rate-limiting decorators (e.g. login, post creation, swiping) to prevent brute-force attacks and credential stuffing.
- **Atomic Concurrency Control**: Matchmaking and swipe actions use MongoDB atomic claim leases to prevent race conditions and duplicate relationships.

### 4. Media & Input Sanitation
- **File Validation**: Image and media uploads are validated by mime-type and processed with PIL image thumbnailing to strip malicious metadata and prevent memory exhaustion attacks.
- **Privacy Enforcement**: Strict MongoDB query-level filtering prevents unauthorized access to private accounts, stories hidden from specific users, and close-friends-only content.
