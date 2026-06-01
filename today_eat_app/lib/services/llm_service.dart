import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class LlmConfig {
  LlmConfig({
    required this.apiKey,
    this.baseUrl = 'https://api.openai.com/v1',
    this.model = 'gpt-4o',
    this.temperature = 0.3,
  });

  final String apiKey;
  final String baseUrl;
  final String model;
  final double temperature;
}

class LlmService {
  LlmService({this._config});

  static const _keyStorage = FlutterSecureStorage();
  static const _apiKeyKey = 'llm_api_key';
  static const _baseUrlKey = 'llm_base_url';
  static const _modelKey = 'llm_model';

  LlmConfig? _config;

  bool get isConfigured => _config != null;

  Future<bool> loadConfig() async {
    final apiKey = await _keyStorage.read(key: _apiKeyKey);
    if (apiKey == null || apiKey.isEmpty) return false;

    final baseUrl = await _keyStorage.read(key: _baseUrlKey) ??
        'https://api.openai.com/v1';
    final model = await _keyStorage.read(key: _modelKey) ?? 'gpt-4o';

    _config = LlmConfig(
      apiKey: apiKey,
      baseUrl: baseUrl.replaceAll(RegExp(r'/+$'), ''),
      model: model,
    );
    return true;
  }

  Future<void> saveConfig({
    required String apiKey,
    String? baseUrl,
    String? model,
  }) async {
    await _keyStorage.write(key: _apiKeyKey, value: apiKey);
    if (baseUrl != null) {
      await _keyStorage.write(key: _baseUrlKey, value: baseUrl);
    }
    if (model != null) {
      await _keyStorage.write(key: _modelKey, value: model);
    }
    _config = LlmConfig(
      apiKey: apiKey,
      baseUrl:
          (baseUrl ?? 'https://api.openai.com/v1').replaceAll(RegExp(r'/+$'), ''),
      model: model ?? 'gpt-4o',
    );
  }

  Future<void> clearConfig() async {
    await _keyStorage.delete(key: _apiKeyKey);
    await _keyStorage.delete(key: _baseUrlKey);
    await _keyStorage.delete(key: _modelKey);
    _config = null;
  }

  /// Call LLM with text-only prompt. Expects JSON response.
  Future<Map<String, dynamic>> callLlm({
    required String systemPrompt,
    required String userPrompt,
    double? temperature,
  }) async {
    _ensureConfigured();
    final c = _config!;

    final body = {
      'model': c.model,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
      'response_format': {'type': 'json_object'},
      'temperature': temperature ?? c.temperature,
    };

    final response = await http.post(
      Uri.parse('${c.baseUrl}/chat/completions'),
      headers: {
        'Authorization': 'Bearer ${c.apiKey}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw LlmException(
        'LLM API 错误 (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final content = data['choices']?[0]?['message']?['content'] as String?;
    if (content == null || content.isEmpty) {
      throw LlmException('LLM 返回内容为空');
    }

    return jsonDecode(content) as Map<String, dynamic>;
  }

  /// Call LLM with image (base64). Expects JSON response.
  Future<Map<String, dynamic>> callLlmWithImage({
    required String systemPrompt,
    required String text,
    required String imageBase64,
    double? temperature,
  }) async {
    _ensureConfigured();
    final c = _config!;

    final body = {
      'model': c.model,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': text},
            {
              'type': 'image_url',
              'image_url': {'url': 'data:image/jpeg;base64,$imageBase64'},
            },
          ],
        },
      ],
      'response_format': {'type': 'json_object'},
      'temperature': temperature ?? c.temperature,
    };

    final response = await http.post(
      Uri.parse('${c.baseUrl}/chat/completions'),
      headers: {
        'Authorization': 'Bearer ${c.apiKey}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw LlmException(
        'LLM API 错误 (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final content = data['choices']?[0]?['message']?['content'] as String?;
    if (content == null || content.isEmpty) {
      throw LlmException('LLM 返回内容为空');
    }

    return jsonDecode(content) as Map<String, dynamic>;
  }

  /// Call LLM with multiple image frames (for video analysis). Expects JSON response.
  Future<Map<String, dynamic>> callLlmWithImages({
    required String systemPrompt,
    required String text,
    required List<String> imageBase64List,
    double? temperature,
  }) async {
    _ensureConfigured();
    final c = _config!;

    final contentParts = <Map<String, dynamic>>[
      {'type': 'text', 'text': text},
      ...imageBase64List.map((b64) => {
            'type': 'image_url',
            'image_url': {
              'url': 'data:image/jpeg;base64,$b64',
            },
          }),
    ];

    final body = {
      'model': c.model,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': contentParts},
      ],
      'response_format': {'type': 'json_object'},
      'temperature': temperature ?? c.temperature,
    };

    final response = await http.post(
      Uri.parse('${c.baseUrl}/chat/completions'),
      headers: {
        'Authorization': 'Bearer ${c.apiKey}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw LlmException(
        'LLM API 错误 (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final content = data['choices']?[0]?['message']?['content'] as String?;
    if (content == null || content.isEmpty) {
      throw LlmException('LLM 返回内容为空');
    }

    return jsonDecode(content) as Map<String, dynamic>;
  }

  void _ensureConfigured() {
    if (_config == null) {
      throw LlmException('LLM 未配置，请在设置中输入 API Key');
    }
  }
}

class LlmException implements Exception {
  LlmException(this.message);
  final String message;

  @override
  String toString() => message;
}
