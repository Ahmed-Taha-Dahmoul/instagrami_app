from rest_framework.decorators import api_view, authentication_classes, permission_classes
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework_simplejwt.authentication import JWTAuthentication
from .models import Subscription
from django.utils.timezone import timedelta , now
from payment.models import UserCredit

@api_view(['GET'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def get_active_subscription(request):
    subscription = Subscription.objects.filter(user=request.user, end_date__gt=now()).first()
    if subscription:
        data = {
            "plan": subscription.plan,
            "start_date": subscription.start_date,
            "end_date": subscription.end_date,
            "status": "Active"
        }
        return Response(data)
    return Response(None)





@api_view(['GET'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def get_all_subscriptions(request):
    subscriptions = Subscription.objects.filter(user=request.user)
    if subscriptions:
        data = [{
            "plan": subscription.plan,
            "credits_reduced" : subscription.credits_reduced,
            "start_date": subscription.start_date,
            "end_date": subscription.end_date,
            "status": "Active" if subscription.end_date > now() else "Expired"
        } for subscription in subscriptions]
        return Response(data)
    return Response({"message": "No subscriptions found."}, status=404)







@api_view(['POST'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def change_subscription_to_premium(request):
    try:
        # Check if the user already has an active subscription (either trial, premium, or vip)
        subscription = Subscription.objects.filter(user=request.user, end_date__gt=now()).first()
        
        # Check if the user has enough credits to upgrade
        user_credit = UserCredit.objects.filter(user=request.user).first()
        if user_credit and user_credit.balance >= 10:
            # If the user has an active trial subscription, upgrade it to premium
            if subscription:
                # Update the subscription to premium
                subscription.plan = 'premium'
                subscription.end_date = now() + timedelta(days=30)  # 1 month from now
                subscription.credits_reduced = 10  # Deduct 10 credits for the premium upgrade
                subscription.save()
                # Deduct 10 credits from the user's balance
                user_credit.balance -= 10
                user_credit.save()

                return Response({"message": "Subscription upgraded to Premium and 10 credits deducted."})

            # If the user does not have any active subscription, create a new premium subscription
            else:
                # Deduct 10 credits from the user's balance
                user_credit.balance -= 10
                user_credit.save()

                # Create a new premium subscription with 1 month duration
                Subscription.objects.create(
                    user=request.user,
                    plan='premium',
                    end_date=now() + timedelta(days=30),
                    credits_reduced=10  # Deduct 10 credits for creating a new premium subscription
                )

                return Response({"message": "No active subscription found. New Premium subscription created and 10 credits deducted."})

        else:
            return Response({"message": "Insufficient credits to upgrade or create Premium subscription."}, status=400)

    except Subscription.DoesNotExist:
        return Response({"message": "Subscription not found."}, status=404)









@api_view(['POST'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def change_subscription_to_vip(request):
    try:
        # Check if the user already has an active subscription (either trial, premium, or vip)
        subscription = Subscription.objects.filter(user=request.user, end_date__gt=now()).first()
        
        # Check if the user has enough credits to upgrade
        user_credit = UserCredit.objects.filter(user=request.user).first()
        if user_credit and user_credit.balance >= 15:
            # If the user has an active trial subscription, upgrade it to vip
            if subscription:
                # Update the subscription to vip
                subscription.plan = 'vip'
                subscription.end_date = now() + timedelta(days=30)  # 1 month from now
                subscription.credits_reduced = 15  # Deduct 15 credits for the vip upgrade
                subscription.save()
                # Deduct 15 credits from the user's balance
                user_credit.balance -= 15
                user_credit.save()

                return Response({"message": "Subscription upgraded to VIP and 15 credits deducted."})

            # If the user does not have any active subscription, create a new vip subscription
            else:
                # Deduct 15 credits from the user's balance
                user_credit.balance -= 15
                user_credit.save()

                # Create a new vip subscription with 1 month duration
                Subscription.objects.create(
                    user=request.user,
                    plan='vip',
                    end_date=now() + timedelta(days=30),
                    credits_reduced=15  # Deduct 15 credits for creating a new vip subscription
                )

                return Response({"message": "No active subscription found. New VIP subscription created and 15 credits deducted."})

        else:
            return Response({"message": "Insufficient credits to upgrade or create VIP subscription."}, status=400)

    except Subscription.DoesNotExist:
        return Response({"message": "Subscription not found."}, status=404)