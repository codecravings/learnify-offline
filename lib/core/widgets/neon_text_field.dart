import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// A styled text field with a dark background and neon cyan focus border
/// that glows when active, matching the Learnify glassmorphism aesthetic.
class NeonTextField extends StatefulWidget {
  const NeonTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.maxLines = 1,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
    this.textInputAction,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final int maxLines;
  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;

  @override
  State<NeonTextField> createState() => _NeonTextFieldState();
}

class _NeonTextFieldState extends State<NeonTextField> {
  late FocusNode _focusNode;
  bool _hasFocus = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() => _hasFocus = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  Color get _glowColor {
    if (_hasError) return AppTheme.accentMagenta;
    if (_hasFocus) return AppTheme.accentCyan;
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: _hasFocus || _hasError
            ? [
                BoxShadow(
                  color: _glowColor.withAlpha(50),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        onChanged: widget.onChanged,
        onFieldSubmitted: widget.onSubmitted,
        maxLines: widget.maxLines,
        enabled: widget.enabled,
        autofocus: widget.autofocus,
        textInputAction: widget.textInputAction,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 15,
          color: AppTheme.textPrimary,
        ),
        cursorColor: AppTheme.accentCyan,
        validator: (value) {
          final result = widget.validator?.call(value);
          // Defer setState to after validation frame.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _hasError = result != null);
            }
          });
          return result;
        },
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          labelStyle: GoogleFonts.spaceGrotesk(
            color: AppTheme.textTertiary,
            fontSize: 14,
          ),
          hintStyle: GoogleFonts.spaceGrotesk(
            color: AppTheme.textTertiary.withAlpha(120),
            fontSize: 14,
          ),
          prefixIcon: widget.prefixIcon != null
              ? Icon(widget.prefixIcon, color: AppTheme.textTertiary, size: 20)
              : null,
          suffixIcon: widget.suffixIcon,
          filled: true,
          fillColor: AppTheme.surfaceDark,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                BorderSide(color: AppTheme.glassBorder.withAlpha(60)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: AppTheme.accentCyan, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: AppTheme.accentMagenta, width: 1.2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: AppTheme.accentMagenta, width: 1.5),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                BorderSide(color: AppTheme.glassBorder.withAlpha(30)),
          ),
          errorStyle: GoogleFonts.spaceGrotesk(
            fontSize: 11,
            color: AppTheme.accentMagenta,
          ),
        ),
      ),
    );
  }
}
