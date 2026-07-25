import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/health_context.dart';

String buildDailyAgentFingerprint(HealthContext context) {
  final canonical = jsonEncode(context.toFingerprintJson());
  return sha256.convert(utf8.encode(canonical)).toString();
}
