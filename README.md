# row_row_row 🚣

**Generate Dart models for your Supabase table rows instantly!**

Tired of writing boilerplate Dart classes for your Supabase tables? `row_row_row` fetches your database schema and automatically generates `.row.dart` model files based on your table structure.

## Features

*   Connects securely using your Supabase URL and Service Role Key.
*   Introspects your schema via Supabase's generated OpenAPI specification.
*   Generates clean Dart classes (`YourTable**Row**`) with type-safe fields (camelCase).
*   Includes a `fromJson` factory constructor for easy data parsing.
*   Adds a static `field` record mapping Dart fields back to original database column names.
*   Outputs a handy schema report (`.txt`) for reference.
*   Generate `.row.dart` model files in `lib/row_row_row/tables/`.
*   Create a schema report in `lib/row_row_row/db_schema_report/`.
*   Generate Dart enum files for database enum types in `lib/row_row_row/enums/`.
*   Built-in CRUD operations with comprehensive database integration:
    *   Create, read, update, and delete operations
    *   Range-based retrieval for numeric and date fields
    *   Support for composite primary keys
    *   Proper timezone handling for timestamps
    *   Enhanced enum support with type mapping
    *   Improved error handling and type safety

## Setup

1.  **Environment:**
    *   Ensure you have the Dart SDK installed.
    *   Create a `.env` file in the project root with your Supabase credentials:
        ```dotenv
        SUPABASE_URL=https://<your-project-ref>.supabase.co
        SERVICE_ROLE=<your-supabase-service-role-key>
        ```
        *(**Important:** Add `.env` to your `.gitignore` to keep your key safe!)*

2.  **Installation:**
    
    **Option 1: Add as a dependency to your project**
    ```bash
    dart pub add row_row_row
    ```
    
    **Option 2: Install globally**
    ```bash
    dart pub global activate row_row_row
    ```

## Usage

**Generate Models:**

If installed as a dependency:
```bash
dart run row_row_row generate [options]
```

If used locally:
```bash
dart run bin/row_row_row.dart generate [options]
```

If installed globally:
```bash
dart pub global run row_row_row generate [options]
```

This command will:

*   Fetch the schema from your Supabase project.
*   Generate `.row.dart` model files in `lib/row_row_row/tables/`.
*   Create a schema report in `lib/row_row_row/db_schema_report/`.

**Options:**

*   `--help`, `-h`: Show usage information, including all options.
*   `--dart-format`, `-f`: Automatically format the generated Dart files using `dart format`.
*   `--clean`, `-c`: Delete all existing generated files before generating new ones.

**Examples:**

```bash
# Generate models (no formatting)
dart run row_row_row generate

# Generate models and format them
dart run row_row_row generate --dart-format

# Clean existing files and generate new ones
dart run row_row_row generate --clean

# Clean existing files, generate new ones, and format them
dart run row_row_row generate --clean --dart-format

# Show help
dart run row_row_row --help 
```

## Using Generated Models

The generated Row models include type-safe Dart classes with built-in CRUD operations:

```dart
// Import the generated model
import 'package:your_app/row_row_row/tables/user.row.dart';

// CREATE: Add a new row to the database
// All parameters are nullable, and only non-null values are included in the insert
final createdUser = await UserRow.create(
  name: 'John Doe',
  email: 'john@example.com',
  roleId: 2,
);
print(createdUser.id); // Auto-generated ID is available in the returned object

// READ: Fetch a row by its primary key (throws error if not found)
final user = await UserRow.getFromId('12345');

// READ: Range-based retrieval for numeric fields
final highValueUsers = await UserRow.retrieveBalanceByRange(
  greaterThan: 1000,
  lessThan: 5000,
  orderBy: 'created_at',
  orderAsc: true,
);

// READ: Range-based retrieval for date fields
final recentUsers = await UserRow.retrieveCreatedAtByRange(
  greaterThanOrEqual: DateTime(2024, 1, 1),
  lessThan: DateTime(2024, 2, 1),
  orderBy: 'created_at',
  orderAsc: false,
);

// For tables with non-standard primary keys, method names reflect the field:
// Primary key 'userId' → getFromUserId(userId)
// Composite keys → getFromKey1Key2(key1, key2)
```

Note: The generated CRUD methods require the `supabase_flutter` package to be installed and properly initialized in your app:

```dart
// Add to your pubspec.yaml
dependencies:
  supabase_flutter: ^1.0.0

// Initialize in your app
await Supabase.initialize(
  url: 'YOUR_SUPABASE_URL',
  anonKey: 'YOUR_ANON_KEY',
);
```

---

## Acknowledgements

This project was developed with the assistance of AI.
