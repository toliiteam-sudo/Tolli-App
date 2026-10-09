class UsernameValidator {
  static const int minLength = 3;
  static const int maxLength = 30;

  static const Set<String> reservedUsernames = {
    'admin',
    'administrator',
    'tolii',
    'official',
    'support',
    'root',
    'help',
    'moderator',
    'mod',
    'system',
    'api',
    'null',
    'undefined',
  };

  /// Trim whitespace and convert to lowercase
  static String normalize(String username) {
    return username.trim().toLowerCase();
  }

  /// Generates a clean base username derived from first name and last name
  static String generateBaseUsername(String firstName, String lastName) {
    final String raw = '$firstName $lastName'.trim();
    if (raw.isEmpty) return '';

    // Convert to lowercase
    String norm = raw.toLowerCase();

    // Replace common diacritics / accents
    norm = norm
        .replaceAll(RegExp(r'[āáâäàåã]'), 'a')
        .replaceAll(RegExp(r'[ēéêëè]'), 'e')
        .replaceAll(RegExp(r'[īíîïì]'), 'i')
        .replaceAll(RegExp(r'[ōóôöòõ]'), 'o')
        .replaceAll(RegExp(r'[ūúûüù]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[ñ]'), 'n');

    // Keep only a-z and 0-9
    norm = norm.replaceAll(RegExp(r'[^a-z0-9]'), '');

    // Ensure it starts with a letter (strip leading numbers)
    norm = norm.replaceAll(RegExp(r'^[0-9]+'), '');

    if (norm.isEmpty) return '';

    // Limit base length to 25 chars to leave space for collision suffixes
    if (norm.length > 25) {
      norm = norm.substring(0, 25);
    }

    // Pad with '0' if shorter than minLength (3 chars)
    while (norm.length < minLength) {
      norm += '0';
    }

    if (isReserved(norm)) {
      norm = '${norm}user';
    }

    return norm;
  }

  /// Check if username is in reserved list
  static bool isReserved(String username) {
    return reservedUsernames.contains(normalize(username));
  }

  /// Returns user-friendly error message if username is invalid, or null if valid format
  static String? getValidationError(String username) {
    final norm = normalize(username);

    if (norm.isEmpty) {
      return 'Please choose a username';
    }

    if (norm.length < minLength) {
      return 'Username must be at least $minLength characters';
    }

    if (norm.length > maxLength) {
      return 'Username must not exceed $maxLength characters';
    }

    if (!RegExp(r'^[a-z]').hasMatch(norm)) {
      return 'Username must start with a letter (a-z)';
    }

    if (!RegExp(r'[a-z0-9]$').hasMatch(norm)) {
      return 'Username must end with a letter or number';
    }

    if (!RegExp(r'^[a-z0-9_.]+$').hasMatch(norm)) {
      return 'Use 3–30 characters: letters, numbers, _ and .';
    }

    if (norm.contains('..')) {
      return 'Username cannot contain consecutive periods (..)';
    }

    if (isReserved(norm)) {
      return 'Username is not available';
    }

    return null;
  }

  /// Returns true if username format is valid and not reserved
  static bool isValidFormat(String username) {
    return getValidationError(username) == null;
  }
}
