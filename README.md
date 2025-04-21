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

2.  **Dependencies:**
    ```bash
    dart pub get
    ```

## Usage

**Generate Models:**

```bash
dart run bin/row_row_row.dart list-tables-views [options]
```

This command will:

*   Fetch the schema from your Supabase project.
*   Generate `.row.dart` model files in `lib/row_row_row_generated/tables/`.
*   Create a schema report in `lib/row_row_row_generated/db_schema_report/`.

**Options:**

*   `-f`, `--dart-format`: Automatically format the generated Dart files using `dart format`.
*   `-h`, `--help`: Show usage information, including all options.

**Examples:**

```bash
# Generate models (no formatting)
dart run bin/row_row_row.dart list-tables-views

# Generate models and format them
dart run bin/row_row_row.dart list-tables-views --dart-format

# Show help
dart run bin/row_row_row.dart --help 
```

---

## Acknowledgements

This project was developed with the assistance of AI.
