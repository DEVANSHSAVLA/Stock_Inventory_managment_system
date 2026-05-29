from django.urls import path
from .views import (
    DailyReportView, WeeklyReportView, MonthlyReportView,
    MovementReportView, LowStockReportView, ExpiringReportView,
    ForecastView, ExportReportView, CustomerBalanceView
)

urlpatterns = [
    path('reports/daily/', DailyReportView.as_view(), name='report-daily'),
    path('reports/weekly/', WeeklyReportView.as_view(), name='report-weekly'),
    path('reports/monthly/', MonthlyReportView.as_view(), name='report-monthly'),
    path('reports/movement/', MovementReportView.as_view(), name='report-movement'),
    path('reports/low-stock/', LowStockReportView.as_view(), name='report-low-stock'),
    path('reports/expiring/', ExpiringReportView.as_view(), name='report-expiring'),
    path('reports/customer-balance/', CustomerBalanceView.as_view(), name='report-customer-balance'),
    path('reports/forecast/<int:variant_id>/', ForecastView.as_view(), name='report-forecast'),
    path('reports/export/<str:report_type>/', ExportReportView.as_view(), name='report-export'),
]
