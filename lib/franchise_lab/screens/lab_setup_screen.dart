import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../services/lab_profile_service.dart';
import 'lab_shell.dart';

/// First-run "lab name" prompt. Creates the local lab profile and routes
/// straight to the 3-tab shell.
class LabSetupScreen extends StatefulWidget {
  const LabSetupScreen({super.key});

  @override
  State<LabSetupScreen> createState() => _LabSetupScreenState();
}

class _LabSetupScreenState extends State<LabSetupScreen> {
  final _ctrl = TextEditingController();
  bool _saving = false;

  Future<void> _start() async {
    final name = _ctrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a lab name to continue')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await LabProfileService.instance.createProfile(name: name);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LabShell()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
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
              const SizedBox(height: 36),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: AppTheme.accentMagenta.withAlpha(40),
                  border: Border.all(color: AppTheme.accentMagenta.withAlpha(120)),
                ),
                child: Text(
                  'FRANCHISE LAB · TEST BUILD',
                  style: GoogleFonts.orbitron(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accentMagenta,
                    letterSpacing: 1.8,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text('Welcome to the lab',
                  style: GoogleFonts.orbitron(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  )),
              const SizedBox(height: 8),
              Text(
                'A focused experiment: small Gemma + your favourite franchises + '
                'on-device memory. Let\'s start with a name for your lab profile.',
                style: AppTheme.bodyStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 36),
              _label('Lab name'),
              const SizedBox(height: 8),
              TextField(
                controller: _ctrl,
                style: const TextStyle(color: Colors.white),
                decoration: _decoration('e.g. Tester, Demo, Aarav'),
                textCapitalization: TextCapitalization.words,
                onSubmitted: (_) => _start(),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _start,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentMagenta,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4, color: Colors.black))
                      : Text(
                          'ENTER LAB',
                          style: GoogleFonts.orbitron(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            letterSpacing: 2,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Lab data is stored separately from the main Learnify app — '
                'experimental runs won\'t pollute your real progress.',
                style: AppTheme.bodyStyle(
                  fontSize: 11,
                  color: AppTheme.textTertiary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String s) => Text(s,
      style: const TextStyle(
          color: Colors.white70, fontWeight: FontWeight.w500));

  InputDecoration _decoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white30),
        filled: true,
        fillColor: Colors.white.withAlpha(18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.accentMagenta, width: 1.5),
        ),
      );
}
