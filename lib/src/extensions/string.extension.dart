extension StringExtension on String {
  // --- Helper Functions (Keep private within this file) ---

  /// Converts a snake_case string to PascalCase.
  ///
  /// Takes a [text] string in snake_case format and returns a PascalCase string
  /// where each word segment is capitalized and joined without separators.
  ///
  /// Example: "user_profile" becomes "UserProfile"
  String toPascalCase() {
    if (isEmpty) return '';
    return split('_')
        .map(
          (word) =>
              word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1),
        )
        .join();
  }

  /// Converts a snake_case string to camelCase.
  ///
  /// Takes a [text] string in snake_case format and returns a camelCase string
  /// where the first word is lowercase and subsequent words are capitalized
  /// and joined without separators.
  ///
  /// Example: "user_profile" becomes "userProfile"
  String toCamelCase() {
    if (isEmpty) return '';
    final parts = split('_');
    if (parts.isEmpty) return '';
    final firstWord = parts.first;
    final remainingWords = parts
        .skip(1)
        .map(
          (word) =>
              word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1),
        );
    return [firstWord, ...remainingWords].join();
  }

  /// Converts a string to snake_case.
  ///
  /// Takes a [input] string (which can be camelCase, PascalCase, or snake_case)
  /// and converts it to snake_case format.
  ///
  /// Example:
  /// - "UserType" becomes "user_type"
  /// - "userProfile" becomes "user_profile"
  /// - "user_type" remains "user_type"
  String toSnakeCase() {
    if (isEmpty) return '';
    final firstChar = this[0].toLowerCase();
    final restChars =
        substring(1).split('').map((char) {
          if (char == char.toUpperCase() &&
              char != '_' &&
              char.toUpperCase() != char.toLowerCase()) {
            return '_${char.toLowerCase()}';
          }
          return char.toLowerCase();
        }).join();

    return firstChar + restChars;
  }
}
