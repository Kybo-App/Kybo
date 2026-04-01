# Kybo

**Kybo** is a comprehensive wellness and nutrition management platform that integrates diet plans, workout schedules, and a professional marketplace. It connects clients, nutritionists, personal trainers, and administrators through a unified ecosystem merging a mobile app, an admin dashboard, AI-powered backends, and a gamified reward system.

---

## Architecture

```
                    Landing Page (Next.js)
                           |
            +--------------+--------------+
            |                             |
     Client App (Flutter)         Admin Webapp (Flutter Web)
            |                             |
            +----------+  +--------------+
                       |  |
                  FastAPI Backend
                       |
              +--------+--------+
              |        |        |
          Firebase   Gemini   Tesseract
          (Auth,     (AI      (OCR)
          Firestore,  Parsing)
          FCM)
```

| Project   | Stack                        | Purpose                              |
|-----------|------------------------------|--------------------------------------|
| `client/` | Flutter (iOS/Android)        | End-user mobile app                  |
| `admin/`  | Flutter Web                  | Dashboard for admins & nutritionists |
| `server/` | Python FastAPI               | API, AI parsing, auth validation     |
| `landing/`| Next.js + GSAP               | Marketing website                    |

---

## Features

### Client App

**Diet Management**
- Upload PDF diet plans parsed by Gemini AI into structured daily meal plans
- View meals organized by day with dynamic tab navigation (auto-selects today)
- Meal substitution system with nutritionist-defined alternatives (CAD code-based)
- Consume meals and track which ingredients are used from pantry
- Diet history with restore, delete, and share capabilities
- "Tranquil Mode" to hide calorie information for mental health

**Pantry / Inventory**
- Add items manually with name, quantity, and unit (g, ml, pz, vasetto, fette)
- Scan grocery receipts with AI-powered OCR to bulk-add items
- Automatic availability calculation (which meals can be prepared with current stock)
- Unit conversion dialogs when pantry units differ from recipe units

**Smart Shopping List**
- Generate shopping lists from diet plan (select specific days and meals)
- Automatic ingredient aggregation across meals
- Pantry stock deduction (only shows what you actually need)
- Check-off items and move them to pantry in one tap

**Chat System**
- Real-time messaging with assigned nutritionist via Firestore
- Unread message badges and read receipts
- Participant-based security rules

**Notifications**
- Push notifications via Firebase Cloud Messaging (diet ready alerts)
- Local meal reminder alarms (configurable per meal type, timezone-aware)
- Weekly recurring schedules

**Security & Privacy**
- AES-256 encryption for diet data at rest (user-unique keys, random IV)
- Jailbreak/root detection with security warning
- Firebase Authentication (email/password + Google OAuth)
- GDPR-compliant data handling

**Offline-First Architecture**
- Full offline functionality via SharedPreferences caching
- Smart sync with 3-hour cloud backup intervals
- Firestore persistence with unlimited local cache

**Onboarding**
- Guided tutorial system (ShowCaseWidget) highlighting key features
- Role-aware descriptions (independent user vs nutritionist client)
- Resettable from Settings

---

### Admin Webapp

**User Management**
- Create, edit, and delete users with role assignment
- Roles: Admin, Nutritionist, Personal Trainer, Independent, Client
- Assign/unassign clients to nutritionists
- Force password change on account creation
- Grouped view: clients organized under their nutritionist
- Privacy masking: PII hidden by default, unlock requires audit log entry

**Diet Management**
- Upload PDF diets for any managed user
- Browse diet history with timestamps and structured preview
- Delete specific diet uploads
- Custom AI parser configuration per nutritionist (upload .txt prompt)

**Workout Management**
- Assign workout plans and exercise routines to clients
- Role-based modular UI (Nutritionists see diets, Personal Trainers see workouts)
- Build workouts using an integrated exercise library
- Track client workout completion and performance

**Rewards & Gamification Engine**
- Manage a dynamic rewards catalog (real or virtual prizes)
- Set custom items purchasable by clients using earned XP
- Track claimed rewards and user progress

**Marketplace & Matchmaking**
- Review matchmaking requests from independent users seeking guidance
- Filter prospective clients based on goals, budget, and location tags
- Send consultation offers to convert independent users into managed clients

**Chat System**
- Two chat types: admin-nutritionist support, nutritionist-client communication
- Real-time messaging with unread badges
- Admin can create new support chats with nutritionists
- Role-based message filtering and unread tracking

**System Configuration (Admin only)**
- Manual maintenance mode toggle with broadcast message
- Scheduled maintenance with date/time picker and user notifications
- Real-time system status display

**Audit & Compliance (Admin only)**
- Real-time audit log streaming (last 100 entries)
- Tracks: data access, user creation/deletion/updates
- Color-coded actions (access=orange, delete=red, create=green, update=blue)
- CSV export for compliance reporting

**Role-Based Access Control**
- Admin: full access to all features
- Nutritionist: manages only assigned clients, no system config or audit access
- Non-staff roles blocked from webapp login

---

### Backend (FastAPI)

**Diet Parsing**
- PDF text extraction via pdfplumber (stream-based, no disk storage)
- Gemini AI structured output: weekly plan, substitution tables, dynamic config
- GDPR sanitization before AI processing (strips emails, tax codes, phone numbers, names, addresses)
- Two-level caching: L1 in-memory (100 entries, 1h TTL) + L2 Firestore (30 days)
- Custom parser prompts per nutritionist for different PDF formats
- Concurrency control: max 2 simultaneous heavy tasks

**Receipt Scanning**
- Tesseract OCR (Italian language)
- Gemini fuzzy matching against user's allowed food list
- Cost optimization: max 500 foods in context window

**User Management API**
- Full CRUD with Firebase Auth + Firestore sync
- Role hierarchy enforcement (nutritionists can only create clients)
- Cascading GDPR deletion (user doc + subcollections + auth record)
- User sync endpoint for Firebase Auth <-> Firestore consistency

**Security**
- JWT token verification via Firebase Admin SDK
- Rate limiting with slowapi (IP + user ID composite key)
- File validation via magic bytes (PDF, JPG, PNG, WebP)
- 10MB file size limit
- Environment-based CORS (dev/staging/prod origins)
- Structured logging with PII sanitization (tokens, emails redacted)

**Maintenance System**
- Immediate toggle or scheduled activation
- FCM broadcast to `all_users` topic
- Background worker checks schedule every 60 seconds

---

### Landing Page

**Home Page**
- GSAP letter-by-letter hero animation with ScrollTrigger
- Feature cards grid (diet tracking, smart shopping, virtual pantry, statistics)
- Circular stats display (users, satisfaction, time saved, waste reduced)
- Horizontal scroll gallery with phone mockups
- CTA section with App Store / Google Play buttons
- Lenis smooth scrolling with custom easing

**Business Page (Nutritionists)**
- Professional features showcase (patient management, diet upload, history, security)
- Three pricing tiers: Starter (20 patients), Professional (unlimited), Enterprise (custom)
- Demo request CTA

---

## User Stories

### Independent User
1. Signs up with email or Google account
2. Uploads PDF diet plan received from nutritionist
3. Views daily meals with ingredients and quantities
4. Adds pantry items manually or scans grocery receipt
5. Generates shopping list for the week, sees only what's missing
6. Checks off purchased items, moves them to pantry
7. Consumes meals; pantry quantities update automatically
8. Swaps foods using nutritionist-approved substitutions
9. Sets meal reminder alarms for each meal type
10. Views and completes daily workout plans assigned by Personal Trainers
11. Earns XP via meals and workouts, unlocking custom rewards from the Shop
12. Uses the Matchmaking feature to find a Nutritionist or PT based on goals and budget
13. Toggles "Tranquil Mode" to hide calories when needed

### Client (Assigned to Nutritionist)
1. Receives account from nutritionist with temporary password
2. Changes password on first login
3. Diet plans uploaded directly by nutritionist appear automatically
4. Chats with nutritionist in real-time for questions
5. All data encrypted and synced to cloud

### Nutritionist
1. Logs into admin webapp
2. Creates client accounts with temporary passwords
3. Uploads custom parser configuration for their PDF format
4. Uploads PDF diets for each client
5. Chats with clients for follow-up support
6. Views client diet history and progress
7. Receives admin support via admin-nutritionist chat

### Personal Trainer
1. Logs into admin webapp with adapted UI for workouts
2. Creates and assigns workout plans to clients
3. Manages incoming client matchmaking requests
4. Configures custom XP rewards for their clients to redeem

### Administrator
1. Full user management: creates admins, nutritionists, independents
2. Assigns/unassigns clients between nutritionists
3. Unlocks masked PII with mandatory audit logging
4. Monitors system via audit log with CSV export
5. Controls maintenance mode (immediate or scheduled)
6. Provides support to nutritionists via chat

---

## Data Model

### Firestore Collections

```
/users/{uid}
  - email, firstName, lastName, role, tags, is_nutritionist, is_personal_trainer
  - parent_id (nutritionist/PT UID, if client)
  - requires_password_change
  - platform, createdAt
  - custom_parser_prompt
  - xp_total, xp_today
  └── /diets/current          # Active diet plan (encrypted)
  └── /diets/{auto-id}        # Historical versions (encrypted)
  └── /workouts/{auto-id}     # Assigned workout plans
  └── /claimed_rewards/       # Redeemed rewards history

/chats/{chatId}
  - participants: {clientId, nutritionistId}
  - chatType: 'admin-nutritionist' | 'nutritionist-client'
  - lastMessage, lastMessageTime, lastMessageSender
  - unreadCount: {client: N, nutritionist: N}
  - clientName, clientEmail
  └── /messages/{msgId}
      - message, senderId, senderType
      - timestamp, read

/diet_history/{docId}
  - userId, uploadedBy, uploadedAt
  - fileName, parsedData

/config/global
  - maintenance_mode, maintenance_message
  - is_scheduled, scheduled_maintenance_start

/access_logs/{auto-id}
  - requester_id, target_uid, action, reason, timestamp

/gemini_cache/{contentHash}
  - result, cached_at (30-day TTL)

/rewards_catalog/{itemId}
  - title, description, cost_xp, is_active, quantity_available

/matchmaking_requests/{reqId}
  - user_id, goal, budget, location, status

---

## Tech Stack

| Layer          | Technology                                    |
|----------------|-----------------------------------------------|
| Mobile App     | Flutter, Provider, SharedPreferences          |
| Admin Webapp   | Flutter Web, Provider                         |
| Landing Page   | Next.js 14, GSAP, Lenis                       |
| Backend        | Python, FastAPI, Uvicorn                       |
| AI / NLP       | Google Gemini (gemini-2.5-flash)               |
| OCR            | Tesseract (Italian)                            |
| Auth           | Firebase Authentication, Google OAuth          |
| Database       | Cloud Firestore                                |
| Push           | Firebase Cloud Messaging                       |
| Encryption     | AES-256 (encrypt package)                      |
| Hosting        | Render (backend), Firebase (rules/indexes)     |
| Rate Limiting  | slowapi                                        |
| Logging        | structlog (JSON, sanitized)                    |

---

## API Endpoints

### Diet
| Method | Path                        | Auth     | Description                          |
|--------|-----------------------------|----------|--------------------------------------|
| POST   | `/upload-diet`              | user     | Upload PDF diet for self             |
| POST   | `/upload-diet/{target_uid}` | pro      | Upload PDF diet for managed user     |
| POST   | `/scan-receipt`             | user     | Scan receipt image for pantry items  |

### User Management
| Method | Path                           | Auth     | Description                       |
|--------|--------------------------------|----------|-----------------------------------|
| POST   | `/admin/create-user`           | pro      | Create new user account           |
| PUT    | `/admin/update-user/{uid}`     | admin    | Update user details               |
| DELETE | `/admin/delete-user/{uid}`     | pro      | Delete user and all data (GDPR)   |
| POST   | `/admin/assign-user`           | admin    | Assign client to nutritionist     |
| POST   | `/admin/unassign-user`         | admin    | Remove client assignment          |
| POST   | `/admin/sync-users`            | admin    | Sync Firebase Auth with Firestore |
| DELETE | `/admin/delete-diet/{diet_id}` | pro      | Delete diet history entry         |

### Admin / Config
| Method | Path                                  | Auth  | Description                     |
|--------|---------------------------------------|-------|---------------------------------|
| GET    | `/admin/config/maintenance`           | admin | Get maintenance status          |
| POST   | `/admin/config/maintenance`           | admin | Toggle maintenance mode         |
| POST   | `/admin/schedule-maintenance`         | admin | Schedule maintenance window     |
| POST   | `/admin/cancel-maintenance`           | admin | Cancel scheduled maintenance    |
| POST   | `/admin/upload-parser/{uid}`          | admin | Upload custom parser config     |
| POST   | `/admin/log-access`                   | pro   | Log PII data access             |
| GET    | `/admin/user-history/{uid}`           | pro   | Get user diet history           |
| GET    | `/admin/users-secure`                 | pro   | List users (role-filtered)      |
| GET    | `/admin/user-details-secure/{uid}`    | pro   | Get user details                |
| GET    | `/health`                             | none  | Health check                    |

*Auth levels: `none` = public, `user` = any authenticated, `pro` = admin or nutritionist, `admin` = admin only*

---

## Project Status

Personal project under active development.

---

## Author

**Riccardo Leone**

---

## License

**All Rights Reserved** - Intended for personal use only.
