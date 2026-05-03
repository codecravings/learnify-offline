import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Outcome of a [TextToSpeechService.speak] call.
enum TtsStatus {
  /// Spoken in the requested language.
  ok,

  /// Requested language pack missing — spoken in device default locale instead.
  fallbackToDefault,

  /// TTS engine itself unavailable on this device. Nothing was spoken.
  engineUnavailable,

  /// No usable language pack at all (neither requested nor default). Nothing was spoken.
  noLanguagePack,
}

class TtsResult {
  const TtsResult(this.status, {this.message});

  final TtsStatus status;
  final String? message;

  bool get isError =>
      status == TtsStatus.engineUnavailable ||
      status == TtsStatus.noLanguagePack;
}

/// Singleton TTS service.
///
/// IMPORTANT: TTS is OFF by default. The engine is **not** initialized at
/// startup; the first call to [speak] performs the lazy init. On devices
/// without a TTS language pack the service falls back to the default locale
/// and ultimately returns a typed [TtsResult] rather than throwing.
class TextToSpeechService {
  TextToSpeechService._();
  static final TextToSpeechService instance = TextToSpeechService._();

  FlutterTts? _tts;
  bool _initialized = false;
  bool _speaking = false;

  /// Word boundaries for the most recent [speak] call: each entry is the
  /// `[start, end)` byte/char offset of a token in the source text.
  final List<(int, int)> _wordBoundaries = <(int, int)>[];

  final StreamController<int> _wordIndexController =
      StreamController<int>.broadcast();

  /// Emits the index of the word currently being spoken (0-based).
  /// Emits `-1` when speech ends, is cancelled, or errors out.
  Stream<int> get wordIndexStream => _wordIndexController.stream;

  bool get isInitialized => _initialized;
  bool get isSpeaking => _speaking;

  /// Lazy-init + speak. Falls back to the device default locale if the
  /// requested [language] pack is missing. Never throws — returns a
  /// [TtsResult] describing what happened.
  Future<TtsResult> speak(String text, {String language = 'en-US'}) async {
    if (text.trim().isEmpty) {
      return const TtsResult(TtsStatus.ok);
    }

    final initOk = await _ensureInitialized();
    if (!initOk || _tts == null) {
      return const TtsResult(
        TtsStatus.engineUnavailable,
        message: 'TTS engine could not be initialized on this device',
      );
    }
    final tts = _tts!;

    // Resolve a usable language. flutter_tts.isLanguageAvailable can return
    // null/throw on weird OEM stacks; treat any non-true result as "not ok".
    var resolvedLanguage = language;
    var status = TtsStatus.ok;

    final requestedAvailable = await _isLanguageAvailable(tts, language);
    if (!requestedAvailable) {
      final defaultLang = await _deviceDefaultLanguage(tts);
      if (defaultLang != null &&
          defaultLang != language &&
          await _isLanguageAvailable(tts, defaultLang)) {
        resolvedLanguage = defaultLang;
        status = TtsStatus.fallbackToDefault;
      } else {
        return const TtsResult(
          TtsStatus.noLanguagePack,
          message: 'No TTS language pack on this device',
        );
      }
    }

    try {
      await tts.setLanguage(resolvedLanguage);
    } catch (e) {
      debugPrint('[TTS] setLanguage($resolvedLanguage) failed: $e');
      return TtsResult(
        TtsStatus.engineUnavailable,
        message: 'TTS engine rejected language $resolvedLanguage',
      );
    }

    // Build word boundaries for karaoke highlighting (matches whitespace splits
    // the same way the KaraokeText widget does).
    _rebuildWordBoundaries(text);

    try {
      await tts.stop();
    } catch (_) {/* best-effort */}

    try {
      final result = await tts.speak(text);
      // Android: 1 == success, 0 == failure. iOS returns 1 on success too.
      // Some forks return null — treat null as "fired but uncertain", not error.
      if (result == 0) {
        _speaking = false;
        return const TtsResult(
          TtsStatus.engineUnavailable,
          message: 'TTS engine refused to speak',
        );
      }
      _speaking = true;
      return TtsResult(
        status,
        message: status == TtsStatus.fallbackToDefault
            ? 'Requested language unavailable — using device default'
            : null,
      );
    } catch (e) {
      debugPrint('[TTS] speak() threw: $e');
      _speaking = false;
      return TtsResult(
        TtsStatus.engineUnavailable,
        message: 'TTS engine error: $e',
      );
    }
  }

  Future<void> stop() async {
    final tts = _tts;
    if (tts == null) return;
    try {
      await tts.stop();
    } catch (e) {
      debugPrint('[TTS] stop() failed: $e');
    }
    _speaking = false;
    _emitIndex(-1);
  }

  /// Best-effort pause. Some Android engines silently ignore this; on those
  /// devices the call resolves without speech actually pausing.
  Future<void> pause() async {
    final tts = _tts;
    if (tts == null) return;
    try {
      await tts.pause();
    } catch (e) {
      debugPrint('[TTS] pause() not supported: $e');
    }
  }

  Future<void> dispose() async {
    try {
      await _tts?.stop();
    } catch (_) {/* ignore */}
    if (!_wordIndexController.isClosed) {
      await _wordIndexController.close();
    }
    _tts = null;
    _initialized = false;
    _speaking = false;
    _wordBoundaries.clear();
  }

  // ── internals ─────────────────────────────────────────────────────────────

  Future<bool> _ensureInitialized() async {
    if (_initialized && _tts != null) return true;
    try {
      final tts = FlutterTts();
      // Tunable defaults; tweaked for student listening pace.
      try {
        await tts.setSpeechRate(0.45);
      } catch (_) {/* engine may reject — non-fatal */}
      try {
        await tts.setPitch(1.0);
      } catch (_) {}
      try {
        await tts.setVolume(1.0);
      } catch (_) {}

      // Wait for the platform "speak" future to actually resolve when speech
      // ends — without this, completion fires before the future does on iOS.
      try {
        await tts.awaitSpeakCompletion(true);
      } catch (_) {}

      tts.setStartHandler(() {
        _speaking = true;
      });

      tts.setCompletionHandler(() {
        _speaking = false;
        _emitIndex(-1);
      });

      tts.setCancelHandler(() {
        _speaking = false;
        _emitIndex(-1);
      });

      tts.setErrorHandler((msg) {
        debugPrint('[TTS] errorHandler: $msg');
        _speaking = false;
        _emitIndex(-1);
      });

      // Progress fires per-word on Android with (word, start, end, word_).
      // iOS provides similar offsets. We match by start offset against the
      // boundaries we built in [speak].
      tts.setProgressHandler((
        String word,
        int start,
        int end,
        String wordRaw,
      ) {
        final idx = _indexForStart(start);
        if (idx >= 0) _emitIndex(idx);
      });

      _tts = tts;
      _initialized = true;
      return true;
    } catch (e) {
      debugPrint('[TTS] init failed: $e');
      _tts = null;
      _initialized = false;
      return false;
    }
  }

  Future<bool> _isLanguageAvailable(FlutterTts tts, String lang) async {
    try {
      final result = await tts.isLanguageAvailable(lang);
      // flutter_tts returns dynamic; treat truthy as available.
      if (result is bool) return result;
      if (result is num) return result == 1;
      return result == true;
    } catch (e) {
      debugPrint('[TTS] isLanguageAvailable($lang) threw: $e');
      return false;
    }
  }

  Future<String?> _deviceDefaultLanguage(FlutterTts tts) async {
    // flutter_tts has no direct "default locale" getter, but on Android
    // `getDefaultVoice` includes a locale field, and the platform default
    // language is the first entry returned by the engine. We use a tiny
    // heuristic: try the platform-conventional fallback.
    try {
      final voice = await tts.getDefaultVoice;
      if (voice is Map && voice['locale'] is String) {
        final locale = voice['locale'] as String;
        // flutter_tts uses dash form, e.g. "en-US"; normalise underscores.
        return locale.replaceAll('_', '-');
      }
    } catch (e) {
      debugPrint('[TTS] getDefaultVoice failed: $e');
    }
    // Last-ditch fallback by platform.
    if (Platform.isIOS || Platform.isMacOS) return 'en-US';
    return 'en-US';
  }

  void _rebuildWordBoundaries(String text) {
    _wordBoundaries.clear();
    // Match runs of non-whitespace; record their (start, end) offsets.
    final pattern = RegExp(r'\S+');
    for (final m in pattern.allMatches(text)) {
      _wordBoundaries.add((m.start, m.end));
    }
  }

  int _indexForStart(int start) {
    for (var i = 0; i < _wordBoundaries.length; i++) {
      if (_wordBoundaries[i].$1 == start) return i;
    }
    // Some engines report a slightly-off offset; pick the closest preceding word.
    var best = -1;
    for (var i = 0; i < _wordBoundaries.length; i++) {
      if (_wordBoundaries[i].$1 <= start) {
        best = i;
      } else {
        break;
      }
    }
    return best;
  }

  void _emitIndex(int idx) {
    if (_wordIndexController.isClosed) return;
    _wordIndexController.add(idx);
  }
}
