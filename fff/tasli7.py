import requests
import json
import time


class InstagramService:
    def __init__(self, user_id, session_id, csrf_token, x_ig_app_id):
        self.user_id = user_id
        self.session_id = session_id
        self.csrf_token = csrf_token
        self.x_ig_app_id = x_ig_app_id
        self.base_url = "https://www.instagram.com"  # Store base URL
        self.headers = {
            "cookie": f"csrftoken={self.csrf_token}; ds_user_id={self.user_id}; sessionid={self.session_id}",
            "referer": f"{self.base_url}/{self.user_id}/following/?next=/",
            "x-csrftoken": self.csrf_token,
            "x-ig-app-id": self.x_ig_app_id,
        }
        self.max_retries = 3
        self.retry_delay = 5


    def get_instagram_following(self):
        following = []
        next_max_id = None
        count = 100

        while True:
            url = f"{self.base_url}/api/v1/friendships/{self.user_id}/following/?count={count}"

            if next_max_id:
                url += f"&max_id={next_max_id}"

            retries = 0
            while retries < self.max_retries:
                try:
                    print(url)  # Keep the print for debugging
                    response = requests.get(url, headers=self.headers)

                    if response.status_code != 200:
                        raise Exception(f"Request failed with status: {response.status_code}.  Response text: {response.text}") # added response text

                    data = response.json()
                    if 'users' not in data:
                        print(f"Error: 'users' key not found in response. Response: {data}") # added error handling
                        return None


                    following.extend(data['users'])
                    next_max_id = data.get('next_max_id') # Use .get() to avoid KeyError

                    if next_max_id is None and count == 100:
                        count = 1
                        break

                    if next_max_id is None:
                        break

                    break  # Exit retry loop on success
                except requests.exceptions.RequestException as e: # More specific exception handling
                    print(f"Request error: {e}")
                    retries += 1
                    if retries < self.max_retries:
                        time.sleep(self.retry_delay)
                    else:
                        print("Max retries reached.")
                        return None
                except json.JSONDecodeError as e: #handling json error
                    print(f"JSON decoding error: {e}.  Response text: {response.text}")
                    retries += 1
                    if retries < self.max_retries:
                        time.sleep(self.retry_delay)
                    else:
                        print("Max retries reached.")
                        return None
                except KeyError as e: # handling key error
                   print(f"KeyError: {e}. Response text: {data}")
                   return None



            if next_max_id is None and count == 1:
                break

        return following


# Example usage (Replace with your actual credentials):
if __name__ == "__main__":
    user_id = "3028440064"  # Replace with the target user's ID
    session_id = "3028440064%3ABmdAdyHVWKUzY0%3A3%3AAYeJrTXI5eD_rG9YZL0N1m6DN2gBQ7hbON3gRoT25w"  # Replace with your session ID
    csrf_token = "vMhxh4OeBlmPnCTdR9knHqr7mYH6A9qh"  # Replace with your CSRF token
    x_ig_app_id = "1217981644879628"   # Replace with your X-IG-App-Id

    instagram_service = InstagramService(user_id, session_id, csrf_token, x_ig_app_id)
    following_list = instagram_service.get_instagram_following()

    if following_list:
        print(f"Number of following: {len(following_list)}")
        # Print usernames (or other details) as an example.  Important to check Rate Limits
        for user in following_list:
            print(user.get('username', 'No username'))  # Safely access 'username', default to a message if it doesn't exist
    else:
        print("Failed to retrieve following list.")