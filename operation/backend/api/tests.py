from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient
from datetime import timedelta
from .models import InstagramUser_data
from django.contrib.auth.models import User

class InstagramUserDataTestCase(TestCase):
    def setUp(self):
        """Set up the user and InstagramUser_data instance"""
        # Create a test user
        self.user = User.objects.create_user(username='testuser', password='password123')
        print("Created test user:", self.user.username)

        # Create an InstagramUser_data object linked to the user
        self.instagram_data = InstagramUser_data.objects.create(
            user=self.user,
            instagram_follower_count=1000,
            last_time_fetched=timezone.now() - timedelta(hours=10)  # Set to 10 hours ago
        )
        print("Created InstagramUser_data for user:", self.user.username)

        # Create a client for making requests
        self.client = APIClient()

    def test_check_12_hours_passed_true(self):
        """Test when 12 hours have passed"""
        # Set the last_time_fetched to 13 hours ago
        self.instagram_data.last_time_fetched = timezone.now() - timedelta(hours=13)
        self.instagram_data.save()
        print("Updated last_time_fetched to 13 hours ago.")

        # Authenticate the user
        self.client.force_authenticate(user=self.user)
        print("Authenticated user:", self.user.username)

        # Make the GET request to check if 12 hours have passed
        response = self.client.get('/api/check-12-hours-passed/')
        print("Response:", response.data)

        # Assert the response status code is 200 OK
        self.assertEqual(response.status_code, 200)
        print("Response status code is 200")

        # Assert that the response contains the correct value for 'has_12_hours_passed'
        self.assertEqual(response.data['has_12_hours_passed'], True)
        print("12 hours have passed:", response.data['has_12_hours_passed'])

    def test_check_12_hours_passed_false(self):
        """Test when less than 12 hours have passed"""
        # Set the last_time_fetched to 10 hours ago
        self.instagram_data.last_time_fetched = timezone.now() - timedelta(hours=10)
        self.instagram_data.save()
        print("Updated last_time_fetched to 10 hours ago.")

        # Authenticate the user
        self.client.force_authenticate(user=self.user)
        print("Authenticated user:", self.user.username)

        # Make the GET request to check if 12 hours have passed
        response = self.client.get('/api/check-12-hours-passed/')
        print("Response:", response.data)

        # Assert the response status code is 200 OK
        self.assertEqual(response.status_code, 200)
        print("Response status code is 200")

        # Assert that the response contains the correct value for 'has_12_hours_passed'
        self.assertEqual(response.data['has_12_hours_passed'], False)
        print("12 hours have passed:", response.data['has_12_hours_passed'])

    def test_no_instagram_data_for_user(self):
        """Test when there's no Instagram data for the user"""
        # Create a new user without Instagram data
        new_user = User.objects.create_user(username='newuser', password='newpassword123')
        print("Created new user:", new_user.username)
        
        # Authenticate the new user
        self.client.force_authenticate(user=new_user)
        print("Authenticated new user:", new_user.username)
        
        # Make the GET request to check if 12 hours have passed
        response = self.client.get('/api/check-12-hours-passed/')
        print("Response:", response.data)

        # Assert the response status code is 404 (Not Found)
        self.assertEqual(response.status_code, 404)
        print("Response status code is 404")

        # Assert the response contains the error message
        self.assertEqual(response.data['error'], 'No Instagram data found for this user')
        print("Error message:", response.data['error'])

    def test_unauthenticated_user(self):
        """Test when an unauthenticated user tries to access the API"""
        # Make the GET request without authentication
        response = self.client.get('/api/check-12-hours-passed/')
        print("Response for unauthenticated user:", response.data)

        # Assert the response status code is 401 (Unauthorized)
        self.assertEqual(response.status_code, 401)
        print("Response status code is 401")
