import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

// --- Helper Functions (Keep private within this file) ---

/// Converts a snake_case string to PascalCase.
///
/// Takes a [text] string in snake_case format and returns a PascalCase string
/// where each word segment is capitalized and joined without separators.
///
/// Example: "user_profile" becomes "UserProfile"
String _toPascalCase(String text) {
  if (text.isEmpty) return '';
  return text
      .split('_')
      .map(
        (word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1),
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
String _toCamelCase(String text) {
  if (text.isEmpty) return '';
  final parts = text.split('_');
  if (parts.isEmpty) return '';
  final firstWord = parts.first;
  final remainingWords = parts
      .skip(1)
      .map(
        (word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1),
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
String _toSnakeCase(String input) {
  if (input.isEmpty) return input;

  final result = StringBuffer();
  result.write(input[0].toLowerCase());

  for (int i = 1; i < input.length; i++) {
    final char = input[i];
    if (char == char.toUpperCase() &&
        char != '_' &&
        char.toUpperCase() != char.toLowerCase()) {
      result.write('_');
      result.write(char.toLowerCase());
    } else {
      result.write(char.toLowerCase());
    }
  }

  return result.toString();
}

/// Maps database column types to Dart types, considering potential enums.
///
/// Converts a database [apiType] (derived from format/type in OpenAPI spec)
/// to its corresponding Dart type.
/// If the [property] map contains an 'enum' key, uses the database enum type name
/// or infers it if not explicitly provided.
/// If [isNullable] is true, the returned type will include a nullable suffix '?'.
///
/// Supported standard type mappings:
/// - 'uuid', 'text', 'varchar' → 'String'
/// - 'integer', 'int4', 'int8', 'bigint' → 'int'
/// - 'boolean' → 'bool'
/// - 'timestamp with time zone', 'timestamp without time zone', 'date', 'timestamptz' → 'DateTime'
/// - 'numeric', 'double precision', 'float4', 'float8' → 'double'
/// - 'json', 'jsonb' → 'Map<String, dynamic>'
/// - Any other type → 'dynamic'
String _mapType(
  String apiType,
  bool isNullable, {
  required String columnName,
  required Map<String, dynamic> property,
  Map<String, String>?
  enumTypeNames, // Map column names to their enum type names
}) {
  // Check for enum definition directly in the property
  print('property: $property');
  if (property.containsKey('enum') && property['enum'] is List) {
    // If we have a mapping for this column, use that enum name
    String enumName;
    if (enumTypeNames != null && enumTypeNames.containsKey(columnName)) {
      enumName = enumTypeNames[columnName]!;
    } else {
      // Fallback: Use the database type name if available, otherwise derive from column name
      final typeName =
          property['title'] as String? ??
          property['x-enum-name'] as String? ??
          property['x-pg-enum-name'] as String? ??
          _toPascalCase(apiType == 'string' ? columnName : apiType);
      print('typeName: $property');
      enumName = '${_toPascalCase(typeName)}Enum';
    }
    return isNullable ? '$enumName?' : enumName;
  }

  // Standard type mapping
  final String baseType = switch (apiType) {
    'uuid' || 'text' || 'varchar' => 'String',
    'integer' || 'int4' || 'int8' || 'bigint' => 'int',
    'boolean' => 'bool',
    'timestamp with time zone' ||
    'timestamp without time zone' ||
    'date' ||
    'timestamptz' => 'DateTime',
    'numeric' || 'double precision' || 'float4' || 'float8' => 'double',
    'json' || 'jsonb' => 'Map<String, dynamic>',
    _ => 'dynamic', // Fallback for unknown types
  };
  return isNullable ? '$baseType?' : baseType;
}

/// Generates the content for a Dart enum file based on OpenAPI spec values.
///
/// Takes an [enumName] (inferred PascalCase name) and a list of string [values].
/// Returns a Dart code string defining the enum with helper methods:
/// - `toValue`: Converts the enum member to its original string value.
/// - `fromValue`: Static method to parse a string into an enum member (throws error if invalid).
/// - `tryFromValue`: Static method to parse a string into an enum member (returns null if invalid).
String _generateEnumFile(String enumName, List<String> values) {
  final buffer = StringBuffer();
  buffer.writeln('// Generated by row_row_row tool');
  buffer.writeln('// Auto-generated file. Do not modify.');
  buffer.writeln();
  buffer.writeln('/// Represents the possible values for the $enumName enum.');
  buffer.writeln('enum $enumName {');

  // Generate enum values - attempt basic conversion for safety
  for (final value in values) {
    // Basic sanitization: convert to camelCase, replace non-alphanumeric with underscore
    final dartValue = _toCamelCase(
      value.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_'),
    );
    buffer.writeln('  $dartValue,');
  }
  buffer.writeln('  ;'); // End of enum values
  buffer.writeln();

  // Generate toValue getter
  buffer.writeln(
    '  /// Converts enum to its string value for database interaction.',
  );
  buffer.writeln('  String get toValue => switch (this) {');
  for (final value in values) {
    // FIX: Apply the same sanitization logic here
    final dartValue = _toCamelCase(
      value.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_'),
    );
    buffer.writeln('        $enumName.$dartValue => \'$value\',');
  }
  buffer.writeln('      };');
  buffer.writeln();

  // Generate fromValue static method
  buffer.writeln('  /// Creates an enum from a string value.');
  buffer.writeln('  /// Throws an ArgumentError if the [value] is not found.');
  buffer.writeln('  static $enumName fromValue(String value) {');
  buffer.writeln('    return $enumName.values.firstWhere(');
  buffer.writeln('      (e) => e.toValue == value,');
  buffer.writeln(
    '      orElse: () => throw ArgumentError("Invalid enum value: \$value for $enumName"),',
  );
  buffer.writeln('    );');
  buffer.writeln('  }');
  buffer.writeln();

  // Generate tryFromValue static method
  buffer.writeln(
    '  /// Creates an enum from a string value, returning null if not found or if value is null.',
  );
  buffer.writeln('  static $enumName? tryFromValue(String? value) {');
  buffer.writeln('    if (value == null) return null;');
  buffer.writeln('    try {');
  buffer.writeln('      return fromValue(value);');
  buffer.writeln('    } catch (_) {');
  buffer.writeln('      return null;');
  buffer.writeln('    }');
  buffer.writeln('  }');

  buffer.writeln('}'); // Close enum definition
  return buffer.toString();
}

/// Generates a Dart class for a database table.
///
/// Takes a [tableName], [properties] map containing column information,
/// and [requiredFields] list to determine which fields should be required.
/// The [enums] map contains information about discovered enums for import generation.
/// The [columnEnumMap] maps column names to their enum type names.
///
/// Returns a complete Dart class string that includes:
/// - A static 'field' record for mapping between Dart fields and DB columns
/// - Field declarations with proper Dart types (including generated Enums)
/// - A const constructor with required/optional parameters
/// - A fromJson factory constructor with proper type handling (including Enums)
/// - A toJson method (including Enums)
/// - Necessary import statements for generated enums.
///
/// The class follows naming conventions:
/// - Class name: `<PascalCaseTableName>Row`
/// - Field names: camelCase
String _generateRowClass(
  String tableName,
  Map<String, dynamic> properties,
  List<dynamic> requiredFields,
  Map<String, List<String>> enums, [ // Pass the discovered enums map
  Map<String, String>?
  columnEnumMap, // Optional map of column names to enum types
]) {
  final baseName = _toPascalCase(tableName);
  final className = '${baseName}Row';
  final buffer = StringBuffer();
  bool needsJsonDecodeImport = false;
  final Set<String> requiredEnumImports = {}; // Track required enum imports

  final classBuffer = StringBuffer();
  classBuffer.writeln('class $className {');

  classBuffer.writeln('  static const field = (');
  properties.forEach((columnName, property) {
    if (property is Map<String, dynamic>) {
      final fieldName = _toCamelCase(columnName);
      classBuffer.writeln('    $fieldName: \'$columnName\',');
    }
  });
  classBuffer.writeln('  );');
  classBuffer.writeln();

  properties.forEach((columnName, property) {
    if (property is Map<String, dynamic>) {
      final fieldName = _toCamelCase(columnName);
      final apiType = property['format'] ?? property['type'] ?? 'unknown';
      final isNullable = !requiredFields.contains(columnName);

      // Use column enum mapping if available
      final dartType = _mapType(
        apiType,
        isNullable,
        columnName: columnName,
        property: property,
        enumTypeNames: columnEnumMap,
      );

      // Check if it's an enum type to add import
      if (property.containsKey('enum') && property['enum'] is List) {
        // Get enum name from mapping if available, otherwise derive it
        String enumName;
        if (columnEnumMap != null && columnEnumMap.containsKey(columnName)) {
          enumName = columnEnumMap[columnName]!;
        } else {
          // Fallback to previous behavior
          final typeName =
              property['title'] as String? ??
              property['x-enum-name'] as String? ??
              property['x-pg-enum-name'] as String? ??
              _toPascalCase(apiType == 'string' ? columnName : apiType);
          enumName = '${_toPascalCase(typeName)}Enum';
        }
        requiredEnumImports.add(enumName);
      }

      classBuffer.writeln('  final $dartType $fieldName;');
    }
  });
  classBuffer.writeln();

  classBuffer.writeln('  const $className({');
  properties.forEach((columnName, property) {
    if (property is Map<String, dynamic>) {
      final fieldName = _toCamelCase(columnName);
      final isNullable = !requiredFields.contains(columnName);
      // Get the dart type again to check if it needs 'required'
      final apiType = property['format'] ?? property['type'] ?? 'unknown';
      final dartType = _mapType(
        apiType,
        isNullable,
        columnName: columnName,
        property: property,
      );

      if (!isNullable) {
        classBuffer.writeln('    required this.$fieldName,');
      } else {
        classBuffer.writeln('    this.$fieldName,');
      }
    }
  });
  classBuffer.writeln('  });');
  classBuffer.writeln();

  classBuffer.writeln(
    '  factory $className.fromJson(Map<String, dynamic> json) {',
  );
  classBuffer.writeln('    return $className(');
  properties.forEach((columnName, property) {
    if (property is Map<String, dynamic>) {
      final fieldName = _toCamelCase(columnName);
      final apiType = property['format'] ?? property['type'] ?? 'unknown';
      final isNullable = !requiredFields.contains(columnName);
      final dartType = _mapType(
        apiType,
        isNullable,
        columnName: columnName,
        property: property,
        enumTypeNames: columnEnumMap,
      );
      final jsonAccessor = 'json[field.$fieldName]';
      String parseLogic;

      // Check if it's an enum
      if (property.containsKey('enum') && property['enum'] is List) {
        // Get the enum name from mapping if available
        String enumName;
        if (columnEnumMap != null && columnEnumMap.containsKey(columnName)) {
          enumName = columnEnumMap[columnName]!;
        } else {
          // Fallback to previous behavior
          final typeName =
              property['title'] as String? ??
              property['x-enum-name'] as String? ??
              property['x-pg-enum-name'] as String? ??
              _toPascalCase(apiType == 'string' ? columnName : apiType);
          enumName = '${_toPascalCase(typeName)}Enum';
        }

        if (isNullable) {
          parseLogic = '$enumName.tryFromValue($jsonAccessor as String?)';
        } else {
          parseLogic = '$enumName.fromValue($jsonAccessor as String)';
        }
      } else if (dartType.startsWith('DateTime')) {
        if (isNullable) {
          parseLogic =
              '$jsonAccessor == null ? null : DateTime.tryParse($jsonAccessor ?? \'\')';
        } else {
          parseLogic = 'DateTime.parse($jsonAccessor)';
        }
      } else if (dartType.startsWith('Map<String, dynamic>')) {
        needsJsonDecodeImport = true;
        if (isNullable) {
          parseLogic =
              '$jsonAccessor == null ? null : ($jsonAccessor is String ? jsonDecode($jsonAccessor) : Map<String, dynamic>.from($jsonAccessor))';
        } else {
          parseLogic =
              '$jsonAccessor is String ? jsonDecode($jsonAccessor) : Map<String, dynamic>.from($jsonAccessor)';
        }
      } else if (dartType == 'double') {
        parseLogic =
            '$jsonAccessor == null ? 0.0 : ($jsonAccessor as num).toDouble()';
        if (!isNullable) {
          parseLogic = '($jsonAccessor as num).toDouble()';
        } else {
          parseLogic =
              '$jsonAccessor == null ? null : ($jsonAccessor as num?)?.toDouble()';
        }
      } else if (dartType == 'double?') {
        parseLogic =
            '$jsonAccessor == null ? null : ($jsonAccessor as num?)?.toDouble()';
      } else if (dartType == 'int') {
        parseLogic =
            '$jsonAccessor == null ? 0 : ($jsonAccessor as num).toInt()';
        if (!isNullable) {
          parseLogic = '($jsonAccessor as num).toInt()';
        } else {
          parseLogic =
              '$jsonAccessor == null ? null : ($jsonAccessor as num?)?.toInt()';
        }
      } else if (dartType == 'int?') {
        parseLogic =
            '$jsonAccessor == null ? null : ($jsonAccessor as num?)?.toInt()';
      } else {
        parseLogic = jsonAccessor;
        if (!isNullable && dartType != 'dynamic') {
          parseLogic += ' as $dartType';
        }
      }
      classBuffer.writeln('      $fieldName: $parseLogic,');
    }
  });
  classBuffer.writeln('    );');
  classBuffer.writeln();

  classBuffer.writeln('  Map<String, dynamic> toJson() {');
  classBuffer.writeln('    return {');
  properties.forEach((columnName, property) {
    if (property is Map<String, dynamic>) {
      final fieldName = _toCamelCase(columnName);
      final apiType = property['format'] ?? property['type'] ?? 'unknown';
      final isNullable = !requiredFields.contains(columnName);
      final dartType = _mapType(
        apiType,
        isNullable,
        columnName: columnName,
        property: property,
        enumTypeNames: columnEnumMap,
      );

      String valueAccessor = fieldName;

      // Check if it's an enum
      if (property.containsKey('enum') && property['enum'] is List) {
        // Get enum name from mapping if available
        String enumName;
        if (columnEnumMap != null && columnEnumMap.containsKey(columnName)) {
          enumName = columnEnumMap[columnName]!;
        } else {
          // Fallback to previous behavior
          final typeName =
              property['title'] as String? ??
              property['x-enum-name'] as String? ??
              property['x-pg-enum-name'] as String? ??
              _toPascalCase(apiType == 'string' ? columnName : apiType);
          enumName = '${_toPascalCase(typeName)}Enum';
        }

        if (isNullable) {
          valueAccessor = '$fieldName?.toValue';
        } else {
          valueAccessor = '$fieldName.toValue';
        }
      } else if (dartType.startsWith('DateTime')) {
        if (isNullable) {
          valueAccessor = '$fieldName?.toIso8601String()';
        } else {
          valueAccessor = '$fieldName.toIso8601String()';
        }
      }
      // other types serialize directly
      classBuffer.writeln('      field.$fieldName: $valueAccessor,');
    }
  });
  classBuffer.writeln('    };');
  classBuffer.writeln('  }');

  classBuffer.writeln('}');

  // Add header comments and imports
  buffer.writeln('// Generated by row_row_row tool');
  buffer.writeln('// Auto-generated file. Do not modify.');
  if (needsJsonDecodeImport) {
    buffer.writeln("import 'dart:convert';");
  }
  // Add required enum imports
  for (final enumName in requiredEnumImports) {
    // Strip 'Enum' suffix if present to avoid redundancy in file naming
    final enumBaseName =
        enumName.endsWith('Enum')
            ? enumName.substring(0, enumName.length - 4)
            : enumName;

    buffer.writeln(
      "import '../enums/${_toSnakeCase(enumBaseName)}.dart';",
    ); // Use snake_case for file name convention
  }
  if (needsJsonDecodeImport || requiredEnumImports.isNotEmpty) {
    buffer.writeln(); // Add a newline after imports
  }

  buffer.write(classBuffer.toString());

  return buffer.toString();
}

/// Deletes all files in a directory (but keeps the directory)
Future<void> _cleanDirectory(Directory directory) async {
  if (await directory.exists()) {
    final entities = await directory.list().toList();
    for (final entity in entities) {
      if (entity is File) {
        await entity.delete();
      } else if (entity is Directory) {
        await entity.delete(recursive: true);
      }
    }
    print('Cleaned directory: ${directory.path}');
  }
}

/// Main function to generate Dart model classes and enums for Supabase tables.
///
/// Connects to a Supabase project using [supabaseUrl] and [serviceRoleKey],
/// then fetches the database schema via the OpenAPI specification.
///
/// For each table in the schema:
/// - Analyzes column types and constraints.
/// - Detects columns using enums based on the 'enum' keyword in the spec.
/// - Generates a corresponding Dart class (`<TableName>Row`) with appropriate types.
/// - Creates a file named `<tableName>.row.dart` in `lib/row_row_row_generated/tables/`.
///
/// For each discovered enum type:
/// - Generates a Dart enum file based on the database enum type name
/// - Includes helper methods for serialization/deserialization.
///
/// Additionally, generates a schema report file.
/// If [formatCode] is true, runs `dart format` on the generated files.
/// If [clean] is true, deletes all existing generated files before generating new ones.
///
/// Requires a properly configured Supabase project.
Future<void> generate({
  required String supabaseUrl,
  required String serviceRoleKey,
  required bool formatCode,
  bool clean = false, // Add clean parameter with default value of false
}) async {
  final Uri uri = Uri.parse(supabaseUrl);
  final String projectId = uri.host.split('.').first;
  final client = http.Client();
  final StringBuffer outputBuffer = StringBuffer();
  final dateTime =
      DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];

  // Define output directories
  final baseOutputDir = 'lib/row_row_row_generated';
  final reportDir = Directory('$baseOutputDir/db_schema_report');
  final tablesDir = Directory('$baseOutputDir/tables');
  final enumsDir = Directory('$baseOutputDir/enums'); // New directory for enums

  // Ensure directories exist
  if (!await reportDir.exists()) {
    await reportDir.create(recursive: true);
  }
  if (!await tablesDir.exists()) {
    await tablesDir.create(recursive: true);
  }
  if (!await enumsDir.exists()) {
    await enumsDir.create(recursive: true);
  }

  final outputFile = File('${reportDir.path}/db_schema_$dateTime.txt');
  bool generationSuccessful = false;
  final Map<String, List<String>> enumsToGenerate =
      {}; // Store enums to generate {EnumName: [values]}
  final Map<String, String> columnToEnumMapping =
      {}; // Maps "tableName.columnName" to enum type name

  try {
    outputBuffer.writeln('DATABASE SCHEMA EXPORT (from OpenAPI Spec)');
    outputBuffer.writeln('Exported at: ${DateTime.now()}');
    outputBuffer.writeln('Supabase URL: $supabaseUrl');
    outputBuffer.writeln('Project ID: $projectId');
    outputBuffer.writeln('----------------------------------------\n');

    // Clean output directories before generating new files, but only if clean flag is set
    if (clean) {
      print('Cleaning output directories...');
      await _cleanDirectory(tablesDir);
      await _cleanDirectory(enumsDir);

      // Delete the index file if it exists
      final indexFile = File('$baseOutputDir/row_row_row_generated.dart');
      if (await indexFile.exists()) {
        await indexFile.delete();
        print('Deleted existing index file: ${indexFile.path}');
      }

      print('Done cleaning. Ready to generate new files.');
      outputBuffer.writeln('Cleaned output directories before generation.\n');
    } else {
      print(
        'Skipping cleanup. Use --clean to delete existing files before generation.',
      );
    }

    print('Fetching OpenAPI specification from API root...');
    outputBuffer.writeln(
      'Fetching OpenAPI specification from $supabaseUrl/rest/v1/ ...',
    );

    final response = await client.get(
      Uri.parse('$supabaseUrl/rest/v1/'),
      headers: {
        'apikey': serviceRoleKey,
        'Authorization': 'Bearer $serviceRoleKey',
      },
    );

    if (response.statusCode == 200) {
      try {
        final openApiSpec = jsonDecode(response.body);
        outputBuffer.writeln('Successfully fetched OpenAPI spec.');
        if (openApiSpec is Map && openApiSpec.containsKey('definitions')) {
          final definitions =
              openApiSpec['definitions'] as Map<String, dynamic>;

          if (definitions.isNotEmpty) {
            outputBuffer.writeln('\nTABLES AND VIEWS (from OpenAPI spec):');
            outputBuffer.writeln('--------------------------------------\n');

            int tableCount = 0;

            // First pass: Scan for all enums to build type mappings
            definitions.forEach((tableName, definition) {
              if (tableName.startsWith('pg_') ||
                  tableName == 'swagger' ||
                  tableName == 'info') {
                return; // Skip system tables/views
              }

              if (definition is Map && definition.containsKey('properties')) {
                final properties =
                    definition['properties'] as Map<String, dynamic>;

                // Check for enum type columns
                properties.forEach((columnName, property) {
                  if (property is Map<String, dynamic> &&
                      property.containsKey('enum') &&
                      property['enum'] is List) {
                    final enumValues =
                        (property['enum'] as List).cast<String>();

                    // Try to get the actual enum type name from various possible sources
                    String typeNameSource = 'derived';
                    String typeName;

                    // Check for explicit enum type information
                    if (property.containsKey('format')) {
                      // remove "public." prefix if present
                      typeName = property['format'].toString().replaceFirst(
                        'public.',
                        '',
                      );
                      typeNameSource = 'format';
                    } else if (property.containsKey('title')) {
                      typeName = property['title'] as String;
                      typeNameSource = 'title';
                    } else if (property.containsKey('x-enum-name')) {
                      typeName = property['x-enum-name'] as String;
                      typeNameSource = 'x-enum-name';
                    } else if (property.containsKey('x-pg-enum-name')) {
                      typeName = property['x-pg-enum-name'] as String;
                      typeNameSource = 'x-pg-enum-name';
                    } else if (property.containsKey('type') &&
                        property['type'] != 'string') {
                      // Use the type if it's not just 'string' (which is generic)
                      typeName = property['type'] as String;
                      typeNameSource = 'type';
                    } else {
                      // If no explicit type name, derive it from column name
                      typeName = '${_toPascalCase(columnName)}Type';
                      typeNameSource = 'column name';
                    }

                    // Create a consistent Dart enum name
                    final enumName = '${_toPascalCase(typeName)}Enum';

                    // Store mapping from column to enum type
                    columnToEnumMapping['$tableName.$columnName'] = enumName;

                    // Store for generation, avoid duplicates by checking key
                    if (!enumsToGenerate.containsKey(enumName)) {
                      enumsToGenerate[enumName] = enumValues;

                      print(
                        '• Detected enum type: $enumName (source: $typeNameSource)',
                      );
                      outputBuffer.writeln(
                        'ENUM TYPE: $enumName (source: $typeNameSource)',
                      );
                      outputBuffer.writeln(
                        '  Values: ${enumValues.join(', ')}',
                      );
                      outputBuffer.writeln('');
                    }
                  }
                });
              }
            });

            // Second pass: Generate row classes with proper enum typing
            definitions.forEach((tableName, definition) {
              if (tableName.startsWith('pg_') ||
                  tableName == 'swagger' ||
                  tableName == 'info') {
                return; // Skip system tables/views
              }
              tableCount++;

              if (definition is Map && definition.containsKey('properties')) {
                final properties =
                    definition['properties'] as Map<String, dynamic>;
                final required = definition['required'] as List<dynamic>? ?? [];
                print('• $tableName');
                outputBuffer.writeln('TABLE/VIEW: $tableName');
                outputBuffer.writeln('COLUMNS:');

                // Build map of column names to enum types for this table
                final tableEnumMap = <String, String>{};
                properties.forEach((columnName, property) {
                  if (property is Map<String, dynamic>) {
                    final type =
                        property['format'] ?? property['type'] ?? 'unknown';
                    final isNullable = !required.contains(columnName);
                    final description =
                        property['description'] as String? ?? '';
                    String foreignKeyInfo = '';
                    final fkMatch = RegExp(
                      r"<fk table='(.+?)' column='(.+?)'/>",
                    ).firstMatch(description);
                    if (fkMatch != null) {
                      foreignKeyInfo =
                          ' → ${fkMatch.group(1)}.${fkMatch.group(2)}';
                    }

                    String typeInfo = type;
                    // Check if this column defines an enum
                    if (property.containsKey('enum') &&
                        property['enum'] is List) {
                      // Look up the enum name we previously determined
                      final key = '$tableName.$columnName';
                      if (columnToEnumMapping.containsKey(key)) {
                        final enumName = columnToEnumMapping[key]!;
                        typeInfo = 'enum $enumName'; // Mark as enum in report
                        tableEnumMap[columnName] =
                            enumName; // Store for _mapType calls
                      }
                    }

                    outputBuffer.writeln(
                      '  • $columnName ($typeInfo, ${isNullable ? 'NULL' : 'NOT NULL'})$foreignKeyInfo',
                    );
                  }
                });
                outputBuffer.writeln('');

                try {
                  // Generate the row class, passing the enum type mappings
                  final rowClassContent = _generateRowClass(
                    tableName,
                    properties,
                    required,
                    enumsToGenerate,
                    tableEnumMap, // Pass column->enum mapping for this table
                  );
                  // Use snake_case for file name convention
                  final rowFile = File(
                    '${tablesDir.path}/${_toSnakeCase(tableName)}.row.dart',
                  );
                  rowFile.writeAsStringSync(rowClassContent);
                  print('  -> Generated ${rowFile.path}');
                  outputBuffer.writeln('  -> Generated ${rowFile.path}');
                } catch (e, s) {
                  final errorMsg =
                      'Error generating row file for $tableName: $e\n$s';
                  print('  -> $errorMsg');
                  outputBuffer.writeln('  -> $errorMsg');
                }
              }
            });

            // --- Generate Enum Files ---
            if (enumsToGenerate.isNotEmpty) {
              print('\nGenerating enum files in ${enumsDir.path}...');
              outputBuffer.writeln('\nGENERATED ENUMS:');
              outputBuffer.writeln('----------------');
              enumsToGenerate.forEach((enumName, values) {
                try {
                  final enumFileContent = _generateEnumFile(enumName, values);
                  // Strip 'Enum' suffix if present to avoid redundancy in file naming
                  final enumBaseName =
                      enumName.endsWith('Enum')
                          ? enumName.substring(0, enumName.length - 4)
                          : enumName;

                  // Use snake_case for file name convention
                  final enumFile = File(
                    '${enumsDir.path}/${_toSnakeCase(enumBaseName)}.dart',
                  );
                  enumFile.writeAsStringSync(enumFileContent);
                  print('  -> Generated ${enumFile.path}');
                  outputBuffer.writeln('  ENUM: $enumName -> ${enumFile.path}');
                  outputBuffer.writeln('    Values: ${values.join(', ')}');
                } catch (e, s) {
                  final errorMsg =
                      'Error generating enum file for $enumName: $e\n$s';
                  print('  -> $errorMsg');
                  outputBuffer.writeln('  -> Error for $enumName: $e');
                }
              });
              outputBuffer.writeln();
            }
            // --- End Enum Generation ---

            if (tableCount > 0) {
              print(
                '\nSuccess: Processed $tableCount user definitions (tables/views) in OpenAPI spec.',
              );
              outputBuffer.writeln(
                'Success: Processed $tableCount user definitions in OpenAPI spec.',
              );
              generationSuccessful = true;
            } else {
              print(
                '\nWarning: OpenAPI spec definitions found, but no user tables/views identified after filtering.',
              );
              outputBuffer.writeln(
                'Warning: OpenAPI spec definitions found, but no user tables/views identified after filtering.',
              );
            }
          } else {
            print(
              '\nWarning: OpenAPI spec found, but no table/view definitions.',
            );
            outputBuffer.writeln(
              'Warning: OpenAPI spec found, but no table/view definitions.',
            );
          }
        } else {
          print(
            '\nError: Invalid OpenAPI spec format (missing "definitions").',
          );
          outputBuffer.writeln(
            'Error: Invalid OpenAPI spec format (missing "definitions").\nResponse Body: ${response.body}',
          );
        }
      } catch (e, s) {
        final errorMsg = 'Error: Failed to parse OpenAPI spec: $e\n$s';
        print(errorMsg);
        outputBuffer.writeln('$errorMsg\nResponse Body: ${response.body}');
      }
    } else {
      final errorMsg =
          'Error: Could not fetch OpenAPI spec. Status: ${response.statusCode}';
      print(errorMsg);
      outputBuffer.writeln(errorMsg);
      print(
        '\nPlease check the .env file for correct SUPABASE_URL and SERVICE_ROLE.',
      );
      print(
        '\nEnsure the base REST API endpoint ($supabaseUrl/rest/v1/) is accessible.',
      );
    }

    await outputFile.writeAsString(outputBuffer.toString());
    print('\nSchema report written to ${outputFile.path}');

    // Formatting applies to both tables and enums directories now
    if (generationSuccessful && formatCode) {
      print('\nFormatting generated files in $baseOutputDir...');
      try {
        // Format the base generated directory recursively
        final result = await Process.run('dart', ['format', baseOutputDir]);
        if (result.exitCode == 0) {
          print('Formatting successful.');
        } else {
          print('Error during formatting (exit code: ${result.exitCode}):');
          print(result.stderr);
        }
      } catch (e) {
        print('Error running dart format: $e');
        print('Please ensure the Dart SDK is in your PATH.');
      }
    } else if (generationSuccessful && !formatCode) {
      print('\nSkipping code formatting. Use --dart-format to enable.');
    }
  } finally {
    client.close();
  }
}
