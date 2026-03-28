/// Codama IDL Parser
///
/// Converts a Codama node-tree JSON (used by Pinocchio programs) into the
/// flat [Idl] model used by coral_xyz.
///
/// Codama IDL structure:
/// ```json
/// {
///   "standard": "codama",
///   "version": "1.0.0",
///   "kind": "rootNode",
///   "program": { "kind": "programNode", ... }
/// }
/// ```
///
/// The parser handles:
/// - `ProgramNode` → [Idl] with name, address, instructions, accounts, types
/// - `InstructionNode` → [IdlInstruction] with args, accounts, discriminator
/// - `AccountNode` → [IdlAccount] + [IdlTypeDef]
/// - Codama type nodes → [IdlType] string kinds
library;

import 'idl.dart';

/// Parser that converts Codama JSON into the flat [Idl] model.
///
/// Builds an intermediate JSON map and delegates to [Idl.fromJson] so that
/// all validation and type resolution happens in one place.
///
/// ```dart
/// final json = jsonDecode(codamaIdlString);
/// final idl = CodamaParser.parse(json);
/// final program = Program(idl, provider: provider);
/// ```
class CodamaParser {
  CodamaParser._();

  /// Parse a Codama IDL JSON map into an [Idl].
  ///
  /// Accepts either:
  /// - A `rootNode` containing a `program` key
  /// - A `programNode` directly
  static Idl parse(Map<String, dynamic> json) {
    final Map<String, dynamic> programNode;

    if (json['kind'] == 'rootNode') {
      programNode = json['program'] as Map<String, dynamic>;
    } else if (json['kind'] == 'programNode') {
      programNode = json;
    } else {
      throw ArgumentError(
        'Expected a Codama rootNode or programNode, got: ${json['kind']}',
      );
    }

    final name = programNode['name'] as String? ?? '';
    final publicKey = programNode['publicKey'] as String?;
    final version = programNode['version'] as String? ?? '0.0.0';

    final instructions = _parseInstructions(
      programNode['instructions'] as List<dynamic>? ?? [],
    );

    final accounts = _parseAccounts(
      programNode['accounts'] as List<dynamic>? ?? [],
    );

    final types = _parseDefinedTypes(
      programNode['definedTypes'] as List<dynamic>? ?? [],
    );

    final errors = _parseErrors(programNode['errors'] as List<dynamic>? ?? []);

    // Build account type defs from account nodes (mirrors Anchor pattern)
    final accountTypeDefs = _accountTypeDefs(
      programNode['accounts'] as List<dynamic>? ?? [],
    );

    // Build events from program if present
    final events = _parseEvents(programNode['events'] as List<dynamic>? ?? []);

    return Idl.fromJson({
      'name': name,
      'version': version,
      'address': publicKey ?? '',
      'metadata': {'name': name, 'version': version, 'spec': 'codama'},
      'instructions': instructions,
      'accounts': accounts,
      'types': [...types, ...accountTypeDefs],
      if (events.isNotEmpty) 'events': events,
      if (errors.isNotEmpty) 'errors': errors,
    });
  }

  // ---------------------------------------------------------------------------
  // Instructions → JSON maps
  // ---------------------------------------------------------------------------

  static List<Map<String, dynamic>> _parseInstructions(List<dynamic> nodes) {
    return nodes.whereType<Map<String, dynamic>>().map((node) {
      final name = node['name'] as String? ?? '';

      // Parse arguments
      final rawArgs = (node['arguments'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .where((a) => a['kind'] == 'instructionArgumentNode')
          .toList();

      final args = rawArgs
          .map(
            (a) => {
              'name': a['name'] as String? ?? '',
              'type': _convertTypeToJson(
                a['type'] as Map<String, dynamic>? ?? {},
              ),
              if (_docs(a) != null) 'docs': _docs(a),
            },
          )
          .toList();

      // Parse accounts
      final accounts = (node['accounts'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(_parseInstructionAccount)
          .toList();

      // Parse discriminator
      List<int>? discriminator;
      final discs = node['discriminators'] as List<dynamic>? ?? [];
      for (final disc in discs) {
        if (disc is Map<String, dynamic>) {
          if (disc['kind'] == 'constantDiscriminatorNode') {
            discriminator = _extractConstantDiscBytes(disc);
            if (discriminator != null) break;
          } else if (disc['kind'] == 'fieldDiscriminatorNode') {
            // Field-based discriminator — Pinocchio pattern (first u8 = 0/1).
            final fieldName = disc['name'] as String?;
            final offset = disc['offset'] as int? ?? 0;
            if (fieldName != null) {
              for (final a in rawArgs) {
                if (a['name'] == fieldName) {
                  final dv = a['defaultValue'] as Map<String, dynamic>?;
                  if (dv != null && dv['kind'] == 'numberValueNode') {
                    discriminator = [dv['number'] as int? ?? offset];
                  }
                  break;
                }
              }
            }
          }
        }
      }

      return <String, dynamic>{
        'name': name,
        if (discriminator != null) 'discriminator': discriminator,
        'accounts': accounts,
        'args': args,
        if (_docs(node) != null) 'docs': _docs(node),
      };
    }).toList();
  }

  static Map<String, dynamic> _parseInstructionAccount(
    Map<String, dynamic> node,
  ) {
    final kind = node['kind'] as String? ?? '';

    if (kind == 'instructionAccountNode') {
      return {
        'name': node['name'] as String? ?? '',
        'writable': node['isMutable'] == true,
        'signer': node['isSigner'] == true || node['isSigner'] == 'either',
        'optional': node['isOptional'] == true,
        if (_docs(node) != null) 'docs': _docs(node),
      };
    }

    // instructionRemainingAccountsNode
    return {
      'name': node['name'] as String? ?? 'remainingAccounts',
      'writable': false,
      'signer': false,
      'optional': true,
      if (_docs(node) != null) 'docs': _docs(node),
    };
  }

  // ---------------------------------------------------------------------------
  // Accounts → JSON maps
  // ---------------------------------------------------------------------------

  static List<Map<String, dynamic>> _parseAccounts(List<dynamic> nodes) {
    return nodes.whereType<Map<String, dynamic>>().map((node) {
      final name = node['name'] as String? ?? '';
      final discriminator = _extractDiscriminator(node) ?? <int>[];

      return <String, dynamic>{
        'name': name,
        'discriminator': discriminator,
        if (_docs(node) != null) 'docs': _docs(node),
      };
    }).toList();
  }

  /// Generate TypeDef JSON entries for each account's data structure.
  static List<Map<String, dynamic>> _accountTypeDefs(List<dynamic> nodes) {
    return nodes.whereType<Map<String, dynamic>>().map((node) {
      final name = node['name'] as String? ?? '';
      final data = node['data'] as Map<String, dynamic>?;

      List<Map<String, dynamic>> fields = [];
      if (data != null && data['kind'] == 'structTypeNode') {
        fields = _parseStructFields(data);
      }

      return <String, dynamic>{
        'name': name,
        'type': {'kind': 'struct', 'fields': fields},
        if (_docs(node) != null) 'docs': _docs(node),
      };
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Types → JSON maps
  // ---------------------------------------------------------------------------

  static List<Map<String, dynamic>> _parseDefinedTypes(List<dynamic> nodes) {
    return nodes.whereType<Map<String, dynamic>>().map((node) {
      final name = node['name'] as String? ?? '';
      final typeNode = node['type'] as Map<String, dynamic>? ?? {};

      return <String, dynamic>{
        'name': name,
        'type': _convertTypeDefBody(typeNode),
        if (_docs(node) != null) 'docs': _docs(node),
      };
    }).toList();
  }

  static Map<String, dynamic> _convertTypeDefBody(Map<String, dynamic> node) {
    final kind = node['kind'] as String? ?? '';

    if (kind == 'structTypeNode') {
      return {'kind': 'struct', 'fields': _parseStructFields(node)};
    }

    if (kind == 'enumTypeNode') {
      final variants = (node['variants'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((v) {
            final fields = v['struct'] as Map<String, dynamic>?;
            return <String, dynamic>{
              'name': v['name'] as String? ?? '',
              if (fields != null) 'fields': _parseStructFields(fields),
            };
          })
          .toList();
      return {'kind': 'enum', 'variants': variants};
    }

    // Type alias
    if (kind == 'definedTypeLinkNode' || kind == 'numberTypeNode') {
      return {'kind': 'type', 'alias': _convertTypeToJson(node)};
    }

    return {'kind': 'struct', 'fields': <Map<String, dynamic>>[]};
  }

  static List<Map<String, dynamic>> _parseStructFields(
    Map<String, dynamic> structNode,
  ) {
    final fields = structNode['fields'] as List<dynamic>? ?? [];
    return fields.whereType<Map<String, dynamic>>().map((f) {
      return <String, dynamic>{
        'name': f['name'] as String? ?? '',
        'type': _convertTypeToJson(f['type'] as Map<String, dynamic>? ?? {}),
        if (_docs(f) != null) 'docs': _docs(f),
      };
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Events → JSON maps
  // ---------------------------------------------------------------------------

  static List<Map<String, dynamic>> _parseEvents(List<dynamic> nodes) {
    return nodes.whereType<Map<String, dynamic>>().map((node) {
      final name = node['name'] as String? ?? '';
      final discriminator = _extractDiscriminator(node);

      return <String, dynamic>{
        'name': name,
        if (discriminator != null) 'discriminator': discriminator,
      };
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Errors → JSON maps
  // ---------------------------------------------------------------------------

  static List<Map<String, dynamic>> _parseErrors(List<dynamic> nodes) {
    return nodes.whereType<Map<String, dynamic>>().map((node) {
      return <String, dynamic>{
        'code': node['code'] as int? ?? 0,
        'name': node['name'] as String? ?? '',
        if (node['message'] != null) 'msg': node['message'],
      };
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Type conversion (Codama type nodes → IdlType-compatible JSON)
  // ---------------------------------------------------------------------------

  static dynamic _convertTypeToJson(Map<String, dynamic> node) {
    final kind = node['kind'] as String? ?? '';

    switch (kind) {
      // Number types
      case 'numberTypeNode':
        return node['format'] as String? ?? 'u64';

      // Boolean
      case 'booleanTypeNode':
        return 'bool';

      // Strings
      case 'stringTypeNode':
        return 'string';
      case 'fixedSizeTypeNode':
        final innerType = node['type'] as Map<String, dynamic>?;
        if (innerType != null && innerType['kind'] == 'stringTypeNode') {
          return 'string';
        }
        if (innerType != null) {
          return _convertTypeToJson(innerType);
        }
        return 'bytes';

      // Public keys
      case 'publicKeyTypeNode':
        return 'pubkey';

      // Bytes
      case 'bytesTypeNode':
        return 'bytes';

      // Option
      case 'optionTypeNode':
        final item = node['item'] as Map<String, dynamic>?;
        final prefix = node['prefix'] as Map<String, dynamic>?;
        // COption uses u32 prefix; standard option uses u8
        final isCOption =
            prefix != null &&
            (prefix['format'] == 'u32' || prefix['endian'] == 'le');
        if (item != null) {
          final inner = _convertTypeToJson(item);
          return isCOption ? {'coption': inner} : {'option': inner};
        }
        return {'option': 'u8'};

      // Array (fixed size)
      case 'arrayTypeNode':
        final item = node['item'] as Map<String, dynamic>?;
        final count = node['count'] as Map<String, dynamic>?;
        if (item != null && count != null) {
          final inner = _convertTypeToJson(item);
          if (count['kind'] == 'fixedCountNode') {
            final size = count['value'] as int? ?? 0;
            return {
              'array': [inner, size],
            };
          }
          // Prefixed count → vec
          return {'vec': inner};
        }
        return {'vec': 'u8'};

      // Set / Map → encode as vec
      case 'setTypeNode':
        final item = node['item'] as Map<String, dynamic>?;
        if (item != null) {
          return {'vec': _convertTypeToJson(item)};
        }
        return {'vec': 'u8'};

      case 'mapTypeNode':
        // Maps are typically serialized as Vec<(key, value)>
        return {'vec': 'bytes'};

      // Tuple
      case 'tupleTypeNode':
        return 'bytes';

      // Enums (inline enum reference → u8)
      case 'enumTypeNode':
        return 'u8';

      // Struct (inline struct reference → defined type)
      case 'structTypeNode':
        final name = node['name'] as String?;
        if (name != null) {
          return {'defined': name};
        }
        return 'bytes';

      // Defined type reference
      case 'definedTypeLinkNode':
        final name = node['name'] as String? ?? '';
        return {'defined': name};

      // Amount (e.g., lamports) — maps to the underlying number type
      case 'amountTypeNode':
        final number = node['number'] as Map<String, dynamic>?;
        if (number != null) return _convertTypeToJson(number);
        return 'u64';

      // DateTime → i64
      case 'dateTimeTypeNode':
        return 'i64';

      // SolAmount → u64
      case 'solAmountTypeNode':
        return 'u64';

      // Remainder (rest of bytes) → option
      case 'remainderOptionTypeNode':
        final item = node['item'] as Map<String, dynamic>?;
        if (item != null) {
          return {'option': _convertTypeToJson(item)};
        }
        return {'option': 'bytes'};

      // Zero-able (nullable) → option
      case 'zeroableOptionTypeNode':
        final item = node['item'] as Map<String, dynamic>?;
        if (item != null) {
          return {'option': _convertTypeToJson(item)};
        }
        return {'option': 'u8'};

      default:
        // Unknown type → bytes fallback
        return 'bytes';
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Extract byte discriminator from a node's `discriminators` array.
  static List<int>? _extractDiscriminator(Map<String, dynamic> node) {
    final discs = node['discriminators'] as List<dynamic>? ?? [];
    for (final disc in discs) {
      if (disc is Map<String, dynamic> &&
          disc['kind'] == 'constantDiscriminatorNode') {
        final bytes = _extractConstantDiscBytes(disc);
        if (bytes != null) return bytes;
      }
    }
    return null;
  }

  /// Extract hex bytes from a constantDiscriminatorNode.
  ///
  /// Supports both the upstream Codama format:
  ///   { constant: { kind: 'constantValueNode', value: { kind: 'bytesValueNode', data: '...' } } }
  /// and a flat shorthand:
  ///   { value: { kind: 'bytesValueNode', data: '...' } }
  static List<int>? _extractConstantDiscBytes(Map<String, dynamic> disc) {
    // Upstream format: disc.constant.value
    final constant = disc['constant'] as Map<String, dynamic>?;
    if (constant != null) {
      final value = constant['value'] as Map<String, dynamic>?;
      if (value != null && value['kind'] == 'bytesValueNode') {
        return _hexToBytes(value['data'] as String? ?? '');
      }
    }
    // Flat shorthand: disc.value
    final value = disc['value'] as Map<String, dynamic>?;
    if (value != null && value['kind'] == 'bytesValueNode') {
      return _hexToBytes(value['data'] as String? ?? '');
    }
    return null;
  }

  static List<String>? _docs(Map<String, dynamic> node) {
    final docs = node['docs'] as List<dynamic>?;
    if (docs == null || docs.isEmpty) return null;
    return docs.cast<String>();
  }

  /// Convert a hex string (Codama's bytesValueNode data) to byte list.
  static List<int> _hexToBytes(String hex) {
    final cleaned = hex.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    final bytes = <int>[];
    for (var i = 0; i + 1 < cleaned.length; i += 2) {
      bytes.add(int.parse(cleaned.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }
}
