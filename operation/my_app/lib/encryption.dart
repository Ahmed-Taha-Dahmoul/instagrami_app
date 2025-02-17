import 'package:encrypt/encrypt.dart' as encrypt;
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';

class EncryptionHelper {
  // static const String _secretKey =
  //     "your-32-character-secret-key-abcdef"; // Must be exactly 32 characters (old way)

  // Replace with the Base64 encoded key from Django
  //**IMPORTANT: The key in crypto_utils.py is no longer Base64.  It's a string**
  static final String _secretKeyString = "your-32-character-secret-key-abc";
  static final Uint8List _secretKeyBytes =
      Uint8List.fromList(_secretKeyString.codeUnits);

  static String encryptData(String plainText) {
    final key = encrypt.Key(_secretKeyBytes); // Use bytes!
    final iv = _generateRandomIV(); // Generate a new IV for each encryption

    final encrypter =
        encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
    final encrypted = encrypter.encrypt(plainText, iv: iv);

    // Combine IV + encrypted text and encode as Base64
    final combined = iv.bytes + encrypted.bytes;
    return base64Encode(combined);
  }

  static String decryptData(String encryptedText) {
    final key = encrypt.Key(_secretKeyBytes); // Use bytes!

    final raw = base64Decode(encryptedText);

    final iv = encrypt.IV(Uint8List.fromList(raw.sublist(0, 16))); // Extract IV

    final encryptedBytes = raw.sublist(16); // Extract encrypted data

    final encrypter =
        encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));

    try {
      final decrypted = encrypter.decryptBytes(
        encrypt.Encrypted(Uint8List.fromList(encryptedBytes)),
        iv: iv,
      );

      return utf8.decode(decrypted);
    } catch (e) {
      rethrow; // Re-throw the exception to be caught in ApiService
    }
  }

  static encrypt.IV _generateRandomIV() {
    final random = Random.secure();
    final ivBytes = List<int>.generate(16, (_) => random.nextInt(256));
    return encrypt.IV(Uint8List.fromList(ivBytes));
  }
}
