
import uuid
from django.db import models
from django.contrib.auth.models import User
from django.db.models.signals import post_save
from django.dispatch import receiver
from django.utils.timezone import now


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

    CREDIT_CHOICES = [
        (50, '50 Credits'),
        (10, '10 Credits'),
    ]

    id = models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True)
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    card_number = models.CharField(max_length=50)  
    credit_amount = models.PositiveIntegerField(choices=CREDIT_CHOICES , null=True)  # Either 50 or 10 credits
    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default='pending')
    created_at = models.DateTimeField(auto_now_add=True)
    validated_at = models.DateTimeField(null=True, blank=True)

    def __str__(self):
        return f"Payment {self.id} - {self.user.username} - {self.status}"


class PaymentHistory(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    payment = models.OneToOneField(Payment, on_delete=models.CASCADE)
    credits_added = models.DecimalField(max_digits=10, decimal_places=2 , null = True )
    timestamp = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.user.username} - {self.credits_added} credits on {self.timestamp}"


# Signal to update user credits when a payment is validated
@receiver(post_save, sender=Payment)
def update_user_credit(sender, instance, created, **kwargs):
    """
    Automatically update user credits and payment history when a payment is validated.
    """
    if instance.status == 'validated':
        # Ensure that the user exists in the UserCredit model
        user_credit, _ = UserCredit.objects.get_or_create(user=instance.user)

        # Update user balance based on payment's credit amount
        user_credit.balance += instance.credit_amount
        user_credit.save()

        # Update validation timestamp
        if not instance.validated_at:
            instance.validated_at = now()
            instance.save()

        # Create a payment history record
        PaymentHistory.objects.create(
            user=instance.user,
            payment=instance,
            credits_added=instance.credit_amount
        )













