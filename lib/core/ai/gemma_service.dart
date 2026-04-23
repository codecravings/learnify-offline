import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

/// Wraps flutter_gemma for on-device Gemma 4 E4B inference.
///
/// Model: litert-community/gemma-4-E4B-it-litert-lm (~3.65 GB, downloaded once)
/// GPU-accelerated on Android via LiteRT-LM runtime.
class GemmaService {
  GemmaService._();
  static final GemmaService instance = GemmaService._();

  static const _modelUrl =
      'https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm'
      '/resolve/main/gemma-4-E4B-it.litertlm';

  static const _modelId = 'gemma-4-E4B-it.litertlm';

  static const _hfToken =
      String.fromEnvironment('HF_TOKEN', defaultValue: '');

  bool _modelReady = false;
  bool get isReady => _modelReady;

  /// Call once at app startup before any other API.
  Future<void> bootstrap() async {
    await FlutterGemma.initialize(
      huggingFaceToken: _hfToken.isNotEmpty ? _hfToken : null,
    );
  }

  /// Path for the sideloaded model (pushed via adb or Files app).
  /// On Android this is the app-specific external storage, no permissions needed.
  static const sideloadedPath =
      '/storage/emulated/0/Android/data/com.vidyasetu.vidyasetu/files/gemma-4-E4B-it.litertlm';

  /// Check whether a sideloaded .litertlm file is present at the expected path.
  Future<bool> hasSideloadedFile() async {
    try {
      return await File(sideloadedPath).exists();
    } catch (_) {
      return false;
    }
  }

  /// Call from the setup screen to download + activate the model.
  /// [onProgress] receives 0–100 download percentage.
  Future<void> initialize({void Function(double)? onProgress}) async {
    if (_modelReady) return;

    final installed = await FlutterGemma.isModelInstalled(_modelId);
    if (!installed) {
      await FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
        fileType: ModelFileType.litertlm,
      )
          .fromNetwork(
            _modelUrl,
            token: _hfToken.isNotEmpty ? _hfToken : null,
          )
          .withProgress((p) => onProgress?.call(p.toDouble()))
          .install();
    }

    _modelReady = FlutterGemma.hasActiveModel();
    debugPrint('[Gemma] Model ready: $_modelReady');
  }

  /// One-shot text generation. Creates a fresh chat each time.
  Future<String> generate({
    required String systemPrompt,
    required String userPrompt,
    int maxTokens = 2048,
  }) async {
    _assertReady();
    final model = await FlutterGemma.getActiveModel(maxTokens: maxTokens);
    final chat = await model.createChat(
      systemInstruction: systemPrompt.isNotEmpty ? systemPrompt : null,
    );

    await chat.addQueryChunk(Message.text(text: userPrompt, isUser: true));
    final response = await chat.generateChatResponse();
    return _extractText(response);
  }

  /// Streaming generation — yields tokens as they arrive (typewriter effect).
  Stream<String> generateStream({
    required String systemPrompt,
    required String userPrompt,
    int maxTokens = 2048,
  }) async* {
    _assertReady();
    final model = await FlutterGemma.getActiveModel(maxTokens: maxTokens);
    final chat = await model.createChat(
      systemInstruction: systemPrompt.isNotEmpty ? systemPrompt : null,
    );

    await chat.addQueryChunk(Message.text(text: userPrompt, isUser: true));
    await for (final chunk in chat.generateChatResponseAsync()) {
      if (chunk is TextResponse) yield chunk.token;
    }
  }

  /// Multimodal generation — send an image + text prompt.
  Future<String> generateFromImage({
    required Uint8List imageBytes,
    required String prompt,
    String systemPrompt = '',
  }) async {
    _assertReady();
    final model = await FlutterGemma.getActiveModel(
      maxTokens: 2048,
      supportImage: true,
    );
    final chat = await model.createChat(
      supportImage: true,
      systemInstruction: systemPrompt.isNotEmpty ? systemPrompt : null,
    );

    await chat.addQueryChunk(Message.withImage(
      text: prompt,
      imageBytes: imageBytes,
      isUser: true,
    ));

    final response = await chat.generateChatResponse();
    return _extractText(response);
  }

  /// Creates a persistent multi-turn chat for the Study Companion.
  Future<GemmaAgentChat> createCompanionChat(String systemPrompt) async {
    _assertReady();
    final model = await FlutterGemma.getActiveModel(maxTokens: 2048);
    final chat = await model.createChat(
      systemInstruction: systemPrompt.isNotEmpty ? systemPrompt : null,
    );
    return GemmaAgentChat(chat: chat);
  }

  String _extractText(ModelResponse response) {
    if (response is TextResponse) return response.token;
    return '';
  }

  void _assertReady() {
    if (!_modelReady && !FlutterGemma.hasActiveModel()) {
      throw StateError('Gemma model not initialized yet.');
    }
  }
}

/// A persistent multi-turn chat session for one agent (e.g., Study Companion).
class GemmaAgentChat {
  GemmaAgentChat({required this.chat});

  final InferenceChat chat;

  Future<String> send(String userMessage) async {
    await chat.addQueryChunk(Message.text(text: userMessage, isUser: true));
    final response = await chat.generateChatResponse();
    if (response is TextResponse) return response.token;
    return '';
  }

  Stream<String> sendStream(String userMessage) async* {
    await chat.addQueryChunk(Message.text(text: userMessage, isUser: true));
    await for (final chunk in chat.generateChatResponseAsync()) {
      if (chunk is TextResponse) yield chunk.token;
    }
  }
}
