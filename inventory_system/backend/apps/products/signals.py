from django.db.models.signals import post_save, post_delete
from django.dispatch import receiver
from .models import Product, Variant
from apps.audit.models import AuditLog
import logging

logger = logging.getLogger(__name__)
