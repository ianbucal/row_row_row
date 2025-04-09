import 'package:postgres/postgres.dart';
import 'dart:io';

void main(List<String> args) async {
  final conn = await Connection.open(
    Endpoint(
      host: Platform.environment['DB_HOST']!,
      port: int.parse(Platform.environment['DB_PORT'] ?? '5432'),
      database: Platform.environment['DB_NAME']!,
      username: Platform.environment['DB_USER']!,
      password: Platform.environment['DB_PASSWORD']!,
    ),
    settings: ConnectionSettings(sslMode: SslMode.require),
  );

  final tables = await conn.execute(
    "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';",
  );

  for (final table in tables) {
    final tableName = table[0] as String;

    final columns = await conn.execute('''
      SELECT column_name, data_type, is_nullable
      FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = '$tableName';
    ''');

    final columnList =
        columns
            .map(
              (row) => {
                'column_name': row[0],
                'data_type': row[1],
                'is_nullable': row[2] == 'YES',
              },
            )
            .toList();

    final model = generateModel(tableName, columnList);
    final file = File('lib/models/$tableName.dart');
    await file.create(recursive: true);
    await file.writeAsString(model);
    print('✅ Generated model for $tableName');
  }

  await conn.close();
}

String generateModel(String tableName, List<Map<String, dynamic>> columns) {
  final className = _toPascalCase(tableName);
  final buffer = StringBuffer();
  buffer.writeln('class $className {');

  for (final col in columns) {
    final type = _mapType(col['data_type'], col['is_nullable']);
    buffer.writeln('  final $type ${col['column_name']};');
  }

  buffer.writeln('\n  const $className({');
  for (final col in columns) {
    buffer.writeln('    required this.${col['column_name']},');
  }
  buffer.writeln('  });\n}');

  return buffer.toString();
}

String _mapType(String sqlType, bool isNullable) {
  final baseType = switch (sqlType) {
    'integer' || 'int4' || 'int8' => 'int',
    'text' || 'varchar' => 'String',
    'boolean' => 'bool',
    'timestamp without time zone' ||
    'timestamp with time zone' ||
    'date' => 'DateTime',
    'numeric' || 'double precision' => 'double',
    _ => 'dynamic',
  };
  return isNullable ? '$baseType?' : baseType;
}

String _toPascalCase(String text) =>
    text
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join();
