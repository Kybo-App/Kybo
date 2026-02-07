# Manual Tasks - Feature 5: Comunicazione Avanzata

## What was implemented (code-complete)

### Backend (server/app/routers/communication.py)
- `POST /admin/communication/broadcast` - Sends a message to all client chats
- `GET /admin/communication/notes/{client_uid}` - Get internal notes for a client
- `POST /admin/communication/notes/{client_uid}` - Create a note
- `PUT /admin/communication/notes/{client_uid}/{note_id}` - Update a note
- `DELETE /admin/communication/notes/{client_uid}/{note_id}` - Delete a note

### Admin Panel
- Broadcast button (megaphone icon) in chat header - opens dialog to send message to all clients
- Internal Notes button (note icon) on client/independent user cards
- Full notes CRUD screen with categories (General, Medical, Dietary, Follow-up), pinning, edit, delete

### Firestore Collections Added
- `users/{uid}/internal_notes/{noteId}` - Internal notes subcollection

---

## What YOU need to do manually

### 1. Deploy Backend
- Push branch to `dev` and deploy to Render
- The new router is auto-registered in `main.py`

### 2. Firestore Index (if needed)
- The `internal_notes` subcollection uses `order_by('updated_at', DESCENDING)`
- Firestore may auto-create the index, but if you get an error, create a composite index:
  - Collection: `users/{uid}/internal_notes`
  - Field: `updated_at` DESC

### 3. Still TODO from Feature 5 (not code - needs external services)
- **Email notification for unread messages** - Requires:
  - An email service (SendGrid, Mailgun, SES, etc.) configured in backend
  - A cron job or Cloud Function that checks `unreadCount` periodically
  - Email templates in Italian
  - This is a separate integration that needs your decision on email provider
- **Email alert configuration UI** - Depends on the email service above

### 4. Remaining TODO.md items (not started - these are lower priority)
- Feature 6: Admin UX (keyboard shortcuts, global search, multi-language)
- Feature 7: Client UX (widget, tablet layout, shopping list sharing, gamification)
- Feature 8: External integrations (Google Fit, Apple Health, etc.)
- Feature 9: Landing page improvements (SEO, pricing, comparison table)
- Feature 10: Backend infrastructure (Redis, queue system, APM, Docker)
- Low priority features (wearables, voice, recipes, etc.)

### 5. Existing open TODO from earlier sections
- `server/` - Tesseract on Render dev needs fixing (Docker or build script)
- Feature 2 optional: automatic monthly PDF email report
