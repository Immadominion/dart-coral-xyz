# Backend/Server Integration Guide

This guide shows how to integrate `coral_xyz` into Dart server applications for backend Solana operations.

## 🖥️ Quick Start

### Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  coral_xyz: ^1.0.0
  shelf: ^1.4.0          # For web server
  shelf_router: ^1.1.4   # For routing
  
dev_dependencies:
  test: ^1.24.0
```

### Basic Server Setup

```dart
// bin/server.dart
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:coral_xyz/coral_xyz_anchor.dart';

void main() async {
  final solanaService = SolanaService();
  await solanaService.initialize();
  
  final app = Router()
    ..get('/health', _healthHandler)
    ..post('/transaction', (Request request) => _transactionHandler(request, solanaService))
    ..get('/account/<address>', (Request request, String address) => 
        _accountHandler(request, address, solanaService));
  
  final handler = Pipeline()
    .addMiddleware(logRequests())
    .addMiddleware(_corsMiddleware)
    .addHandler(app);
  
  final server = await serve(handler, InternetAddress.anyIPv4, 8080);
  print('Server listening on port ${server.port}');
}

Response _healthHandler(Request request) {
  return Response.ok('Server is healthy');
}

Middleware get _corsMiddleware {
  return (Handler handler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: _corsHeaders);
      }
      
      final response = await handler(request);
      return response.change(headers: _corsHeaders);
    };
  };
}

final _corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};
```

## 🏗️ Architecture Patterns

### 1. Service Layer Pattern

```dart
// lib/services/solana_service.dart
import 'package:coral_xyz/coral_xyz_anchor.dart';

class SolanaService {
  late final Connection _connection;
  late final AnchorProvider _provider;
  late final Map<String, Program> _programs;
  
  SolanaService() {
    _programs = {};
  }
  
  Future<void> initialize({
    String rpcUrl = 'https://api.mainnet-beta.solana.com',
  }) async {
    _connection = Connection(rpcUrl);
    
    // For server operations, you might use a service keypair
    final serviceKeypair = await _loadServiceKeypair();
    _provider = AnchorProvider(_connection, serviceKeypair);
  }
  
  Future<Program> getProgram(String programId, Map<String, dynamic> idl) async {
    return _programs.putIfAbsent(programId, () {
      return Program(idl, programId, _provider);
    });
  }
  
  Future<String> submitTransaction(
    String programId,
    Map<String, dynamic> idl,
    String methodName,
    Map<String, dynamic> accounts,
    List<dynamic> args,
  ) async {
    final program = await getProgram(programId, idl);
    
    return await program.methods
      .call(methodName, args)
      .accounts(accounts)
      .rpc();
  }
  
  Future<Map<String, dynamic>> getAccount(
    String programId,
    Map<String, dynamic> idl,
    String accountType,
    String address,
  ) async {
    final program = await getProgram(programId, idl);
    final publicKey = PublicKey.fromBase58(address);
    
    return await program.account[accountType].fetch(publicKey);
  }
  
  Future<List<Map<String, dynamic>>> getAllAccounts(
    String programId,
    Map<String, dynamic> idl,
    String accountType,
  ) async {
    final program = await getProgram(programId, idl);
    return await program.account[accountType].all();
  }
  
  Future<Keypair> _loadServiceKeypair() async {
    // Load service keypair from environment or secure storage
    final secretKeyEnv = Platform.environment['SOLANA_SECRET_KEY'];
    if (secretKeyEnv != null) {
      final secretKey = base64Decode(secretKeyEnv);
      return Keypair.fromSecretKey(secretKey);
    }
    
    // Fallback to file-based key (ensure proper security)
    final keyFile = File('keys/service-keypair.json');
    if (await keyFile.exists()) {
      final keyData = await keyFile.readAsString();
      final keyJson = json.decode(keyData);
      return Keypair.fromSecretKey(List<int>.from(keyJson));
    }
    
    throw Exception('Service keypair not found');
  }
}
```

### 2. Repository Pattern

```dart
// lib/repositories/program_repository.dart
abstract class ProgramRepository {
  Future<Map<String, dynamic>> getAccount(String address);
  Future<List<Map<String, dynamic>>> getAllAccounts();
  Future<String> createAccount(Map<String, dynamic> data);
  Future<String> updateAccount(String address, Map<String, dynamic> data);
}

// lib/repositories/counter_repository.dart
class CounterRepository implements ProgramRepository {
  final Program _program;
  
  CounterRepository(this._program);
  
  @override
  Future<Map<String, dynamic>> getAccount(String address) async {
    final publicKey = PublicKey.fromBase58(address);
    return await _program.account.counter.fetch(publicKey);
  }
  
  @override
  Future<List<Map<String, dynamic>>> getAllAccounts() async {
    return await _program.account.counter.all();
  }
  
  @override
  Future<String> createAccount(Map<String, dynamic> data) async {
    final counterKeypair = Keypair.generate();
    
    return await _program.methods
      .initialize()
      .accounts({
        'counter': counterKeypair.publicKey,
        'user': _program.provider.wallet.publicKey,
        'systemProgram': SystemProgram.programId,
      })
      .signers([counterKeypair])
      .rpc();
  }
  
  @override
  Future<String> updateAccount(String address, Map<String, dynamic> data) async {
    final publicKey = PublicKey.fromBase58(address);
    
    return await _program.methods
      .increment()
      .accounts({
        'counter': publicKey,
      })
      .rpc();
  }
}
```

### 3. API Controller Pattern

```dart
// lib/controllers/transaction_controller.dart
class TransactionController {
  final SolanaService _solanaService;
  
  TransactionController(this._solanaService);
  
  Future<Response> handleTransaction(Request request) async {
    try {
      final payload = await request.readAsString();
      final data = json.decode(payload) as Map<String, dynamic>;
      
      // Validate request
      final validation = _validateTransactionRequest(data);
      if (validation != null) {
        return Response.badRequest(
          body: json.encode({'error': validation}),
          headers: {'Content-Type': 'application/json'},
        );
      }
      
      // Execute transaction
      final signature = await _solanaService.submitTransaction(
        data['programId'],
        data['idl'],
        data['method'],
        data['accounts'],
        data['args'] ?? [],
      );
      
      return Response.ok(
        json.encode({
          'success': true,
          'signature': signature,
          'timestamp': DateTime.now().toIso8601String(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
      
    } catch (e) {
      return Response.internalServerError(
        body: json.encode({
          'error': 'Transaction failed',
          'details': e.toString(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
  
  String? _validateTransactionRequest(Map<String, dynamic> data) {
    if (!data.containsKey('programId')) return 'programId is required';
    if (!data.containsKey('idl')) return 'idl is required';
    if (!data.containsKey('method')) return 'method is required';
    if (!data.containsKey('accounts')) return 'accounts is required';
    
    // Additional validation...
    return null;
  }
}

// lib/controllers/account_controller.dart
class AccountController {
  final SolanaService _solanaService;
  
  AccountController(this._solanaService);
  
  Future<Response> getAccount(Request request, String address) async {
    try {
      // Extract program info from query parameters
      final programId = request.url.queryParameters['programId'];
      final accountType = request.url.queryParameters['type'];
      
      if (programId == null || accountType == null) {
        return Response.badRequest(
          body: json.encode({
            'error': 'programId and type query parameters are required'
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }
      
      // Load IDL (you might want to cache this)
      final idl = await _loadIdl(programId);
      
      final accountData = await _solanaService.getAccount(
        programId,
        idl,
        accountType,
        address,
      );
      
      return Response.ok(
        json.encode({
          'success': true,
          'account': accountData,
          'address': address,
        }),
        headers: {'Content-Type': 'application/json'},
      );
      
    } catch (e) {
      return Response.internalServerError(
        body: json.encode({
          'error': 'Failed to fetch account',
          'details': e.toString(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
  
  Future<Map<String, dynamic>> _loadIdl(String programId) async {
    // Load IDL from file, cache, or remote source
    final idlFile = File('idls/$programId.json');
    if (await idlFile.exists()) {
      final idlContent = await idlFile.readAsString();
      return json.decode(idlContent);
    }
    
    throw Exception('IDL not found for program: $programId');
  }
}
```

## 🔐 Authentication & Authorization

### 1. API Key Authentication

```dart
// lib/middleware/auth_middleware.dart
Middleware apiKeyAuth(String validApiKey) {
  return (Handler handler) {
    return (Request request) async {
      final apiKey = request.headers['X-API-Key'];
      
      if (apiKey != validApiKey) {
        return Response.unauthorized(
          json.encode({'error': 'Invalid API key'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
      
      return await handler(request);
    };
  };
}

// Usage in main()
final protectedRoutes = Router()
  ..post('/transaction', transactionController.handleTransaction);

final publicRoutes = Router()
  ..get('/health', _healthHandler);

final app = Router()
  ..mount('/api/v1/', Pipeline()
    .addMiddleware(apiKeyAuth(Platform.environment['API_KEY']!))
    .addHandler(protectedRoutes))
  ..mount('/', publicRoutes);
```

### 2. JWT Authentication

```dart
// lib/middleware/jwt_middleware.dart
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

Middleware jwtAuth(String secretKey) {
  return (Handler handler) {
    return (Request request) async {
      final authHeader = request.headers['Authorization'];
      
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return Response.unauthorized(
          json.encode({'error': 'Missing or invalid authorization header'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
      
      final token = authHeader.substring(7); // Remove 'Bearer '
      
      try {
        final jwt = JWT.verify(token, SecretKey(secretKey));
        
        // Add user info to request context
        final modifiedRequest = request.change(context: {
          'user': jwt.payload,
        });
        
        return await handler(modifiedRequest);
        
      } catch (e) {
        return Response.unauthorized(
          json.encode({'error': 'Invalid token'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    };
  };
}
```

### 3. Wallet Signature Verification

```dart
// lib/auth/wallet_auth.dart
class WalletAuth {
  static Future<bool> verifySignature(
    String message,
    String signature,
    String publicKey,
  ) async {
    try {
      final messageBytes = utf8.encode(message);
      final signatureBytes = base58.decode(signature);
      final pubKey = PublicKey.fromBase58(publicKey);
      
      return await Ed25519.verify(
        messageBytes,
        signatureBytes,
        pubKey.toBytes(),
      );
    } catch (e) {
      return false;
    }
  }
  
  static String generateNonce() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base58.encode(bytes);
  }
}

// Usage in authentication endpoint
Future<Response> authenticateWallet(Request request) async {
  final payload = await request.readAsString();
  final data = json.decode(payload) as Map<String, dynamic>;
  
  final isValid = await WalletAuth.verifySignature(
    data['message'],
    data['signature'],
    data['publicKey'],
  );
  
  if (isValid) {
    final token = JWT({
      'publicKey': data['publicKey'],
      'exp': DateTime.now().add(Duration(hours: 24)).millisecondsSinceEpoch,
    }).sign(SecretKey(Platform.environment['JWT_SECRET']!));
    
    return Response.ok(json.encode({'token': token}));
  }
  
  return Response.unauthorized(json.encode({'error': 'Invalid signature'}));
}
```

## 📊 Monitoring & Logging

### 1. Structured Logging

```dart
// lib/utils/logger.dart
import 'package:logging/logging.dart';

class AppLogger {
  static final Logger _logger = Logger('SolanaServer');
  
  static void setup() {
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      final timestamp = record.time.toIso8601String();
      final level = record.level.name;
      final message = record.message;
      final error = record.error?.toString() ?? '';
      
      final logEntry = {
        'timestamp': timestamp,
        'level': level,
        'message': message,
        'error': error,
        'logger': record.loggerName,
      };
      
      print(json.encode(logEntry));
    });
  }
  
  static void info(String message, [Map<String, dynamic>? extra]) {
    _logger.info('$message ${extra != null ? json.encode(extra) : ''}');
  }
  
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.severe(message, error, stackTrace);
  }
  
  static void transaction(String signature, String method, Duration duration) {
    info('Transaction completed', {
      'signature': signature,
      'method': method,
      'duration_ms': duration.inMilliseconds,
    });
  }
}
```

### 2. Metrics Collection

```dart
// lib/utils/metrics.dart
class Metrics {
  static final Map<String, int> _counters = {};
  static final Map<String, List<Duration>> _timings = {};
  
  static void incrementCounter(String name) {
    _counters[name] = (_counters[name] ?? 0) + 1;
  }
  
  static void recordTiming(String name, Duration duration) {
    _timings.putIfAbsent(name, () => []).add(duration);
  }
  
  static Future<T> timeOperation<T>(String name, Future<T> Function() operation) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final result = await operation();
      incrementCounter('${name}_success');
      return result;
    } catch (e) {
      incrementCounter('${name}_error');
      rethrow;
    } finally {
      stopwatch.stop();
      recordTiming(name, stopwatch.elapsed);
    }
  }
  
  static Map<String, dynamic> getMetrics() {
    final averages = <String, double>{};
    
    _timings.forEach((name, timings) {
      if (timings.isNotEmpty) {
        final total = timings.fold<int>(0, (sum, duration) => sum + duration.inMilliseconds);
        averages['${name}_avg_ms'] = total / timings.length;
      }
    });
    
    return {
      'counters': _counters,
      'averages': averages,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}

// Metrics endpoint
Response metricsHandler(Request request) {
  return Response.ok(
    json.encode(Metrics.getMetrics()),
    headers: {'Content-Type': 'application/json'},
  );
}
```

## 🔄 Background Processing

### 1. Transaction Monitoring

```dart
// lib/services/transaction_monitor.dart
class TransactionMonitor {
  final SolanaService _solanaService;
  final Duration _pollInterval;
  Timer? _timer;
  
  TransactionMonitor(this._solanaService, {
    Duration pollInterval = const Duration(seconds: 30),
  }) : _pollInterval = pollInterval;
  
  void start() {
    _timer = Timer.periodic(_pollInterval, (_) => _checkPendingTransactions());
    AppLogger.info('Transaction monitor started');
  }
  
  void stop() {
    _timer?.cancel();
    AppLogger.info('Transaction monitor stopped');
  }
  
  Future<void> _checkPendingTransactions() async {
    try {
      final pendingTxs = await _getPendingTransactions();
      
      for (final tx in pendingTxs) {
        final status = await _solanaService._connection.getTransactionStatus(tx.signature);
        
        if (status.isConfirmed) {
          await _updateTransactionStatus(tx.id, 'confirmed');
          AppLogger.info('Transaction confirmed', {'signature': tx.signature});
        } else if (status.isExpired) {
          await _updateTransactionStatus(tx.id, 'expired');
          AppLogger.error('Transaction expired', tx.signature);
        }
      }
    } catch (e) {
      AppLogger.error('Error checking pending transactions', e);
    }
  }
  
  Future<List<PendingTransaction>> _getPendingTransactions() async {
    // Fetch from database or cache
    return [];
  }
  
  Future<void> _updateTransactionStatus(String id, String status) async {
    // Update database
  }
}

class PendingTransaction {
  final String id;
  final String signature;
  final DateTime createdAt;
  
  PendingTransaction({
    required this.id,
    required this.signature,
    required this.createdAt,
  });
}
```

### 2. Event Listening

```dart
// lib/services/event_listener.dart
class EventListener {
  final Program _program;
  StreamSubscription? _subscription;
  
  EventListener(this._program);
  
  void startListening() {
    _subscription = _program.addEventListener('EventName', (event, slot) {
      _handleEvent(event, slot);
    });
    
    AppLogger.info('Event listener started for program ${_program.programId}');
  }
  
  void stopListening() {
    _subscription?.cancel();
    AppLogger.info('Event listener stopped');
  }
  
  void _handleEvent(Map<String, dynamic> event, int slot) {
    try {
      AppLogger.info('Event received', {
        'event': event,
        'slot': slot,
        'program': _program.programId.toString(),
      });
      
      // Process event data
      _processEvent(event);
      
    } catch (e) {
      AppLogger.error('Error processing event', e);
    }
  }
  
  Future<void> _processEvent(Map<String, dynamic> event) async {
    // Store in database, trigger webhooks, etc.
  }
}
```

## 🗄️ Database Integration

### 1. Transaction Storage

```dart
// lib/models/transaction_record.dart
class TransactionRecord {
  final String id;
  final String signature;
  final String programId;
  final String method;
  final Map<String, dynamic> accounts;
  final List<dynamic> args;
  final String status;
  final DateTime createdAt;
  final DateTime? confirmedAt;
  
  TransactionRecord({
    required this.id,
    required this.signature,
    required this.programId,
    required this.method,
    required this.accounts,
    required this.args,
    required this.status,
    required this.createdAt,
    this.confirmedAt,
  });
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'signature': signature,
    'program_id': programId,
    'method': method,
    'accounts': accounts,
    'args': args,
    'status': status,
    'created_at': createdAt.toIso8601String(),
    'confirmed_at': confirmedAt?.toIso8601String(),
  };
  
  factory TransactionRecord.fromJson(Map<String, dynamic> json) {
    return TransactionRecord(
      id: json['id'],
      signature: json['signature'],
      programId: json['program_id'],
      method: json['method'],
      accounts: json['accounts'],
      args: json['args'],
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      confirmedAt: json['confirmed_at'] != null 
        ? DateTime.parse(json['confirmed_at']) 
        : null,
    );
  }
}
```

### 2. Cache Management

```dart
// lib/services/cache_service.dart
class CacheService {
  static final Map<String, CacheEntry> _cache = {};
  
  static void set(String key, dynamic value, {Duration? ttl}) {
    final expiry = ttl != null ? DateTime.now().add(ttl) : null;
    _cache[key] = CacheEntry(value, expiry);
  }
  
  static T? get<T>(String key) {
    final entry = _cache[key];
    
    if (entry == null) return null;
    
    if (entry.expiry != null && DateTime.now().isAfter(entry.expiry!)) {
      _cache.remove(key);
      return null;
    }
    
    return entry.value as T?;
  }
  
  static void remove(String key) {
    _cache.remove(key);
  }
  
  static void clear() {
    _cache.clear();
  }
  
  // Cache IDLs with 1 hour TTL
  static Future<Map<String, dynamic>> getIdl(String programId) async {
    final cacheKey = 'idl:$programId';
    final cached = get<Map<String, dynamic>>(cacheKey);
    
    if (cached != null) return cached;
    
    // Load IDL from file or remote source
    final idl = await _loadIdlFromFile(programId);
    set(cacheKey, idl, ttl: Duration(hours: 1));
    
    return idl;
  }
  
  static Future<Map<String, dynamic>> _loadIdlFromFile(String programId) async {
    final file = File('idls/$programId.json');
    final content = await file.readAsString();
    return json.decode(content);
  }
}

class CacheEntry {
  final dynamic value;
  final DateTime? expiry;
  
  CacheEntry(this.value, this.expiry);
}
```

## 🧪 Testing

### 1. Unit Testing

```dart
// test/services/solana_service_test.dart
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';

class MockConnection extends Mock implements Connection {}
class MockAnchorProvider extends Mock implements AnchorProvider {}

void main() {
  group('SolanaService', () {
    late SolanaService service;
    late MockConnection mockConnection;
    
    setUp(() {
      mockConnection = MockConnection();
      service = SolanaService();
    });
    
    test('should initialize correctly', () async {
      await service.initialize(rpcUrl: 'https://api.devnet.solana.com');
      expect(service.isInitialized, isTrue);
    });
    
    test('should submit transaction', () async {
      // Mock transaction submission
      when(mockConnection.sendTransaction(any))
        .thenAnswer((_) async => 'mock-signature');
      
      final signature = await service.submitTransaction(
        'program-id',
        {'name': 'test'},
        'initialize',
        {},
        [],
      );
      
      expect(signature, isNotEmpty);
    });
  });
}
```

### 2. Integration Testing

```dart
// test/integration/api_test.dart
import 'package:test/test.dart';
import 'package:http/http.dart' as http;

void main() {
  group('API Integration Tests', () {
    const baseUrl = 'http://localhost:8080';
    
    test('health endpoint should return OK', () async {
      final response = await http.get(Uri.parse('$baseUrl/health'));
      expect(response.statusCode, 200);
      expect(response.body, 'Server is healthy');
    });
    
    test('transaction endpoint should require API key', () async {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/transaction'),
        body: json.encode({'test': 'data'}),
      );
      
      expect(response.statusCode, 401);
    });
  });
}
```

## 🚀 Deployment

### 1. Docker Configuration

```dockerfile
# Dockerfile
FROM dart:stable AS build

WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

COPY . .
RUN dart compile exe bin/server.dart -o bin/server

FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/bin/server /app/bin/

EXPOSE 8080
ENTRYPOINT ["/app/bin/server"]
```

### 2. Environment Configuration

```yaml
# docker-compose.yml
version: '3.8'
services:
  solana-server:
    build: .
    ports:
      - "8080:8080"
    environment:
      - SOLANA_SECRET_KEY=${SOLANA_SECRET_KEY}
      - API_KEY=${API_KEY}
      - JWT_SECRET=${JWT_SECRET}
      - RPC_URL=${RPC_URL}
    volumes:
      - ./idls:/app/idls:ro
      - ./keys:/app/keys:ro
```

---

**Need Help?** Join our [GitHub Discussions](https://github.com/Immadominion/dart-coral-xyz/discussions) for server-side development questions and support!
