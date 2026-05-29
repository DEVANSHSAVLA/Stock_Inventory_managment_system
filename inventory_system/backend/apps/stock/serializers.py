from rest_framework import serializers
from .models import StockEntry, StockTransfer, DailyLedger
from apps.products.serializers import VariantSerializer
from apps.locations.serializers import LocationSerializer
from apps.auth_app.serializers import UserSerializer


class StockEntrySerializer(serializers.ModelSerializer):
    variant_name = serializers.SerializerMethodField()
    location_name = serializers.CharField(source='location.name', read_only=True)
    logged_by_name = serializers.SerializerMethodField()
    approved_by_name = serializers.SerializerMethodField()
    cases_display = serializers.SerializerMethodField()

    class Meta:
        model = StockEntry
        fields = (
            'id', 'variant', 'variant_name', 'location', 'location_name',
            'entry_type', 'quantity', 'cases', 'cases_display', 'purchase_price', 'entry_date',
            'reference_number', 'batch_number',
            'expiry_date', 'supplier', 'note', 'logged_by', 'logged_by_name',
            'approved_by', 'approved_by_name', 'is_approved', 'timestamp', 'created_at'
        )
        read_only_fields = ('id', 'logged_by', 'approved_by', 'is_approved', 'created_at', 'cases_display')

    def get_variant_name(self, obj):
        return f'{obj.variant.product.name} {obj.variant.size} {obj.variant.flavour}'.strip()

    def get_logged_by_name(self, obj):
        return obj.logged_by.get_full_name() or obj.logged_by.email if obj.logged_by else None

    def get_approved_by_name(self, obj):
        return obj.approved_by.get_full_name() or obj.approved_by.email if obj.approved_by else None

    def get_cases_display(self, obj):
        if obj.cases:
            return f'{obj.cases} cases / {obj.quantity} pcs'
        return None


class StockTransferSerializer(serializers.ModelSerializer):
    from_location_name = serializers.CharField(source='from_location.name', read_only=True)
    to_location_name = serializers.CharField(source='to_location.name', read_only=True)
    variant_name = serializers.SerializerMethodField()
    transferred_by_name = serializers.SerializerMethodField()

    class Meta:
        model = StockTransfer
        fields = (
            'id', 'from_location', 'from_location_name', 'to_location', 'to_location_name',
            'variant', 'variant_name', 'quantity', 'transferred_by', 'transferred_by_name',
            'timestamp', 'note', 'created_at'
        )
        read_only_fields = ('id', 'transferred_by', 'created_at')

    def get_variant_name(self, obj):
        return f'{obj.variant.product.name} {obj.variant.size} {obj.variant.flavour}'.strip()

    def get_transferred_by_name(self, obj):
        return obj.transferred_by.get_full_name() or obj.transferred_by.email if obj.transferred_by else None


class DailyLedgerSerializer(serializers.ModelSerializer):
    class Meta:
        model = DailyLedger
        fields = '__all__'


class OrderItemSerializer(serializers.ModelSerializer):
    variant_name = serializers.SerializerMethodField()
    location_name = serializers.CharField(source='location.name', read_only=True)

    class Meta:
        from .models import OrderItem
        model = OrderItem
        fields = ('id', 'variant', 'variant_name', 'location', 'location_name', 'quantity', 'cases', 'unit_price', 'subtotal')
        read_only_fields = ('id', 'subtotal')

    def get_variant_name(self, obj):
        return f'{obj.variant.product.name} {obj.variant.size} {obj.variant.flavour}'.strip()


class OrderSerializer(serializers.ModelSerializer):
    items = OrderItemSerializer(many=True, read_only=True)
    created_by_name = serializers.SerializerMethodField()
    warehouse_name = serializers.CharField(source='warehouse.name', read_only=True, default=None)

    class Meta:
        from .models import Order
        model = Order
        fields = (
            'id', 'order_number', 'customer_name', 'customer_phone', 'customer_address',
            'date', 'transport', 'transport_carrier', 'transport_vehicle', 'transport_driver',
            'warehouse', 'warehouse_name', 'is_delivered_at_booking',
            'notes', 'status', 'created_by', 'created_by_name', 'created_at', 'items'
        )
        read_only_fields = ('id', 'order_number', 'status', 'created_by', 'created_at')

    def get_created_by_name(self, obj):
        return obj.created_by.get_full_name() or obj.created_by.email if obj.created_by else None
