import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

// --- Helper Functions (Keep private within this file) ---
String _toPascalCase(String text) {
  if (text.isEmpty) return '';
  return text
      .split('_')
      .map(
        (word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1),
      )
      .join();
}

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

String _mapType(String apiType, bool isNullable) {
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
    _ => 'dynamic',
  };
  return isNullable ? '$baseType?' : baseType;
}

String _generateRowClass(
  String tableName,
  Map<String, dynamic> properties,
  List<dynamic> requiredFields,
) {
  final baseName = _toPascalCase(tableName);
  final className = '${baseName}Row';
  final buffer = StringBuffer();
  bool needsJsonDecodeImport = false;

  final classBuffer = StringBuffer();
  classBuffer.writeln('class $className {');

  classBuffer.writeln('  static const field = (');
  properties.forEach((columnName, property) {
    if (property is Map) {
      final fieldName = _toCamelCase(columnName);
      classBuffer.writeln('    $fieldName: \'$columnName\',');
    }
  });
  classBuffer.writeln('  );');
  classBuffer.writeln();

  properties.forEach((columnName, property) {
    if (property is Map) {
      final fieldName = _toCamelCase(columnName);
      final apiType = property['format'] ?? property['type'] ?? 'unknown';
      final isNullable = !requiredFields.contains(columnName);
      final dartType = _mapType(apiType, isNullable);
      classBuffer.writeln('  final $dartType $fieldName;');
    }
  });
  classBuffer.writeln();

  classBuffer.writeln('  const $className({');
  properties.forEach((columnName, property) {
    if (property is Map) {
      final fieldName = _toCamelCase(columnName);
      final isNullable = !requiredFields.contains(columnName);
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
    if (property is Map) {
      final fieldName = _toCamelCase(columnName);
      final apiType = property['format'] ?? property['type'] ?? 'unknown';
      final isNullable = !requiredFields.contains(columnName);
      final dartType = _mapType(apiType, isNullable);
      final jsonAccessor = 'json[field.$fieldName]';
      String parseLogic;
      if (dartType.startsWith('DateTime')) {
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
        parseLogic = '($jsonAccessor as num).toDouble()';
      } else if (dartType == 'double?') {
        parseLogic =
            '$jsonAccessor == null ? null : ($jsonAccessor as num?)?.toDouble()';
      } else if (dartType == 'int') {
        parseLogic = '($jsonAccessor as num).toInt()';
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
  classBuffer.writeln('  }');
  classBuffer.writeln();

  classBuffer.writeln('  Map<String, dynamic> toJson() {');
  classBuffer.writeln('    return {');
  properties.forEach((columnName, property) {
    if (property is Map) {
      final fieldName = _toCamelCase(columnName);
      final dartType = _mapType(
        property['format'] ?? property['type'] ?? 'unknown',
        !requiredFields.contains(columnName),
      );
      String valueAccessor = fieldName;
      if (dartType.startsWith('DateTime')) {
        if (dartType.endsWith('?')) {
          valueAccessor = '$fieldName?.toIso8601String()';
        } else {
          valueAccessor = '$fieldName.toIso8601String()';
        }
      }
      classBuffer.writeln('      field.$fieldName: $valueAccessor,');
    }
  });
  classBuffer.writeln('    };');
  classBuffer.writeln('  }');

  classBuffer.writeln('}');

  buffer.writeln('// Generated by row_row_row tool');
  buffer.writeln('// Auto-generated file. Do not modify.');
  if (needsJsonDecodeImport) {
    buffer.writeln("import 'dart:convert';\n");
  }
  buffer.write(classBuffer.toString());

  return buffer.toString();
}

// --- Main Public Function ---
Future<void> generate({
  required String supabaseUrl,
  required String serviceRoleKey,
  required bool formatCode,
}) async {
  final Uri uri = Uri.parse(supabaseUrl);
  final String projectId = uri.host.split('.').first;
  final client = http.Client();
  final StringBuffer outputBuffer = StringBuffer();
  final dateTime =
      DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
  final reportDir = Directory('lib/row_row_row_generated/db_schema_report');
  final tablesDir = Directory('lib/row_row_row_generated/tables');

  if (!await reportDir.exists()) {
    await reportDir.create(recursive: true);
  }
  if (!await tablesDir.exists()) {
    await tablesDir.create(recursive: true);
  }

  final outputFile = File('${reportDir.path}/db_schema_$dateTime.txt');
  bool generationSuccessful = false;

  try {
    outputBuffer.writeln('DATABASE SCHEMA EXPORT (from OpenAPI Spec)');
    outputBuffer.writeln('Exported at: ${DateTime.now()}');
    outputBuffer.writeln('Supabase URL: $supabaseUrl');
    outputBuffer.writeln('Project ID: $projectId');
    outputBuffer.writeln('----------------------------------------\n');

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
            definitions.forEach((tableName, definition) {
              if (tableName.startsWith('pg_') ||
                  tableName == 'swagger' ||
                  tableName == 'info') {
                return;
              }
              tableCount++;

              if (definition is Map && definition.containsKey('properties')) {
                final properties =
                    definition['properties'] as Map<String, dynamic>;
                final required = definition['required'] as List<dynamic>? ?? [];
                print('• $tableName');
                outputBuffer.writeln('TABLE/VIEW: $tableName');
                outputBuffer.writeln('COLUMNS:');
                properties.forEach((columnName, property) {
                  if (property is Map) {
                    final type =
                        property['format'] ?? property['type'] ?? 'unknown';
                    final nullable =
                        !required.contains(columnName) ? 'NULL' : 'NOT NULL';
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
                    outputBuffer.writeln(
                      '  • $columnName ($type, $nullable)$foreignKeyInfo',
                    );
                  }
                });
                outputBuffer.writeln('');

                try {
                  final rowClassContent = _generateRowClass(
                    tableName,
                    properties,
                    required,
                  );
                  final rowFile = File('${tablesDir.path}/$tableName.row.dart');
                  rowFile.writeAsStringSync(rowClassContent);
                  print('  -> Generated ${rowFile.path}');
                  outputBuffer.writeln('  -> Generated ${rowFile.path}');
                } catch (e) {
                  print('  -> Error generating row file for $tableName: $e');
                  outputBuffer.writeln(
                    '  -> Error generating row file for $tableName: $e',
                  );
                }
              }
            });

            if (tableCount > 0) {
              print(
                'Success: Found $tableCount user definitions (tables/views) in OpenAPI spec.',
              );
              outputBuffer.writeln(
                'Success: Found $tableCount user definitions in OpenAPI spec.',
              );
              generationSuccessful = true;
            } else {
              print(
                'Warning: OpenAPI spec definitions found, but no user tables/views identified after filtering.',
              );
              outputBuffer.writeln(
                'Warning: OpenAPI spec definitions found, but no user tables/views identified after filtering.',
              );
            }
          } else {
            print(
              'Warning: OpenAPI spec found, but no table/view definitions.',
            );
            outputBuffer.writeln(
              'Warning: OpenAPI spec found, but no table/view definitions.',
            );
          }
        } else {
          print('Error: Invalid OpenAPI spec format (missing "definitions").');
          outputBuffer.writeln(
            'Error: Invalid OpenAPI spec format (missing "definitions").\nResponse Body: ${response.body}',
          );
        }
      } catch (e) {
        print('Error: Failed to parse OpenAPI spec: $e');
        outputBuffer.writeln(
          'Error: Failed to parse OpenAPI spec: $e\nResponse Body: ${response.body}',
        );
      }
    } else {
      print(
        'Error: Could not fetch OpenAPI spec. Status: ${response.statusCode}',
      );
      outputBuffer.writeln(
        'Error: Could not fetch OpenAPI spec. Status: ${response.statusCode}',
      );
      outputBuffer.writeln('Response: ${response.body}');
      print(
        'Please check the .env file for correct SUPABASE_URL and SERVICE_ROLE.',
      );
      print(
        'Ensure the base REST API endpoint ($supabaseUrl/rest/v1/) is accessible.',
      );
    }

    await outputFile.writeAsString(outputBuffer.toString());
    print('\nSchema report written to ${outputFile.path}');

    if (generationSuccessful && formatCode) {
      print('\nFormatting generated files in ${tablesDir.path}...');
      try {
        final result = await Process.run('dart', ['format', tablesDir.path]);
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
