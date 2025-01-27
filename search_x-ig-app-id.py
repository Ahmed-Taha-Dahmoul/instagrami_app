from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.service import Service
from webdriver_manager.chrome import ChromeDriverManager
import re

def extract_x_ig_app_id():
    options = webdriver.ChromeOptions()
    options.add_argument('--start-maximized')
    options.add_argument('--user-data-dir=C:\\Users\\friv1\\AppData\\Local\\Google\\Chrome\\User Data')  # Default profile directory
    options.add_argument('--profile-directory=Default')  # Explicitly using the 'Default' profile
    options.add_argument('--disable-extensions')
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')

    # Launch the browser
    service = Service(ChromeDriverManager().install())
    driver = webdriver.Chrome(service=service, options=options)
    print("Browser launched!")

    try:
        # Load Instagram
        driver.get("https://www.instagram.com/")

        # Wait for the page to load completely (adjust timeout as needed)
        driver.implicitly_wait(10)

        # Extract all page source
        page_source = driver.page_source

        # Look for x-ig-app-id in the page source or JavaScript files
        match = re.search(r'"appId":"(\d+)"', page_source)

        if match:
            x_ig_app_id = match.group(1)
            print(f"Extracted x-ig-app-id: {x_ig_app_id}")
            return x_ig_app_id
        else:
            print("Could not find x-ig-app-id in the page source.")
            return None

    finally:
        driver.quit()

# Example usage
x_ig_app_id = extract_x_ig_app_id()
if x_ig_app_id:
    print(f"x-ig-app-id: {x_ig_app_id}")
else:
    print("Failed to extract x-ig-app-id.")
