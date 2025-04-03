from django.urls import path
from . import views


urlpatterns = [
    path('active/', views.get_active_subscription, name='get_active_subscription'),
    path('all/', views.get_all_subscriptions, name='get_all_subscriptions'),
    path('upgrade-to-premium/', views.change_subscription_to_premium, name='upgrade_to_premium'),
    path('upgrade-to-vip/', views.change_subscription_to_vip, name='upgrade_to_vip'),
]


