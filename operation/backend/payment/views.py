from rest_framework.decorators import api_view, authentication_classes, permission_classes
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework_simplejwt.authentication import JWTAuthentication
from .models import Payment , PaymentHistory, UserCredit










def create_payment(request, credit_amount):
    """
    Helper function to create a payment request.
    """
    try:
        card_number = request.data.get('card_number')

        if not card_number:
            return Response({"error": "Card number is required"}, status=status.HTTP_400_BAD_REQUEST)

        # Create a payment record with 'pending' status
        payment = Payment.objects.create(
            user=request.user,
            card_number=card_number,
            credit_amount = credit_amount,
            status='pending',  # Payment must be validated by an admin
        )

        return Response({
            "message": f"Payment request for {credit_amount} credits created successfully. Awaiting validation.",
            "payment_id": str(payment.id),
            "status": payment.status
        }, status=status.HTTP_201_CREATED)

    except Exception as e:
        return Response({
            "error": "An error occurred",
            "details": str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def add_payment_50(request):
    """
    API endpoint to create a payment request for 50 credits.
    """
    return create_payment(request, 50)


@api_view(['POST'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def add_payment_10(request):
    """
    API endpoint to create a payment request for 10 credits.
    """
    return create_payment(request, 10)







@api_view(['GET'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def get_payments(request):
    """
    API endpoint to fetch all payments for the authenticated user.
    """
    try:
        payments = Payment.objects.filter(user=request.user).order_by('-created_at')

        payments_data = [
            {
                "payment_id": str(payment.id),
                "status": payment.status,
                "card_number": payment.card_number,  # Consider masking for security
                "created_at": payment.created_at.strftime('%Y-%m-%d %H:%M:%S'),
                "validated_at": payment.validated_at.strftime('%Y-%m-%d %H:%M:%S') if payment.validated_at else None
            }
            for payment in payments
        ]
    
        return Response({"payments": payments_data}, status=status.HTTP_200_OK)

    except Exception as e:
        return Response({
            "error": "An error occurred",
            "details": str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)



@api_view(['GET'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def get_payment_history(request):
    """
    API endpoint to fetch the payment history for the authenticated user.
    """
    try:
        payment_history = PaymentHistory.objects.filter(user=request.user).order_by('-timestamp')

        history_data = [
            {
                "payment_id": str(record.payment.id),
                "credits_added": str(record.credits_added),
                "timestamp": record.timestamp.strftime('%Y-%m-%d %H:%M:%S'),
            }
            for record in payment_history
        ]

        
        return Response({"payment_history": history_data}, status=status.HTTP_200_OK)

    except Exception as e:
        return Response({
            "error": "An error occurred",
            "details": str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        







@api_view(['GET'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def get_user_credit(request):
    """
    API endpoint to fetch the current credit balance of the authenticated user.
    """
    try:
        # Get or create a UserCredit object for the user
        user_credit, _ = UserCredit.objects.get_or_create(user=request.user)

        return Response({
            "user": request.user.username,
            "credit_balance": str(user_credit.balance)
        }, status=status.HTTP_200_OK)

    except Exception as e:
        return Response({
            "error": "An error occurred",
            "details": str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)







from .models import Subscription
from django.utils.timezone import timedelta , now

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
        if user_credit and user_credit.balance >= 100:
            # If the user has an active trial subscription, upgrade it to premium
            if subscription:
                # Update the subscription to premium
                subscription.plan = 'premium'
                subscription.end_date = now() + timedelta(days=30)  # 1 month from now
                subscription.credits_reduced = 100  # Deduct 100 credits for the premium upgrade
                subscription.save()
                # Deduct 100 credits from the user's balance
                user_credit.balance -= 100
                user_credit.save()

                return Response({"message": "Subscription upgraded to Premium and 100 credits deducted."})

            # If the user does not have any active subscription, create a new premium subscription
            else:
                # Deduct 100 credits from the user's balance
                user_credit.balance -= 100
                user_credit.save()

                # Create a new premium subscription with 1 month duration
                Subscription.objects.create(
                    user=request.user,
                    plan='premium',
                    end_date=now() + timedelta(days=30),
                    credits_reduced=100  # Deduct 100 credits for creating a new premium subscription
                )

                return Response({"message": "No active subscription found. New Premium subscription created and 100 credits deducted."})

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
        if user_credit and user_credit.balance >= 150:
            # If the user has an active trial subscription, upgrade it to vip
            if subscription:
                # Update the subscription to vip
                subscription.plan = 'vip'
                subscription.end_date = now() + timedelta(days=30)  # 1 month from now
                subscription.credits_reduced = 150  # Deduct 150 credits for the vip upgrade
                subscription.save()
                # Deduct 150 credits from the user's balance
                user_credit.balance -= 150
                user_credit.save()

                return Response({"message": "Subscription upgraded to VIP and 150 credits deducted."})

            # If the user does not have any active subscription, create a new vip subscription
            else:
                # Deduct 150 credits from the user's balance
                user_credit.balance -= 150
                user_credit.save()

                # Create a new vip subscription with 1 month duration
                Subscription.objects.create(
                    user=request.user,
                    plan='vip',
                    end_date=now() + timedelta(days=30),
                    credits_reduced=150  # Deduct 150 credits for creating a new vip subscription
                )

                return Response({"message": "No active subscription found. New VIP subscription created and 150 credits deducted."})

        else:
            return Response({"message": "Insufficient credits to upgrade or create VIP subscription."}, status=400)

    except Subscription.DoesNotExist:
        return Response({"message": "Subscription not found."}, status=404)














@api_view(['GET'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def user_info(request):
    user = request.user  # Get the authenticated user

    # Return user details
    return Response({
        "id": user.id,
        "username": user.username,
        "email": user.email,
        "first_name": user.first_name,
        "last_name": user.last_name
    })
