from rest_framework import serializers
from .models import Product, Variant


class VariantSerializer(serializers.ModelSerializer):
    product_name = serializers.CharField(source='product.name', read_only=True)
    selling_price = serializers.DecimalField(max_digits=10, decimal_places=2, read_only=True)
    live_stock = serializers.SerializerMethodField()

    class Meta:
        model = Variant
        fields = ('id', 'product', 'product_name', 'size', 'flavour', 'sku',
                  'barcode', 'reorder_point', 'reorder_qty',
                  'erp_price', 'mrp', 'weight', 'length', 'width', 'height',
                  'selling_price', 'case_quantity', 'case_weight',
                  'case_dimension', 'drive_image_url', 'live_stock',
                  'is_active', 'created_at')
        read_only_fields = ('id', 'sku', 'created_at', 'selling_price', 'live_stock')

    def get_live_stock(self, obj):
        # Use bulk-prefetched stock map from context if available to prevent N+1 queries
        live_stock_map = self.context.get('live_stock_map')
        if live_stock_map is not None and obj.id in live_stock_map:
            return float(live_stock_map[obj.id])

        try:
            from apps.stock.stock_engine import get_live_stock
            from django.utils import timezone
            today = timezone.now().date()
            return float(get_live_stock(obj.id, None, today))
        except Exception as e:
            import logging
            logging.getLogger('django').error(f"Error getting live stock for variant {obj.id}: {e}")
            return 0.0


class ProductSerializer(serializers.ModelSerializer):
    variants = VariantSerializer(many=True, read_only=True)

    class Meta:
        model = Product
        fields = ('id', 'name', 'category', 'unit_of_measure', 'description',
                  'drive_image_url', 'is_active', 'created_at', 'variants')
        read_only_fields = ('id', 'created_at')


class ProductListSerializer(serializers.ModelSerializer):
    variant_count = serializers.IntegerField(source='variants.count', read_only=True)

    class Meta:
        model = Product
        fields = ('id', 'name', 'category', 'unit_of_measure', 'drive_image_url',
                  'is_active', 'variant_count', 'created_at')
