# Kybo - Project Context for Claude Code

## Overview
Kybo is a diet management platform for nutritionists and their clients. It consists of:
- **Client App**: Flutter mobile app (iOS/Android) for end users to view diets, track meals, chat with nutritionists
- **Admin Panel**: Flutter web app for nutritionists/admins to manage users, upload diets, chat, view analytics
- **Backend API**: Python FastAPI server with Firebase integration
- **Landing Page**: Static marketing site

## Tech Stack

| Component | Technology |
|-----------|------------|
| Client App | Flutter 3.5+, Dart, Firebase Auth/Firestore/Messaging |
| Admin Panel | Flutter Web, same libraries |
| Backend | Python 3.11+, FastAPI, Firebase Admin SDK, OpenAI API |
| Database | Firebase Firestore |
| Storage | Firebase Storage (for PDFs, images) |
| Auth | Firebase Authentication |
| Hosting | Render (backend), Firebase Hosting (landing) |

## Project Structure

```
Kybo/
├── client/           # Flutter mobile app
│   ├── lib/
│   │   ├── models/       # Data models (User, Diet, ChatMessage, etc.)
│   │   ├── providers/    # State management (ChangeNotifier providers)
│   │   ├── screens/      # UI screens
│   │   ├── services/     # API services
│   │   ├── widgets/      # Reusable widgets
│   │   └── core/         # Design system (KyboColors, etc.)
│   └── pubspec.yaml
│
├── admin/            # Flutter web admin panel
│   ├── lib/
│   │   ├── models/       # Shared/admin-specific models
│   │   ├── providers/    # Admin state management
│   │   ├── screens/      # Admin screens (dashboard, users, chat, etc.)
│   │   ├── services/     # Admin API services
│   │   └── widgets/      # Design system (PillCard, PillButton, etc.)
│   └── pubspec.yaml
│
├── server/           # FastAPI backend
│   ├── app/
│   │   ├── main.py           # App entry point, router registration
│   │   ├── core/
│   │   │   ├── config.py     # Settings (env vars)
│   │   │   ├── firebase.py   # Firebase Admin SDK init
│   │   │   └── security.py   # Auth dependencies (verify_admin, verify_professional)
│   │   ├── routers/          # API endpoints by domain
│   │   │   ├── admin.py      # User management
│   │   │   ├── analytics.py  # Analytics endpoints
│   │   │   ├── auth.py       # Authentication
│   │   │   ├── chat.py       # Chat & attachments
│   │   │   ├── diet.py       # Diet CRUD & parsing
│   │   │   └── ...
│   │   └── services/         # Business logic
│   └── requirements.txt
│
├── landing/          # Static landing page
│   └── public/
│
├── TODO.md           # Task roadmap (feature-based)
└── README.md         # Setup instructions
```

## Design System

### Admin Panel (Pill-shaped design)
- **Colors**: Use `KyboColors` from `widgets/design_system.dart`
  - `KyboColors.primary` - Green (#2E7D32)
  - `KyboColors.surface` - White cards
  - `KyboColors.text` - Dark text
  - `KyboColors.textLight` - Secondary text
  - `KyboColors.error` - Red for errors
  - `KyboColors.warning` - Orange for warnings

- **Widgets**:
  - `PillCard` - Container with rounded corners (radius 24)
  - `PillButton` - Primary action button
  - `PillTextField` - Text input
  - `PillBadge` - Status badges
  - `StatCard` - Metric display card

### Client App
- **Colors**: Use `KyboColors.background(context)` - context-aware for dark mode
- Similar widget patterns adapted for mobile

## Key Patterns

### Authentication & Authorization
```python
# Backend: Two auth levels
from app.core.security import verify_admin, verify_professional

@router.get("/admin-only")
async def admin_only(user=Depends(verify_admin)):  # Only role="admin"
    ...

@router.get("/both-roles")
async def both_roles(user=Depends(verify_professional)):  # admin OR nutritionist
    ...
```

### Firestore Structure
```
users/{uid}
  ├── role: "client" | "nutritionist" | "admin"
  ├── email, displayName, ...
  └── assigned_nutritionist: uid (for clients)

diets/{dietId}
  ├── userId, nutritionistId
  ├── meals: [...]
  └── createdAt, updatedAt

chats/{chatId}
  ├── participants: [uid1, uid2]
  └── messages/{messageId}
        ├── senderId, text, timestamp
        └── attachmentUrl?, attachmentType?, fileName?
```

### API Base URLs
- **Client**: `Env.apiUrl` from `.env` file
- **Admin**: `ApiService.baseUrl` configured in code
- **Production**: `https://kybo-api.onrender.com`

## Useful Commands

### Client App
```bash
cd client
flutter pub get
flutter run                    # Run on connected device
flutter build apk --release    # Build Android APK
flutter build ios --release    # Build iOS
```

### Admin Panel
```bash
cd admin
flutter pub get
flutter run -d chrome          # Run in browser
flutter build web --release    # Build for deployment
```

### Backend
```bash
cd server
pip install -r requirements.txt
uvicorn app.main:app --reload  # Local development
```

### Git
```bash
git status
git add <files>
git commit -m "type(scope): message"
git push origin <branch>
```

## Environment Variables

### Backend (server/.env or Render)
```
OPENAI_API_KEY=sk-...
FIREBASE_CREDENTIALS={"type":"service_account",...}
STORAGE_BUCKET=your-bucket.appspot.com
SENTRY_DSN=https://...@sentry.io/...
```

### Client (client/.env)
```
API_URL=https://kybo-api.onrender.com
```

## Commit Convention
```
type(scope): description

Types: feat, fix, refactor, docs, style, test, chore
Scopes: client, admin, server, landing
```

## Current Task List
See `TODO.md` for the full roadmap organized by feature.
