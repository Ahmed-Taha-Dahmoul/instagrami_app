from django.test import TestCase
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APIRequestFactory, force_authenticate
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth.models import User
from .models import InstagramUser_data, FrontFlags
from .views import remove_following  # Import your view function!


class RemoveFollowingViewTest(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(username="testuser", password="testpassword")
        self.factory = APIRequestFactory()
        FrontFlags.objects.create(user=self.user)
        self.url = reverse("remove_following")  # Still useful for other tests

    def _create_user_data(self):
        self.user_data = InstagramUser_data.objects.create(
            user=self.user,
            user1_id="123",
            session_id="session123",
            csrftoken="csrf123",
            x_ig_app_id="app123",
            new_following_list=[
                {"pk": "1", "username": "user1"},
                {"pk": "2", "username": "user2"},
            ],
            old_following_list=[
                {"pk": "1", "username": "user1"},
                {"pk": "2", "username": "user2"},
            ],
            instagram_following_count=2,
        )

    def _get_authenticated_request(self, data=None):
        # Helper function to create an authenticated request
        request = self.factory.post(self.url, data, format='json') # Use the factory
        refresh = RefreshToken.for_user(self.user)
        force_authenticate(request, user=self.user, token=str(refresh.access_token))
        return request

    def test_remove_following_success(self):
        """Test successful removal."""
        self._create_user_data()
        data = {"pk": "1"}
        request = self._get_authenticated_request(data)
        response = remove_following(request)  # Call the view function directly!
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data, {"message": "User removed from following list successfully"})

        self.user_data.refresh_from_db()
        self.assertEqual(len(self.user_data.new_following_list), 1)
        self.assertEqual(self.user_data.new_following_list[0]["pk"], "2")
        self.assertEqual(self.user_data.old_following_list[0]["pk"], "2") # Corrected assertion
        self.assertEqual(self.user_data.instagram_following_count, 1)
        self.assertEqual(self.user_data.who_i_follow_he_dont_followback, ["2"])

    def test_remove_following_missing_pk(self):
        """Test missing 'pk'."""
        self._create_user_data()
        data = {}  # Missing pk
        request = self._get_authenticated_request(data)
        response = remove_following(request) # Call view directly
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(response.data, {"error": "Missing 'pk' in request body"})

    def test_remove_following_user_not_found(self):
        """Test 'pk' not in following list."""
        self._create_user_data()
        data = {"pk": "3"}  # Invalid pk
        request = self._get_authenticated_request(data)
        response = remove_following(request) # Call view directly
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(response.data, {"error": "User not found in following list"})

    def test_remove_following_no_instagram_data(self):
        """Test no Instagram data."""
        # Don't create user_data
        data = {"pk": "1"}
        request = self._get_authenticated_request(data)
        response = remove_following(request) # Call view directly
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(response.data, {"error": "No Instagram data found for this user"})

    def test_remove_following_no_authentication(self):
        """Test unauthenticated request."""
        # Don't authenticate the request
        request = self.factory.post(self.url, {"pk":"1"}, format='json')
        response = remove_following(request)
        # Expect 401 Unauthorized (or possibly 403 Forbidden)
        self.assertTrue(
            response.status_code == status.HTTP_401_UNAUTHORIZED
            or response.status_code == status.HTTP_403_FORBIDDEN
        )

    def test_remove_following_count_zero(self):
        self._create_user_data()
        self.user_data.instagram_following_count = 0
        self.user_data.save()
        data = {"pk": "1"}
        request = self._get_authenticated_request(data)
        response = remove_following(request)  # Call the view function directly!
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.user_data.refresh_from_db()
        self.assertEqual(self.user_data.instagram_following_count, 0)

    def test_remove_following_count_none(self):
        self._create_user_data()
        self.user_data.instagram_following_count = None
        self.user_data.save()
        data = {"pk": "1"}
        request = self._get_authenticated_request(data)
        response = remove_following(request)  # Call the view function directly!
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.user_data.refresh_from_db()
        self.assertIsNone(self.user_data.instagram_following_count)