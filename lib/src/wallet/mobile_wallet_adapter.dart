/// Mobile wallet adapter implementation for native mobile wallet integration
///
/// This module provides comprehensive mobile wallet adapter functionality that
/// follows the Mobile Wallet Adapter (MWA) protocol for secure communication
/// between mobile apps and wallet applications.

library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import '../types/public_key.dart';
import '../types/transaction.dart';
import 'wallet_adapter.dart';

/// Mobile wallet adapter implementing the MWA protocol
///
/// This adapter handles communication with mobile wallet applications through
/// deep linking and custom URL schemes. It provides secure transaction signing
/// and account management for mobile environments.
class MobileWalletAdapter extends BaseWalletAdapter {
  static const String _name = 'Mobile Wallet Adapter';

  /// Configuration for the mobile wallet adapter
  final MobileWalletAdapterConfig _config;

  /// Active session information
  MobileWalletSession? _session;

  /// Deep link handler for wallet communication
  final MobileWalletDeepLinkHandler _deepLinkHandler;

  /// Timeout for wallet operations
  final Duration _timeout;

  /// Constructor for mobile wallet adapter
  MobileWalletAdapter({
    MobileWalletAdapterConfig? config,
    MobileWalletDeepLinkHandler? deepLinkHandler,
    Duration? timeout,
  })  : _config = config ?? MobileWalletAdapterConfig.defaultConfig(),
        _deepLinkHandler = deepLinkHandler ?? MobileWalletDeepLinkHandler(),
        _timeout = timeout ?? const Duration(minutes: 5) {
    _initialize();
  }

  @override
  String get name => _name;

  @override
  String? get icon => _config.icon;

  @override
  String? get url => _config.url;

  @override
  bool get supported => _config.platform.isSupported;

  /// Initialize the mobile wallet adapter
  void _initialize() {
    setReadyState(_config.platform.isSupported
        ? WalletReadyState.installed
        : WalletReadyState.unsupported);

    setProperty('protocol', 'MWA');
    setProperty('version', _config.protocolVersion);
    setProperty('platform', _config.platform.name);

    // Listen for deep link responses
    _deepLinkHandler.onResponse.listen(_handleDeepLinkResponse);
  }

  @override
  Future<void> connect() async {
    if (connected) return;

    if (!supported) {
      throw const WalletNotSupportedException(
          'Mobile Wallet Adapter is not supported on this platform');
    }

    try {
      setReadyState(WalletReadyState.loading);

      // Create connection request
      final request = MobileWalletRequest.connect(
        appName: _config.appName,
        appIcon: _config.appIcon,
        cluster: _config.cluster,
        permissions: _config.permissions,
      );

      // Launch wallet with connection request
      await _launchWallet(request);

      // Wait for connection response
      final response = await _waitForResponse(request.id, _timeout);

      if (response.isSuccess) {
        final connectResponse = response as MobileWalletConnectResponse;
        _session = MobileWalletSession(
          sessionId: connectResponse.sessionId,
          publicKey: connectResponse.publicKey,
          walletUriBase: connectResponse.walletUriBase,
        );

        setPublicKey(connectResponse.publicKey);
        setConnected(true);
        setReadyState(WalletReadyState.installed);

        setProperty('sessionId', _session!.sessionId);
        setProperty('walletName', connectResponse.walletName);
        setProperty('walletIcon', connectResponse.walletIcon);
      } else {
        final error = response as MobileWalletErrorResponse;
        if (error.isUserRejection) {
          throw WalletUserRejectedException(error.message);
        } else {
          throw WalletConnectionException(error.message, code: error.code);
        }
      }
    } catch (e) {
      setReadyState(WalletReadyState.installed);
      if (e is WalletException) {
        rethrow;
      } else {
        throw WalletConnectionException(
          'Failed to connect to mobile wallet: $e',
          cause: e,
        );
      }
    }
  }

  @override
  Future<void> disconnect() async {
    if (!connected) return;

    try {
      if (_session != null) {
        // Send disconnect request to wallet
        final request = MobileWalletRequest.disconnect(
          sessionId: _session!.sessionId,
        );

        // Best effort to notify wallet - don't wait for response
        _launchWallet(request).catchError((_) {});
      }
    } finally {
      _session = null;
      setPublicKey(null);
      setConnected(false);
      emitDisconnect();
    }
  }

  @override
  Future<Transaction> signTransaction(Transaction transaction) async {
    if (!connected || _session == null) {
      throw const WalletNotConnectedException();
    }

    try {
      // Serialize transaction for signing
      final transactionBytes = transaction.compileMessage();

      // Create signing request
      final request = MobileWalletRequest.signTransaction(
        sessionId: _session!.sessionId,
        transaction: transactionBytes,
      );

      // Launch wallet with signing request
      await _launchWallet(request);

      // Wait for signing response
      final response = await _waitForResponse(request.id, _timeout);

      if (response.isSuccess) {
        final signResponse = response as MobileWalletSignResponse;

        // Apply signature to transaction
        transaction.addSignature(publicKey!, signResponse.signature);
        return transaction;
      } else {
        final error = response as MobileWalletErrorResponse;
        if (error.isUserRejection) {
          throw WalletUserRejectedException(error.message);
        } else {
          throw WalletSigningException(error.message, cause: error.code);
        }
      }
    } catch (e) {
      if (e is WalletException) {
        rethrow;
      } else {
        throw WalletSigningException(
          'Failed to sign transaction: $e',
          cause: e,
        );
      }
    }
  }

  @override
  Future<List<Transaction>> signAllTransactions(
    List<Transaction> transactions,
  ) async {
    if (!connected || _session == null) {
      throw const WalletNotConnectedException();
    }

    if (transactions.isEmpty) return [];

    try {
      // Serialize all transactions for signing
      final transactionBytes =
          transactions.map((tx) => tx.compileMessage()).toList();

      // Create batch signing request
      final request = MobileWalletRequest.signTransactions(
        sessionId: _session!.sessionId,
        transactions: transactionBytes,
      );

      // Launch wallet with signing request
      await _launchWallet(request);

      // Wait for signing response
      final response = await _waitForResponse(request.id, _timeout);

      if (response.isSuccess) {
        final signResponse = response as MobileWalletSignResponse;

        if (signResponse.signatures.length != transactions.length) {
          throw WalletSigningException(
            'Wallet returned ${signResponse.signatures.length} signatures '
            'but expected ${transactions.length}',
          );
        }

        // Apply signatures to transactions
        for (int i = 0; i < transactions.length; i++) {
          transactions[i].addSignature(publicKey!, signResponse.signatures[i]);
        }

        return transactions;
      } else {
        final error = response as MobileWalletErrorResponse;
        if (error.isUserRejection) {
          throw WalletUserRejectedException(error.message);
        } else {
          throw WalletSigningException(error.message, cause: error.code);
        }
      }
    } catch (e) {
      if (e is WalletException) {
        rethrow;
      } else {
        throw WalletSigningException(
          'Failed to sign transactions: $e',
          cause: e,
        );
      }
    }
  }

  @override
  Future<Uint8List> signMessage(Uint8List message) async {
    if (!connected || _session == null) {
      throw const WalletNotConnectedException();
    }

    try {
      // Create message signing request
      final request = MobileWalletRequest.signMessage(
        sessionId: _session!.sessionId,
        message: message,
      );

      // Launch wallet with signing request
      await _launchWallet(request);

      // Wait for signing response
      final response = await _waitForResponse(request.id, _timeout);

      if (response.isSuccess) {
        final signResponse = response as MobileWalletSignResponse;
        return signResponse.signature;
      } else {
        final error = response as MobileWalletErrorResponse;
        if (error.isUserRejection) {
          throw WalletUserRejectedException(error.message);
        } else {
          throw WalletSigningException(error.message, cause: error.code);
        }
      }
    } catch (e) {
      if (e is WalletException) {
        rethrow;
      } else {
        throw WalletSigningException(
          'Failed to sign message: $e',
          cause: e,
        );
      }
    }
  }

  /// Launch the wallet application with a request
  Future<void> _launchWallet(MobileWalletRequest request) async {
    final uri = _buildWalletUri(request);
    await _deepLinkHandler.launch(uri);
  }

  /// Build the wallet URI for a request
  Uri _buildWalletUri(MobileWalletRequest request) {
    final baseUri = _session?.walletUriBase ?? _config.defaultWalletUri;

    return Uri.parse(baseUri).replace(
      queryParameters: {
        'request': base64Url.encode(utf8.encode(json.encode(request.toJson()))),
      },
    );
  }

  /// Wait for a response from the wallet
  Future<MobileWalletResponse> _waitForResponse(
    String requestId,
    Duration timeout,
  ) async {
    final completer = Completer<MobileWalletResponse>();

    late StreamSubscription subscription;
    subscription = _deepLinkHandler.onResponse.listen((response) {
      if (response.requestId == requestId) {
        subscription.cancel();
        completer.complete(response);
      }
    });

    // Set up timeout
    Timer(timeout, () {
      if (!completer.isCompleted) {
        subscription.cancel();
        completer.completeError(WalletTimeoutException(timeout));
      }
    });

    return completer.future;
  }

  /// Handle deep link responses from the wallet
  void _handleDeepLinkResponse(MobileWalletResponse response) {
    // Response handling is done in _waitForResponse
    // This method could be extended for additional response processing
  }

  @override
  void dispose() {
    _deepLinkHandler.dispose();
    super.dispose();
  }
}

/// Configuration for mobile wallet adapter
class MobileWalletAdapterConfig {
  /// The name of the requesting application
  final String appName;

  /// Icon URL for the requesting application
  final String? appIcon;

  /// Solana cluster to use
  final String cluster;

  /// Permissions requested from the wallet
  final List<String> permissions;

  /// Target platform configuration
  final MobileWalletPlatform platform;

  /// Default wallet URI for launching
  final String defaultWalletUri;

  /// Protocol version
  final String protocolVersion;

  /// Adapter icon
  final String? icon;

  /// Adapter URL
  final String? url;

  const MobileWalletAdapterConfig({
    required this.appName,
    this.appIcon,
    this.cluster = 'mainnet-beta',
    this.permissions = const ['sign_transactions', 'sign_messages'],
    this.platform = const MobileWalletPlatform.universal(),
    this.defaultWalletUri = 'https://phantom.app/ul/v1/connect',
    this.protocolVersion = '1.0',
    this.icon,
    this.url,
  });

  /// Default configuration
  static MobileWalletAdapterConfig defaultConfig() {
    return const MobileWalletAdapterConfig(
      appName: 'Coral XYZ Dart SDK',
      cluster: 'mainnet-beta',
    );
  }
}

/// Platform configuration for mobile wallet adapter
class MobileWalletPlatform {
  /// Platform name
  final String name;

  /// Whether the platform is supported
  final bool isSupported;

  const MobileWalletPlatform({
    required this.name,
    required this.isSupported,
  });

  /// Universal platform (supports all platforms)
  const MobileWalletPlatform.universal()
      : name = 'universal',
        isSupported = true;

  /// iOS platform
  const MobileWalletPlatform.ios()
      : name = 'ios',
        isSupported = true;

  /// Android platform
  const MobileWalletPlatform.android()
      : name = 'android',
        isSupported = true;

  /// Web platform (not supported for mobile wallet adapter)
  const MobileWalletPlatform.web()
      : name = 'web',
        isSupported = false;
}

/// Active mobile wallet session
class MobileWalletSession {
  /// Unique session identifier
  final String sessionId;

  /// Connected wallet's public key
  final PublicKey publicKey;

  /// Base URI for wallet communication
  final String walletUriBase;

  /// Session creation timestamp
  final DateTime createdAt;

  MobileWalletSession({
    required this.sessionId,
    required this.publicKey,
    required this.walletUriBase,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

/// Mobile wallet request types
abstract class MobileWalletRequest {
  /// Unique request identifier
  final String id;

  /// Request type
  final String type;

  /// Request timestamp
  final DateTime timestamp;

  MobileWalletRequest({
    String? id,
    required this.type,
    DateTime? timestamp,
  })  : id = id ?? _generateRequestId(),
        timestamp = timestamp ?? DateTime.now();

  /// Convert request to JSON
  Map<String, dynamic> toJson();

  /// Generate a unique request ID
  static String _generateRequestId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// Create a connection request
  factory MobileWalletRequest.connect({
    required String appName,
    String? appIcon,
    String? cluster,
    List<String>? permissions,
  }) {
    return MobileWalletConnectRequest(
      appName: appName,
      appIcon: appIcon,
      cluster: cluster ?? 'mainnet-beta',
      permissions: permissions ?? const ['sign_transactions', 'sign_messages'],
    );
  }

  /// Create a disconnect request
  factory MobileWalletRequest.disconnect({
    required String sessionId,
  }) {
    return MobileWalletDisconnectRequest(sessionId: sessionId);
  }

  /// Create a transaction signing request
  factory MobileWalletRequest.signTransaction({
    required String sessionId,
    required Uint8List transaction,
  }) {
    return MobileWalletSignTransactionRequest(
      sessionId: sessionId,
      transaction: transaction,
    );
  }

  /// Create a batch transaction signing request
  factory MobileWalletRequest.signTransactions({
    required String sessionId,
    required List<Uint8List> transactions,
  }) {
    return MobileWalletSignTransactionsRequest(
      sessionId: sessionId,
      transactions: transactions,
    );
  }

  /// Create a message signing request
  factory MobileWalletRequest.signMessage({
    required String sessionId,
    required Uint8List message,
  }) {
    return MobileWalletSignMessageRequest(
      sessionId: sessionId,
      message: message,
    );
  }
}

/// Connection request implementation
class MobileWalletConnectRequest extends MobileWalletRequest {
  final String appName;
  final String? appIcon;
  final String cluster;
  final List<String> permissions;

  MobileWalletConnectRequest({
    required this.appName,
    this.appIcon,
    this.cluster = 'mainnet-beta',
    this.permissions = const ['sign_transactions', 'sign_messages'],
    String? id,
  }) : super(id: id, type: 'connect');

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
      'appName': appName,
      'appIcon': appIcon,
      'cluster': cluster,
      'permissions': permissions,
    };
  }
}

/// Disconnect request implementation
class MobileWalletDisconnectRequest extends MobileWalletRequest {
  final String sessionId;

  MobileWalletDisconnectRequest({
    required this.sessionId,
    String? id,
  }) : super(id: id, type: 'disconnect');

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
      'sessionId': sessionId,
    };
  }
}

/// Transaction signing request implementation
class MobileWalletSignTransactionRequest extends MobileWalletRequest {
  final String sessionId;
  final Uint8List transaction;

  MobileWalletSignTransactionRequest({
    required this.sessionId,
    required this.transaction,
    String? id,
  }) : super(id: id, type: 'sign_transaction');

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
      'sessionId': sessionId,
      'transaction': base64.encode(transaction),
    };
  }
}

/// Batch transaction signing request implementation
class MobileWalletSignTransactionsRequest extends MobileWalletRequest {
  final String sessionId;
  final List<Uint8List> transactions;

  MobileWalletSignTransactionsRequest({
    required this.sessionId,
    required this.transactions,
    String? id,
  }) : super(id: id, type: 'sign_transactions');

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
      'sessionId': sessionId,
      'transactions': transactions.map((tx) => base64.encode(tx)).toList(),
    };
  }
}

/// Message signing request implementation
class MobileWalletSignMessageRequest extends MobileWalletRequest {
  final String sessionId;
  final Uint8List message;

  MobileWalletSignMessageRequest({
    required this.sessionId,
    required this.message,
    String? id,
  }) : super(id: id, type: 'sign_message');

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
      'sessionId': sessionId,
      'message': base64.encode(message),
    };
  }
}

/// Mobile wallet response types
abstract class MobileWalletResponse {
  /// Request ID this response corresponds to
  final String requestId;

  /// Response type
  final String type;

  /// Whether the response indicates success
  final bool isSuccess;

  /// Response timestamp
  final DateTime timestamp;

  MobileWalletResponse({
    required this.requestId,
    required this.type,
    required this.isSuccess,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create response from JSON
  factory MobileWalletResponse.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    final isSuccess = json['isSuccess'] as bool;

    if (isSuccess) {
      switch (type) {
        case 'connect':
          return MobileWalletConnectResponse.fromJson(json);
        case 'sign':
          return MobileWalletSignResponse.fromJson(json);
        default:
          throw ArgumentError('Unknown response type: $type');
      }
    } else {
      return MobileWalletErrorResponse.fromJson(json);
    }
  }
}

/// Successful connection response
class MobileWalletConnectResponse extends MobileWalletResponse {
  final String sessionId;
  final PublicKey publicKey;
  final String walletUriBase;
  final String walletName;
  final String? walletIcon;

  MobileWalletConnectResponse({
    required String requestId,
    required this.sessionId,
    required this.publicKey,
    required this.walletUriBase,
    required this.walletName,
    this.walletIcon,
    DateTime? timestamp,
  }) : super(
          requestId: requestId,
          type: 'connect',
          isSuccess: true,
          timestamp: timestamp,
        );

  factory MobileWalletConnectResponse.fromJson(Map<String, dynamic> json) {
    return MobileWalletConnectResponse(
      requestId: json['requestId'] as String,
      sessionId: json['sessionId'] as String,
      publicKey: PublicKey.fromBase58(json['publicKey'] as String),
      walletUriBase: json['walletUriBase'] as String,
      walletName: json['walletName'] as String,
      walletIcon: json['walletIcon'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

/// Successful signing response
class MobileWalletSignResponse extends MobileWalletResponse {
  final Uint8List signature;
  final List<Uint8List> signatures;

  MobileWalletSignResponse({
    required String requestId,
    Uint8List? signature,
    List<Uint8List>? signatures,
    DateTime? timestamp,
  })  : signature = signature ??
            (signatures?.isNotEmpty == true ? signatures!.first : Uint8List(0)),
        signatures = signatures ?? (signature != null ? [signature] : []),
        super(
          requestId: requestId,
          type: 'sign',
          isSuccess: true,
          timestamp: timestamp,
        );

  factory MobileWalletSignResponse.fromJson(Map<String, dynamic> json) {
    final signatureData = json['signature'];
    final signaturesData = json['signatures'];

    Uint8List? signature;
    List<Uint8List>? signatures;

    if (signatureData != null) {
      signature = base64.decode(signatureData as String);
    }

    if (signaturesData != null) {
      signatures = (signaturesData as List)
          .map((sig) => base64.decode(sig as String))
          .toList();
    }

    return MobileWalletSignResponse(
      requestId: json['requestId'] as String,
      signature: signature,
      signatures: signatures,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

/// Error response
class MobileWalletErrorResponse extends MobileWalletResponse {
  final String code;
  final String message;

  MobileWalletErrorResponse({
    required String requestId,
    required this.code,
    required this.message,
    DateTime? timestamp,
  }) : super(
          requestId: requestId,
          type: 'error',
          isSuccess: false,
          timestamp: timestamp,
        );

  /// Whether this error represents user rejection
  bool get isUserRejection =>
      code == 'USER_REJECTED' || code == 'USER_CANCELLED';

  factory MobileWalletErrorResponse.fromJson(Map<String, dynamic> json) {
    return MobileWalletErrorResponse(
      requestId: json['requestId'] as String,
      code: json['code'] as String,
      message: json['message'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

/// Deep link handler for mobile wallet communication
class MobileWalletDeepLinkHandler {
  /// Stream controller for responses
  final StreamController<MobileWalletResponse> _responseController =
      StreamController<MobileWalletResponse>.broadcast();

  /// Stream of wallet responses
  Stream<MobileWalletResponse> get onResponse => _responseController.stream;

  /// Launch a URI (to be implemented by platform-specific code)
  Future<void> launch(Uri uri) async {
    // This is a placeholder implementation
    // In a real implementation, this would use platform-specific
    // code to launch the wallet app with the given URI

    // For now, just print the URI that would be launched
    print('Would launch wallet with URI: $uri');

    // Simulate a delayed response for testing
    Future.delayed(const Duration(seconds: 2), () {
      // Simulate a successful connection response
      _responseController.add(MobileWalletConnectResponse(
        requestId: 'test',
        sessionId: 'test-session',
        publicKey: PublicKey.fromBase58('11111111111111111111111111111112'),
        walletUriBase: 'https://phantom.app/ul/v1',
        walletName: 'Test Wallet',
      ));
    });
  }

  /// Handle incoming deep link (to be called by platform-specific code)
  void handleIncomingLink(String link) {
    try {
      final uri = Uri.parse(link);
      final responseData = uri.queryParameters['response'];

      if (responseData != null) {
        final decodedData = utf8.decode(base64Url.decode(responseData));
        final json = jsonDecode(decodedData) as Map<String, dynamic>;
        final response = MobileWalletResponse.fromJson(json);

        _responseController.add(response);
      }
    } catch (e) {
      // Handle malformed response
      print('Failed to parse mobile wallet response: $e');
    }
  }

  /// Clean up resources
  void dispose() {
    _responseController.close();
  }
}
