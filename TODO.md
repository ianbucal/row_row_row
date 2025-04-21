# TODO for row_row_row

## Core Functionality & Refactoring

-   [ ] Refactor `listTablesAndViewsFromOpenApi` in `bin/row_row_row.dart` into smaller, more focused functions (e.g., fetch spec, parse definitions, write file, format code).
-   [ ] Move core logic (helper functions, `generateRowClass`, OpenAPI parsing) from `bin/` to `lib/` to make it a reusable library.
-   [ ] Improve error handling with more specific exit codes and messages for different failure types (API fetch fail, parse fail, write fail, format fail).
-   [ ] Investigate if OpenAPI spec reliably distinguishes between TABLE and VIEW types and update generation accordingly if possible.

## Generated Code Enhancements

-   [ ] Add optional generation of `copyWith` method to row classes.
-   [ ] Add optional generation of `toString` method to row classes.
-   [ ] Add optional generation of equality operators (`==`) and `hashCode` (consider using `package:equatable` integration or manual generation).

## Configuration & CLI

-   [ ] Allow configuring output directories (`tables`, `db_schema_report`) via command-line arguments or a config file.
-   [ ] Add an option to configure the class name suffix (defaulting to `Row`).
-   [ ] Add an option to explicitly *only* generate the schema report or *only* generate the row files.

## Quality & Publishing

-   [ ] Add unit tests for helper functions (`_toCamelCase`, `_mapType`).
-   [ ] Add integration tests for the main command execution flow (might require a mock Supabase API or a dedicated test project).
-   [ ] Update `pubspec.yaml` with a proper `version`, `description`, `repository`, `homepage`, etc.
-   [ ] Add a `LICENSE` file (e.g., MIT, Apache 2.0).
-   [ ] Write contribution guidelines if accepting community contributions. 