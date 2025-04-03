from rest_framework import serializers
from .models import Subscription, UserCredit

class SubscriptionSerializer(serializers.ModelSerializer):
    class Meta:
        model = Subscription
        fields = ['plan', 'start_date', 'end_date']

class UserCreditSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserCredit
        fields = ['balance']
