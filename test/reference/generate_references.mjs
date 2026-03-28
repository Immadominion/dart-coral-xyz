/**
 * Reference value generator for Dart Coral XYZ parity testing.
 *
 * Computes discriminators, instruction encodings, and account sizes
 * using the same algorithms as @coral-xyz/anchor TypeScript SDK.
 *
 * Algorithm reference:
 *   Discriminator = SHA256("prefix:name")[0..8]
 *   Instruction prefix: "global:"
 *   Account prefix: "account:"
 *   Event prefix: "event:"
 */

import { createHash } from "crypto";
import { readFileSync, writeFileSync } from "fs";
import { fileURLToPath } from "url";
import { dirname, join } from "path";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// ─── Case conversion ─────────────────────────────────────────────────────────

/**
 * Convert camelCase to snake_case.
 * Anchor computes instruction discriminators from the original Rust function
 * names which are snake_case, but the legacy IDL format stores them as
 * camelCase.
 */
function camelToSnakeCase(str) {
  return str
    .replace(/([A-Z])/g, (match) => `_${match.toLowerCase()}`)
    .replace(/^_/, ""); // remove leading underscore if name starts uppercase
}

// ─── Discriminator computation ───────────────────────────────────────────────

function sha256(data) {
  return createHash("sha256").update(data).digest();
}

function instructionDiscriminator(name) {
  // Anchor TS: SHA256("global:<snake_case_name>")[0..8]
  // Legacy IDL stores camelCase names; convert to snake_case first
  const snakeName = camelToSnakeCase(name);
  const hash = sha256(`global:${snakeName}`);
  return Array.from(hash.subarray(0, 8));
}

function instructionPreimage(name) {
  return `global:${camelToSnakeCase(name)}`;
}

function accountDiscriminator(name) {
  // Anchor TS: SHA256("account:<PascalCaseName>")[0..8]
  const hash = sha256(`account:${name}`);
  return Array.from(hash.subarray(0, 8));
}

function eventDiscriminator(name) {
  // Anchor TS: SHA256("event:<PascalCaseName>")[0..8]
  const hash = sha256(`event:${name}`);
  return Array.from(hash.subarray(0, 8));
}

// ─── Borsh encoding helpers ──────────────────────────────────────────────────

function encodeU8(value) {
  const buf = Buffer.alloc(1);
  buf.writeUInt8(value, 0);
  return Array.from(buf);
}

function encodeU16(value) {
  const buf = Buffer.alloc(2);
  buf.writeUInt16LE(value, 0);
  return Array.from(buf);
}

function encodeU32(value) {
  const buf = Buffer.alloc(4);
  buf.writeUInt32LE(value, 0);
  return Array.from(buf);
}

function encodeU64(value) {
  const buf = Buffer.alloc(8);
  buf.writeBigUInt64LE(BigInt(value), 0);
  return Array.from(buf);
}

function encodeI8(value) {
  const buf = Buffer.alloc(1);
  buf.writeInt8(value, 0);
  return Array.from(buf);
}

function encodeI16(value) {
  const buf = Buffer.alloc(2);
  buf.writeInt16LE(value, 0);
  return Array.from(buf);
}

function encodeI32(value) {
  const buf = Buffer.alloc(4);
  buf.writeInt32LE(value, 0);
  return Array.from(buf);
}

function encodeI64(value) {
  const buf = Buffer.alloc(8);
  buf.writeBigInt64LE(BigInt(value), 0);
  return Array.from(buf);
}

function encodeBool(value) {
  return [value ? 1 : 0];
}

function encodeString(value) {
  const strBytes = Buffer.from(value, "utf8");
  return [
    ...encodeU32(strBytes.length),
    ...Array.from(strBytes),
  ];
}

function encodePublicKey(base58) {
  // Decode base58 to 32 bytes
  const ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";
  let num = 0n;
  for (const c of base58) {
    num = num * 58n + BigInt(ALPHABET.indexOf(c));
  }
  const bytes = [];
  while (num > 0n) {
    bytes.unshift(Number(num % 256n));
    num /= 256n;
  }
  // Add leading zeros for leading '1's in base58
  for (const c of base58) {
    if (c === "1") bytes.unshift(0);
    else break;
  }
  // Pad to 32 bytes
  while (bytes.length < 32) bytes.unshift(0);
  return bytes.slice(0, 32);
}

function encodeVecLength(length) {
  return encodeU32(length);
}

function encodeBytes(value) {
  return [...encodeU32(value.length), ...value];
}

// Borsh-encode a value according to its IDL type
function encodeBorshValue(type, value) {
  if (typeof type === "string") {
    switch (type) {
      case "bool":
        return encodeBool(value);
      case "u8":
        return encodeU8(value);
      case "u16":
        return encodeU16(value);
      case "u32":
        return encodeU32(value);
      case "u64":
        return encodeU64(value);
      case "i8":
        return encodeI8(value);
      case "i16":
        return encodeI16(value);
      case "i32":
        return encodeI32(value);
      case "i64":
        return encodeI64(value);
      case "string":
        return encodeString(value);
      case "publicKey":
        return encodePublicKey(value);
      case "bytes":
        return encodeBytes(value);
      default:
        throw new Error(`Unsupported type: ${type}`);
    }
  }

  if (type.vec) {
    const items = value.map((v) => encodeBorshValue(type.vec, v));
    return [...encodeVecLength(value.length), ...items.flat()];
  }

  if (type.option) {
    if (value === null || value === undefined) {
      return [0];
    }
    return [1, ...encodeBorshValue(type.option, value)];
  }

  if (type.array) {
    const [innerType, size] = type.array;
    if (value.length !== size) {
      throw new Error(`Array length mismatch: expected ${size}, got ${value.length}`);
    }
    return value.map((v) => encodeBorshValue(innerType, v)).flat();
  }

  throw new Error(`Unsupported complex type: ${JSON.stringify(type)}`);
}

// Encode a full instruction: discriminator + args
function encodeInstruction(ixName, args, ixDef) {
  const disc = instructionDiscriminator(ixName);
  const argsBytes = [];
  for (const argDef of ixDef.args) {
    if (!(argDef.name in args)) {
      throw new Error(`Missing argument: ${argDef.name}`);
    }
    argsBytes.push(...encodeBorshValue(argDef.type, args[argDef.name]));
  }
  return [...disc, ...argsBytes];
}

// ─── Size computation ────────────────────────────────────────────────────────

function typeSize(type, types) {
  if (typeof type === "string") {
    switch (type) {
      case "bool":
        return 1;
      case "u8":
      case "i8":
        return 1;
      case "u16":
      case "i16":
        return 2;
      case "u32":
      case "i32":
      case "f32":
        return 4;
      case "u64":
      case "i64":
      case "f64":
        return 8;
      case "u128":
      case "i128":
        return 16;
      case "u256":
      case "i256":
        return 32;
      case "pubkey":
      case "publicKey":
        return 32;
      case "bool":
        return 1;
      case "string":
      case "bytes":
        return -1; // Variable length
      default:
        throw new Error(`Unknown type: ${type}`);
    }
  }

  if (type.option) return 1 + typeSize(type.option, types);
  if (type.vec) return -1; // Variable length
  if (type.array) return typeSize(type.array[0], types) * type.array[1];
  if (type.defined) {
    const name = typeof type.defined === "string" ? type.defined : type.defined.name;
    const typeDef = (types || []).find((t) => t.name === name);
    if (!typeDef) throw new Error(`Type not found: ${name}`);
    return structSize(typeDef, types);
  }

  throw new Error(`Unknown complex type: ${JSON.stringify(type)}`);
}

function structSize(typeDef, types) {
  if (typeDef.type.kind !== "struct") return -1;
  let total = 0;
  for (const field of typeDef.type.fields || []) {
    const sz = typeSize(field.type, types);
    if (sz === -1) return -1; // Contains variable-length field
    total += sz;
  }
  return total;
}

// ─── Process each IDL ────────────────────────────────────────────────────────

function processIdl(name, idl) {
  const result = {
    name: idl.name || name,
    version: idl.version || "unknown",
    instructions: {},
    accounts: {},
    events: {},
    encodedInstructions: {},
    accountSizes: {},
  };

  // Instruction discriminators
  for (const ix of idl.instructions || []) {
    result.instructions[ix.name] = {
      discriminator: instructionDiscriminator(ix.name),
      discriminatorHex: Buffer.from(instructionDiscriminator(ix.name)).toString("hex"),
      preimage: instructionPreimage(ix.name),
    };
  }

  // Account discriminators
  for (const acc of idl.accounts || []) {
    const accName = acc.name;
    result.accounts[accName] = {
      discriminator: accountDiscriminator(accName),
      discriminatorHex: Buffer.from(accountDiscriminator(accName)).toString("hex"),
      preimage: `account:${accName}`,
    };
  }

  // Event discriminators (if the IDL has events)
  for (const evt of idl.events || []) {
    const evtName = evt.name;
    result.events[evtName] = {
      discriminator: eventDiscriminator(evtName),
      discriminatorHex: Buffer.from(eventDiscriminator(evtName)).toString("hex"),
      preimage: `event:${evtName}`,
    };
  }

  // Account sizes (discriminator + struct size)
  const types = idl.types || [];
  // Legacy Anchor IDLs store struct definitions inside accounts[].type
  // Combine with types[] for lookup
  const allTypes = [...types];
  for (const acc of idl.accounts || []) {
    if (acc.type) {
      allTypes.push({ name: acc.name, type: acc.type });
    }
  }

  for (const acc of idl.accounts || []) {
    const accName = acc.name;
    try {
      const typeDef = allTypes.find((t) => t.name === accName);
      if (typeDef) {
        const bodySize = structSize(typeDef, allTypes);
        result.accountSizes[accName] = {
          discriminatorSize: 8,
          bodySize: bodySize,
          totalSize: bodySize === -1 ? -1 : 8 + bodySize,
          isVariableLength: bodySize === -1,
        };
      }
    } catch (e) {
      result.accountSizes[accName] = { error: e.message };
    }
  }

  return result;
}

// ─── Encode sample instructions ──────────────────────────────────────────────

function generateEncodedInstructions(idl) {
  const encoded = [];

  const idlName = idl.name;

  // basic_counter: increment(amount: u64)
  if (idlName === "basic_counter") {
    const ix = idl.instructions.find((i) => i.name === "increment");
    if (ix) {
      // Test case: increment with amount=42
      const bytes = encodeInstruction("increment", { amount: 42 }, ix);
      encoded.push({
        instruction: "increment",
        args: { amount: 42 },
        bytes: bytes,
        hex: Buffer.from(bytes).toString("hex"),
      });

      // Test case: increment with amount=0
      const bytes0 = encodeInstruction("increment", { amount: 0 }, ix);
      encoded.push({
        instruction: "increment",
        args: { amount: 0 },
        bytes: bytes0,
        hex: Buffer.from(bytes0).toString("hex"),
      });

      // Test case: increment with amount=MAX_U64
      const bytesMax = encodeInstruction(
        "increment",
        { amount: "18446744073709551615" },
        ix
      );
      encoded.push({
        instruction: "increment",
        args: { amount: "18446744073709551615" },
        bytes: bytesMax,
        hex: Buffer.from(bytesMax).toString("hex"),
      });
    }

    // Test case: initialize (no args)
    const initIx = idl.instructions.find((i) => i.name === "initialize");
    if (initIx) {
      const bytes = encodeInstruction("initialize", {}, initIx);
      encoded.push({
        instruction: "initialize",
        args: {},
        bytes: bytes,
        hex: Buffer.from(bytes).toString("hex"),
      });
    }
  }

  // clever_todo: addTodo(content: string), markTodo(todoIdx: u8)
  if (idlName === "clever_todo") {
    const addTodoIx = idl.instructions.find((i) => i.name === "addTodo");
    if (addTodoIx) {
      const bytes = encodeInstruction(
        "addTodo",
        { content: "Buy groceries" },
        addTodoIx
      );
      encoded.push({
        instruction: "addTodo",
        args: { content: "Buy groceries" },
        bytes: bytes,
        hex: Buffer.from(bytes).toString("hex"),
      });
    }

    const markTodoIx = idl.instructions.find((i) => i.name === "markTodo");
    if (markTodoIx) {
      const bytes = encodeInstruction("markTodo", { todoIdx: 3 }, markTodoIx);
      encoded.push({
        instruction: "markTodo",
        args: { todoIdx: 3 },
        bytes: bytes,
        hex: Buffer.from(bytes).toString("hex"),
      });
    }

    const initIx = idl.instructions.find(
      (i) => i.name === "initializeUser"
    );
    if (initIx) {
      const bytes = encodeInstruction("initializeUser", {}, initIx);
      encoded.push({
        instruction: "initializeUser",
        args: {},
        bytes: bytes,
        hex: Buffer.from(bytes).toString("hex"),
      });
    }
  }

  // flutter_vote: initialize(name, description, options), vote(voteId)
  if (idlName === "flutter_vote") {
    const initIx = idl.instructions.find((i) => i.name === "initialize");
    if (initIx) {
      const bytes = encodeInstruction(
        "initialize",
        {
          name: "Best Language",
          description: "Vote for the best programming language",
          options: ["Dart", "Rust", "TypeScript"],
        },
        initIx
      );
      encoded.push({
        instruction: "initialize",
        args: {
          name: "Best Language",
          description: "Vote for the best programming language",
          options: ["Dart", "Rust", "TypeScript"],
        },
        bytes: bytes,
        hex: Buffer.from(bytes).toString("hex"),
      });
    }

    const voteIx = idl.instructions.find((i) => i.name === "vote");
    if (voteIx) {
      const bytes = encodeInstruction("vote", { voteId: 1 }, voteIx);
      encoded.push({
        instruction: "vote",
        args: { voteId: 1 },
        bytes: bytes,
        hex: Buffer.from(bytes).toString("hex"),
      });
    }
  }

  return encoded;
}

// ─── Main ────────────────────────────────────────────────────────────────────

function main() {
  const idlFiles = [
    { name: "basic_counter", file: "basic_counter_idl.json" },
    { name: "clever_todo", file: "todo_idl.json" },
    { name: "flutter_vote", file: "voting_idl.json" },
  ];

  const references = {
    generatedAt: new Date().toISOString(),
    generator: "coral-xyz-reference-generator",
    description:
      "Reference values computed using the same algorithms as @coral-xyz/anchor TS SDK. " +
      "Discriminators use SHA256 with the documented prefixes.",
    programs: {},
  };

  for (const { name, file } of idlFiles) {
    const idlPath = join(__dirname, file);
    const idl = JSON.parse(readFileSync(idlPath, "utf8"));

    const processed = processIdl(name, idl);
    processed.encodedInstructions = generateEncodedInstructions(idl);

    references.programs[name] = processed;
  }

  // Also add standalone discriminator tests
  references.standaloneDiscriminators = {
    // Test with well-known instruction names
    instructions: {
      initialize: {
        preimage: instructionPreimage("initialize"),
        discriminator: instructionDiscriminator("initialize"),
        hex: Buffer.from(instructionDiscriminator("initialize")).toString("hex"),
      },
      transfer: {
        preimage: instructionPreimage("transfer"),
        discriminator: instructionDiscriminator("transfer"),
        hex: Buffer.from(instructionDiscriminator("transfer")).toString("hex"),
      },
      close: {
        preimage: instructionPreimage("close"),
        discriminator: instructionDiscriminator("close"),
        hex: Buffer.from(instructionDiscriminator("close")).toString("hex"),
      },
      mint: {
        preimage: instructionPreimage("mint"),
        discriminator: instructionDiscriminator("mint"),
        hex: Buffer.from(instructionDiscriminator("mint")).toString("hex"),
      },
      set_authority: {
        preimage: instructionPreimage("set_authority"),
        discriminator: instructionDiscriminator("set_authority"),
        hex: Buffer.from(instructionDiscriminator("set_authority")).toString("hex"),
      },
    },
    accounts: {
      Counter: {
        preimage: "account:Counter",
        discriminator: accountDiscriminator("Counter"),
        hex: Buffer.from(accountDiscriminator("Counter")).toString("hex"),
      },
      TokenAccount: {
        preimage: "account:TokenAccount",
        discriminator: accountDiscriminator("TokenAccount"),
        hex: Buffer.from(accountDiscriminator("TokenAccount")).toString("hex"),
      },
      Mint: {
        preimage: "account:Mint",
        discriminator: accountDiscriminator("Mint"),
        hex: Buffer.from(accountDiscriminator("Mint")).toString("hex"),
      },
      Poll: {
        preimage: "account:Poll",
        discriminator: accountDiscriminator("Poll"),
        hex: Buffer.from(accountDiscriminator("Poll")).toString("hex"),
      },
      UserProfile: {
        preimage: "account:UserProfile",
        discriminator: accountDiscriminator("UserProfile"),
        hex: Buffer.from(accountDiscriminator("UserProfile")).toString("hex"),
      },
    },
    events: {
      TransferEvent: {
        preimage: "event:TransferEvent",
        discriminator: eventDiscriminator("TransferEvent"),
        hex: Buffer.from(eventDiscriminator("TransferEvent")).toString("hex"),
      },
      NewPollEvent: {
        preimage: "event:NewPollEvent",
        discriminator: eventDiscriminator("NewPollEvent"),
        hex: Buffer.from(eventDiscriminator("NewPollEvent")).toString("hex"),
      },
    },
  };

  // Add Borsh encoding reference values for primitive types
  references.borshEncoding = {
    u8: { value: 42, bytes: encodeU8(42), hex: Buffer.from(encodeU8(42)).toString("hex") },
    u16: { value: 1000, bytes: encodeU16(1000), hex: Buffer.from(encodeU16(1000)).toString("hex") },
    u32: { value: 100000, bytes: encodeU32(100000), hex: Buffer.from(encodeU32(100000)).toString("hex") },
    u64: { value: "1000000000000", bytes: encodeU64("1000000000000"), hex: Buffer.from(encodeU64("1000000000000")).toString("hex") },
    i8: { value: -42, bytes: encodeI8(-42), hex: Buffer.from(encodeI8(-42)).toString("hex") },
    i16: { value: -1000, bytes: encodeI16(-1000), hex: Buffer.from(encodeI16(-1000)).toString("hex") },
    i32: { value: -100000, bytes: encodeI32(-100000), hex: Buffer.from(encodeI32(-100000)).toString("hex") },
    i64: { value: "-1000000000000", bytes: encodeI64("-1000000000000"), hex: Buffer.from(encodeI64("-1000000000000")).toString("hex") },
    bool_true: { value: true, bytes: encodeBool(true), hex: Buffer.from(encodeBool(true)).toString("hex") },
    bool_false: { value: false, bytes: encodeBool(false), hex: Buffer.from(encodeBool(false)).toString("hex") },
    string: {
      value: "hello world",
      bytes: encodeString("hello world"),
      hex: Buffer.from(encodeString("hello world")).toString("hex"),
    },
    string_empty: {
      value: "",
      bytes: encodeString(""),
      hex: Buffer.from(encodeString("")).toString("hex"),
    },
    string_unicode: {
      value: "日本語",
      bytes: encodeString("日本語"),
      hex: Buffer.from(encodeString("日本語")).toString("hex"),
    },
  };

  const outputPath = join(__dirname, "references.json");
  writeFileSync(outputPath, JSON.stringify(references, null, 2));
  console.log(`Generated references.json with:`);
  console.log(`  - ${idlFiles.length} programs`);
  for (const [name, prog] of Object.entries(references.programs)) {
    console.log(`    - ${name}: ${Object.keys(prog.instructions).length} instructions, ${Object.keys(prog.accounts).length} accounts`);
  }
  console.log(`  - ${Object.keys(references.standaloneDiscriminators.instructions).length} standalone instruction discriminators`);
  console.log(`  - ${Object.keys(references.standaloneDiscriminators.accounts).length} standalone account discriminators`);
  console.log(`  - ${Object.keys(references.standaloneDiscriminators.events).length} standalone event discriminators`);
  console.log(`  - ${Object.keys(references.borshEncoding).length} Borsh encoding reference values`);
}

main();
