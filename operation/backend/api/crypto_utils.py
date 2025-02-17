from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives import padding
from cryptography.hazmat.backends import default_backend
import base64
import os

# Option 1: Use a string-based key (make sure it's 32 characters)
SECRET_KEY_STRING = "your-32-character-secret-key-abc"

if len(SECRET_KEY_STRING) != 32:
    raise ValueError("Secret key must be 32 characters long.")

SECRET_KEY = SECRET_KEY_STRING.encode("utf-8")




def encrypt_data(plain_text, key=SECRET_KEY):
    """Encrypts the given plain text using AES-256 CBC mode."""
    iv = os.urandom(16)  # Generate a random IV
    cipher = Cipher(algorithms.AES(key), modes.CBC(iv), backend=default_backend())
    encryptor = cipher.encryptor()

    # Pad the plain_text to be a multiple of 16 bytes
    padder = padding.PKCS7(algorithms.AES.block_size).padder()
    padded_text = padder.update(plain_text.encode("utf-8")) + padder.finalize()

    encrypted_bytes = encryptor.update(padded_text) + encryptor.finalize()
    return base64.b64encode(iv + encrypted_bytes).decode("utf-8")


def decrypt_data(encrypted_text, key=SECRET_KEY):
    """Decrypts the given encrypted text using AES-256 CBC mode."""
    encrypted_data = base64.b64decode(encrypted_text)
    iv = encrypted_data[:16]
    encrypted_bytes = encrypted_data[16:]

    cipher = Cipher(algorithms.AES(key), modes.CBC(iv), backend=default_backend())
    decryptor = cipher.decryptor()

    decrypted_padded_text = decryptor.update(encrypted_bytes) + decryptor.finalize()

    # Remove padding
    unpadder = padding.PKCS7(algorithms.AES.block_size).unpadder()
    decrypted_text = unpadder.update(decrypted_padded_text) + unpadder.finalize()

    return decrypted_text.decode("utf-8")