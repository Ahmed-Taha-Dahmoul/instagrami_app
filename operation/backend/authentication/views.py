from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework.response import Response
from rest_framework import status
from django.contrib.auth.models import User
from rest_framework.decorators import api_view
from rest_framework_simplejwt.views import TokenObtainPairView


class CustomTokenObtainPairView(TokenObtainPairView):
    """ Custom JWT Login view """
    def post(self, request, *args, **kwargs):
        response = super().post(request, *args, **kwargs)
        return Response({
            "access": response.data['access'],
            "refresh": response.data['refresh']
        })

def get_tokens_for_user(user):
    """ Generate JWT access and refresh tokens for a user """
    refresh = RefreshToken.for_user(user)
    return {
        'refresh': str(refresh),
        'access': str(refresh.access_token),
    }

# Register View (Creates User & Logs Them In)
@api_view(['POST'])
def register(request):
    """ Register a new user and return JWT tokens """
    username = request.data.get('username')
    password = request.data.get('password')
    first_name = request.data.get('first_name', '')
    

    if not username or not password:
        return Response({"error": "Username and password are required"}, status=status.HTTP_400_BAD_REQUEST)

    if User.objects.filter(username=username).exists():
        return Response({"error": "Username already exists"}, status=status.HTTP_400_BAD_REQUEST)

    # Create user
    user = User.objects.create_user(
        username=username,
        password=password,
        first_name=first_name,
        
    )

    # Generate JWT tokens for the new user
    tokens = get_tokens_for_user(user)

    return Response({
        "message": "User created successfully",
        "access": tokens['access'],
        "refresh": tokens['refresh'],
        "full_name": f"{user.first_name}".strip()
    }, status=status.HTTP_201_CREATED)

