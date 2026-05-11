import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ai/gemma_service.dart';
import '../../../core/services/local_profile_service.dart';
import '../../../core/theme/app_theme.dart';

/// Shown on cold launch when a sideloaded / previously-downloaded model file
/// exists but flutter_gemma's per-process active session hasn't been warmed
/// yet. Replaces the old "stare at a black native splash for 48 s" UX where
/// `main.dart` blocked `runApp()` for the full file-copy + engine-warm.
///
/// Flow: pulse + Learnify branding + progress bar + status text. On success
/// it redirects to /home (or /setup/profile if the user has no profile yet).
/// On failure it falls back to /setup so the user can hit the Download or
/// Pick-file CTA and see the real error.
class BootstrapScreen extends StatefulWidget {
  const BootstrapScreen({super.key});

  @override
  State<BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<BootstrapScreen>
    with SingleTickerProviderStateMixin {
  double _progress = 0;
  String _status = 'Waking your AI tutor…';
  bool _failed = false;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    try {
      await GemmaService.instance.resumeIfInstalled(
        onProgress: (p) {
          if (!mounted) return;
          setState(() => _progress = p / 100);
        },
        onStatus: (label) {
          if (!mounted) return;
          setState(() => _status = label);
        },
      );

      if (!mounted) return;
      if (!GemmaService.instance.isReady) {
        // File was there but couldn't be loaded — bounce to the download
        // screen so the user sees the actual error and can pick another file.
        context.go('/setup');
        return;
      }
      final dest = LocalProfileService.instance.hasProfile
          ? '/home'
          : '/setup/profile';
      context.go(dest);
    } catch (e, st) {
      debugPrint('[BootstrapScreen] resume failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _failed = true;
        _status = 'Couldn\'t load your model. Tap to choose a fresh file.';
      });
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, _) => Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.accentCyan
                            .withOpacity(0.7 + _pulseCtrl.value * 0.3),
                        AppTheme.accentPurple
                            .withOpacity(0.5 + _pulseCtrl.value * 0.4),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentCyan
                            .withOpacity(0.25 + _pulseCtrl.value * 0.25),
                        blurRadius: 28,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.psychology_rounded,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Learnify',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Powered by Gemma 4 E2B',
                style: TextStyle(color: AppTheme.accentCyan, fontSize: 14),
              ),
              const SizedBox(height: 28),
              Text(
                _status,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
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
              const SizedBox(height: 6),
              Text(
                _progress > 0
                    ? '${(_progress * 100).toStringAsFixed(0)}%'
                    : 'Starting…',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
              if (_failed) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.go('/setup'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentCyan,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Open setup',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
              const Spacer(flex: 2),
              Center(
                child: Text(
                  'First launch loads ~2.6 GB into RAM. After that it\'s instant.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
