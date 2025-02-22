import httpx
import asyncio
import json
import os
from typing import Optional, List, Dict, Any


async def get_instagram_following(
    user_id: str, session_id: str, csrftoken: str, x_ig_app_id: str
) -> Optional[List[Dict[str, Any]]]:
    """
    Asynchronously retrieves the list of users a given Instagram user is following.

    Args:
        user_id: The Instagram user ID.
        session_id: The Instagram session ID.
        csrftoken: The CSRF token.
        x_ig_app_id: The X-IG-App-ID.

    Returns:
        A list of dictionaries, where each dictionary represents a user being
        followed, or None if the retrieval fails.  The list is also saved
        to a JSON file.
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
    count = 100  # Keep it reasonable to avoid rate-limiting

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
                    response.raise_for_status()  # Raises HTTPStatusError for bad responses (4xx or 5xx)
                    data = response.json()

                    if "users" not in data:
                        print(f"Error: 'users' key not found in the response: {data}")
                        return None  # Or raise an exception, depending on desired behavior

                    users_data = data.get("users", [])
                    following.extend(users_data)

                    next_max_id = data.get("next_max_id")

                    if not next_max_id:
                        break  # No more pages
                    break # Exit retry loop on success
                except httpx.RequestError as e:
                    print(f"Request failed: {e}")
                    retries += 1
                    if retries < max_retries:
                        print(f"Retrying in {retry_delay} seconds...")
                        await asyncio.sleep(retry_delay)
                    else:
                        print(f"Max retries exceeded. Aborting.")
                        return None  # Or raise an exception

                except httpx.HTTPStatusError as e:
                    print(f"HTTP error occurred: {e}")
                    # Add more specific error handling here if needed, e.g., for 404, 429 (rate limit)
                    if e.response.status_code == 429: # Too Many Requests
                        print("Rate limited.  Consider increasing retry_delay or implementing exponential backoff.")
                        retry_after = int(e.response.headers.get("retry-after", retry_delay))
                        print(f"Waiting for {retry_after} seconds")
                        await asyncio.sleep(retry_after)
                        retries +=1

                    elif e.response.status_code == 404: # Not Found.
                        print("user ID not found")
                        return None
                    else: # other error.
                        return None


                except (KeyError, json.JSONDecodeError) as e:
                    print(f"Data error: {e}")  # Handle cases where the response is not as expected
                    return None

            if not next_max_id:
                break #exit the While loop if there is no next id.

    return following


async def save_following_to_json(following: List[Dict[str, Any]], user_id: str):
    """
    Saves the following list to a JSON file.

    Args:
        following: The list of users being followed.
        user_id: The Instagram user ID (used for the filename).
    """
    filename = f"following_{user_id}.json"
    filepath = os.path.join(".", filename)  # Save in the current directory

    try:
        with open(filepath, "w", encoding="utf-8") as f:
            json.dump(following, f, indent=4)  # Use indent for readability
        print(f"Following list saved to {filepath}")
    except Exception as e:
        print(f"Error saving to JSON: {e}")


async def main():
    # Replace these values with your actual credentials and data
    user_id = "5100464648"
    session_id = (
        "5100464648%3AVpkViEWQDRKBNM%3A25%3AAYfLDSm2V44fHwTTVsPHnmTGlB964G60FtAVxd2fpg"
    )
    csrftoken = "7huvCGE2GpZzZfaaw6s0Lhbzz1dpovOj"
    x_ig_app_id = "1217981644879628"

    following = await get_instagram_following(user_id, session_id, csrftoken, x_ig_app_id)

    if following:
        print(f"Found {len(following)} people the user is following.")
        await save_following_to_json(following, user_id)
    else:
        print("Failed to retrieve following list.")


if __name__ == "__main__":
    asyncio.run(main())