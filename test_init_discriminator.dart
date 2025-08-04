import 'package:coral_xyz/src/coder/discriminator_computer.dart';

String toSnakeCase(String camelCase) {
  if (camelCase.isEmpty) return camelCase;

  return camelCase
      .replaceAllMapped(
          RegExp(r'[A-Z]'), (match) => '_${match.group(0)!.toLowerCase()}')
      .replaceFirst(RegExp(r'^_'), ''); // Remove leading underscore if present
}

void main() {
  // Test conversion with multiple cases
  final testCases = ['initializeUser', 'addTodo', 'markTodo', 'removeTodo'];

  for (final camelCase in testCases) {
    final snakeCase = toSnakeCase(camelCase);
    print('$camelCase -> $snakeCase');
  }
}
