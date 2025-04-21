import 'dart:io';
import 'dart:convert';
import 'package:dotenv/dotenv.dart' as dotenv;
import 'package:args/args.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

void main(List<String> args) async {
  // Load environment variables
  final env = dotenv.DotEnv()..load();

  // Set up command parser
  final parser =
      ArgParser()
        // Add help flag FIRST
        ..addFlag(
          'help',
          negatable: false,
          abbr: 'h',
          help: 'Print this usage information.',
        )
        ..addCommand('list-tables-views')
        ..addFlag(
          'dart-format',
          negatable: false,
          abbr: 'f',
          help:
              'Automatically format generated Dart files using "dart format".',
          defaultsTo: false,
        );

  try {
    final results = parser.parse(args);

    // Check for help flag before doing anything else
    if (results['help'] as bool) {
      printUsage(parser);
      exit(0); // Exit cleanly after showing help
    }

    final command = results.command?.name;
    final shouldFormat = results['dart-format'] as bool;

    if (command == 'list-tables-views') {
      await listTablesAndViewsFromOpenApi(env, formatCode: shouldFormat);
    } else {
      // If no command is given (and not --help), show usage and exit with error
      print('Error: No command specified.\n');
      printUsage(parser);
      exit(1);
    }
  } catch (e) {
    if (e is FormatException) {
      print('Error parsing arguments: ${e.message}\n');
    } else {
      print('Error: $e\n');
    }
    printUsage(parser);
    exit(1); // Exit with error code
  }
}

void printUsage(ArgParser parser) {
  print('Usage: dart run bin/row_row_row.dart <command> [options]');
  print('\nGenerates Dart models for Supabase table rows.');
  print('\nAvailable commands:');
  // Consider dynamically listing commands if more are added
  print('  list-tables-views   List tables/views and generate Dart models.');
  print('\nOptions:');
  print(parser.usage); // This automatically includes help for all flags
}

// --- Helper Function ---
String _toPascalCase(String text) {
  if (text.isEmpty) return '';
  return text
      .split('_')
      .map(
        (word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1),
      )
      .join();
}

// New helper for camelCase
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
    'json' ||
    'jsonb' => 'Map<String, dynamic>', // Or use a specific JSON handling class
    _ => 'dynamic', // Default fallback
  };
  return isNullable ? '$baseType?' : baseType;
}

String generateRowClass(
  String tableName,
  Map<String, dynamic> properties,
  List<dynamic> requiredFields,
) {
  final baseName = _toPascalCase(tableName);
  final className = '${baseName}Row';
  final buffer = StringBuffer();
  bool needsJsonDecodeImport = false;

  // --- Generate the main class structure first ---
  final classBuffer = StringBuffer();
  classBuffer.writeln('class $className {');

  // Generate the static field record FIRST
  classBuffer.writeln('  static const field = (');
  properties.forEach((columnName, property) {
    if (property is Map) {
      final fieldName = _toCamelCase(columnName);
      // Map camelCase field name to original snake_case column name
      classBuffer.writeln('    $fieldName: \'$columnName\',');
    }
  });
  classBuffer.writeln('  );');
  classBuffer.writeln(); // Add a blank line after the record

  // Generate fields using camelCase
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

  // Generate constructor
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

  // Generate fromJson factory constructor using field record for keys
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

  // Generate toJson method using field record for keys
  classBuffer.writeln('  Map<String, dynamic> toJson() {');
  classBuffer.writeln('    return {');
  properties.forEach((columnName, property) {
    if (property is Map) {
      final fieldName = _toCamelCase(columnName);
      final apiType = property['format'] ?? property['type'] ?? 'unknown';
      final isNullable = !requiredFields.contains(columnName);
      final dartType = _mapType(apiType, isNullable);

      String valueAccessor = fieldName;
      if (dartType.startsWith('DateTime')) {
        if (isNullable) {
          valueAccessor = '$fieldName?.toIso8601String()';
        } else {
          valueAccessor = '$fieldName.toIso8601String()';
        }
      }

      // Use the field record for the key: field.fieldName
      classBuffer.writeln('      field.$fieldName: $valueAccessor,');
    }
  });
  classBuffer.writeln('    };');
  classBuffer.writeln('  }');

  classBuffer.writeln('}');
  // --- End Class structure generation ---

  // --- Assemble final file content ---
  buffer.writeln('// Generated by row_row_row tool');
  buffer.writeln('// Auto-generated file. Do not modify.');
  if (needsJsonDecodeImport) {
    buffer.writeln("import 'dart:convert';\n");
  }
  buffer.write(classBuffer.toString());

  return buffer.toString();
}
// --- End Helper Functions ---

Future<void> listTablesAndViewsFromOpenApi(
  dotenv.DotEnv env, {
  required bool formatCode,
}) async {
  final supabaseUrl = env['SUPABASE_URL']!;
  final serviceRoleKey = env['SERVICE_ROLE']!;

  if (supabaseUrl.isEmpty || serviceRoleKey.isEmpty) {
    print('Error: SUPABASE_URL and SERVICE_ROLE must be set in .env file');
    return;
  }

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

                // --- Generate Row File ---
                try {
                  final rowClassContent = generateRowClass(
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
                // --- End Row File Generation ---
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

    // Write the schema report file
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
