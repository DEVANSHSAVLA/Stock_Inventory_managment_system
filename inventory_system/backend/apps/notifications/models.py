from django.db import models


class Notification(models.Model):
    TYPE_LOW_STOCK = 'LOW_STOCK'
    TYPE_EXPIRY = 'EXPIRY'
    TYPE_APPROVAL = 'APPROVAL'
    TYPE_SYSTEM = 'SYSTEM'
    TYPE_CHOICES = [
        (TYPE_LOW_STOCK, 'Low Stock'),
        (TYPE_EXPIRY, 'Expiry Alert'),
        (TYPE_APPROVAL, 'Approval Required'),
        (TYPE_SYSTEM, 'System'),
    ]

    user = models.ForeignKey('auth_app.User', on_delete=models.CASCADE, related_name='notifications')
    message = models.TextField()
    type = models.CharField(max_length=20, choices=TYPE_CHOICES, default=TYPE_SYSTEM)
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'{self.type} - {self.user.email}: {self.message[:50]}'
