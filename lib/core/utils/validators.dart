import 'package:vidyasetu/core/constants/app_constants.dart';

/// Form-field validators for authentication and profile screens.
///
/// Every method returns `null` on success or an error message [String]
/// on failure, matching Flutter's [FormFieldValidator<String>] signature.
class Validators {
  Validators._();

  // ─── Patterns ────────────────────────────────────────────────────────

  static final RegExp _emailRegExp = RegExp(
    r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)*$',
  );

  static final RegExp _usernameRegExp = RegExp(r'^[a-zA-Z0-9_]+$');

  static final RegExp _upperCase = RegExp(r'[A-Z]');
  static final RegExp _lowerCase = RegExp(r'[a-z]');
  static final RegExp _digit = RegExp(r'\d');
  static final RegExp _specialChar = RegExp(r'[!@#$%^&*(),.?":{}|<>]');

  // ─── Email ───────────────────────────────────────────────────────────

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    if (!_emailRegExp.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  // ─── Password ────────────────────────────────────────────────────────

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < AppConstants.minPasswordLength) {
      return 'Password must be at least ${AppConstants.minPasswordLength} characters';
    }
    if (!_upperCase.hasMatch(value)) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!_lowerCase.hasMatch(value)) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!_digit.hasMatch(value)) {
      return 'Password must contain at least one number';
    }
    if (!_specialChar.hasMatch(value)) {
      return 'Password must contain at least one special character';
    }
    return null;
  }

  /// Validates that [value] matches [original].
  static String? Function(String?) confirmPassword(String original) {
    return (String? value) {
      if (value == null || value.isEmpty) {
        return 'Please confirm your password';
      }
      if (value != original) {
        return 'Passwords do not match';
      }
      return null;
    };
  }

  // ─── Username ────────────────────────────────────────────────────────

  static String? username(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Username is required';
    }
    final trimmed = value.trim();
    if (trimmed.length < 3) {
      return 'Username must be at least 3 characters';
    }
    if (trimmed.length > AppConstants.maxUsernameLength) {
      return 'Username must be at most ${AppConstants.maxUsernameLength} characters';
    }
    if (!_usernameRegExp.hasMatch(trimmed)) {
      return 'Username can only contain letters, numbers, and underscores';
    }
    return null;
  }

  // ─── Display Name ───────────────────────────────────────────────────

  static String? displayName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    if (value.trim().length > 50) {
      return 'Name must be at most 50 characters';
    }
    return null;
  }

  // ─── Bio ─────────────────────────────────────────────────────────────

  static String? bio(String? value) {
    if (value != null && value.length > AppConstants.maxBioLength) {
      return 'Bio must be at most ${AppConstants.maxBioLength} characters';
    }
    return null;
  }

  // ─── Generic Required Field ──────────────────────────────────────────

  static String? required(String? value, [String fieldName = 'This field']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  // ─── OTP / Verification Code ─────────────────────────────────────────

  static String? otp(String? value, {int length = 6}) {
    if (value == null || value.trim().isEmpty) {
      return 'Verification code is required';
    }
    if (value.trim().length != length || !RegExp(r'^\d+$').hasMatch(value.trim())) {
      return 'Enter a valid $length-digit code';
    }
    return null;
  }

  // ─── Password Strength Meter ─────────────────────────────────────────

  /// Returns a score from 0 (very weak) to 4 (very strong).
  static int passwordStrength(String password) {
    if (password.isEmpty) return 0;

    int score = 0;
    if (password.length >= AppConstants.minPasswordLength) score++;
    if (password.length >= 12) score++;
    if (_upperCase.hasMatch(password) && _lowerCase.hasMatch(password)) score++;
    if (_digit.hasMatch(password) && _specialChar.hasMatch(password)) score++;

    return score;
  }

  /// Human-readable label for a password strength [score] (0-4).
  static String passwordStrengthLabel(int score) {
    return switch (score) {
      0 => 'Very Weak',
      1 => 'Weak',
      2 => 'Fair',
      3 => 'Strong',
      _ => 'Very Strong',
    };
  }
}
