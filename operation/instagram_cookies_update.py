import os
import json
import random
import re
import getpass
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from webdriver_manager.chrome import ChromeDriverManager

USER_AGENTS = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Safari/537.36",
    "Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
]

USER_DATA_FILE = "users_data.json"

def save_user_data(new_data):
    """
    Saves user data to a JSON file. Appends to the file or updates existing user data.

    Args:
        new_data (dict): The new user data to save (must include 'user_id').
    """
    if not os.path.exists(USER_DATA_FILE):
        with open(USER_DATA_FILE, 'w', encoding='utf-8') as f:
            json.dump([new_data], f, indent=4, ensure_ascii=False)
        return

    with open(USER_DATA_FILE, 'r', encoding='utf-8') as f:
        existing_data = json.load(f)

    for i, user in enumerate(existing_data):
        if user['user_id'] == new_data['user_id']:
            existing_data[i] = new_data
            break
    else:
        existing_data.append(new_data)

    with open(USER_DATA_FILE, 'w', encoding='utf-8') as f:
        json.dump(existing_data, f, indent=4, ensure_ascii=False)

def get_user_credentials():
    """Reads user credentials (username and password) from the users_data.json file."""
    try:
        with open(USER_DATA_FILE, 'r', encoding='utf-8') as f:
            users_data = json.load(f)
            if users_data:
                # Return credentials of the first user in the file (if multiple users exist, we can modify the logic)
                return users_data[0]['username'], users_data[0]['password']
    except (FileNotFoundError, json.JSONDecodeError):
        return None, None

def update_instagram_data():
    """
    Prompts the user for credentials, extracts dynamic Instagram data, and saves it.

    Returns:
        dict: A dictionary containing x-ig-app-id, csrftoken, sessionid, and user_id, or None on error.
    """
    # Read existing user credentials (if available)
    username, password = get_user_credentials()
    if not username or not password:
        print("No valid user data found in the file. Please enter your Instagram credentials.")
        username = input("Username: ")
        password = getpass.getpass("Password: ")

    options = webdriver.ChromeOptions()
    options.add_argument('--start-maximized')
    options.add_argument('--disable-extensions')
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    options.add_argument('--disable-gpu')
    options.add_argument('--window-size=1920x1080')
    options.add_argument('--incognito')

    user_agent = random.choice(USER_AGENTS)
    options.add_argument(f"user-agent={user_agent}")

    service = Service(ChromeDriverManager().install())
    driver = webdriver.Chrome(service=service, options=options)

    try:
        driver.get("https://www.instagram.com/")
        WebDriverWait(driver, 20).until(
            EC.presence_of_element_located((By.NAME, "username"))
        )

        username_field = driver.find_element(By.NAME, "username")
        password_field = driver.find_element(By.NAME, "password")
        username_field.send_keys(username)
        password_field.send_keys(password)

        login_button = driver.find_element(By.XPATH, "//button[@type='submit']")
        login_button.click()

        try:
            WebDriverWait(driver, 20).until(
                EC.any_of(
                    EC.presence_of_element_located((By.NAME, "verificationCode")),
                    EC.presence_of_element_located((By.XPATH, "//div[@role='radiogroup']"))
                )
            )
            print("Verification might be required.")
        except:
            pass

        WebDriverWait(driver, 30).until(
            EC.presence_of_element_located((By.XPATH, "//a[contains(@href, '/direct/inbox/')]"))
        )

        cookies_dict = {cookie['name']: cookie['value'] for cookie in driver.get_cookies()}
        x_ig_app_id = re.search(r'"appId":"(\d+)"', driver.page_source)
        x_ig_app_id = x_ig_app_id.group(1) if x_ig_app_id else None

        session_id = cookies_dict.get("sessionid")
        csrftoken = cookies_dict.get("csrftoken")
        user_id = cookies_dict.get("ds_user_id")

        if x_ig_app_id and session_id and csrftoken and user_id:
            user_data = {
                'username': username,
                'password': password,
                'user_id': user_id,
                'session_id': session_id,
                'csrftoken': csrftoken,
                'x_ig_app_id': x_ig_app_id
            }
            save_user_data(user_data)
            return user_data
        else:
            return None
    finally:
        driver.quit()
