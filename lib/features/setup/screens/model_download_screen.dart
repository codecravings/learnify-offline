import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ai/gemma_service.dart';
import '../../../core/theme/app_theme.dart';

/// Downloads Gemma 4 E4B on first launch (~3.65 GB, one-time only).
/// Shows animated progress with storage/requirement info.
class ModelDownloadScreen extends StatefulWidget {
  const ModelDownloadScreen({super.key});

  @override
  State<ModelDownloadScreen> createState() => _ModelDownloadScreenState();
}

class _ModelDownloadScreenState extends State<ModelDownloadScreen>
    with SingleTickerProviderStateMixin {
  double _progress = 0;
  String _status = 'Preparing download...';
  bool _downloading = false;
  bool _error = false;
  bool _hasSideloadedFile = false;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _checkSideloadedFile();
  }

  Future<void> _checkSideloadedFile() async {
    final found = await GemmaService.instance.hasSideloadedFile();
    if (mounted) setState(() => _hasSideloadedFile = found);
  }

  Future<void> _importFromFile() async {
    setState(() {
      _downloading = true;
      _error = false;
      _status = 'Importing model from device storage...';
      _progress = 0;
    });
    try {
      await GemmaService.instance.initializeFromFile(
        onProgress: (p) {
          if (!mounted) return;
          setState(() {
            _progress = p / 100;
            if (p < 70) {
              _status = 'Copying model to app storage: ${p.round()}%';
            } else if (p < 80) {
              _status = 'Registering model...';
            } else if (p < 100) {
              _status = 'Warming up engine (10–30s)...';
            } else {
              _status = 'Ready!';
            }
          });
        },
      );
      if (!mounted) return;
      context.go('/setup/profile');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _downloading = false;
        _status = 'Import failed: $e';
      });
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _startDownload() async {
    setState(() {
      _downloading = true;
      _error = false;
      _status = 'Downloading Gemma 4 E4B...';
    });

    try {
      await GemmaService.instance.initialize(
        onProgress: (p) {
          if (!mounted) return;
          setState(() {
            _progress = p / 100;
            _status = p < 100
                ? 'Downloading model: ${p.round()}%'
                : 'Loading into memory...';
          });
        },
      );

      if (!mounted) return;
      context.go('/setup/profile');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _downloading = false;
        _status = 'Download failed. Check storage space and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              // Gemma logo / branding
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, __) => Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.accentCyan.withOpacity(0.8 + _pulseCtrl.value * 0.2),
                        AppTheme.accentPurple.withOpacity(0.6 + _pulseCtrl.value * 0.4),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentCyan.withOpacity(0.3 + _pulseCtrl.value * 0.2),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 38),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Learnify',
                style: Theme.of(context)
                    .textTheme
                    .headlineLarge
                    ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Powered by Gemma 4 E4B',
                style: TextStyle(color: AppTheme.accentCyan, fontSize: 15),
              ),
              const SizedBox(height: 16),
              Text(
                'Your personal AI tutor runs entirely on your device.\nNo internet needed after setup. Your data stays private.',
                style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 40),
              // Requirements card
              _RequirementCard(),
              const SizedBox(height: 40),
              // Progress
              if (_downloading) ...[
                Text(_status,
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation(AppTheme.accentCyan),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 8),
                if (_progress > 0)
                  Text(
                    '${(_progress * 3.65).toStringAsFixed(2)} GB / 3.65 GB',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
              ] else ...[
                if (_error)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(_status,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                  ),
                if (_hasSideloadedFile) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _importFromFile,
                      icon: const Icon(Icons.offline_bolt_rounded),
                      label: const Text(
                        'Import model from device (instant)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentGreen,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Model file detected — no network needed.',
                      style: TextStyle(color: AppTheme.accentGreen, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(child: Divider(color: Colors.white12)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('or', style: TextStyle(color: Colors.white38)),
                    ),
                    Expanded(child: Divider(color: Colors.white12)),
                  ]),
                  const SizedBox(height: 20),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _startDownload,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentCyan,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      _error ? 'Retry Download' : 'Download Gemma 4 E4B (3.65 GB)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'One-time download. Uses your local storage.',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RequirementCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Requirements', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _req('Storage', '~4 GB free space'),
          _req('RAM', '6 GB+ recommended'),
          _req('GPU', 'Accelerated on most Android phones'),
          _req('Internet', 'Only for this one-time download'),
        ],
      ),
    );
  }

  Widget _req(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text('$label: ',
                style: const TextStyle(color: Colors.white54, fontSize: 13)),
            Text(value,
                style: const TextStyle(color: Colors.white, fontSize: 13)),
          ],
        ),
      );
}
