/// Extension methods for String class
extension StringExtension on String {
  /// Converts a string to PascalCase
  String toPascalCase() {
    if (isEmpty) return '';
    return split(RegExp(r'[_\s-]'))
        .map((word) => word.isEmpty
            ? ''
            : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
        .join('');
  }

  /// Converts a string to camelCase
  String toCamelCase() {
    if (isEmpty) return '';
    final pascalCase = toPascalCase();
    return '${pascalCase[0].toLowerCase()}${pascalCase.substring(1)}';
  }

  /// Converts a string to snake_case
  String toSnakeCase() {
    if (isEmpty) return '';
    return replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => '_${match.group(1)!.toLowerCase()}',
    ).replaceAll(RegExp(r'^_'), '');
  }
}
