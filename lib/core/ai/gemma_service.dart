import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';

/// Wraps flutter_gemma for on-device Gemma 4 E2B inference.
///
/// Model: litert-community/gemma-4-E2B-it-litert-lm (~2.58 GB, downloaded once)
/// GPU-accelerated on Android via LiteRT-LM runtime.
class GemmaService {
  GemmaService._();
  static final GemmaService instance = GemmaService._();

  static const _modelUrl =
      'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm'
      '/resolve/main/gemma-4-E2B-it.litertlm';

  static const _modelId = 'gemma-4-E2B-it.litertlm';

  static const _hfToken =
      String.fromEnvironment('HF_TOKEN', defaultValue: '');

  bool _modelReady = false;
  bool get isReady => _modelReady;

  /// ID of the currently active model (which variant we last warmed).
  /// Useful for lab vs main-app preference logic.
  String _activeModelId = _modelId;
  String get activeModelId => _activeModelId;

  /// Lighter Gemma 4 variant — ~2.4 GB instead of 3.4 GB. Used by Franchise
  /// Lab for faster on-device generation. Same prompt API, different file.
  static const e2bModelId = 'gemma-4-E2B-it.litertlm';

  /// Single token ceiling for ALL text generation calls. Varying maxTokens
  /// across calls forces flutter_gemma to rebuild the InferenceModel, which
  /// is fragile on-device and surfaces as "unable to load model" after a few
  /// requests. Keep this fixed and bigger than any single response we expect.
  static const int _textMaxTokens = 8192;

  /// Call once at app startup before any other API.
  Future<void> bootstrap() async {
    await FlutterGemma.initialize(
      huggingFaceToken: _hfToken.isNotEmpty ? _hfToken : null,
    );
  }

  /// Re-activate a previously installed model on cold launch.
  /// flutter_gemma's active-session state is process-local, so even when the
  /// model is "installed" we need to re-run installModel() + getActiveModel()
  /// every launch. Falls through to a silent re-import from the local file
  /// when one is present so the user doesn't have to tap Import again.
  Future<void> resumeIfInstalled() async {
    if (_modelReady) return;
    try {
      // Fast path — already installed, just warm the engine.
      if (await FlutterGemma.isModelInstalled(_modelId)) {
        try {
          await FlutterGemma.getActiveModel(maxTokens: 2048);
          _modelReady = FlutterGemma.hasActiveModel();
          if (_modelReady) {
            debugPrint('[Gemma] Resumed installed model (fast path)');
            return;
          }
        } catch (e) {
          debugPrint('[Gemma] Fast resume failed, falling back: $e');
        }
      }

      // Fallback — re-import from the local file (idempotent, skips copy).
      if (await findSideloadedFile() != null) {
        debugPrint('[Gemma] Resuming via full init from local file...');
        await initializeFromFile();
      }
    } catch (e) {
      debugPrint('[Gemma] resumeIfInstalled failed: $e');
    }
  }

  /// Legacy external sideload path (pushed via `adb push`).
  /// On Android 11+ the app process can't always read this location (scoped
  /// storage + SELinux), so we also check an internal documents path that
  /// the app *always* has access to.
  static const sideloadedPath =
      '/storage/emulated/0/Android/data/com.vidyasetu.vidyasetu/files/gemma-4-E4B-it.litertlm';

  Future<String> _internalModelPath() async {
    final docs = await getApplicationDocumentsDirectory();
    return '${docs.path}/$_modelId';
  }

  /// Resolve the first readable sideloaded file path, or null.
  Future<String?> findSideloadedFile() async {
    // Prefer the internal copy if it's already there (fast, always readable).
    try {
      final internal = await _internalModelPath();
      if (await File(internal).exists()) return internal;
    } catch (_) {}
    try {
      if (await File(sideloadedPath).exists()) return sideloadedPath;
    } catch (_) {}
    return null;
  }

  Future<bool> hasSideloadedFile() async =>
      (await findSideloadedFile()) != null;

  /// Look for any specific model variant by id (e.g. [e2bModelId]).
  /// Returns the absolute on-device path if present, else null.
  Future<String?> findVariantFile(String modelId) async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final p = '${docs.path}/$modelId';
      if (await File(p).exists()) return p;
    } catch (_) {}
    try {
      const externalRoot =
          '/storage/emulated/0/Android/data/com.vidyasetu.vidyasetu/files';
      final p = '$externalRoot/$modelId';
      if (await File(p).exists()) return p;
    } catch (_) {}
    return null;
  }

  /// Switch the active model to [modelId] from its on-disk path. Idempotent.
  /// flutter_gemma keeps multiple models installed but only one active at a
  /// time; calling installModel().fromFile().install() makes that variant
  /// the new active one. Cheap if it was already active.
  Future<bool> activateVariant(String modelId) async {
    if (_activeModelId == modelId && _modelReady) return true;
    final path = await findVariantFile(modelId);
    if (path == null) {
      debugPrint('[Gemma] activateVariant($modelId) — file not found');
      return false;
    }
    try {
      await FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
        fileType: ModelFileType.litertlm,
      ).fromFile(path).install();
      await FlutterGemma.getActiveModel(maxTokens: _textMaxTokens);
      _modelReady = FlutterGemma.hasActiveModel();
      if (_modelReady) {
        _activeModelId = modelId;
        debugPrint('[Gemma] active variant → $modelId');
      }
      return _modelReady;
    } catch (e) {
      debugPrint('[Gemma] activateVariant($modelId) failed: $e');
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
    final src = filePath ?? await findSideloadedFile();
    final sw = Stopwatch()..start();

    if (src == null || !await File(src).exists()) {
      throw StateError('No model file found (tried internal + external paths)');
    }
    debugPrint('[Gemma] Source file: $src (${sw.elapsedMilliseconds}ms)');

    // sdcard memory-mapping is flaky on Android — copy once to internal
    // app storage, then use that fast path for all future launches.
    onProgress?.call(5);
    final localPath = await _ensureLocalCopy(src, (p) {
      // p is 0..100 for the copy phase — map to overall 5..70.
      onProgress?.call(5 + p * 0.65);
    });
    debugPrint('[Gemma] Local copy ready at $localPath '
        '(${sw.elapsedMilliseconds}ms total)');

    // installModel().install() is idempotent — skips the copy if already
    // installed but always sets this model as the active session, which is
    // required after every cold app launch (session is process-local).
    onProgress?.call(72);
    await FlutterGemma.installModel(
      modelType: ModelType.gemmaIt,
      fileType: ModelFileType.litertlm,
    ).fromFile(localPath).install();
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

    // install() is idempotent — skips the download if already installed
    // but always sets the active session for this process.
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

    await FlutterGemma.getActiveModel(maxTokens: 2048);
    _modelReady = FlutterGemma.hasActiveModel();
    debugPrint('[Gemma] Model ready: $_modelReady');
  }

  /// One-shot text generation. Creates a fresh chat each time.
  ///
  /// [maxTokens] is accepted for API compatibility but ignored — the engine
  /// uses [_textMaxTokens] for every text call so the InferenceModel stays
  /// stable across calls. Override only matters for multimodal/image flows.
  Future<String> generate({
    required String systemPrompt,
    required String userPrompt,
    int maxTokens = _textMaxTokens,
  }) async {
    _assertReady();
    final model = await _activeTextModel();
    final chat = await model.createChat(
      systemInstruction: systemPrompt.isNotEmpty ? systemPrompt : null,
    );

    await chat.addQueryChunk(Message.text(text: userPrompt, isUser: true));
    final response = await chat.generateChatResponse();
    final out = _extractText(response);
    debugPrint('[Gemma] generate → ${out.length} chars: '
        '${out.substring(0, out.length.clamp(0, 240))}');
    return out;
  }

  /// Streaming generation — yields tokens as they arrive (typewriter effect).
  Stream<String> generateStream({
    required String systemPrompt,
    required String userPrompt,
    int maxTokens = _textMaxTokens,
  }) async* {
    _assertReady();
    final model = await _activeTextModel();
    final chat = await model.createChat(
      systemInstruction: systemPrompt.isNotEmpty ? systemPrompt : null,
    );

    await chat.addQueryChunk(Message.text(text: userPrompt, isUser: true));
    await for (final chunk in chat.generateChatResponseAsync()) {
      if (chunk is TextResponse) yield chunk.token;
    }
  }

  /// Acquire the text-only inference model with one retry. flutter_gemma
  /// occasionally returns a stale handle right after install; the second
  /// call always succeeds in practice. Surfaces the underlying error if
  /// both attempts fail so the UI can show something meaningful.
  Future<dynamic> _activeTextModel() async {
    try {
      return await FlutterGemma.getActiveModel(maxTokens: _textMaxTokens);
    } catch (e) {
      debugPrint('[Gemma] getActiveModel failed once ($e) — retrying...');
      await Future.delayed(const Duration(milliseconds: 250));
      return FlutterGemma.getActiveModel(maxTokens: _textMaxTokens);
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

  /// Force a fresh `getActiveModel()` call to recover from a stuck engine.
  /// Useful when a UI flow has just hit an "unable to load model" error and
  /// wants to retry without restarting the whole app.
  Future<bool> reactivateModel() async {
    try {
      await FlutterGemma.getActiveModel(maxTokens: _textMaxTokens);
      _modelReady = FlutterGemma.hasActiveModel();
      debugPrint('[Gemma] reactivateModel: $_modelReady');
      return _modelReady;
    } catch (e) {
      debugPrint('[Gemma] reactivateModel failed: $e');
      return false;
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
