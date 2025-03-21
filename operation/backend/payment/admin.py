from django.contrib import admin
from .models import Payment, UserCredit, PaymentHistory
from django.utils.html import format_html
from django.urls import path, reverse
from django.http import HttpResponseRedirect
from django.shortcuts import get_object_or_404


class PaymentAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'card_number', 'status', 'created_at', 'validated_at', 'validate_button')
    list_filter = ('status', 'user')
    search_fields = ('user__username', 'card_number')
    actions = ['validate_payment']

    def validate_button(self, obj):
        """Display a button to validate a payment directly from the list view"""
        if obj.status != 'validated':  # Only show button if not already validated
            return format_html(
                '<a class="button" href="{}">Validate</a>',
                reverse('admin:validate_payment', args=[obj.id])  # Use reverse for URL
            )
        return "Already Validated" # Show text if validated

    validate_button.short_description = "Validate Payment"
    validate_button.allow_tags = True

    def validate_payment(self, request, queryset):
      """Mark the selected payments as validated (bulk action)."""
      for payment in queryset:
          if payment.status != 'validated':  # Check status before proceeding
              payment.status = 'validated'
              payment.validated_at = payment.created_at
              payment.save()  # Save payment changes

              # Add credits and create history (using get_or_create is redundant here because of signal)
              # Signal will handle it. No need for manual history or credit update.
          else:
              self.message_user(request, f"Payment {payment.id} is already validated.")

      self.message_user(request, "Selected payments have been processed.")

    validate_payment.short_description = "Validate Selected Payments"


    def get_urls(self):
        urls = super().get_urls()
        custom_urls = [
            path('<uuid:payment_id>/validate/', self.admin_site.admin_view(self.validate_payment_view), name='validate_payment'),
        ]
        return custom_urls + urls

    def validate_payment_view(self, request, payment_id):
        """Handles the validation of a single payment via the custom URL."""
        payment = get_object_or_404(Payment, id=payment_id)

        if payment.status == 'validated':
            self.message_user(request, "Payment has already been validated.")
        else:
            payment.status = 'validated'
            payment.validated_at = payment.created_at  # Use current time or creation time
            payment.save()  # This will trigger the post_save signal

            self.message_user(request, "Payment has been validated.")

        # Redirect back to the payment *list* view.  This is the key fix!
        return HttpResponseRedirect(reverse('admin:payment_payment_changelist'))



# Register the PaymentAdmin class with the Payment model
admin.site.register(Payment, PaymentAdmin)


# Admin page for UserCredit
class UserCreditAdmin(admin.ModelAdmin):
    list_display = ('user', 'balance')
    search_fields = ('user__username',)

# Admin page for PaymentHistory
class PaymentHistoryAdmin(admin.ModelAdmin):
    list_display = ('user', 'payment', 'credits_added', 'timestamp')
    list_filter = ('timestamp', 'user')
    search_fields = ('user__username',)

# Register models with the admin site
admin.site.register(UserCredit, UserCreditAdmin)
admin.site.register(PaymentHistory, PaymentHistoryAdmin)