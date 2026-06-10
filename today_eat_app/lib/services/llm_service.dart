import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

enum LlmMode { direct, server }

class LlmConfig {
  LlmConfig({
    this.mode = LlmMode.direct,
    // Direct mode
    this.apiKey,
    this.baseUrl = 'https://api.openai.com/v1',
    this.model = 'gpt-4o',
    // Server mode
    this.serverUrl,
    this.authToken,
    this.username,
    this.temperature = 0.3,
  });

  final LlmMode mode;
  final String? apiKey;
  final String? baseUrl;
  final String? model;
  final String? serverUrl;
  final String? authToken;
  final String? username;
  final double temperature;
}

class LlmService {
  LlmService({this._config});

  static const _keyStorage = FlutterSecureStorage();
  static const _modeKey = 'llm_mode';
  static const _apiKeyKey = 'llm_api_key';
  static const _baseUrlKey = 'llm_base_url';
  static const _modelKey = 'llm_model';
  static const _serverUrlKey = 'llm_server_url';
  static const _authTokenKey = 'llm_auth_token';
  static const _usernameKey = 'llm_username';

  LlmConfig? get config => _config;

  LlmConfig? _config;

  bool get isConfigured {
    if (_config == null) return false;
    if (_config!.mode == LlmMode.server) {
      return _config!.serverUrl != null &&
          _config!.serverUrl!.isNotEmpty &&
          _config!.authToken != null &&
          _config!.authToken!.isNotEmpty;
    }
    return _config!.apiKey != null && _config!.apiKey!.isNotEmpty;
  }

  Future<bool> loadConfig() async {
    final modeStr = await _keyStorage.read(key: _modeKey) ?? 'direct';
    final mode = modeStr == 'server' ? LlmMode.server : LlmMode.direct;

    if (mode == LlmMode.server) {
      final serverUrl = await _keyStorage.read(key: _serverUrlKey);
      final authToken = await _keyStorage.read(key: _authTokenKey);
      final username = await _keyStorage.read(key: _usernameKey);
      if (serverUrl == null || serverUrl.isEmpty ||
          authToken == null || authToken.isEmpty) {
        return false;
      }
      _config = LlmConfig(
        mode: LlmMode.server,
        serverUrl: serverUrl.replaceAll(RegExp(r'/+$'), ''),
        authToken: authToken,
        username: username,
      );
      return true;
    }

    // Direct mode
    final apiKey = await _keyStorage.read(key: _apiKeyKey);
    if (apiKey == null || apiKey.isEmpty) return false;

    final baseUrl = await _keyStorage.read(key: _baseUrlKey) ??
        'https://api.openai.com/v1';
    final model = await _keyStorage.read(key: _modelKey) ?? 'gpt-4o';

    _config = LlmConfig(
      mode: LlmMode.direct,
      apiKey: apiKey,
      baseUrl: baseUrl.replaceAll(RegExp(r'/+$'), ''),
      model: model,
    );
    return true;
  }

  Future<void> saveDirectConfig({
    required String apiKey,
    String? baseUrl,
    String? model,
  }) async {
    await _keyStorage.write(key: _modeKey, value: 'direct');
    await _keyStorage.write(key: _apiKeyKey, value: apiKey);
    if (baseUrl != null) {
      await _keyStorage.write(key: _baseUrlKey, value: baseUrl);
    }
    if (model != null) {
      await _keyStorage.write(key: _modelKey, value: model);
    }
    _config = LlmConfig(
      mode: LlmMode.direct,
      apiKey: apiKey,
      baseUrl: (baseUrl ?? 'https://api.openai.com/v1')
          .replaceAll(RegExp(r'/+$'), ''),
      model: model ?? 'gpt-4o',
    );
  }

  Future<void> saveServerConfig({
    required String serverUrl,
    required String authToken,
    String? username,
  }) async {
    await _keyStorage.write(key: _modeKey, value: 'server');
    await _keyStorage.write(key: _serverUrlKey, value: serverUrl);
    await _keyStorage.write(key: _authTokenKey, value: authToken);
    if (username != null) {
      await _keyStorage.write(key: _usernameKey, value: username);
    }
    _config = LlmConfig(
      mode: LlmMode.server,
      serverUrl: serverUrl.replaceAll(RegExp(r'/+$'), ''),
      authToken: authToken,
      username: username,
    );
  }

  Future<void> clearConfig() async {
    await _keyStorage.delete(key: _modeKey);
    await _keyStorage.delete(key: _apiKeyKey);
    await _keyStorage.delete(key: _baseUrlKey);
    await _keyStorage.delete(key: _modelKey);
    await _keyStorage.delete(key: _serverUrlKey);
    await _keyStorage.delete(key: _authTokenKey);
    await _keyStorage.delete(key: _usernameKey);
    _config = null;
  }

  /// Call LLM with text-only prompt.
  Future<Map<String, dynamic>> callLlm({
    required String systemPrompt,
    required String userPrompt,
    double? temperature,
  }) async {
    _ensureConfigured();

    if (_config!.mode == LlmMode.server) {
      return _callServerChat(
        messages: [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
        temperature: temperature,
      );
    }

    // Direct mode
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

    return _parseResponse(response);
  }

  /// Call LLM with single image (base64).
  Future<Map<String, dynamic>> callLlmWithImage({
    required String systemPrompt,
    required String text,
    required String imageBase64,
    double? temperature,
  }) async {
    _ensureConfigured();

    if (_config!.mode == LlmMode.server) {
      return _callServerChat(
        messages: [
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
        temperature: temperature,
      );
    }

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

    return _parseResponse(response);
  }

  /// Call LLM with multiple images (for multi-photo food recognition).
  Future<Map<String, dynamic>> callLlmWithImages({
    required String systemPrompt,
    required String text,
    required List<String> imageBase64List,
    double? temperature,
  }) async {
    _ensureConfigured();

    final contentParts = <Map<String, dynamic>>[
      {'type': 'text', 'text': text},
      ...imageBase64List.map((b64) => {
            'type': 'image_url',
            'image_url': {'url': 'data:image/jpeg;base64,$b64'},
          }),
    ];

    if (_config!.mode == LlmMode.server) {
      return _callServerChat(
        messages: [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': contentParts},
        ],
        temperature: temperature,
      );
    }

    final c = _config!;
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
    ).timeout(const Duration(seconds: 45));

    return _parseResponse(response);
  }

  // ===== Server mode internals =====

  Future<Map<String, dynamic>> _callServerChat({
    required List<Map<String, dynamic>> messages,
    double? temperature,
  }) async {
    final c = _config!;
    final body = <String, dynamic>{
      'model': 'gpt-4o',
      'messages': messages,
      'temperature': temperature ?? c.temperature,
    };

    // Always request JSON format for structured output
    body['response_format'] = {'type': 'json_object'};

    final response = await http.post(
      Uri.parse('${c.serverUrl}/v1/ai/chat'),
      headers: {
        'Authorization': 'Bearer ${c.authToken}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw LlmException(
        '服务器 AI 代理错误 (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final content = data['choices']?[0]?['message']?['content'] as String?;
    if (content == null || content.isEmpty) {
      throw LlmException('AI 返回内容为空');
    }

    return jsonDecode(content) as Map<String, dynamic>;
  }

  // ===== Shared internals =====

  Map<String, dynamic> _parseResponse(http.Response response) {
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
      throw LlmException('LLM 未配置，请在设置中配置 AI');
    }
  }
}

class LlmException implements Exception {
  LlmException(this.message);
  final String message;

  @override
  String toString() => message;
}
