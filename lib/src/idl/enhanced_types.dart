/// Enhanced IDL type system with generics and advanced type support
///
/// This module provides an enhanced type system that matches the TypeScript
/// implementation's support for generics, advanced array handling, and
/// sophisticated type definitions.

library;

/// Enhanced IDL type system with generics and advanced type support
abstract class IdlType {
  const IdlType();

  factory IdlType.fromJson(dynamic json) {
    if (json is String) {
      // Simple primitive types
      return IdlTypePrimitive(json);
    } else if (json is Map<String, dynamic>) {
      if (json.containsKey('option')) {
        return IdlTypeOption(IdlType.fromJson(json['option']));
      } else if (json.containsKey('coption')) {
        return IdlTypeCOption(IdlType.fromJson(json['coption']));
      } else if (json.containsKey('vec')) {
        return IdlTypeVec(IdlType.fromJson(json['vec']));
      } else if (json.containsKey('array')) {
        final arrayData = json['array'];
        if (arrayData is List && arrayData.length == 2) {
          return IdlTypeArray(
            IdlType.fromJson(arrayData[0]),
            IdlArrayLen.fromJson(arrayData[1]),
          );
        }
        throw ArgumentError('Invalid array type definition: $json');
      } else if (json.containsKey('defined')) {
        final definedData = json['defined'];
        if (definedData is String) {
          return IdlTypeDefined(IdlTypeDefinedSimple(definedData));
        } else if (definedData is Map<String, dynamic>) {
          return IdlTypeDefined(IdlTypeDefinedGeneric.fromJson(definedData));
        }
        throw ArgumentError('Invalid defined type: $json');
      } else if (json.containsKey('generic')) {
        return IdlTypeGeneric(json['generic'] as String);
      }
      throw ArgumentError('Unknown type format: $json');
    }
    throw ArgumentError('Invalid type definition: $json');
  }

  dynamic toJson();
}

/// Primitive types (bool, u8, i8, etc.)
class IdlTypePrimitive extends IdlType {
  final String type;

  const IdlTypePrimitive(this.type);

  @override
  dynamic toJson() => type;

  @override
  String toString() => 'IdlTypePrimitive($type)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is IdlTypePrimitive && type == other.type;

  @override
  int get hashCode => type.hashCode;
}

/// Option type
class IdlTypeOption extends IdlType {
  final IdlType inner;

  const IdlTypeOption(this.inner);

  @override
  dynamic toJson() => {'option': inner.toJson()};

  @override
  String toString() => 'IdlTypeOption($inner)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is IdlTypeOption && inner == other.inner;

  @override
  int get hashCode => inner.hashCode;
}

/// COption type (compact option)
class IdlTypeCOption extends IdlType {
  final IdlType inner;

  const IdlTypeCOption(this.inner);

  @override
  dynamic toJson() => {'coption': inner.toJson()};

  @override
  String toString() => 'IdlTypeCOption($inner)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is IdlTypeCOption && inner == other.inner;

  @override
  int get hashCode => inner.hashCode;
}

/// Vector type
class IdlTypeVec extends IdlType {
  final IdlType inner;

  const IdlTypeVec(this.inner);

  @override
  dynamic toJson() => {'vec': inner.toJson()};

  @override
  String toString() => 'IdlTypeVec($inner)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is IdlTypeVec && inner == other.inner;

  @override
  int get hashCode => inner.hashCode;
}

/// Array type with length
class IdlTypeArray extends IdlType {
  final IdlType inner;
  final IdlArrayLen length;

  const IdlTypeArray(this.inner, this.length);

  @override
  dynamic toJson() => {
        'array': [inner.toJson(), length.toJson()]
      };

  @override
  String toString() => 'IdlTypeArray($inner, $length)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IdlTypeArray && inner == other.inner && length == other.length;

  @override
  int get hashCode => Object.hash(inner, length);
}

/// Defined type (user-defined)
class IdlTypeDefined extends IdlType {
  final IdlTypeDefinedData defined;

  const IdlTypeDefined(this.defined);

  @override
  dynamic toJson() => {'defined': defined.toJson()};

  @override
  String toString() => 'IdlTypeDefined($defined)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IdlTypeDefined && defined == other.defined;

  @override
  int get hashCode => defined.hashCode;
}

/// Generic type parameter
class IdlTypeGeneric extends IdlType {
  final String name;

  const IdlTypeGeneric(this.name);

  @override
  dynamic toJson() => {'generic': name};

  @override
  String toString() => 'IdlTypeGeneric($name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is IdlTypeGeneric && name == other.name;

  @override
  int get hashCode => name.hashCode;
}

/// Base class for defined type data
abstract class IdlTypeDefinedData {
  const IdlTypeDefinedData();
  dynamic toJson();
}

/// Simple defined type (just a name)
class IdlTypeDefinedSimple extends IdlTypeDefinedData {
  final String name;

  const IdlTypeDefinedSimple(this.name);

  @override
  dynamic toJson() => name;

  @override
  String toString() => 'IdlTypeDefinedSimple($name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IdlTypeDefinedSimple && name == other.name;

  @override
  int get hashCode => name.hashCode;
}

/// Generic defined type (name + generics)
class IdlTypeDefinedGeneric extends IdlTypeDefinedData {
  final String name;
  final List<IdlGenericArg>? generics;

  const IdlTypeDefinedGeneric(this.name, this.generics);

  factory IdlTypeDefinedGeneric.fromJson(Map<String, dynamic> json) {
    return IdlTypeDefinedGeneric(
      json['name'] as String,
      (json['generics'] as List<dynamic>?)
          ?.map((e) => IdlGenericArg.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  dynamic toJson() => {
        'name': name,
        if (generics != null)
          'generics': generics!.map((e) => e.toJson()).toList(),
      };

  @override
  String toString() => 'IdlTypeDefinedGeneric($name, $generics)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IdlTypeDefinedGeneric &&
          name == other.name &&
          _listEquals(generics, other.generics);

  @override
  int get hashCode => Object.hash(name, generics);
}

/// Array length specification
abstract class IdlArrayLen {
  const IdlArrayLen();

  factory IdlArrayLen.fromJson(dynamic json) {
    if (json is int) {
      return IdlArrayLenValue(json);
    } else if (json is Map<String, dynamic> && json.containsKey('generic')) {
      return IdlArrayLenGeneric(json['generic'] as String);
    }
    throw ArgumentError('Invalid array length: $json');
  }

  dynamic toJson();
}

/// Fixed array length
class IdlArrayLenValue extends IdlArrayLen {
  final int value;

  const IdlArrayLenValue(this.value);

  @override
  dynamic toJson() => value;

  @override
  String toString() => 'IdlArrayLenValue($value)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IdlArrayLenValue && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// Generic array length
class IdlArrayLenGeneric extends IdlArrayLen {
  final String generic;

  const IdlArrayLenGeneric(this.generic);

  @override
  dynamic toJson() => {'generic': generic};

  @override
  String toString() => 'IdlArrayLenGeneric($generic)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IdlArrayLenGeneric && generic == other.generic;

  @override
  int get hashCode => generic.hashCode;
}

/// Generic argument
abstract class IdlGenericArg {
  const IdlGenericArg();

  factory IdlGenericArg.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('kind')) {
      final kind = json['kind'] as String;
      if (kind == 'type') {
        return IdlGenericArgType(IdlType.fromJson(json['type']));
      } else if (kind == 'const') {
        return IdlGenericArgConst(json['value'] as String);
      }
    }
    throw ArgumentError('Invalid generic argument: $json');
  }

  dynamic toJson();
}

/// Type generic argument
class IdlGenericArgType extends IdlGenericArg {
  final IdlType type;

  const IdlGenericArgType(this.type);

  @override
  dynamic toJson() => {
        'kind': 'type',
        'type': type.toJson(),
      };

  @override
  String toString() => 'IdlGenericArgType($type)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IdlGenericArgType && type == other.type;

  @override
  int get hashCode => type.hashCode;
}

/// Const generic argument
class IdlGenericArgConst extends IdlGenericArg {
  final String value;

  const IdlGenericArgConst(this.value);

  @override
  dynamic toJson() => {
        'kind': 'const',
        'value': value,
      };

  @override
  String toString() => 'IdlGenericArgConst($value)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IdlGenericArgConst && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// Enhanced type definition with generics support
class IdlTypeDefEnhanced {
  final String name;
  final List<String>? docs;
  final String? serialization;
  final IdlRepr? repr;
  final List<IdlTypeDefGeneric>? generics;
  final IdlTypeDefTy type;

  const IdlTypeDefEnhanced({
    required this.name,
    this.docs,
    this.serialization,
    this.repr,
    this.generics,
    required this.type,
  });

  factory IdlTypeDefEnhanced.fromJson(Map<String, dynamic> json) {
    return IdlTypeDefEnhanced(
      name: json['name'] as String,
      docs: (json['docs'] as List<dynamic>?)?.cast<String>(),
      serialization: json['serialization'] as String?,
      repr: json['repr'] != null
          ? IdlRepr.fromJson(json['repr'] as Map<String, dynamic>)
          : null,
      generics: (json['generics'] as List<dynamic>?)
          ?.map((e) => IdlTypeDefGeneric.fromJson(e as Map<String, dynamic>))
          .toList(),
      type: IdlTypeDefTy.fromJson(json['type'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (docs != null) 'docs': docs,
        if (serialization != null) 'serialization': serialization,
        if (repr != null) 'repr': repr!.toJson(),
        if (generics != null)
          'generics': generics!.map((e) => e.toJson()).toList(),
        'type': type.toJson(),
      };

  @override
  String toString() => 'IdlTypeDefEnhanced($name)';
}

/// Type definition generics
abstract class IdlTypeDefGeneric {
  const IdlTypeDefGeneric();

  factory IdlTypeDefGeneric.fromJson(Map<String, dynamic> json) {
    final kind = json['kind'] as String;
    if (kind == 'type') {
      return IdlTypeDefGenericType(json['name'] as String);
    } else if (kind == 'const') {
      return IdlTypeDefGenericConst(
        json['name'] as String,
        json['type'] as String,
      );
    }
    throw ArgumentError('Invalid type def generic: $json');
  }

  Map<String, dynamic> toJson();
}

/// Type generic
class IdlTypeDefGenericType extends IdlTypeDefGeneric {
  final String name;

  const IdlTypeDefGenericType(this.name);

  @override
  Map<String, dynamic> toJson() => {
        'kind': 'type',
        'name': name,
      };

  @override
  String toString() => 'IdlTypeDefGenericType($name)';
}

/// Const generic
class IdlTypeDefGenericConst extends IdlTypeDefGeneric {
  final String name;
  final String type;

  const IdlTypeDefGenericConst(this.name, this.type);

  @override
  Map<String, dynamic> toJson() => {
        'kind': 'const',
        'name': name,
        'type': type,
      };

  @override
  String toString() => 'IdlTypeDefGenericConst($name, $type)';
}

/// Type definition kind
abstract class IdlTypeDefTy {
  const IdlTypeDefTy();

  factory IdlTypeDefTy.fromJson(Map<String, dynamic> json) {
    final kind = json['kind'] as String;
    switch (kind) {
      case 'struct':
        return IdlTypeDefTyStruct(
          json['fields'] != null
              ? IdlDefinedFields.fromJson(json['fields'])
              : null,
        );
      case 'enum':
        return IdlTypeDefTyEnum(
          (json['variants'] as List<dynamic>)
              .map((e) => IdlEnumVariant.fromJson(e as Map<String, dynamic>))
              .toList(),
        );
      case 'type':
        return IdlTypeDefTyType(IdlType.fromJson(json['alias']));
      default:
        throw ArgumentError('Invalid type def kind: $kind');
    }
  }

  Map<String, dynamic> toJson();
}

/// Struct type definition
class IdlTypeDefTyStruct extends IdlTypeDefTy {
  final IdlDefinedFields? fields;

  const IdlTypeDefTyStruct(this.fields);

  @override
  Map<String, dynamic> toJson() => {
        'kind': 'struct',
        if (fields != null) 'fields': fields!.toJson(),
      };

  @override
  String toString() => 'IdlTypeDefTyStruct($fields)';
}

/// Enum type definition
class IdlTypeDefTyEnum extends IdlTypeDefTy {
  final List<IdlEnumVariant> variants;

  const IdlTypeDefTyEnum(this.variants);

  @override
  Map<String, dynamic> toJson() => {
        'kind': 'enum',
        'variants': variants.map((e) => e.toJson()).toList(),
      };

  @override
  String toString() => 'IdlTypeDefTyEnum($variants)';
}

/// Type alias definition
class IdlTypeDefTyType extends IdlTypeDefTy {
  final IdlType alias;

  const IdlTypeDefTyType(this.alias);

  @override
  Map<String, dynamic> toJson() => {
        'kind': 'type',
        'alias': alias.toJson(),
      };

  @override
  String toString() => 'IdlTypeDefTyType($alias)';
}

/// Defined fields (named or tuple)
abstract class IdlDefinedFields {
  const IdlDefinedFields();

  factory IdlDefinedFields.fromJson(dynamic json) {
    if (json is List) {
      if (json.isEmpty) {
        return const IdlDefinedFieldsNamed([]);
      }
      // Check if first element has 'name' field (named) or is a type (tuple)
      final first = json.first;
      if (first is Map<String, dynamic> && first.containsKey('name')) {
        // Named fields
        return IdlDefinedFieldsNamed(
          json
              .map((e) => IdlField.fromJson(e as Map<String, dynamic>))
              .toList(),
        );
      } else {
        // Tuple fields
        return IdlDefinedFieldsTuple(
          json.map((e) => IdlType.fromJson(e)).toList(),
        );
      }
    }
    throw ArgumentError('Invalid defined fields: $json');
  }

  dynamic toJson();
}

/// Named fields
class IdlDefinedFieldsNamed extends IdlDefinedFields {
  final List<IdlField> fields;

  const IdlDefinedFieldsNamed(this.fields);

  @override
  dynamic toJson() => fields.map((e) => e.toJson()).toList();

  @override
  String toString() => 'IdlDefinedFieldsNamed($fields)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IdlDefinedFieldsNamed && _listEquals(fields, other.fields);

  @override
  int get hashCode => fields.hashCode;
}

/// Tuple fields
class IdlDefinedFieldsTuple extends IdlDefinedFields {
  final List<IdlType> fields;

  const IdlDefinedFieldsTuple(this.fields);

  @override
  dynamic toJson() => fields.map((e) => e.toJson()).toList();

  @override
  String toString() => 'IdlDefinedFieldsTuple($fields)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IdlDefinedFieldsTuple && _listEquals(fields, other.fields);

  @override
  int get hashCode => fields.hashCode;
}

/// Enum variant
class IdlEnumVariant {
  final String name;
  final IdlDefinedFields? fields;

  const IdlEnumVariant(this.name, this.fields);

  factory IdlEnumVariant.fromJson(Map<String, dynamic> json) {
    return IdlEnumVariant(
      json['name'] as String,
      json['fields'] != null ? IdlDefinedFields.fromJson(json['fields']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (fields != null) 'fields': fields!.toJson(),
      };

  @override
  String toString() => 'IdlEnumVariant($name, $fields)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IdlEnumVariant && name == other.name && fields == other.fields;

  @override
  int get hashCode => Object.hash(name, fields);
}

/// Representation metadata
abstract class IdlRepr {
  const IdlRepr();

  factory IdlRepr.fromJson(Map<String, dynamic> json) {
    final kind = json['kind'] as String;
    switch (kind) {
      case 'rust':
        return IdlReprRust(
          packed: json['packed'] as bool?,
          align: json['align'] as int?,
        );
      case 'c':
        return IdlReprC(
          packed: json['packed'] as bool?,
          align: json['align'] as int?,
        );
      case 'transparent':
        return const IdlReprTransparent();
      default:
        throw ArgumentError('Invalid repr kind: $kind');
    }
  }

  Map<String, dynamic> toJson();
}

/// Rust representation
class IdlReprRust extends IdlRepr {
  final bool? packed;
  final int? align;

  const IdlReprRust({this.packed, this.align});

  @override
  Map<String, dynamic> toJson() => {
        'kind': 'rust',
        if (packed != null) 'packed': packed,
        if (align != null) 'align': align,
      };

  @override
  String toString() => 'IdlReprRust(packed: $packed, align: $align)';
}

/// C representation
class IdlReprC extends IdlRepr {
  final bool? packed;
  final int? align;

  const IdlReprC({this.packed, this.align});

  @override
  Map<String, dynamic> toJson() => {
        'kind': 'c',
        if (packed != null) 'packed': packed,
        if (align != null) 'align': align,
      };

  @override
  String toString() => 'IdlReprC(packed: $packed, align: $align)';
}

/// Transparent representation
class IdlReprTransparent extends IdlRepr {
  const IdlReprTransparent();

  @override
  Map<String, dynamic> toJson() => {'kind': 'transparent'};

  @override
  String toString() => 'IdlReprTransparent()';
}

/// Field definition
class IdlField {
  final String name;
  final List<String>? docs;
  final IdlType type;

  const IdlField({
    required this.name,
    this.docs,
    required this.type,
  });

  factory IdlField.fromJson(Map<String, dynamic> json) {
    return IdlField(
      name: json['name'] as String,
      docs: (json['docs'] as List<dynamic>?)?.cast<String>(),
      type: IdlType.fromJson(json['type']),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (docs != null) 'docs': docs,
        'type': type.toJson(),
      };

  @override
  String toString() => 'IdlField($name, $type)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IdlField &&
          name == other.name &&
          type == other.type &&
          _listEquals(docs, other.docs);

  @override
  int get hashCode => Object.hash(name, type, docs);
}

/// Utility function for list equality
bool _listEquals<T>(List<T>? a, List<T>? b) {
  if (a == null) return b == null;
  if (b == null || a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Factory functions for common types
IdlType idlTypeBool() => const IdlTypePrimitive('bool');
IdlType idlTypeU8() => const IdlTypePrimitive('u8');
IdlType idlTypeI8() => const IdlTypePrimitive('i8');
IdlType idlTypeU16() => const IdlTypePrimitive('u16');
IdlType idlTypeI16() => const IdlTypePrimitive('i16');
IdlType idlTypeU32() => const IdlTypePrimitive('u32');
IdlType idlTypeI32() => const IdlTypePrimitive('i32');
IdlType idlTypeU64() => const IdlTypePrimitive('u64');
IdlType idlTypeI64() => const IdlTypePrimitive('i64');
IdlType idlTypeF32() => const IdlTypePrimitive('f32');
IdlType idlTypeF64() => const IdlTypePrimitive('f64');
IdlType idlTypeU128() => const IdlTypePrimitive('u128');
IdlType idlTypeI128() => const IdlTypePrimitive('i128');
IdlType idlTypeU256() => const IdlTypePrimitive('u256');
IdlType idlTypeI256() => const IdlTypePrimitive('i256');
IdlType idlTypeString() => const IdlTypePrimitive('string');
IdlType idlTypeBytes() => const IdlTypePrimitive('bytes');
IdlType idlTypePubkey() => const IdlTypePrimitive('pubkey');
IdlType idlTypeVec(IdlType inner) => IdlTypeVec(inner);
IdlType idlTypeOption(IdlType inner) => IdlTypeOption(inner);
IdlType idlTypeCOption(IdlType inner) => IdlTypeCOption(inner);
IdlType idlTypeArray(IdlType inner, IdlArrayLen length) =>
    IdlTypeArray(inner, length);
IdlType idlTypeDefined(String name) =>
    IdlTypeDefined(IdlTypeDefinedSimple(name));
IdlType idlTypeDefinedGeneric(String name, List<IdlGenericArg> generics) =>
    IdlTypeDefined(IdlTypeDefinedGeneric(name, generics));
IdlType idlTypeGeneric(String name) => IdlTypeGeneric(name);
