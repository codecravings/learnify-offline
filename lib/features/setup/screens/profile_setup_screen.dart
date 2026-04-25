import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/local_profile_service.dart';
import '../../../core/theme/app_theme.dart';

/// Creates a local profile (name + language + grade). No login required.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameCtrl = TextEditingController();
  String _language = 'English';
  String _grade = 'Student';
  bool _loading = false;

  static const _languages = [
    'English', 'Hindi', 'Spanish', 'French', 'Arabic',
    'Portuguese', 'Bengali', 'Mandarin', 'Swahili', 'Urdu',
  ];

  static const _grades = [
    'Student', 'Grade 6–8', 'Grade 9–10', 'Grade 11–12',
    'College', 'Professional', 'Teacher',
  ];

  Future<void> _createProfile() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter a username to continue')));
      return;
    }

    setState(() => _loading = true);
    try {
      await LocalProfileService.instance.createProfile(
        name: name,
        language: _language,
        grade: _grade,
      );
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
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
              Text('Who are you?',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                "Create your Learner profile. No account needed — everything stays on your device.",
                style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 40),
              // Username
              _label('Username'),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Choose a username'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 28),
              // Language
              _label('Learning language'),
              const SizedBox(height: 8),
              _dropdown(
                value: _language,
                items: _languages,
                onChanged: (v) => setState(() => _language = v!),
              ),
              const SizedBox(height: 28),
              // Grade
              _label('I am a...'),
              const SizedBox(height: 8),
              _dropdown(
                value: _grade,
                items: _grades,
                onChanged: (v) => setState(() => _grade = v!),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _createProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentCyan,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black),
                        )
                      : const Text('Start Learning',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500));

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white30),
        filled: true,
        fillColor: Colors.white.withOpacity(0.07),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.accentCyan),
        ),
      );

  Widget _dropdown({
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) =>
      DropdownButtonFormField<String>(
        value: value,
        dropdownColor: AppTheme.surfaceDark,
        style: const TextStyle(color: Colors.white),
        decoration: _inputDecoration('').copyWith(hintText: null),
        items: items
            .map((i) => DropdownMenuItem(value: i, child: Text(i)))
            .toList(),
        onChanged: onChanged,
      );
}
