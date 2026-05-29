import os
from celery import Celery
from celery.schedules import crontab

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')

app = Celery('inventory')
app.config_from_object('django.conf:settings', namespace='CELERY')
app.autodiscover_tasks()

app.conf.beat_schedule = {
    'midnight-rollover': {
        'task': 'apps.stock.tasks.midnight_rollover',
        'schedule': crontab(hour=23, minute=59),
    },
    'check-low-stock': {
        'task': 'apps.stock.tasks.check_low_stock',
        'schedule': crontab(minute=0, hour='*/2'),
    },
    'send-daily-summary': {
        'task': 'apps.reports.tasks.send_daily_summary_email',
        'schedule': crontab(hour=8, minute=0),
    },
    'auto-generate-pos': {
        'task': 'apps.suppliers.tasks.auto_generate_purchase_orders',
        'schedule': crontab(hour=9, minute=0),
    },
    'check-expiring-batches': {
        'task': 'apps.stock.tasks.check_expiring_batches',
        'schedule': crontab(hour=7, minute=0),
    },
}
