# Zenvora — Android Release & Google Play Store Guide

This guide describes how to configure release signing, build Android App Bundles (AAB), and publish Zenvora to the Google Play Store.

---

## 1. Package Configuration

- **Application ID:** `com.zenvora.app`
- **Minimum SDK:** API 21 (Android 5.0)
- **Target SDK:** API 34+
- **Cleartext Traffic:** Disabled (`usesCleartextTraffic="false"` in release builds, governed by `@xml/network_security_config`).

---

## 2. Generate Release Keystore

Generate an upload keystore locally (keep this secure and out of source control):

```bash
keytool -genkey -v -keystore android/upload-keystore.jks \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -alias upload
```

---

## 3. Configure Release Signing Credentials

Create `android/key.properties` (this file is excluded from Git in `.gitignore`):

```properties
storePassword=YOUR_STRONG_STORE_PASSWORD
keyPassword=YOUR_STRONG_KEY_PASSWORD
keyAlias=upload
storeFile=../upload-keystore.jks
```

---

## 4. Build Release Artifacts

Execute clean build and generate Play Store Android App Bundle (AAB):

```bash
# Clean previous build cache
flutter clean
flutter pub get

# Validate code static analysis
flutter analyze

# Run test suite
flutter test

# Generate Android App Bundle for Play Store submission
flutter build appbundle --release
```

Output location:
`build/app/outputs/bundle/release/app-release.aab`

---

## 5. Play Store Checklist

- [x] Application ID updated to `com.zenvora.app`
- [x] Cleartext HTTP traffic blocked for production release
- [x] Production keystore signing configured
- [x] Privacy policy provided for anonymous features
- [x] Content rating questionnaire prepared (17+ for anonymous social/chat)
- [x] App Bundle built and verified
