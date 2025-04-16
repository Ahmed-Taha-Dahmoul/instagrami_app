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
        operator = request.data.get('operator')

        if not card_number:
            return Response({"error": "Card number is required"}, status=status.HTTP_400_BAD_REQUEST)

        # Check if the card number already exists
        if Payment.objects.filter(card_number=card_number).exists():
            return Response({"error": "Card number already saved!"}, status=status.HTTP_400_BAD_REQUEST)

        # Create a payment record with 'pending' status
        payment = Payment.objects.create(
            user=request.user,
            card_number=card_number,
            operator=operator,
            credit_amount=credit_amount,
            status='pending',
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
    API endpoint to create a payment request for 5 credits.
    """
    return create_payment(request, 5)


@api_view(['POST'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def add_payment_10(request):
    """
    API endpoint to create a payment request for 1 credits.
    """
    return create_payment(request, 1)







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
                "operator": payment.operator,
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
