from django.contrib import admin

from .models import Subscription 



@admin.register(Subscription)
class SubscriptionAdmin(admin.ModelAdmin):
    list_display = ('user', 'plan', 'start_date', 'end_date', 'is_active_status')
    list_filter = ('plan', 'end_date')
    search_fields = ('user__username', 'plan')

    def is_active_status(self, obj):
        return obj.is_active()
    is_active_status.boolean = True
    is_active_status.short_description = 'Active'