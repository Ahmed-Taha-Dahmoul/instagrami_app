from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from webdriver_manager.chrome import ChromeDriverManager
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
import requests
import re
import json
import time
import random

# List of common User-Agent strings for avoiding detection
USER_AGENTS = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4430.93 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Safari/537.36",
    "Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36 Edge/91.0.864.64"
]

def get_dynamic_instagram_data(username, password):
    """
    Uses Selenium to extract dynamic Instagram data.
    Handles verification code if required.

    Args:
        username (str): Instagram username.
        password (str): Instagram password.

    Returns:
        dict: A dictionary containing x-ig-app-id, csrftoken, and sessionid, or None on error.
    """
    options = webdriver.ChromeOptions()
    options.add_argument('--start-maximized')
    options.add_argument('--disable-extensions')
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    options.add_argument('--disable-gpu')
    options.add_argument('--window-size=1920x1080')
    options.add_argument('--incognito')
    options.add_argument('--headless')  # Enable headless mode

    # Randomly select a User-Agent to reduce detection
    user_agent = random.choice(USER_AGENTS)
    options.add_argument(f"user-agent={user_agent}")

    options.add_argument('--enable-unsafe-swiftshader')

    service = Service(ChromeDriverManager().install())
    driver = webdriver.Chrome(service=service, options=options)
    print("Browser launched!")

    try:
        driver.get("https://www.instagram.com/")
        WebDriverWait(driver, 20).until(
            EC.presence_of_element_located((By.NAME, "username"))
        )

        # Find the username and password fields and input the credentials
        username_field = driver.find_element(By.NAME, "username")
        password_field = driver.find_element(By.NAME, "password")
        username_field.send_keys(username)
        password_field.send_keys(password)

        # Find the login button and click it
        login_button = driver.find_element(By.XPATH, "//button[@type='submit']")
        login_button.click()

        # Check for verification code request
        try:
            WebDriverWait(driver, 20).until(
                EC.presence_of_element_located((By.NAME, "verificationCode"))
            )
            print("Instagram is asking for a verification code.")
            verification_code = input("Please enter the verification code sent to your device: ")

            verification_field = driver.find_element(By.NAME, "verificationCode")
            verification_field.send_keys(verification_code)

            # Find the confirm button and click it
            confirm_button = driver.find_element(By.XPATH, "//button[text()='Confirmer']")
            confirm_button.click()

        except:
            print("No verification code needed.")
            pass  # No verification code needed

        # Wait for the "Save Your Login Info?" prompt or the homepage to load
        try:
            WebDriverWait(driver, 30).until(
                EC.presence_of_element_located((By.XPATH, "//button[text()='Not Now']"))
            ).click()  # Click "Not Now" on the "Save Your Login Info?" prompt
        except:
            pass  # Ignore if the prompt doesn't appear

        # Wait for the homepage to fully load
        WebDriverWait(driver, 30).until(
            EC.presence_of_element_located((By.XPATH, "//a[contains(@href, '/direct/inbox/')]"))
        )

        # Extract cookies
        instagram_cookies = [
            cookie for cookie in driver.get_cookies() if "instagram.com" in cookie['domain']
        ]
        cookies_dict = {cookie['name']: cookie['value'] for cookie in instagram_cookies}
        print(cookies_dict)

        # Extract x-ig-app-id from page source
        page_source = driver.page_source
        match = re.search(r'"appId":"(\d+)"', page_source)
        x_ig_app_id = match.group(1) if match else None

        session_id = cookies_dict.get("sessionid")
        csrftoken = cookies_dict.get("csrftoken")
        user_id = cookies_dict.get("ds_user_id")

        if x_ig_app_id and session_id and csrftoken and user_id:
            return {
                'x_ig_app_id': x_ig_app_id,
                'session_id': session_id,
                'csrftoken': csrftoken,
                'user_id': user_id
            }
        else:
            print("Failed to extract all required data.")
            return None

    finally:
        driver.quit()
        print("Browser closed!")

def get_instagram_following(user_id, session_id, csrftoken, x_ig_app_id):
    """Fetches the list of users a user is following on Instagram."""
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

def save_to_json(data, filename="instagram_following.json"):
    """Saves data to a JSON file."""
    with open(filename, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=4, ensure_ascii=False)
    print(f"Data saved to '{filename}'")

if __name__ == '__main__':
    username = input("Enter your Instagram username: ")
    password = input("Enter your Instagram password: ")

    instagram_data = get_dynamic_instagram_data(username, password)

    if instagram_data:
        print("Dynamic Instagram data retrieved successfully.")
        following_list = get_instagram_following(
            instagram_data['user_id'],
            instagram_data['session_id'],
            instagram_data['csrftoken'],
            instagram_data['x_ig_app_id']
        )

        if following_list:
            save_to_json(following_list)
            print("Following list saved to instagram_following.json")
        else:
            print("Failed to retrieve following list.")
    else:
        print("Failed to retrieve dynamic Instagram data.")
