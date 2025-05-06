# Changelog

All notable changes to this project will be documented in this file.

## 0.1.6 - Integrated CRUD Operations

*   Added built-in CRUD operations directly in the Row model classes:
    *   Added flexible `create` static method with all nullable parameters.
    *   Added `getFromId` method to fetch rows by primary key (throws on not found).
    *   Added safer `findById` method that returns null when records don't exist.
    *   Smart insert payload - only non-null fields are included in the database insert.
    *   Full developer control - all fields can be explicitly set or left for database defaults.
    *   Automatic type handling - timestamps, dates, and enums are properly converted.
    *   Table/View detection - CRUD operations are only generated for tables, not for views.
    *   Generated models now include Supabase database integration.
*   Row model files now import the Supabase Flutter package for database operations.
*   Updated README with usage examples for CRUD operations.

## 0.1.5 - Folder changes

*   Moved the generated folder from `row_row_row_generated` into `row_row_row`.
* Changed json, jsonb into dynamic
* Changed json[], jsonb into List<dynamic>

## 0.1.4 - Enhanced Usability and Data Type Handling

*   Added `copyWith` method to all generated row classes for easier object modification.
*   Removed nullable `?` for dynamic value typings.
*   Improved JSON conversion with additional type support in `fromJson` factory:
    *   Added support for `Map.from()` for dynamic maps.
    *   Added support for `List<String>.from()` for string lists.
    *   Added support for `List<int>.from()` with type conversion.
    *   Added support for `List<double>.from()` with type conversion.
    *   Added support for `List<Map>.from()` for lists of maps.
*   Added support for more PostgreSQL data types:
    *   `character` and `character varying` mapped to `String`.
    *   `smallint` mapped to `int`.
    *   Array variants of these types also supported.

## 0.1.3 - Enum Type Detection & Generation, Cleaning & Enum Improvements

*   Added support for detecting and generating Dart enums from PostgreSQL enum types.
*   Enum names are now derived from the database enum type name (instead of the column 
name).
*   Created a new `enums` directory for the generated enum files with naming pattern 
`<EnumName>.enum.dart`.
*   Added helper methods in generated enum classes:
    *   `toValue` getter to convert enum to database string value.
    *   `fromValue` static method to convert database string value to enum.
    *   `tryFromValue` static method for safe conversion with null handling.
*   Table row classes now use the proper enum types for columns that use enum types.
*   Added optional `--clean` / `-c` flag to delete all existing generated files before generation.
*   Improved enum file naming to be more consistent with Dart conventions:
    *   Changed file naming pattern to use snake_case (`user_type.enum.dart` instead of camelCase).
    *   Fixed redundant enum naming that could lead to names like `UserTypeEnum.enum.dart`.
*   Fixed implementation of `_toSnakeCase` for proper conversion from camelCase and PascalCase.
*   Fixed missing function `_getJsonCastType` that was causing errors.
*   Removed redundant duplicate functions and code.
*   Improved error handling in the code generation process.
*   Added more descriptive logging during the generation process.

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
