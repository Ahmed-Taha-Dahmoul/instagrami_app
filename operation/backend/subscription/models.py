from django.db import models
from django.contrib.auth.models import User
from datetime import timedelta
from django.db.models.signals import post_save
from django.dispatch import receiver
from django.utils.timezone import now

class Subscription(models.Model):
    PLAN_CHOICES = [
        ('trial', 'Trial'),
        ('premium', 'Premium'),
        ('vip', 'VIP'),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE)  # Allow multiple subscriptions
    plan = models.CharField(max_length=10, choices=PLAN_CHOICES, default='trial')
    credits_reduced = models.DecimalField(max_digits=10, decimal_places=2 , null = True )
    start_date = models.DateTimeField(auto_now_add=True)
    end_date = models.DateTimeField(null=False, blank=False)

    def __str__(self):
        return f"{self.user.username} - {self.plan} ({'Active' if self.is_active() else 'Expired'})"

    def is_active(self):
        """Check if the subscription is still valid."""
        return self.end_date and self.end_date > now()

    


@receiver(post_save, sender=User)
def create_or_update_subscription(sender, instance, created, **kwargs):
    """Creates a new subscription with a 3-day trial for the newly created user."""
    if created:
        # Set the end_date to 3 days from now
        end_date = now() + timedelta(days=3)
        Subscription.objects.create(user=instance, plan='trial', end_date=end_date)