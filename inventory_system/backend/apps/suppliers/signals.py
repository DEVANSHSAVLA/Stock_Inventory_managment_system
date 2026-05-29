from django.db.models.signals import post_save
from django.dispatch import receiver
from .models import PurchaseOrder
import logging

logger = logging.getLogger(__name__)
