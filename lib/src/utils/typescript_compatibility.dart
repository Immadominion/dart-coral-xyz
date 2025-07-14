/// TypeScript-like utility types and functions for dart-coral-xyz.
/// Provides TypeScript-like API compatibility for easier migration from Anchor TS.
library;

/// TypeScript-like `Record<K, V>` type
typedef Record<K, V> = Map<K, V>;

/// TypeScript-like `Partial<T>` type simulation using nullable fields
/// Since Dart doesn't have exact TypeScript-style partials, this provides
/// a base for creating partial-like objects
abstract class Partial {}

/// TypeScript-like utility functions
class TSUtils {
  /// TypeScript-like Object.keys() equivalent
  static List<String> keys<T>(Map<String, T> object) => object.keys.toList();

  /// TypeScript-like Object.values() equivalent
  static List<T> values<T>(Map<String, T> object) => object.values.toList();

  /// TypeScript-like Object.entries() equivalent
  static List<MapEntry<String, T>> entries<T>(Map<String, T> object) => object.entries.toList();

  /// TypeScript-like Object.assign() equivalent
  static Map<String, dynamic> assign(
    Map<String, dynamic> target,
    Map<String, dynamic> source,
  ) => {...target, ...source};

  /// TypeScript-like Object.freeze() equivalent (returns unmodifiable view)
  static Map<K, V> freeze<K, V>(Map<K, V> object) => Map.unmodifiable(object);

  /// TypeScript-like Array.from() equivalent
  static List<T> arrayFrom<T>(Iterable<T> iterable) => List<T>.from(iterable);

  /// TypeScript-like array includes() method
  static bool includes<T>(List<T> array, T searchElement) => array.contains(searchElement);

  /// TypeScript-like array find() method
  static T? find<T>(List<T> array, bool Function(T) predicate) {
    try {
      return array.firstWhere(predicate);
    } catch (e) {
      return null;
    }
  }

  /// TypeScript-like array filter() method
  static List<T> filter<T>(List<T> array, bool Function(T) predicate) => array.where(predicate).toList();

  /// TypeScript-like array map() method
  static List<R> map<T, R>(List<T> array, R Function(T) mapper) => array.map(mapper).toList();

  /// TypeScript-like array reduce() method
  static R reduce<T, R>(
    List<T> array,
    R Function(R accumulator, T current) reducer,
    R initialValue,
  ) => array.fold(initialValue, reducer);
}

/// TypeScript-like Promise simulation using Future
typedef Promise<T> = Future<T>;

/// TypeScript-like setTimeout simulation
Future<void> setTimeout(void Function() callback, int milliseconds) => Future.delayed(Duration(milliseconds: milliseconds), callback);

/// TypeScript-like console object simulation
class Console {
  static void log(Object? message) {
    print(message);
  }

  static void warn(Object? message) {
    print('Warning: $message');
  }

  static void error(Object? message) {
    print('Error: $message');
  }

  static void info(Object? message) {
    print('Info: $message');
  }
}

/// Global console instance (TypeScript-like)
final console = Console();

/// TypeScript-like JSON object simulation
class JSON {
  /// JSON.stringify() equivalent
  static String stringify(Object? value) {
    // This is a basic implementation - in real usage you'd want
    // to use dart:convert's jsonEncode
    return value.toString();
  }

  /// JSON.parse() equivalent
  /// Note: This is a placeholder - use dart:convert's jsonDecode in real usage
  static dynamic parse(String text) {
    throw UnimplementedError(
      'Use dart:convert jsonDecode instead of JSON.parse',
    );
  }
}

/// Global JSON instance (TypeScript-like)
final json = JSON();

/// TypeScript-like unknown type (equivalent to dynamic)
typedef Unknown = dynamic;

/// TypeScript-like any type (equivalent to dynamic)
typedef Any = dynamic;

/// TypeScript-like void type for functions that don't return values
typedef Void = void;

/// TypeScript-like utility for making all properties optional
/// This is a marker class - actual implementation would need code generation
abstract class Optional<T> {}

/// TypeScript-like utility for making all properties required
/// This is a marker class - actual implementation would need code generation
abstract class Required<T> {}

/// TypeScript-like utility for picking specific properties
/// This is a marker class - actual implementation would need code generation
abstract class Pick<T, K> {}

/// TypeScript-like utility for omitting specific properties
/// This is a marker class - actual implementation would need code generation
abstract class Omit<T, K> {}

/// TypeScript-like error types
class TypeError extends Error {
  TypeError(super.message);
}

class ReferenceError extends Error {
  ReferenceError(super.message);
}

class RangeError extends Error {
  RangeError(super.message);
}

/// TypeScript-like Error base class
class Error implements Exception {

  Error(this.message, {this.name, this.stack});
  final String message;
  final String? name;
  final String? stack;

  @override
  String toString() => name != null ? '$name: $message' : message;
}
