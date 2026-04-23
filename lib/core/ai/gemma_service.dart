import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';

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

  /// Install the model from a pre-pushed file on device — zero network.
  /// Eagerly loads the engine into RAM so errors surface here, not on first chat.
  Future<void> initializeFromFile({
    String? filePath,
    void Function(double)? onProgress,
  }) async {
    if (_modelReady) return;
    final src = filePath ?? sideloadedPath;
    final sw = Stopwatch()..start();

    if (!await File(src).exists()) {
      throw StateError('No model file found at $src');
    }
    debugPrint('[Gemma] Source file OK (${sw.elapsedMilliseconds}ms)');

    // sdcard memory-mapping is flaky on Android — copy once to internal
    // app storage, then use that fast path for all future launches.
    onProgress?.call(5);
    final localPath = await _ensureLocalCopy(src, (p) {
      // p is 0..100 for the copy phase — map to overall 5..70.
      onProgress?.call(5 + p * 0.65);
    });
    debugPrint('[Gemma] Local copy ready at $localPath '
        '(${sw.elapsedMilliseconds}ms total)');

    onProgress?.call(72);
    final installed = await FlutterGemma.isModelInstalled(_modelId);
    if (!installed) {
      await FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
        fileType: ModelFileType.litertlm,
      ).fromFile(localPath).install();
    }
    debugPrint('[Gemma] installModel done (${sw.elapsedMilliseconds}ms total)');

    // Force-load into RAM now so the next call is instant + errors are caught.
    onProgress?.call(80);
    try {
      await FlutterGemma.getActiveModel(maxTokens: 2048);
    } catch (e) {
      throw StateError('Engine init failed: $e');
    }
    debugPrint('[Gemma] Engine warm (${sw.elapsedMilliseconds}ms total)');

    onProgress?.call(100);
    _modelReady = FlutterGemma.hasActiveModel();
    debugPrint('[Gemma] Model ready (from file): $_modelReady');
  }

  /// Copies the sideloaded model from external storage to the app's internal
  /// documents dir for fast mmap. Skips if already copied.
  Future<String> _ensureLocalCopy(
    String src,
    void Function(double) onPercent,
  ) async {
    final docs = await getApplicationDocumentsDirectory();
    final dst = '${docs.path}/$_modelId';
    final dstFile = File(dst);
    final srcFile = File(src);

    if (await dstFile.exists()) {
      final srcSize = await srcFile.length();
      final dstSize = await dstFile.length();
      if (srcSize == dstSize) {
        debugPrint('[Gemma] Local copy already present, skipping copy');
        onPercent(100);
        return dst;
      }
      await dstFile.delete();
    }

    final total = await srcFile.length();
    final sink = dstFile.openWrite();
    var copied = 0;
    var lastReport = 0;
    await for (final chunk in srcFile.openRead()) {
      sink.add(chunk);
      copied += chunk.length;
      final pct = (copied / total * 100).round();
      if (pct != lastReport) {
        lastReport = pct;
        onPercent(pct.toDouble());
      }
    }
    await sink.flush();
    await sink.close();
    return dst;
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
