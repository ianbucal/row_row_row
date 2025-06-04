// Note: This example will show linter errors until you run the generator.
// The generator will create the necessary files in:
// - lib/row_row_row/tables/users.row.dart
// - lib/row_row_row/enums/user_status.enum.dart
//
// After running the generator, the linter errors will be resolved.

// ignore_for_file: uri_does_not_exist
// ignore_for_file: undefined_identifier

import 'package:row_row_row/row_row_row.dart';
// Import the generated classes - these will be available after running the generator
import 'package:row_row_row/tables/users.row.dart';
import 'package:row_row_row/enums/user_status.enum.dart';

/// Example demonstrating how to use the row_row_row package
void main() async {
  // Initialize the generator with your Supabase credentials
  await generate(
    supabaseUrl: 'YOUR_SUPABASE_URL',
    serviceRoleKey: 'YOUR_SERVICE_ROLE_KEY',
    formatCode: true,
    clean: true,
  );

  // After generation, you can use the generated classes like this:
  // Note: This is just an example - the actual class names will depend on your database schema

  // Example: Create a new user
  final user = await UsersRow.create(
    email: 'user@example.com',
    name: 'John Doe',
  );
  print('Created user: ${user.name}');

  // Example: Retrieve a user by ID
  final retrievedUser = await UsersRow.retrieveFromId(1);
  print('Retrieved user: ${retrievedUser.name}');

  // Example: Update a user
  final updatedUser = await retrievedUser
      .copyWith(
        name: 'Jane Doe',
      )
      .update();
  print('Updated user: ${updatedUser.name}');

  // Example: Delete a user
  await retrievedUser.delete();
  print('User deleted');

  // Example: Range-based queries
  final recentUsers = await UsersRow.retrieveCreatedAtByRange(
    greaterThanOrEqual: DateTime(2024, 1, 1),
    lessThan: DateTime(2024, 2, 1),
    orderBy: 'created_at',
    orderAsc: false,
  );
  print('Found ${recentUsers.length} recent users');

  // Example: Using enums
  final status = UserStatusEnum.active;
  print('User status: ${status.toValue}');

  // Example: Converting from string to enum
  final statusFromString = UserStatusEnum.tryFromValue('active');
  print('Status from string: ${statusFromString?.toValue}');
}
