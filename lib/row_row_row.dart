/// A Flutter package that generates type-safe database row classes from your Supabase database schema.
///
/// The row_row_row library connects to your Supabase project, fetches the
/// database schema via the OpenAPI specification, and generates strongly-typed
/// Dart classes for each table in your database.
///
/// The generated classes follow a consistent pattern:
/// - Class name: `<TableName>Row`
/// - Fields: camelCase property names matching the table's columns
/// - Constructor: const constructor with appropriate required/optional parameters
/// - Serialization: fromJson and toJson methods for easy data marshalling
/// - Column mapping: static field record to map between Dart fields and DB columns
///
/// Features:
/// - Type-safe field definitions based on database column types
/// - Proper handling of nullable/non-nullable fields
/// - Special handling for various types (DateTime, JSON, numeric types, etc.)
/// - Generated schema reports for documentation
library row_row_row;

export 'src/generator.dart' show generate;
