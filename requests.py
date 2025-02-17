import httpx
import asyncio

# Your original script...
async def get_instagram_following(user_id, session_id, csrftoken, x_ig_app_id):
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

    async with httpx.AsyncClient() as client:
        while True:
            url = f"https://www.instagram.com/api/v1/friendships/{user_id}/following/?count={count}"
            if next_max_id:
                url += f"&max_id={next_max_id}"

            retries = 0
            while retries < max_retries:
                try:
                    print(f"Fetching URL: {url}, Retry: {retries}, Count: {count}")
                    response = await client.get(url, headers=headers, timeout=15)
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
                        await asyncio.sleep(retry_delay)
                    else:
                        print(f"Max retries exceeded. Aborting.")
                        return None

            if not next_max_id and count == 1:
                break

    return following

# Example usage:
async def main():
    # Replace these values with your actual credentials and data
    user_id = '5100464648'
    session_id = '5100464648%3AVpkViEWQDRKBNM%3A25%3AAYfLDSm2V44fHwTTVsPHnmTGlB964G60FtAVxd2fpg'
    csrftoken = '7huvCGE2GpZzZfaaw6s0Lhbzz1dpovOj'
    x_ig_app_id = '1217981644879628'

    following = await get_instagram_following(user_id, session_id, csrftoken, x_ig_app_id)
    if following:
        print(f"Found {len(following)} people the user is following.")
    else:
        print("Failed to retrieve following list.")

# Run the main function in asyncio loop
if __name__ == "__main__":
    asyncio.run(main())
