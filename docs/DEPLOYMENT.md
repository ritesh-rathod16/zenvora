# ZENVORA - Production Deployment Guide

## 1. Environment Configuration
Create a `.env` file in the `backend/` directory based on `.env.example`:

```env
ENVIRONMENT=production
MONGODB_URL=mongodb+srv://<username>:<password>@cluster.mongodb.net/zenvora?retryWrites=true&w=majority
DATABASE_NAME=zenvora
SECRET_KEY=your_production_secure_secret_key_here
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=1440
ADMIN_EMAIL=zenvora@gmail.com
ADMIN_PASSWORD=your_secure_admin_password
CORS_ORIGINS=https://zenvora.app
```

---

## 2. Docker Compose Deployment
ZENVORA includes a production-ready `docker-compose.yml` file orchestration Redis and FastAPI backend.

1. **Build and Start Containers**:
   ```bash
   docker-compose up -d --build
   ```
2. **Verify Health Check**:
   ```bash
   curl http://localhost:8000/health/ready
   ```
3. **View Logs**:
   ```bash
   docker-compose logs -f backend
   ```

---

## 3. Flutter Release Build
1. **Clean Project**:
   ```bash
   flutter clean
   flutter pub get
   ```
2. **Build Android App Bundle**:
   ```bash
   flutter build appbundle --release
   ```
3. **Build iOS App**:
   ```bash
   flutter build ios --release
   ```
