import 'dart:convert';
import 'dart:math';

class EncryptionHelper {
  // Lightweight client-side encryption simulation for E2EE disappearing messages
  // In production, use Signal Protocol or AES-256-GCM with derived chat keys.
  static String encryptMessage(String plainText, String secretKey) {
    if (plainText.isEmpty) return plainText;
    try {
      final keyBytes = utf8.encode(secretKey);
      final textBytes = utf8.encode(plainText);
      List<int> encrypted = [];
      for (int i = 0; i < textBytes.length; i++) {
        encrypted.add(textBytes[i] ^ keyBytes[i % keyBytes.length]);
      }
      return "E2EE:${base64Encode(encrypted)}";
    } catch (_) {
      return plainText;
    }
  }

  static String decryptMessage(String cipherText, String secretKey) {
    if (!cipherText.startsWith("E2EE:")) return cipherText;
    try {
      final raw = cipherText.substring(5);
      final keyBytes = utf8.encode(secretKey);
      final textBytes = base64Decode(raw);
      List<int> decrypted = [];
      for (int i = 0; i < textBytes.length; i++) {
        decrypted.add(textBytes[i] ^ keyBytes[i % keyBytes.length]);
      }
      return utf8.decode(decrypted);
    } catch (_) {
      return cipherText;
    }
  }

  static String generateSecretKey(String chatId) {
    return "ZenvoraE2EEKey_$chatId";
  }
}
