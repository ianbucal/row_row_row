# Changelog

All notable changes to this project will be documented in this file.

## 0.1.3 - Enum Type Detection & Generation

*   Added support for detecting and generating Dart enums from PostgreSQL enum types.
*   Enum names are now derived from the database enum type name (instead of the column name).
*   Created a new `enums` directory for the generated enum files with naming pattern `<EnumName>.enum.dart`.
*   Added helper methods in generated enum classes:
    *   `toValue` getter to convert enum to database string value.
    *   `fromValue` static method to convert database string value to enum.
    *   `tryFromValue` static method for safe conversion with null handling.
*   Table row classes now use the proper enum types for columns that use enum types.

## 0.1.2 - Command Name Improvement

*   Changed the command name from `list-tables-views` to `generate` for improved usability.
*   Updated documentation to reflect the new command.

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
