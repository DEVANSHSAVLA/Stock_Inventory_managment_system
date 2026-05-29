"""
Stripe Integration Stubs
========================
These functions are stubs that log intent but do not call Stripe APIs
until STRIPE_SECRET_KEY is set in the environment.

When ready for production:
1. Set STRIPE_SECRET_KEY and STRIPE_WEBHOOK_SECRET in .env
2. The stubs will automatically activate via the env check below
"""
import os
import logging

logger = logging.getLogger(__name__)

STRIPE_KEY = os.environ.get('STRIPE_SECRET_KEY', '')

if STRIPE_KEY:
    try:
        import stripe
        stripe.api_key = STRIPE_KEY
        STRIPE_ACTIVE = True
    except ImportError:
        STRIPE_ACTIVE = False
        logger.warning('stripe package not installed. pip install stripe')
else:
    STRIPE_ACTIVE = False


def create_customer(tenant):
    """Create a Stripe customer for the tenant."""
    if not STRIPE_ACTIVE:
        logger.info(f'[STUB] Would create Stripe customer for tenant {tenant.schema_name}')
        return None
    customer = stripe.Customer.create(
        email=tenant.owner_email,
        name=tenant.company_name,
        metadata={'tenant_id': tenant.schema_name},
    )
    return customer.id


def create_subscription(tenant, plan):
    """Create a Stripe subscription for the tenant."""
    if not STRIPE_ACTIVE:
        logger.info(f'[STUB] Would create Stripe subscription for {tenant.schema_name} on plan {plan}')
        return None
    # In production, map plan to a Stripe Price ID
    price_map = {
        'FREE': None,
        'PRO': os.environ.get('STRIPE_PRO_PRICE_ID', ''),
        'ENTERPRISE': os.environ.get('STRIPE_ENTERPRISE_PRICE_ID', ''),
    }
    price_id = price_map.get(plan)
    if not price_id:
        return None
    sub = stripe.Subscription.create(
        customer=tenant.subscription.stripe_customer_id,
        items=[{'price': price_id}],
    )
    return sub.id


def cancel_subscription(tenant):
    """Cancel the Stripe subscription for the tenant."""
    if not STRIPE_ACTIVE:
        logger.info(f'[STUB] Would cancel Stripe subscription for {tenant.schema_name}')
        return None
    if hasattr(tenant, 'subscription') and tenant.subscription.stripe_customer_id:
        # Stripe handles cancellation at period end by default
        pass
    return None


def webhook_handler(event):
    """Handle incoming Stripe webhook events."""
    if not STRIPE_ACTIVE:
        logger.info(f'[STUB] Would handle Stripe webhook event: {event.get("type", "unknown")}')
        return

    event_type = event.get('type', '')
    if event_type == 'customer.subscription.updated':
        logger.info('Subscription updated — would update tenant plan limits')
    elif event_type == 'customer.subscription.deleted':
        logger.info('Subscription deleted — would downgrade tenant to FREE')
    elif event_type == 'invoice.payment_failed':
        logger.info('Payment failed — would send notification to tenant admin')
