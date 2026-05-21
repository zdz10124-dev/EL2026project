import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

/// 加密服务
/// 用于保护用户敏感信息（密码、学号等）
class EncryptionService {
  // 用于 AES 加密的密钥（实际应用中应从安全存储获取）
  late final encrypt.Key _key;
  late final encrypt.IV _iv;

  EncryptionService() {
    // 初始化密钥（实际应用中应从安全存储读取或由用户提供）
    _key = encrypt.Key.fromUtf8('GKJYQ2026ELKEY!'); // 32位密钥
    _iv = encrypt.IV.fromLength(16);
  }

  /// 使用自定义密钥初始化
  EncryptionService.withKey(String keyString, String ivString) {
    _key = encrypt.Key.fromUtf8(keyString.padRight(32).substring(0, 32));
    _iv = encrypt.IV.fromUtf8(ivString.padRight(16).substring(0, 16));
  }

  /// AES 加密
  String encryptAES(String plainText) {
    final encrypter = encrypt.Encrypter(encrypt.AES(_key, mode: encrypt.AESMode.cbc));
    final encrypted = encrypter.encrypt(plainText, iv: _iv);
    return encrypted.base64;
  }

  /// AES 解密
  String decryptAES(String encryptedText) {
    final encrypter = encrypt.Encrypter(encrypt.AES(_key, mode: encrypt.AESMode.cbc));
    try {
      final decrypted = encrypter.decrypt64(encryptedText, iv: _iv);
      return decrypted;
    } catch (e) {
      throw Exception('解密失败: $e');
    }
  }

  /// SHA-256 哈希（用于密码存储，不可逆）
  String hashSHA256(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// 生成随机盐值
  static String generateSalt({int length = 16}) {
    final random = Random.secure();
    final bytes = List<int>.generate(length, (_) => random.nextInt(256));
    return base64Encode(bytes);
  }

  /// 加盐哈希（用于安全密码存储）
  String hashWithSalt(String password, String salt) {
    return hashSHA256(password + salt);
  }

  /// 验证密码
  bool verifyPassword(String password, String salt, String storedHash) {
    return hashWithSalt(password, salt) == storedHash;
  }

  /// 对敏感数据进行脱敏处理
  /// 例如：学号 20241234 -> 2024****
  static String maskSensitiveData(String data, {int visibleChars = 4}) {
    if (data.length <= visibleChars) return data;
    final visible = data.substring(0, visibleChars);
    final masked = '*' * (data.length - visibleChars);
    return '$visible$masked';
  }
}
