from django.urls import path
from .views import add_payment_50,add_payment_10, get_payment_history, get_payments, get_user_credit 


urlpatterns = [
    path('add-payment-50/', add_payment_50, name='add_payment_50'),
    path('add-payment-10/', add_payment_10, name='add_payment_10'),
    path('history/', get_payment_history, name='get_payment_history'),
    path('payments/', get_payments, name='get_payments'),  # Fetch all payments
    path('user/credit/', get_user_credit, name='get_user_credit'),

    
]


