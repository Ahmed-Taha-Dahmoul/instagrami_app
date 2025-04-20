import httpx
from .models import InstagramUser_data
from django.db import transaction

def get_instagram_following(user_id, session_id, csrftoken, x_ig_app_id):
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

    with httpx.Client() as client:
        while True:
            url = f"https://www.instagram.com/api/v1/friendships/{user_id}/following/?count={count}"
            if next_max_id:
                url += f"&max_id={next_max_id}"

            retries = 0
            while retries < max_retries:
                try:
                    print(f"Fetching URL: {url}, Retry: {retries}, Count: {count}")
                    response = client.get(url, headers=headers, timeout=15)
                    response.raise_for_status()
                    data = response.json()

                    if 'users' not in data:
                        print(f"Error: 'users' key not found in the response: {data}")
                        return None

                    users_data = data.get('users', [])
                    following.extend(users_data)

                    # Update next_max_id for pagination
                    next_max_id = data.get('next_max_id')

                    if not next_max_id and count == 12:
                        print("No more results with count 12, switching to count 1.")
                        count = 1
                        break

                    if not next_max_id:
                        break
                    break
                except httpx.RequestError as e:
                    print(f"Request failed: {e}")
                    retries += 1
                    if retries < max_retries:
                        print(f"Retrying in {retry_delay} seconds...")
                        import time
                        time.sleep(retry_delay)
                    else:
                        print(f"Max retries exceeded. Aborting.")
                        return None

            if not next_max_id and count == 1:
                break

    return following

@transaction.atomic
def _update_instagram_user_data(user, following_data):
    try:
        user_instances = InstagramUser_data.objects.filter(user=user)

        if user_instances.exists():
            for user_instance in user_instances:
                user_instance.old_list = user_instance.new_list
                user_instance.new_list = following_data
                user_instance.save()
                print(f"Data updated for user {user.username}")
        else:
            print(f"Instagram data not found for user {user.username}.")
    except Exception as e:
        print(f"Error saving data: {e}")
        raise


def fetch_and_save_following(user):
    instagram_data = InstagramUser_data.objects.filter(user=user).first()

    if not instagram_data:
        print(f"No Instagram data found for user {user.username}.")
        return

    user_id = instagram_data.user1_id
    session_id = instagram_data.session_id
    csrftoken = instagram_data.csrftoken
    x_ig_app_id = instagram_data.x_ig_app_id

    following_data = get_instagram_following(user_id, session_id, csrftoken, x_ig_app_id)

    if following_data is not None:
        try:
            _update_instagram_user_data(user, following_data)
        except Exception as e:
            print(f"Error saving data: {e}")
