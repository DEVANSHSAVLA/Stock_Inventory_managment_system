from django.urls import path
from .views import (
    ProductListCreateView, ProductDetailView,
    VariantListCreateView, VariantDetailView,
    VariantMatrixView, VariantBulkImportView,
    ProductSearchView, ImageUploadView
)

urlpatterns = [
    path('products/', ProductListCreateView.as_view(), name='product-list'),
    path('products/search/', ProductSearchView.as_view(), name='product-search'),
    path('products/upload-image/', ImageUploadView.as_view(), name='product-upload-image'),
    path('products/<int:pk>/', ProductDetailView.as_view(), name='product-detail'),
    path('variants/', VariantListCreateView.as_view(), name='variant-list'),
    path('variants/<int:pk>/', VariantDetailView.as_view(), name='variant-detail'),
    path('variants/matrix/', VariantMatrixView.as_view(), name='variant-matrix'),
    path('variants/bulk-import/', VariantBulkImportView.as_view(), name='variant-bulk-import'),
]
