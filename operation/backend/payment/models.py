import uuid
from django.db import models
from django.contrib.auth.models import User
from django.db.models.signals import post_save
from django.dispatch import receiver

class UserCredit(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE)
    balance = models.DecimalField(max_digits=10, decimal_places=2, default=0.0)

    def __str__(self):
        return f"{self.user.username} - {self.balance} credits"


class Payment(models.Model):
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('validated', 'Validated'),
        ('rejected', 'Rejected'),
    ]

    id = models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True)
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    card_number = models.CharField(max_length=255)  # Store the card number as plain text
    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default='pending')
    created_at = models.DateTimeField(auto_now_add=True)
    validated_at = models.DateTimeField(null=True, blank=True)

    def __str__(self):
        return f"Payment {self.id} - {self.user.username} - {self.status}"


class PaymentHistory(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    payment = models.OneToOneField(Payment, on_delete=models.CASCADE)
    credits_added = models.DecimalField(max_digits=10, decimal_places=2)
    timestamp = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.user.username} - {self.credits_added} credits on {self.timestamp}"


# Signal to update user credits when a payment is validated
@receiver(post_save, sender=Payment)
def update_user_credit(sender, instance, created, **kwargs):
    # Only trigger when the payment status is changed to validated
    if instance.status == 'validated':
        # Ensure that the user exists in the UserCredit model
        user_credit, created = UserCredit.objects.get_or_create(user=instance.user)
        # Add 50 credits
        user_credit.balance += 50
        user_credit.save()

        # Create a payment history record
        PaymentHistory.objects.create(
            user=instance.user,
            payment=instance,
            credits_added=50
        )
