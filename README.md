# row_row_row 🚣

A Flutter package that generates type-safe database row classes from your Supabase database schema.

## Features

- Automatically generates Dart classes for your Supabase database tables
- Supports all PostgreSQL data types including enums
- Generates proper type-safe methods for CRUD operations
- Handles nullable fields and proper type conversions
- Supports database views (read-only)
- Includes helper methods for common queries
- Generates proper enum classes with serialization support

## Getting Started

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  row_row_row: ^1.0.0
```

## Usage

1. First, ensure you have your Supabase URL and service role key:

```dart
import 'package:row_row_row/row_row_row.dart';

void main() async {
  await generate(
    supabaseUrl: 'YOUR_SUPABASE_URL',
    serviceRoleKey: 'YOUR_SERVICE_ROLE_KEY',
    formatCode: true, // Optional: format generated code
    clean: true, // Optional: clean existing generated files
  );
}
```

2. The generator will create:
   - Row classes in `lib/row_row_row/tables/`
   - Enum classes in `lib/row_row_row/enums/`
   - A schema report in `lib/row_row_row/db_schema_report/`

3. Use the generated classes in your code:

```dart
import 'package:row_row_row/tables/users.row.dart';

// Create a new user
final user = await UsersRow.create(
  email: 'user@example.com',
  name: 'John Doe',
);

// Retrieve a user
final retrievedUser = await UsersRow.retrieveFromId(1);

// Update a user
final updatedUser = await retrievedUser.copyWith(
  name: 'Jane Doe',
).update();

// Delete a user
await retrievedUser.delete();
```

## Features

### Type Safety
All generated classes are fully type-safe, with proper null safety support.

### CRUD Operations
Each row class includes methods for:
- Creating new rows
- Retrieving rows by various criteria
- Updating existing rows
- Deleting rows

### Enum Support
Database enums are automatically converted to Dart enums with:
- Type-safe serialization
- Helper methods for conversion
- Null safety support

### View Support
Database views are properly detected and handled as read-only objects.

## Additional Information

- [API Documentation](https://pub.dev/documentation/row_row_row/latest/)
- [GitHub Repository](https://github.com/yourusername/row_row_row)
- [Issue Tracker](https://github.com/yourusername/row_row_row/issues)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
