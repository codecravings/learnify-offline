import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_downloader/flutter_downloader.dart';

/// Resilient background downloader for the Gemma 4 E2B model file.
///
/// Wraps `flutter_downloader` so the user's 2.58 GB one-time download
/// survives screen-lock, app backgrounding, and brief network drops
/// (HTTP Range resume). Replaces flutter_gemma's flaky in-process
/// `installModel().fromNetwork()` which restarted from zero on every
/// failure and could not run when the app was backgrounded.
///
/// Saves to the SAME path our sideload-detection scans, so once the
/// download completes the existing `GemmaService.resumeIfInstalled()`
/// fast-path picks it up on next cold launch with zero extra plumbing.
class ModelDownloader {
  ModelDownloader._();
  static final ModelDownloader instance = ModelDownloader._();

  /// Name of the IsolateNameServer port the background callback messages on.
  static const _portName = 'gemma_model_downloader_port';

  ReceivePort? _port;
  Completer<String>? _completer;
  void Function(double)? _onProgress;
  String? _activeTaskId;
  String _expectedSavedPath = '';

  /// Start (or attach to) a background download of [url] into [savedDir]
  /// with the file written as [fileName]. If a prior task for the same URL
  /// is already complete / running / paused, it is reused/resumed instead
  /// of starting fresh — so users never lose progress on an app restart.
  ///
  /// Resolves with the full saved file path on completion.
  /// Rejects if the task fails, is canceled, or storage is unavailable.
  Future<String> downloadModel({
    required String url,
    required String savedDir,
    required String fileName,
    String? token,
    void Function(double percent)? onProgress,
  }) async {
    _onProgress = onProgress;
    _completer = Completer<String>();
    _expectedSavedPath = '$savedDir/$fileName';

    // Make sure the savedDir exists (flutter_downloader does NOT mkdir for us).
    await Directory(savedDir).create(recursive: true);

    _bindPort();
    await FlutterDownloader.registerCallback(_downloadCallback, step: 1);

    final existing = await _findExistingTask(url, fileName);
    if (existing != null) {
      _activeTaskId = existing.taskId;
      switch (existing.status) {
        case DownloadTaskStatus.complete:
          // File already on disk from a previous session.
          if (await File(_expectedSavedPath).exists()) {
            _onProgress?.call(100);
            _cleanup();
            return _expectedSavedPath;
          }
          // Status says complete but file is gone (cleared, reinstall, etc).
          // Drop the stale task record and re-enqueue fresh.
          await FlutterDownloader.remove(taskId: existing.taskId);
          _activeTaskId = await _enqueueFresh(url, savedDir, fileName, token);
          break;
        case DownloadTaskStatus.paused:
          _activeTaskId =
              await FlutterDownloader.resume(taskId: existing.taskId);
          break;
        case DownloadTaskStatus.failed:
        case DownloadTaskStatus.canceled:
          _activeTaskId =
              await FlutterDownloader.retry(taskId: existing.taskId);
          break;
        case DownloadTaskStatus.enqueued:
        case DownloadTaskStatus.running:
          // Already in flight — just listen.
          _onProgress?.call(existing.progress.toDouble());
          break;
        case DownloadTaskStatus.undefined:
          _activeTaskId = await _enqueueFresh(url, savedDir, fileName, token);
          break;
      }
    } else {
      _activeTaskId = await _enqueueFresh(url, savedDir, fileName, token);
    }

    return _completer!.future;
  }

  /// Returns true if there's any task for [url] in any state. The setup
  /// screen uses this on entry to flip into "resuming…" mode without the
  /// user having to tap Download again after coming back to the app.
  Future<DownloadTask?> findExisting({
    required String url,
    required String fileName,
  }) =>
      _findExistingTask(url, fileName);

  /// Cancel + remove the current task and any prior tasks for this URL,
  /// also deleting the partial file. Used when the user explicitly resets.
  Future<void> resetAll({required String url, required String fileName}) async {
    final tasks = await FlutterDownloader.loadTasks() ?? const [];
    for (final t in tasks) {
      if (t.url == url || t.filename == fileName) {
        await FlutterDownloader.remove(taskId: t.taskId, shouldDeleteContent: true);
      }
    }
    _cleanup();
  }

  Future<String?> _enqueueFresh(
    String url,
    String savedDir,
    String fileName,
    String? token,
  ) {
    return FlutterDownloader.enqueue(
      url: url,
      savedDir: savedDir,
      fileName: fileName,
      headers: token != null && token.isNotEmpty
          ? {'Authorization': 'Bearer $token'}
          : const {},
      showNotification: true,
      openFileFromNotification: false,
      // false: don't let WorkManager defer the task on a "storage low" reading;
      // we already check for free space in the UI.
      requiresStorageNotLow: false,
      saveInPublicStorage: false,
      allowCellular: true,
    );
  }

  Future<DownloadTask?> _findExistingTask(String url, String fileName) async {
    final tasks = await FlutterDownloader.loadTasks();
    if (tasks == null) return null;
    for (final t in tasks) {
      if (t.url == url && t.filename == fileName) return t;
    }
    return null;
  }

  void _bindPort() {
    if (_port != null) return;
    _port = ReceivePort();
    IsolateNameServer.removePortNameMapping(_portName);
    IsolateNameServer.registerPortWithName(_port!.sendPort, _portName);
    _port!.listen(_handleStatus);
  }

  void _handleStatus(dynamic data) {
    if (data is! List || data.length != 3) return;
    final id = data[0] as String;
    final statusValue = data[1] as int;
    final progress = data[2] as int;
    if (id != _activeTaskId) return;

    final status = DownloadTaskStatus.values[statusValue];
    if (status == DownloadTaskStatus.running ||
        status == DownloadTaskStatus.enqueued) {
      _onProgress?.call(progress.toDouble());
      return;
    }
    if (status == DownloadTaskStatus.complete) {
      _onProgress?.call(100);
      _settle((c) => c.complete(_expectedSavedPath));
    } else if (status == DownloadTaskStatus.failed ||
        status == DownloadTaskStatus.canceled) {
      _settle((c) => c.completeError(StateError(
          'Model download $status — check connection and retry')));
    }
  }

  void _settle(void Function(Completer<String>) complete) {
    final c = _completer;
    if (c != null && !c.isCompleted) complete(c);
    _cleanup();
  }

  void _cleanup() {
    _port?.close();
    IsolateNameServer.removePortNameMapping(_portName);
    _port = null;
  }
}

/// Top-level entry point invoked by flutter_downloader from a separate
/// isolate; bounces the (id, status, progress) tuple back to the UI
/// isolate via [IsolateNameServer].
@pragma('vm:entry-point')
void _downloadCallback(String id, int status, int progress) {
  final send = IsolateNameServer.lookupPortByName(ModelDownloader._portName);
  if (send == null) {
    debugPrint('[ModelDownloader] no port bound — dropping callback');
    return;
  }
  send.send([id, status, progress]);
}
