# Changelog

All notable changes to this project will be documented in this file.

## 0.1.1 - Package Usability Improvements

*   Updated package configuration to support usage from other projects.
*   Fixed executable configuration in `pubspec.yaml`.
*   Updated README with clearer installation and usage instructions:
    *   Added instructions for using as a dependency.
    *   Added instructions for global activation.
    *   Clarified command usage patterns for all installation methods.

## 0.1.0 - Initial Release

*   Initial version of the Supabase row generator.
*   Connects to Supabase via Service Role Key using `.env` file.
*   Fetches schema by parsing the OpenAPI specification from `/rest/v1/`.
*   Generates Dart model classes (`<TableName>Row`) in `lib/row_row_row_generated/tables/`.
*   Generated classes include:
    *   `camelCase` fields corresponding to `snake_case` columns.
    *   `const` constructor with required/optional named parameters.
    *   `fromJson` factory constructor.
    *   `toJson` method.
    *   Static `field` record mapping Dart fields to DB column names.
*   Generates a schema report text file in `lib/row_row_row_generated/db_schema_report/`.
*   Provides CLI options:
    *   `--dart-format` / `-f` to optionally format generated code.
    *   `--help` / `-h` to display usage.
