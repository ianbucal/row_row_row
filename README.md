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
*   Generate `.row.dart` model files in `lib/row_row_row_generated/tables/`.
*   Create a schema report in `lib/row_row_row_generated/db_schema_report/`.

**Options:**

*   `-f`, `--dart-format`: Automatically format the generated Dart files using `dart format`.
*   `-c`, `--clean`: Delete all existing generated files before generating new ones.
*   `-h`, `--help`: Show usage information, including all options.

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

---

## Acknowledgements

This project was developed with the assistance of AI.
