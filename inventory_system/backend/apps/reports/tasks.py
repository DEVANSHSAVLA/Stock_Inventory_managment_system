from celery import shared_task
from django.utils import timezone
from django.core.mail import send_mail
from django.conf import settings
import logging

logger = logging.getLogger(__name__)


@shared_task
def send_daily_summary_email():
    from apps.auth_app.models import User
    from apps.stock.models import StockEntry
    from django.db.models import Sum
    from datetime import timedelta

    yesterday = timezone.now().date() - timedelta(days=1)
    recipients = list(User.objects.filter(role__in=['ADMIN', 'MANAGER'], is_active=True).values_list('email', flat=True))
    if not recipients:
        return

    entries = StockEntry.objects.filter(timestamp__date=yesterday, is_approved=True)
    total_in = entries.filter(entry_type='IN').aggregate(t=Sum('quantity'))['t'] or 0
    total_out = entries.filter(entry_type='OUT').aggregate(t=Sum('quantity'))['t'] or 0

    subject = f'Daily Stock Summary - {yesterday}'
    body = (
        f'Daily Inventory Summary for {yesterday}\n\n'
        f'Total Stock IN: {total_in}\n'
        f'Total Stock OUT: {total_out}\n'
        f'Net Movement: {float(total_in) - float(total_out)}\n\n'
        f'Login to the Inventory Management System for detailed reports.'
    )
    try:
        send_mail(subject, body, settings.DEFAULT_FROM_EMAIL, recipients)
        logger.info(f'Daily summary sent to {len(recipients)} users.')
    except Exception as e:
        logger.error(f'Failed to send daily summary: {e}')
