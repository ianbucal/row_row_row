import 'dart:io';
import 'package:dotenv/dotenv.dart' as dotenv;
import 'package:args/args.dart';
import 'package:row_row_row/row_row_row.dart'; // Import the library

/// Entry point for the row_row_row command-line application.
///
/// Processes command-line [args] to:
/// 1. Load environment variables from a .env file
/// 2. Parse and validate arguments using ArgParser
/// 3. Execute the appropriate command based on user input
///
/// The main supported command is `generate`, which generates Dart model classes
/// from a Supabase database schema.
///
/// Environment variables required:
/// - SUPABASE_URL: URL of the Supabase project
/// - SERVICE_ROLE: Service role key for API authentication
///
/// Exit codes:
/// - 0: Success
/// - 1: Error (invalid arguments, missing environment variables, etc.)
void main(List<String> args) async {
  // Load environment variables
  final env = dotenv.DotEnv()..load();

  // Set up command parser
  final parser =
      ArgParser()
        // Add help flag FIRST
        ..addFlag(
          'help',
          negatable: false,
          abbr: 'h',
          help: 'Print this usage information.',
        )
        ..addCommand(
          'generate',
        ) // Keep command for structure, though only one exists
        ..addFlag(
          'dart-format',
          negatable: false,
          abbr: 'f',
          help:
              'Automatically format generated Dart files using "dart format".',
          defaultsTo: false,
        );

  try {
    final results = parser.parse(args);

    // Check for help flag before doing anything else
    if (results['help'] as bool) {
      printUsage(parser);
      exit(0); // Exit cleanly after showing help
    }

    final command = results.command?.name;
    final shouldFormat = results['dart-format'] as bool;

    // Ensure the command is the one we expect
    if (command == 'generate') {
      // Get required environment variables
      final supabaseUrl = env['SUPABASE_URL'];
      final serviceRoleKey = env['SERVICE_ROLE'];

      if (supabaseUrl == null || supabaseUrl.isEmpty) {
        print('Error: SUPABASE_URL must be set in .env file');
        exit(1);
      }
      if (serviceRoleKey == null || serviceRoleKey.isEmpty) {
        print('Error: SERVICE_ROLE must be set in .env file');
        exit(1);
      }

      // Call the library function
      await generate(
        supabaseUrl: supabaseUrl,
        serviceRoleKey: serviceRoleKey,
        formatCode: shouldFormat,
      );
      exit(0); // Success exit
    } else {
      // If no command or wrong command is given (and not --help), show usage and exit with error
      print('Error: Invalid or missing command.\n');
      printUsage(parser);
      exit(1);
    }
  } catch (e) {
    if (e is FormatException) {
      print('Error parsing arguments: ${e.message}\n');
    } else {
      print('An unexpected error occurred: $e\n');
    }
    printUsage(parser);
    exit(1); // Exit with error code
  }
}

/// Prints usage information for the command-line tool.
///
/// Displays:
/// - Basic usage syntax
/// - Brief description
/// - Available commands
/// - Options with descriptions generated from the [parser]
void printUsage(ArgParser parser) {
  print('Usage: dart run row_row_row <command> [options]');
  print('\nGenerates Dart models for Supabase table rows.');
  print('\nAvailable commands:');
  print('  generate   Generate Dart models from Supabase schema.');
  print('\nOptions:');
  print(parser.usage);
}

// All helper functions and generation logic have been moved to lib/src/generator.dart
