from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from rest_framework.response import Response
from rest_framework import status
from django.contrib.auth.models import User
from rest_framework.decorators import api_view

# User Registration View
@api_view(['POST'])
def register(request):
    """ Register a new user """
    username = request.data.get('username')
    password = request.data.get('password')

    if not username or not password:
        return Response({"error": "Username and password are required"}, status=status.HTTP_400_BAD_REQUEST)

    if User.objects.filter(username=username).exists():
        return Response({"error": "Username already exists"}, status=status.HTTP_400_BAD_REQUEST)

    user = User.objects.create_user(username=username, password=password)
    return Response({"message": "User created successfully"}, status=status.HTTP_201_CREATED)

# Custom Token Obtain Pair View (Login)
class CustomTokenObtainPairView(TokenObtainPairView):
    """ Custom JWT Login view """
    def post(self, request, *args, **kwargs):
        # Call the default TokenObtainPairView to generate tokens
        response = super().post(request, *args, **kwargs)
        # Return the access and refresh tokens
        return Response({
            "access": response.data['access'],
            "refresh": response.data['refresh']
        })
