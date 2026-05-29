from django.urls import path
from .views import (
    SupplierListCreateView, SupplierDetailView,
    PurchaseOrderListCreateView, PurchaseOrderDetailView,
    PurchaseOrderReceiveView
)

urlpatterns = [
    path('suppliers/', SupplierListCreateView.as_view(), name='supplier-list'),
    path('suppliers/<int:pk>/', SupplierDetailView.as_view(), name='supplier-detail'),
    path('purchase-orders/', PurchaseOrderListCreateView.as_view(), name='po-list'),
    path('purchase-orders/<int:pk>/', PurchaseOrderDetailView.as_view(), name='po-detail'),
    path('purchase-orders/<int:pk>/receive/', PurchaseOrderReceiveView.as_view(), name='po-receive'),
]
