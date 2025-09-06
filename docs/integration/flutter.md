# Flutter Integration Guide

This guide shows how to integrate `coral_xyz` into Flutter applications for mobile and web Solana dApps.

## 📱 Quick Start

### Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  coral_xyz: ^1.0.0
  flutter:
    sdk: flutter
```

### Basic Setup

```dart
import 'package:flutter/material.dart';
import 'package:coral_xyz/coral_xyz_anchor.dart';

class SolanaService {
  late final AnchorProvider _provider;
  late final Program _program;
  
  Future<void> initialize() async {
    // Initialize connection
    final connection = Connection('https://api.devnet.solana.com');
    
    // Set up wallet (for demo - use proper wallet in production)
    final wallet = Keypair.generate();
    
    // Create provider
    _provider = AnchorProvider(connection, wallet);
    
    // Load your program
    _program = Program(idl, programId, _provider);
  }
  
  Future<void> callProgram() async {
    await _program.methods
      .initialize()
      .accounts({'counter': counterKeypair.publicKey})
      .rpc();
  }
}
```

## 🏗️ Architecture Patterns

### 1. Service Layer Pattern

```dart
// lib/services/solana_service.dart
class SolanaService {
  static final SolanaService _instance = SolanaService._internal();
  factory SolanaService() => _instance;
  SolanaService._internal();

  AnchorProvider? _provider;
  Program? _program;

  bool get isInitialized => _provider != null && _program != null;

  Future<void> initialize({
    required String rpcUrl,
    required Keypair wallet,
    required Map<String, dynamic> idl,
    required String programId,
  }) async {
    final connection = Connection(rpcUrl);
    _provider = AnchorProvider(connection, wallet);
    _program = Program(idl, programId, _provider!);
  }

  Future<T> callMethod<T>(
    String methodName,
    Map<String, dynamic>? accounts,
    List<dynamic>? args,
  ) async {
    if (!isInitialized) throw StateError('SolanaService not initialized');
    
    var methodBuilder = _program!.methods.call(methodName, args ?? []);
    
    if (accounts != null) {
      methodBuilder = methodBuilder.accounts(accounts);
    }
    
    return await methodBuilder.rpc();
  }
}
```

### 2. Provider Pattern with ChangeNotifier

```dart
// lib/providers/solana_provider.dart
import 'package:flutter/foundation.dart';
import 'package:coral_xyz/coral_xyz_anchor.dart';

class SolanaProvider extends ChangeNotifier {
  Connection? _connection;
  AnchorProvider? _provider;
  Program? _program;
  
  bool _isConnected = false;
  String? _error;

  // Getters
  bool get isConnected => _isConnected;
  String? get error => _error;
  Program? get program => _program;

  Future<void> connect({
    required String rpcUrl,
    required Keypair wallet,
    required Map<String, dynamic> idl,
    required String programId,
  }) async {
    try {
      _error = null;
      notifyListeners();

      _connection = Connection(rpcUrl);
      _provider = AnchorProvider(_connection!, wallet);
      _program = Program(idl, programId, _provider!);
      
      _isConnected = true;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isConnected = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    _connection = null;
    _provider = null;
    _program = null;
    _isConnected = false;
    notifyListeners();
  }

  Future<T> executeTransaction<T>(
    Future<T> Function(Program program) transaction,
  ) async {
    if (!_isConnected || _program == null) {
      throw StateError('Not connected to Solana');
    }

    try {
      _error = null;
      notifyListeners();
      
      final result = await transaction(_program!);
      return result;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }
}
```

### 3. Using Provider in Widgets

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SolanaProvider()),
      ],
      child: MyApp(),
    ),
  );
}

// lib/screens/home_screen.dart
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Solana dApp')),
      body: Consumer<SolanaProvider>(
        builder: (context, solana, child) {
          if (!solana.isConnected) {
            return ConnectWalletWidget();
          }
          
          return Column(
            children: [
              if (solana.error != null)
                ErrorBanner(error: solana.error!),
              ProgramInteractionWidget(),
            ],
          );
        },
      ),
    );
  }
}
```

## 📱 Mobile-Specific Considerations

### 1. Wallet Integration

```dart
// For mobile wallet integration
import 'package:solana_mobile_client/solana_mobile_client.dart';

class MobileWalletService {
  static Future<Keypair?> connectMobileWallet() async {
    try {
      // Use Solana Mobile Stack for wallet connection
      final client = SolanaMobileClient();
      final result = await client.authorize();
      
      if (result.authToken != null) {
        return Keypair.fromSecretKey(result.secretKey);
      }
    } catch (e) {
      debugPrint('Mobile wallet connection failed: $e');
    }
    return null;
  }
}
```

### 2. Network Management

```dart
class NetworkManager {
  static const Map<String, String> networks = {
    'mainnet': 'https://api.mainnet-beta.solana.com',
    'devnet': 'https://api.devnet.solana.com',
    'testnet': 'https://api.testnet.solana.com',
  };

  static String getCurrentNetwork() {
    // Use appropriate network based on build mode
    if (kDebugMode) return networks['devnet']!;
    if (kProfileMode) return networks['testnet']!;
    return networks['mainnet']!;
  }
}
```

## 🌐 Web-Specific Considerations

### 1. Web Wallet Integration

```dart
// For web wallet integration (Phantom, Solflare, etc.)
import 'dart:html' as html;
import 'dart:js' as js;

class WebWalletService {
  static Future<Keypair?> connectPhantomWallet() async {
    if (html.window.navigator.userAgent.contains('Chrome')) {
      try {
        // Check if Phantom is installed
        final phantom = js.context['phantom'];
        if (phantom != null) {
          // Connect to Phantom wallet
          final response = await phantom.callMethod('connect');
          // Convert response to Keypair
          return Keypair.fromSecretKey(response['secretKey']);
        }
      } catch (e) {
        debugPrint('Phantom wallet connection failed: $e');
      }
    }
    return null;
  }
}
```

### 2. CORS Considerations

```dart
// Configure connection for web
class WebConnection {
  static Connection createWebConnection(String rpcUrl) {
    return Connection(
      rpcUrl,
      httpClient: HttpClient()
        ..connectionTimeout = Duration(seconds: 30)
        ..idleTimeout = Duration(seconds: 30),
    );
  }
}
```

## 🎨 UI Components

### 1. Connection Status Widget

```dart
class ConnectionStatusWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<SolanaProvider>(
      builder: (context, solana, child) {
        return Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: solana.isConnected ? Colors.green : Colors.red,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                solana.isConnected ? Icons.wifi : Icons.wifi_off,
                color: Colors.white,
                size: 16,
              ),
              SizedBox(width: 4),
              Text(
                solana.isConnected ? 'Connected' : 'Disconnected',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

### 2. Transaction Button

```dart
class TransactionButton extends StatefulWidget {
  final String label;
  final Future<void> Function() onPressed;

  const TransactionButton({
    Key? key,
    required this.label,
    required this.onPressed,
  }) : super(key: key);

  @override
  _TransactionButtonState createState() => _TransactionButtonState();
}

class _TransactionButtonState extends State<TransactionButton> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _isLoading ? null : _handlePress,
      child: _isLoading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(widget.label),
    );
  }

  Future<void> _handlePress() async {
    setState(() => _isLoading = true);
    
    try {
      await widget.onPressed();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Transaction successful!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Transaction failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
```

## 🔒 Security Best Practices

### 1. Secure Key Storage

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureWalletStorage {
  static const _storage = FlutterSecureStorage();
  static const _keyPrefix = 'coral_xyz_wallet_';

  static Future<void> storeWallet(String name, List<int> secretKey) async {
    await _storage.write(
      key: '$_keyPrefix$name',
      value: base64Encode(secretKey),
    );
  }

  static Future<Keypair?> loadWallet(String name) async {
    final encoded = await _storage.read(key: '$_keyPrefix$name');
    if (encoded != null) {
      final secretKey = base64Decode(encoded);
      return Keypair.fromSecretKey(secretKey);
    }
    return null;
  }

  static Future<void> deleteWallet(String name) async {
    await _storage.delete(key: '$_keyPrefix$name');
  }
}
```

### 2. Network Security

```dart
class SecureConnection {
  static Connection createSecureConnection(String rpcUrl) {
    return Connection(
      rpcUrl,
      httpClient: HttpClient()
        ..badCertificateCallback = (cert, host, port) => false // Reject bad certs
        ..connectionTimeout = Duration(seconds: 30),
    );
  }
}
```

## 📊 Performance Optimization

### 1. Connection Pooling

```dart
class ConnectionPool {
  static final Map<String, Connection> _connections = {};

  static Connection getConnection(String rpcUrl) {
    return _connections.putIfAbsent(
      rpcUrl,
      () => Connection(rpcUrl),
    );
  }

  static void dispose() {
    _connections.clear();
  }
}
```

### 2. Caching Strategies

```dart
class ProgramCache {
  static final Map<String, Program> _programs = {};

  static Program getProgram(
    String programId,
    Map<String, dynamic> idl,
    AnchorProvider provider,
  ) {
    final key = '$programId-${provider.hashCode}';
    return _programs.putIfAbsent(
      key,
      () => Program(idl, programId, provider),
    );
  }
}
```

## 🧪 Testing

### 1. Widget Testing

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

class MockSolanaProvider extends Mock implements SolanaProvider {}

void main() {
  group('SolanaWidget Tests', () {
    testWidgets('should show loading when connecting', (tester) async {
      final mockProvider = MockSolanaProvider();
      when(mockProvider.isConnected).thenReturn(false);
      
      await tester.pumpWidget(
        ChangeNotifierProvider<SolanaProvider>.value(
          value: mockProvider,
          child: MaterialApp(home: SolanaWidget()),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
```

### 2. Integration Testing

```dart
import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Solana Integration Tests', () {
    testWidgets('full transaction flow', (tester) async {
      // Test complete user flow
      await tester.pumpWidget(MyApp());
      
      // Connect wallet
      await tester.tap(find.text('Connect Wallet'));
      await tester.pumpAndSettle();
      
      // Execute transaction
      await tester.tap(find.text('Send Transaction'));
      await tester.pumpAndSettle();
      
      // Verify success
      expect(find.text('Transaction Successful'), findsOneWidget);
    });
  });
}
```

## 📚 Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Solana Mobile Stack](https://solanamobile.com/developers)
- [coral_xyz API Reference](https://pub.dev/documentation/coral_xyz)
- [Anchor Framework Guide](https://coral-xyz.github.io/anchor/)

## 🤝 Community Examples

Check out these community-created Flutter + coral_xyz examples:

- **DeFi Portfolio Tracker** - Track Solana DeFi positions
- **NFT Marketplace** - Buy and sell NFTs on Solana
- **Governance Voting** - Participate in DAO governance
- **Token Swap Interface** - Swap SPL tokens

---

**Need Help?** Join our [GitHub Discussions](https://github.com/coral-xyz/dart-coral-xyz/discussions) or check out the [Flutter Community](https://flutter.dev/community) for additional support!
