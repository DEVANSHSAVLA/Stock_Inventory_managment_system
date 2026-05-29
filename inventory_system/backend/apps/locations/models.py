from django.db import models


class Location(models.Model):
    TYPE_WAREHOUSE = 'WAREHOUSE'
    TYPE_BRANCH = 'BRANCH'
    TYPE_SHELF = 'SHELF'
    TYPE_CHOICES = [
        (TYPE_WAREHOUSE, 'Warehouse'),
        (TYPE_BRANCH, 'Branch'),
        (TYPE_SHELF, 'Shelf'),
    ]

    name = models.CharField(max_length=200)
    type = models.CharField(max_length=20, choices=TYPE_CHOICES, default=TYPE_WAREHOUSE)
    address = models.TextField(blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f'{self.name} ({self.type})'
