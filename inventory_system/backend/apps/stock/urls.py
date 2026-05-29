from django.urls import path
from .views import (
    StockIncomingView, StockOutgoingView, StockAdjustmentView, StockEntriesView,
    StockEntryApproveView, LiveStockView, LiveStockVariantView,
    StockTransferListCreateView, DashboardSummaryView,
    OrderListCreateView, OrderActionView
)

urlpatterns = [
    path('stock/incoming/', StockIncomingView.as_view(), name='stock-incoming'),
    path('stock/outgoing/', StockOutgoingView.as_view(), name='stock-outgoing'),
    path('stock/adjustment/', StockAdjustmentView.as_view(), name='stock-adjustment'),
    path('stock/entries/', StockEntriesView.as_view(), name='stock-entries'),
    path('stock/entries/<int:pk>/approve/', StockEntryApproveView.as_view(), name='stock-approve'),
    path('stock/live/', LiveStockView.as_view(), name='stock-live'),
    path('stock/live/<int:variant_id>/', LiveStockVariantView.as_view(), name='stock-live-variant'),
    path('transfers/', StockTransferListCreateView.as_view(), name='transfer-list'),
    path('dashboard/summary/', DashboardSummaryView.as_view(), name='dashboard-summary'),
    path('orders/', OrderListCreateView.as_view(), name='order-list-create'),
    path('orders/<int:pk>/<str:action>/', OrderActionView.as_view(), name='order-action'),
]
