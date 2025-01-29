import requests
import time

def get_instagram_following(user_id, session_id, csrftoken, x_ig_app_id):
    """
    Fetches the list of users a user is following on Instagram.

    Args:
        user_id (str): Instagram user ID.
        session_id (str): Instagram session ID.
        csrftoken (str): Instagram CSRF token.
        x_ig_app_id (str): Instagram app ID.

    Returns:
        list: A list of users the account is following, or None on error.
    """
    headers = {
        "cookie": f"csrftoken={csrftoken}; ds_user_id={user_id}; sessionid={session_id}",
        "referer": f"https://www.instagram.com/{user_id}/following/?next=/",
        "x-csrftoken": csrftoken,
        "x-ig-app-id": x_ig_app_id,
    }

    following = []
    next_max_id = None
    max_retries = 3
    retry_delay = 5
    count = 12

    while True:
        url = f"https://www.instagram.com/api/v1/friendships/{user_id}/following/?count={count}"
        if next_max_id:
            url += f"&max_id={next_max_id}"

        retries = 0
        while retries < max_retries:
            try:
                print(f"Fetching URL: {url}, Retry: {retries}, Count: {count}")
                response = requests.get(url, headers=headers, timeout=15)
                response.raise_for_status()
                data = response.json()

                if 'users' not in data:
                    print(f"Error: 'users' key not found in the response: {data}")
                    return None

                users_data = data.get('users', [])
                following.extend(users_data)

                # Update next_max_id for pagination
                next_max_id = data.get('next_max_id')

                # If no more results and count is still 12, switch to count=1
                if not next_max_id and count == 12:
                    print("No more results with count 12, switching to count 1.")
                    count = 1
                    break  # Break out of this request loop to retry with count=1

                # If no more results with count=1, exit the loop
                if not next_max_id:
                    break
                break
            except requests.exceptions.RequestException as e:
                print(f"Request failed: {e}")
                retries += 1
                if retries < max_retries:
                    print(f"Retrying in {retry_delay} seconds...")
                    time.sleep(retry_delay)
                else:
                    print(f"Max retries exceeded. Aborting.")
                    return None

        # Exit the main loop if no next_max_id and count=1
        if not next_max_id and count == 1:
            break

    return following
