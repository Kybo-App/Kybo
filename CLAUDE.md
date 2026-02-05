# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Kybo is a diet management platform for nutritionists and clients with four components:
- **client/** - Flutter mobile app (iOS/Android) for viewing diets, tracking meals, chatting
- **admin/** - Flutter web app for nutritionists/admins to manage users, upload diets, view analytics
- **server/** - Python FastAPI backend with Firebase + Google Gemini AI integration
- **landing/** - Next.js marketing site with GSAP animations

## Development Commands

### Client App (Flutter Mobile)
```bash
cd client && flutter pub get
flutter run --flavor dev              # Run dev flavor on device
flutter run --flavor prod             # Run prod flavor on device
flutter build apk --flavor dev        # Android dev build
flutter build apk --flavor prod --release  # Android prod release
flutter build ios --flavor prod --release  # iOS prod release
```

### Admin Panel (Flutter Web)
```bash
cd admin && flutter pub get
flutter run -d chrome                 # Run in browser
flutter build web --release           # Production build
```

### Backend (FastAPI)
```bash
cd server && pip install -r requirements.txt
uvicorn app.main:app --reload         # Local dev server
```

### Landing Page (Next.js)
```bash
cd landing && npm install
npm run dev                           # Local dev server
npm run build                         # Production build
npm run lint                          # Run ESLint
```

## Architecture

**Data Flow**: Client/Admin → FastAPI → Firebase (Auth/Firestore/Storage) + Gemini AI (diet parsing) + Tesseract (receipt OCR)

**Auth dependencies** (in `server/app/core/dependencies.py`):
- `verify_token` - any authenticated user
- `verify_admin` - admin role only
- `verify_professional` - admin OR nutritionist roles
- `get_current_uid` - returns current user's UID

**User roles**: `client` | `nutritionist` | `admin` | `independent`

**API Base URLs**:
- Dev: `https://kybo-test.onrender.com`
- Prod: `https://kybo.onrender.com`
- Client reads from `Env.apiUrl` (.env), Admin from `ApiService.baseUrl`

## Key Patterns

### Flutter State Management
Both apps use Provider with ChangeNotifier. Providers in `lib/providers/`, services in `lib/services/`.

### Design System
Both apps use pill-shaped UI components from `lib/widgets/design_system.dart`:
- **Admin**: Uses `KyboColors` static getters (e.g., `KyboColors.background`) and widgets (`PillCard`, `PillButton`, `PillTextField`, `PillBadge`, `StatCard`)
- **Client**: Uses `KyboColors` with context for dark mode (e.g., `KyboColors.background(context)`) - requires `ThemeProvider`
- Colors are synchronized between both apps (same hex values)

### Firestore Collections
```
users/{uid}           → role, email, parent_id (nutritionist), custom_parser_prompt
  └── diets/current   → Active diet (encrypted)
  └── diets/{id}      → Historical diets (encrypted)
chats/{chatId}        → participants, chatType, unreadCount
  └── messages/{id}   → message, senderId, timestamp, attachmentUrl?
diet_history/{id}     → userId, uploadedBy, parsedData
config/global         → maintenance_mode, scheduled_maintenance_start
access_logs/{id}      → Audit trail for PII access
gemini_cache/{hash}   → AI response cache (30-day TTL)
```

### Backend Services
- Diet parsing: PDF → pdfplumber → Gemini AI (gemini-2.5-flash) with GDPR sanitization
- Receipt scanning: Image → Tesseract OCR (Italian) → Gemini fuzzy matching
- Caching: L1 in-memory (100 entries, 1h) + L2 Firestore (30 days)
- Rate limiting: slowapi with IP + user ID composite key

## Environment Variables

### Backend (server/.env)
```
FIREBASE_CREDENTIALS={"type":"service_account",...}
STORAGE_BUCKET=your-bucket.appspot.com
SENTRY_DSN=https://...@sentry.io/...
```

### Flutter Apps (.env)
```
API_URL=https://kybo-test.onrender.com
```

## Commit Convention
```
type(scope): description

Types: feat, fix, refactor, docs, style, test, chore
Scopes: client, admin, server, landing

## Important Notes
- Always work on `dev` branch, not production
- Client diet data is AES-256 encrypted at rest
- Always push to `dev` branch once a task is finished
- No test suite currently exists - feature roadmap includes adding tests
- See `TODO.md` for feature roadmap
