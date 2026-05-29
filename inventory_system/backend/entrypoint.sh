#!/bin/bash

# Run database migrations and seed data automatically on startup
echo "[*] Running database migrations..."
python manage.py migrate_schemas --noinput

echo "[*] Running tenant and superuser seeding..."
python create_demo_tenant.py

echo "[*] Running sample stock and product data seeding..."
python seed_demo_data.py

# Start Celery Worker and Beat combined in the background
echo "[*] Starting Celery Worker and Beat scheduler combined..."
celery -A config worker -l info -B --scheduler django_celery_beat.schedulers:DatabaseScheduler &

# Start the Daphne ASGI Web Server in the foreground
echo "[*] Starting Daphne Web Server on port ${PORT:-7860}..."
exec daphne -b 0.0.0.0 -p ${PORT:-7860} config.asgi:application
