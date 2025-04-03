from django.urls import path
from .views import add_payment_50,add_payment_10, get_payment_history, get_payments, get_user_credit 
from . import views

urlpatterns = [
    path('add-payment-50/', add_payment_50, name='add_payment_50'),
    path('add-payment-10/', add_payment_10, name='add_payment_10'),
    path('history/', get_payment_history, name='get_payment_history'),
    path('payments/', get_payments, name='get_payments'),  # Fetch all payments
    path('user/credit/', get_user_credit, name='get_user_credit'),

    path('subscription/active/', views.get_active_subscription, name='get_active_subscription'),
    path('subscription/all/', views.get_all_subscriptions, name='get_all_subscriptions'),
    path('subscription/upgrade-to-premium/', views.change_subscription_to_premium, name='upgrade_to_premium'),
    path('subscription/upgrade-to-vip/', views.change_subscription_to_vip, name='upgrade_to_vip'),
]


