from django.urls import path
from .views import add_payment, get_payment_history, get_payments, get_user_credit

urlpatterns = [
    path('payment/add/', add_payment, name='add_payment'),
    path('payment/history/', get_payment_history, name='get_payment_history'),
    path('payments/', get_payments, name='get_payments'),  # Fetch all payments
    path('user/credit/', get_user_credit, name='get_user_credit'),
]
