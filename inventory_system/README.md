# InventoryPro — Private Inventory Management System

A production-ready, full-stack inventory management system with a Django REST + WebSocket backend and a Flutter cross-platform frontend (Android, iOS, Web).

---

## Architecture Overview

```
inventory_system/
├── backend/          Django 4.2 + DRF + Channels + Celery
└── flutter_app/      Flutter 3.x (Android + iOS + Web)
```

**Tech stack:**
- Backend: Django 4.2, DRF, Django Channels, Celery + Beat, Redis, PostgreSQL
- Frontend: Flutter 3.x, flutter_riverpod, dio, web_socket_channel, hive, fl_chart
- Database: PostgreSQL (primary), Redis (cache + sessions + channels)

---

## Backend Setup

### Option A: Docker (Recommended)

```bash
cd backend
cp .env.example .env
# Edit .env with your values (or use defaults for local dev)
docker-compose up --build
```

Services started:
- `web` → http://localhost:8000 (Django + Daphne ASGI)
- `celery` → Background task worker
- `celery-beat` → Scheduled tasks
- `db` → PostgreSQL on port 5432
- `redis` → Redis on port 6379

After containers start:
```bash
docker-compose exec web python manage.py migrate
docker-compose exec web python manage.py seed_data
docker-compose exec web python manage.py createsuperuser  # optional
```

### Option B: Local (without Docker)

```bash
cd backend
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt

# Start PostgreSQL and Redis locally, then:
cp .env.example .env
# Edit DATABASE_URL and REDIS_URL in .env

python manage.py migrate
python manage.py seed_data
python manage.py runserver
```

Start Celery (separate terminal):
```bash
celery -A config worker -l info
celery -A config beat -l info
```

---

## Flutter Setup

### Prerequisites
- Flutter 3.x SDK: https://flutter.dev/docs/get-started/install
- Android Studio or VS Code with Flutter plugin

### Run the App

```bash
cd flutter_app
flutter pub get
flutter run
```

### Configure API Base URL

Edit `lib/core/constants/api_urls.dart`:
```dart
static const String baseUrl = 'http://your-server-ip:8000';
static const String wsBaseUrl = 'ws://your-server-ip:8000';
```

Or pass at build time:
```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.100:8000 --dart-define=WS_BASE_URL=ws://192.168.1.100:8000
```

### Build for Web
```bash
flutter build web --dart-define=API_BASE_URL=https://your-api.com
```

### Build for Android
```bash
flutter build apk --dart-define=API_BASE_URL=https://your-api.com
```

---

## Default Seed Credentials

Run `python manage.py seed_data` to create:

| Role    | Email                      | Password      |
|---------|----------------------------|---------------|
| Admin   | admin@inventory.local      | Admin@1234    |
| Manager | manager1@inventory.local   | Manager@1234  |
| Manager | manager2@inventory.local   | Manager@1234  |
| Staff   | staff1@inventory.local     | Staff@1234    |
| Staff   | staff2@inventory.local     | Staff@1234    |
| Staff   | staff3@inventory.local     | Staff@1234    |
| Staff   | staff4@inventory.local     | Staff@1234    |
| Staff   | staff5@inventory.local     | Staff@1234    |

Also creates: 3 locations, 50 products with 3 variants each (S/M/L × Original/Classic/Premium), 5 suppliers, and 30 days of realistic stock entries.

---

## Environment Variables

| Variable              | Description                              | Default                      |
|-----------------------|------------------------------------------|------------------------------|
| `SECRET_KEY`          | Django secret key                        | insecure default (change!)   |
| `DEBUG`               | Debug mode                               | True                         |
| `ALLOWED_HOSTS`       | Comma-separated allowed hosts            | localhost,127.0.0.1          |
| `DATABASE_URL`        | PostgreSQL connection URL                | postgres://...@localhost/... |
| `REDIS_URL`           | Redis connection URL                     | redis://localhost:6379/0     |
| `CORS_ALLOWED_ORIGINS`| Comma-separated CORS origins             | http://localhost:3000        |
| `EMAIL_HOST`          | SMTP server hostname                     | smtp.gmail.com               |
| `EMAIL_PORT`          | SMTP port                                | 587                          |
| `EMAIL_HOST_USER`     | SMTP username                            | (empty)                      |
| `EMAIL_HOST_PASSWORD` | SMTP password / app password             | (empty)                      |
| `DEFAULT_FROM_EMAIL`  | From email for sent emails               | inventory@localhost          |
| `CELERY_BROKER_URL`   | Celery broker (uses REDIS_URL by default)| redis://localhost:6379/0     |

---

## API Overview

All responses follow this envelope:
```json
{
  "success": true,
  "data": {},
  "message": "...",
  "errors": {}
}
```

### Authentication
- `POST /api/auth/login/` — Get JWT tokens
- `POST /api/auth/refresh/` — Refresh access token
- `POST /api/auth/logout/` — Invalidate refresh token
- `GET  /api/auth/me/` — Get current user

All other endpoints require `Authorization: Bearer <access_token>` header.

### WebSocket
Connect to `ws://host/ws/stock/?token=<access_token>` to receive live stock updates.

---

## Roles & Permissions

| Feature            | Admin | Manager | Staff |
|--------------------|-------|---------|-------|
| Log stock IN/OUT   | ✓     | ✓       | ✓     |
| Approve entries    | ✓     | ✓       | ✗     |
| View reports       | ✓     | ✓       | ✗     |
| Manage suppliers   | ✓     | ✓       | ✗     |
| Manage users       | ✓     | ✗       | ✗     |
| Delete products    | ✓     | ✗       | ✗     |

---

## Live Stock Engine

Live stock is computed on-the-fly (never stored during the day):

```
live_stock = opening_stock + SUM(IN entries) - SUM(OUT entries)
             (scoped to variant + location, date = today, is_approved = True)
```

Results are cached in Redis for 30 seconds (`stock:{variant_id}:{location_id}:{date}`).

At 23:59 daily, Celery runs a midnight rollover that locks closing stock and creates the next day's opening ledger.

---

## Django Admin

Available at `http://localhost:8000/admin/` — all models are registered with search, filter, and list_display.

---

## Celery Scheduled Tasks

| Task                       | Schedule       | Description                              |
|----------------------------|----------------|------------------------------------------|
| `midnight_rollover`        | Daily 23:59    | Roll closing → opening for all variants  |
| `check_low_stock`          | Every 2 hours  | Create LOW_STOCK notifications           |
| `send_daily_summary_email` | Daily 8:00 AM  | Email yesterday's summary to Admin+Mgr   |
| `auto_generate_pos`        | Daily 9:00 AM  | Create DRAFT POs for low-stock items     |
| `check_expiring_batches`   | Daily 7:00 AM  | Flag batches expiring within 30 days     |
