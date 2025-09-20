# Web Integration Guide

This guide shows how to integrate `coral_xyz` into Dart web applications for browser-based Solana dApps.

## 🌐 Quick Start

### Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  coral_xyz: ^1.0.0
  
# For web-specific dependencies
dev_dependencies:
  build_web_compilers: ^4.0.0
```

### Basic HTML Setup

```html
<!-- web/index.html -->
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>My Solana dApp</title>
  <script defer src="main.dart.js"></script>
</head>
<body>
  <div id="app"></div>
  
  <!-- Wallet adapter scripts -->
  <script src="https://unpkg.com/@solana/wallet-adapter-wallets/lib/index.iife.js"></script>
</body>
</html>
```

### Basic Dart Web App

```dart
// web/main.dart
import 'dart:html';
import 'package:coral_xyz/coral_xyz_anchor.dart';

void main() {
  final app = querySelector('#app')!;
  
  app.children.add(DivElement()
    ..text = 'Solana dApp'
    ..onClick.listen((_) => connectWallet()));
}

Future<void> connectWallet() async {
  final connection = Connection('https://api.devnet.solana.com');
  
  // For demo - in production use proper wallet
  final wallet = Keypair.generate();
  final provider = AnchorProvider(connection, wallet);
  
  print('Connected to Solana!');
}
```

## 🏗️ Architecture Patterns

### 1. Single Page Application (SPA) Pattern

```dart
// lib/app.dart
import 'dart:html';
import 'package:coral_xyz/coral_xyz_anchor.dart';

class SolanaApp {
  late final Element _container;
  late final SolanaService _solanaService;
  
  SolanaApp(this._container) {
    _solanaService = SolanaService();
    _initialize();
  }
  
  void _initialize() {
    _renderConnectButton();
  }
  
  void _renderConnectButton() {
    _container.children.clear();
    
    final button = ButtonElement()
      ..text = 'Connect Wallet'
      ..onClick.listen((_) => _connectWallet());
    
    _container.children.add(button);
  }
  
  Future<void> _connectWallet() async {
    try {
      await _solanaService.connect();
      _renderDApp();
    } catch (e) {
      _showError(e.toString());
    }
  }
  
  void _renderDApp() {
    _container.children.clear();
    
    final content = DivElement()
      ..children.addAll([
        HeadingElement.h2()..text = 'Solana dApp',
        _createTransactionButton(),
        _createStatusDisplay(),
      ]);
    
    _container.children.add(content);
  }
  
  Element _createTransactionButton() {
    return ButtonElement()
      ..text = 'Send Transaction'
      ..onClick.listen((_) => _sendTransaction());
  }
  
  Element _createStatusDisplay() {
    return DivElement()
      ..id = 'status'
      ..text = 'Ready to transact';
  }
  
  Future<void> _sendTransaction() async {
    final status = querySelector('#status')!;
    status.text = 'Sending transaction...';
    
    try {
      await _solanaService.executeTransaction();
      status.text = 'Transaction successful!';
    } catch (e) {
      status.text = 'Transaction failed: $e';
    }
  }
  
  void _showError(String message) {
    final error = DivElement()
      ..text = 'Error: $message'
      ..style.color = 'red';
    
    _container.children.add(error);
  }
}

// Initialize app
void main() {
  final container = querySelector('#app')!;
  SolanaApp(container);
}
```

### 2. Component-Based Architecture

```dart
// lib/components/base_component.dart
abstract class Component {
  Element render();
  void destroy() {}
}

// lib/components/wallet_connector.dart
class WalletConnector extends Component {
  final Function(Keypair) onConnect;
  final Function(String) onError;
  
  WalletConnector({
    required this.onConnect,
    required this.onError,
  });
  
  @override
  Element render() {
    final container = DivElement()..className = 'wallet-connector';
    
    // Phantom Wallet button
    final phantomBtn = ButtonElement()
      ..text = 'Connect Phantom'
      ..className = 'wallet-btn phantom-btn'
      ..onClick.listen((_) => _connectPhantom());
    
    // Solflare Wallet button
    final solflareBtn = ButtonElement()
      ..text = 'Connect Solflare'
      ..className = 'wallet-btn solflare-btn'
      ..onClick.listen((_) => _connectSolflare());
    
    container.children.addAll([phantomBtn, solflareBtn]);
    return container;
  }
  
  Future<void> _connectPhantom() async {
    try {
      final wallet = await PhantomWallet.connect();
      if (wallet != null) {
        onConnect(wallet);
      } else {
        onError('Failed to connect to Phantom wallet');
      }
    } catch (e) {
      onError('Phantom connection error: $e');
    }
  }
  
  Future<void> _connectSolflare() async {
    try {
      final wallet = await SolflareWallet.connect();
      if (wallet != null) {
        onConnect(wallet);
      } else {
        onError('Failed to connect to Solflare wallet');
      }
    } catch (e) {
      onError('Solflare connection error: $e');
    }
  }
}

// lib/components/program_interface.dart
class ProgramInterface extends Component {
  final Program program;
  Element? _container;
  
  ProgramInterface(this.program);
  
  @override
  Element render() {
    _container = DivElement()..className = 'program-interface';
    
    final title = HeadingElement.h3()
      ..text = 'Program Interface'
      ..className = 'interface-title';
    
    final methodsContainer = DivElement()..className = 'methods-container';
    
    // Dynamically generate method buttons based on IDL
    for (final method in program.idl.instructions) {
      final button = _createMethodButton(method);
      methodsContainer.children.add(button);
    }
    
    _container!.children.addAll([title, methodsContainer]);
    return _container!;
  }
  
  Element _createMethodButton(dynamic method) {
    final button = ButtonElement()
      ..text = method.name
      ..className = 'method-btn'
      ..onClick.listen((_) => _callMethod(method.name));
    
    return button;
  }
  
  Future<void> _callMethod(String methodName) async {
    try {
      final result = await program.methods
        .call(methodName)
        .rpc();
      
      _showResult('$methodName called successfully: $result');
    } catch (e) {
      _showError('$methodName failed: $e');
    }
  }
  
  void _showResult(String message) {
    final result = DivElement()
      ..text = message
      ..className = 'result success';
    
    _container!.children.add(result);
    
    // Auto-remove after 5 seconds
    Timer(Duration(seconds: 5), () => result.remove());
  }
  
  void _showError(String message) {
    final error = DivElement()
      ..text = message
      ..className = 'result error';
    
    _container!.children.add(error);
    
    // Auto-remove after 5 seconds
    Timer(Duration(seconds: 5), () => error.remove());
  }
}
```

## 🔗 Wallet Integration

### 1. Phantom Wallet Integration

```dart
// lib/wallets/phantom_wallet.dart
import 'dart:js' as js;
import 'dart:js_util' as js_util;

class PhantomWallet {
  static bool get isInstalled {
    try {
      return js.context.hasProperty('phantom') && 
             js.context['phantom'].hasProperty('solana');
    } catch (e) {
      return false;
    }
  }
  
  static Future<Keypair?> connect() async {
    if (!isInstalled) {
      throw Exception('Phantom wallet not installed');
    }
    
    try {
      final phantom = js.context['phantom']['solana'];
      
      // Request connection
      final response = await js_util.promiseToFuture(
        phantom.callMethod('connect')
      );
      
      // Extract public key
      final publicKeyArray = response['publicKey']['_bn']['words'];
      final publicKey = _convertToPublicKey(publicKeyArray);
      
      return PhantomKeypair(publicKey, phantom);
    } catch (e) {
      throw Exception('Failed to connect to Phantom: $e');
    }
  }
  
  static PublicKey _convertToPublicKey(List<int> words) {
    // Convert JavaScript BigNumber words to Dart PublicKey
    final bytes = <int>[];
    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      bytes.addAll([
        (word >> 0) & 0xFF,
        (word >> 8) & 0xFF,
        (word >> 16) & 0xFF,
        (word >> 24) & 0xFF,
      ]);
    }
    return PublicKey.fromBytes(bytes.take(32).toList());
  }
}

// Custom Keypair for Phantom wallet
class PhantomKeypair extends Keypair {
  final js.JsObject _phantom;
  
  PhantomKeypair(PublicKey publicKey, this._phantom) 
    : super.fromPublicKey(publicKey);
  
  @override
  Future<List<int>> sign(List<int> message) async {
    final response = await js_util.promiseToFuture(
      _phantom.callMethod('signMessage', [message])
    );
    
    return List<int>.from(response['signature']);
  }
}
```

### 2. Solflare Wallet Integration

```dart
// lib/wallets/solflare_wallet.dart
class SolflareWallet {
  static bool get isInstalled {
    try {
      return js.context.hasProperty('solflare');
    } catch (e) {
      return false;
    }
  }
  
  static Future<Keypair?> connect() async {
    if (!isInstalled) {
      throw Exception('Solflare wallet not installed');
    }
    
    try {
      final solflare = js.context['solflare'];
      
      final response = await js_util.promiseToFuture(
        solflare.callMethod('connect')
      );
      
      final publicKeyBytes = List<int>.from(response['publicKey']);
      final publicKey = PublicKey.fromBytes(publicKeyBytes);
      
      return SolflareKeypair(publicKey, solflare);
    } catch (e) {
      throw Exception('Failed to connect to Solflare: $e');
    }
  }
}
```

### 3. Universal Wallet Adapter

```dart
// lib/wallets/wallet_adapter.dart
enum WalletType { phantom, solflare, sollet }

class WalletAdapter {
  static final Map<WalletType, String> _walletNames = {
    WalletType.phantom: 'Phantom',
    WalletType.solflare: 'Solflare',
    WalletType.sollet: 'Sollet',
  };
  
  static List<WalletType> getAvailableWallets() {
    final available = <WalletType>[];
    
    if (PhantomWallet.isInstalled) available.add(WalletType.phantom);
    if (SolflareWallet.isInstalled) available.add(WalletType.solflare);
    // Add more wallet checks...
    
    return available;
  }
  
  static Future<Keypair?> connect(WalletType walletType) async {
    switch (walletType) {
      case WalletType.phantom:
        return await PhantomWallet.connect();
      case WalletType.solflare:
        return await SolflareWallet.connect();
      default:
        throw UnsupportedError('Wallet type not supported: $walletType');
    }
  }
  
  static String getWalletName(WalletType walletType) {
    return _walletNames[walletType] ?? 'Unknown';
  }
  
  static String getInstallUrl(WalletType walletType) {
    switch (walletType) {
      case WalletType.phantom:
        return 'https://phantom.app/';
      case WalletType.solflare:
        return 'https://solflare.com/';
      default:
        return '';
    }
  }
}
```

## 🎨 UI Styling

### 1. CSS Styles

```css
/* web/styles.css */
.wallet-connector {
  display: flex;
  flex-direction: column;
  gap: 16px;
  max-width: 400px;
  margin: 0 auto;
  padding: 24px;
}

.wallet-btn {
  padding: 12px 24px;
  border: none;
  border-radius: 8px;
  font-size: 16px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s ease;
}

.phantom-btn {
  background: linear-gradient(135deg, #AB9FF2, #7057FF);
  color: white;
}

.phantom-btn:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(112, 87, 255, 0.3);
}

.solflare-btn {
  background: linear-gradient(135deg, #FFD700, #FFA500);
  color: white;
}

.program-interface {
  max-width: 600px;
  margin: 0 auto;
  padding: 24px;
}

.methods-container {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 16px;
  margin-top: 16px;
}

.method-btn {
  padding: 16px;
  border: 2px solid #e0e0e0;
  border-radius: 8px;
  background: white;
  cursor: pointer;
  transition: all 0.2s ease;
}

.method-btn:hover {
  border-color: #7057FF;
  transform: translateY(-1px);
}

.result {
  margin: 8px 0;
  padding: 12px;
  border-radius: 4px;
  font-weight: 500;
}

.result.success {
  background: #d4edda;
  color: #155724;
  border: 1px solid #c3e6cb;
}

.result.error {
  background: #f8d7da;
  color: #721c24;
  border: 1px solid #f5c6cb;
}

/* Loading animations */
.loading {
  display: inline-block;
  width: 20px;
  height: 20px;
  border: 3px solid #f3f3f3;
  border-top: 3px solid #3498db;
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}
```

### 2. Dynamic Styling in Dart

```dart
// lib/utils/styling.dart
class StyleUtils {
  static void applyCssClass(Element element, String className) {
    element.classes.add(className);
  }
  
  static void removeCssClass(Element element, String className) {
    element.classes.remove(className);
  }
  
  static void setLoadingState(ButtonElement button, bool loading) {
    if (loading) {
      button.disabled = true;
      button.text = '';
      
      final spinner = SpanElement()
        ..className = 'loading';
      
      button.children.clear();
      button.children.add(spinner);
    } else {
      button.disabled = false;
      button.children.clear();
    }
  }
  
  static void showToast(String message, {bool isError = false}) {
    final toast = DivElement()
      ..text = message
      ..className = isError ? 'toast error' : 'toast success'
      ..style.position = 'fixed'
      ..style.top = '20px'
      ..style.right = '20px'
      ..style.padding = '12px 16px'
      ..style.borderRadius = '4px'
      ..style.zIndex = '1000';
    
    document.body!.children.add(toast);
    
    // Auto-remove after 3 seconds
    Timer(Duration(seconds: 3), () => toast.remove());
  }
}
```

## 🔒 Security Considerations

### 1. Content Security Policy

```html
<!-- web/index.html -->
<meta http-equiv="Content-Security-Policy" 
      content="default-src 'self'; 
               script-src 'self' 'unsafe-inline' https://unpkg.com; 
               connect-src 'self' https://api.mainnet-beta.solana.com https://api.devnet.solana.com; 
               style-src 'self' 'unsafe-inline';">
```

### 2. Secure Communication

```dart
// lib/security/secure_rpc.dart
class SecureRpcClient {
  static Connection createSecureConnection(String rpcUrl) {
    // Validate RPC URL
    if (!_isValidRpcUrl(rpcUrl)) {
      throw ArgumentError('Invalid RPC URL');
    }
    
    return Connection(rpcUrl, httpClient: _createSecureHttpClient());
  }
  
  static bool _isValidRpcUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null && 
           (uri.scheme == 'https' || uri.scheme == 'wss') &&
           _isWhitelistedDomain(uri.host);
  }
  
  static bool _isWhitelistedDomain(String domain) {
    const whitelist = [
      'api.mainnet-beta.solana.com',
      'api.devnet.solana.com',
      'api.testnet.solana.com',
      // Add your trusted RPC providers
    ];
    
    return whitelist.contains(domain);
  }
  
  static HttpClient _createSecureHttpClient() {
    return HttpClient()
      ..connectionTimeout = Duration(seconds: 30)
      ..idleTimeout = Duration(seconds: 30);
  }
}
```

## 📊 Performance Optimization

### 1. Connection Pooling

```dart
// lib/services/connection_pool.dart
class ConnectionPool {
  static final Map<String, Connection> _connections = {};
  
  static Connection getConnection(String rpcUrl) {
    return _connections.putIfAbsent(rpcUrl, () {
      return SecureRpcClient.createSecureConnection(rpcUrl);
    });
  }
  
  static void warmUpConnections() {
    // Pre-establish connections to improve performance
    getConnection('https://api.mainnet-beta.solana.com');
    getConnection('https://api.devnet.solana.com');
  }
  
  static void clearConnections() {
    _connections.clear();
  }
}
```

### 2. Lazy Loading

```dart
// lib/utils/lazy_loader.dart
class LazyLoader {
  static final Map<String, Future<dynamic>> _cache = {};
  
  static Future<Program> loadProgram(
    String programId,
    String idlUrl,
    AnchorProvider provider,
  ) async {
    final cacheKey = '$programId-$idlUrl';
    
    return _cache.putIfAbsent(cacheKey, () async {
      final idlResponse = await HttpRequest.getString(idlUrl);
      final idl = json.decode(idlResponse);
      return Program(idl, programId, provider);
    }) as Future<Program>;
  }
}
```

## 🧪 Testing

### 1. Unit Testing

```dart
// test/wallets/phantom_wallet_test.dart
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';

void main() {
  group('PhantomWallet', () {
    test('should detect when phantom is installed', () {
      // Mock browser environment
      expect(PhantomWallet.isInstalled, isFalse);
    });
    
    test('should throw when phantom not installed', () {
      expect(
        () => PhantomWallet.connect(),
        throwsA(isA<Exception>()),
      );
    });
  });
}
```

### 2. Integration Testing with Browser

```dart
// test_driver/app_test.dart
import 'package:webdriver/webdriver.dart';
import 'package:test/test.dart';

void main() {
  group('Solana Web App Integration', () {
    late WebDriver driver;
    
    setUpAll(() async {
      driver = await createDriver();
    });
    
    tearDownAll(() async {
      await driver.quit();
    });
    
    test('should load the application', () async {
      await driver.get('http://localhost:8080');
      
      final title = await driver.title;
      expect(title, contains('Solana dApp'));
    });
    
    test('should show wallet connection options', () async {
      final connectBtn = await driver.findElement(By.text('Connect Wallet'));
      expect(await connectBtn.displayed, isTrue);
    });
  });
}
```

## 📚 Resources

- [Dart Web Development](https://dart.dev/web)
- [Solana Wallet Adapter](https://github.com/solana-labs/wallet-adapter)
- [Web3.js Documentation](https://solana-labs.github.io/solana-web3.js/)
- [coral_xyz API Reference](https://pub.dev/documentation/coral_xyz)

## 🤝 Community Examples

Check out these community-created web applications:

- **Portfolio Dashboard** - Track Solana investments in the browser
- **DEX Interface** - Decentralized exchange built with coral_xyz
- **NFT Gallery** - Showcase and trade NFTs
- **Voting Platform** - Decentralized governance interface

---

**Need Help?** Join our [GitHub Discussions](https://github.com/coral-xyz/dart-coral-xyz/discussions) for web-specific questions and support!
