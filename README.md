# InventoryPro — Enterprise Stock & Inventory Management System

InventoryPro is a production-ready, full-stack, enterprise-grade stock and inventory telemetry platform. Built with a high-fidelity **Django REST & WebSocket backend** and a beautiful, high-performance **Flutter multi-platform frontend**, it supports instant cross-device updates for Web, Windows Desktop, and Android mobile environments.

---

## ✨ Design System & Visual Overhaul

InventoryPro has been upgraded to a premium **SaaS Modern Dark-Slate** aesthetic:
* **UI/UX Aesthetics:** Curated dark-slate design system with subtle radial and mesh accent gradients.
* **Glassmorphic Authentication:** Login and Sign-up screens engineered with futuristic frosted-glass panels and responsive glow metrics.
* **Glowing State Indicators:** Real-time stock alerts, active telemetry states, and interactive KPIs equipped with fine, translucent neon borders and status-matching glow highlights.
* **Responsive Visual Panels:** Analytics widgets, DataTable displays, and navigation controls fully adapted to dark environments for high readability and premium feel.

---

## 🛠️ Architecture & Tech Stack

```
Stock_Inventory_managment_system/
├── inventory_system/
│   ├── backend/          Django 4.2, DRF, Django Channels (WebSockets), Daphne, Celery, PostgreSQL
│   └── flutter_app/      Flutter 3.x Cross-Platform Client (Riverpod, Dio, WebSockets, Hive)
└── Distribution/         Pre-compiled, production-ready release targets
```

### Technical Highlights
* **WebSockets Telemetry:** Live stock updates broadcasted instantly to all connected active devices.
* **Dynamic Rollover Engine:** Background automation executes daily closing opening ledgers via Celery Beat.
* **Robust Local Storage:** Local device offline caches and status configurations handled using Hive.

---

## 📦 Production Builds (Distribution Directory)

The application has been compiled, packaged, and cleanly separated into the `Distribution/` folder:

| Platform | Format / Type | Location |
|---|---|---|
| **Web** | High-performance JS Bundle | `Distribution/Web/` |
| **Android** | Release APK | `Distribution/Mobile/InventoryPro.apk` |
| **Windows** | Native Desktop Executable | `Distribution/Windows/flutter_app.exe` |

---

## 🚀 Getting Started

### 1. Running the Backend
```bash
cd inventory_system/backend
cp .env.example .env
# Edit configurations as needed, then start:
docker-compose up --build
```
After containers are initialized, seed the database with test assets:
```bash
docker-compose exec web python manage.py migrate
docker-compose exec web python manage.py seed_data
```

### 2. Running/Compiling the Frontend
Ensure you have the Flutter SDK configured, then start the dev server:
```bash
cd inventory_system/flutter_app
flutter pub get
flutter run
```
To generate release distributions automatically, use the automated build tool:
```bash
# Windows automated build & separation script
./build_apps.bat
```

---

## 🔐 Default Credentials (Seed Data)

Run `seed_data` to generate the following credentials:

| Role | Email | Password |
|---|---|---|
| **Admin** | `admin@inventory.local` | `Admin@1234` |
| **Manager** | `manager1@inventory.local` | `Manager@1234` |
| **Staff** | `staff1@inventory.local` | `Staff@1234` |

