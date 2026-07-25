import 'dart:convert';

Map<String, dynamic> parseLlmJsonObject(String content) {
  var normalized = content.trim();
  if (normalized.startsWith('```')) {
    normalized = normalized
        .replaceFirst(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'\s*```$'), '')
        .trim();
  }
  if (normalized.isEmpty) {
    throw const FormatException('AI 返回内容为空');
  }
  final decoded = jsonDecode(normalized);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('AI 返回内容必须是 JSON 对象');
  }
  return decoded;
}
