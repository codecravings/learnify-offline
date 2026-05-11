import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';

import 'model_downloader.dart';

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

  /// The HuggingFace URL we download from. Exposed so the setup screen can
  /// look up an in-flight `flutter_downloader` task and auto-resume.
  static String get modelUrl => _modelUrl;

  /// The on-disk filename used by both the network download and the
  /// sideload sniff. Exposed for the same reason as [modelUrl].
  static String get modelFileName => _modelId;

  static const _hfToken =
      String.fromEnvironment('HF_TOKEN', defaultValue: '');

  bool _modelReady = false;
  bool get isReady => _modelReady;

  /// Synchronously-readable cache of `hasSideloadedFile()`. Populated once
  /// during app bootstrap so the GoRouter redirect (which is sync) can decide
  /// whether to send the user to the model-download screen or to the warm-up
  /// splash without awaiting a filesystem call on every navigation.
  bool _hasSideloadedFileCached = false;
  bool get hasSideloadedFileSync => _hasSideloadedFileCached;

  /// Run once at app startup. Cheap (one or two `File.exists()` calls) so
  /// running it before `runApp()` adds at most a handful of milliseconds.
  Future<void> precomputeHasSideloadedFile() async {
    _hasSideloadedFileCached = await hasSideloadedFile();
  }

  /// Single token ceiling for ALL text generation calls. Varying maxTokens
  /// across calls forces flutter_gemma to rebuild the InferenceModel, which
  /// is fragile on-device and surfaces as "unable to load model" after a few
  /// requests. Keep this fixed and bigger than any single response we expect.
  ///
  /// Lowered from 8192 → 4096: at 8192 the LiteRT-LM JNI was segfaulting
  /// mid-generation on 6 GB devices (`Java_com_google_ai_edge_litertlm_
  /// LiteRtLmJni_nativeSendMessage` SIGSEGV). 4096 halves the KV-cache
  /// buffer pressure and is still ≫ anything we ever generate (the
  /// chat-bubble Story chunks are ~200–300 tokens each).
  static const int _textMaxTokens = 4096;

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
  Future<void> resumeIfInstalled({
    void Function(double percent)? onProgress,
    void Function(String label)? onStatus,
  }) async {
    if (_modelReady) {
      onProgress?.call(100);
      return;
    }
    try {
      // Fast path — already installed, just warm the engine. Report a single
      // "warming" status because there's nothing granular to show during
      // getActiveModel.
      if (await FlutterGemma.isModelInstalled(_modelId)) {
        try {
          onStatus?.call('Warming up engine (10–30 s)…');
          onProgress?.call(50);
          await FlutterGemma.getActiveModel(maxTokens: 2048);
          _modelReady = FlutterGemma.hasActiveModel();
          if (_modelReady) {
            debugPrint('[Gemma] Resumed installed model (fast path)');
            onProgress?.call(100);
            return;
          }
        } catch (e) {
          debugPrint('[Gemma] Fast resume failed, falling back: $e');
        }
      }

      // Fallback — re-import from the local file (idempotent, skips copy).
      if (await findSideloadedFile() != null) {
        debugPrint('[Gemma] Resuming via full init from local file...');
        await initializeFromFile(onProgress: (p) {
          if (p < 70) {
            onStatus?.call('Copying model to app storage…');
          } else if (p < 80) {
            onStatus?.call('Registering model…');
          } else if (p < 100) {
            onStatus?.call('Warming up engine (10–30 s)…');
          } else {
            onStatus?.call('Ready!');
          }
          onProgress?.call(p);
        });
      }
    } catch (e) {
      debugPrint('[Gemma] resumeIfInstalled failed: $e');
      rethrow;
    }
  }

  /// External sideload path (pushed via `adb push`).
  /// On Android 11+ the app process can't always read this location (scoped
  /// storage + SELinux), so we also check an internal documents path that
  /// the app *always* has access to.
  static const sideloadedPath =
      '/storage/emulated/0/Android/data/com.vidyasetu.vidyasetu/files/$_modelId';

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
  ///
  /// Three phases, all reported through [onProgress] as 0–100:
  ///   * 0–90  — `flutter_downloader` background download (resumable, survives
  ///             screen-lock). Saves to the SAME path our sideload-detector
  ///             checks, so a future cold launch silently re-installs.
  ///   * 90–95 — flutter_gemma `installModel().fromFile().install()` to register
  ///             the file with the LiteRT-LM runtime.
  ///   * 95–100 — `getActiveModel()` warms the engine (mmap + GPU init +
  ///             KV-cache prefill) so the very next inference call is instant.
  ///
  /// On completion the model is ready for inference immediately — no app
  /// restart, no extra tap. If the download was already complete from a
  /// previous run, this short-circuits straight to the install + warm phase.
  Future<void> initialize({void Function(double)? onProgress}) async {
    if (_modelReady) return;

    // Save into the app's internal documents dir. Two reasons:
    //  1) Android 13+ scoped storage blocks `Directory.create()` on the
    //     external `/storage/emulated/0/Android/data/<pkg>/files` path even
    //     for our own scoped dir, when the path is constructed as a raw
    //     string instead of via path_provider.
    //  2) `findSideloadedFile()` already checks this internal path first, so
    //     a partial-download survivor or completed file is auto-picked up by
    //     the silent-resume on the next cold launch.
    final savedDir = (await getApplicationDocumentsDirectory()).path;

    final downloadedPath = await ModelDownloader.instance.downloadModel(
      url: _modelUrl,
      savedDir: savedDir,
      fileName: _modelId,
      token: _hfToken.isNotEmpty ? _hfToken : null,
      // Map 0..100 download progress into the 0..90 band.
      onProgress: (p) => onProgress?.call(p * 0.90),
    );
    debugPrint('[Gemma] Download landed at $downloadedPath');

    // Hand off to the same install + warm flow as a sideloaded file. Reuses
    // _ensureLocalCopy so the model is mmap'd from internal storage (sdcard
    // mmap is flaky on Android).
    onProgress?.call(91);
    await initializeFromFile(
      filePath: downloadedPath,
      onProgress: (p) {
        // initializeFromFile reports 0..100 across copy + register + warm.
        // Compress that into the 91..100 band of the outer progress.
        onProgress?.call(91 + (p / 100) * 9);
      },
    );
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
    // Just length on success — full output preview only when something
    // failed downstream (callers print their own diagnostic dump).
    debugPrint('[Gemma] generate → ${out.length} chars');
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
    var chunkCount = 0;
    var textCount = 0;
    try {
      await for (final chunk in chat.generateChatResponseAsync()) {
        chunkCount++;
        if (chunk is TextResponse) {
          textCount++;
          yield chunk.token;
        } else {
          debugPrint('[Gemma.stream] non-text chunk #$chunkCount: '
              '${chunk.runtimeType}');
        }
      }
    } catch (e, st) {
      debugPrint('[Gemma.stream] threw after $chunkCount chunks '
          '($textCount text): $e\n$st');
      rethrow;
    }
    debugPrint('[Gemma.stream] done: $chunkCount chunks, $textCount text');
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
