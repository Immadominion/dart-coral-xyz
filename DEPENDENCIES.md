# External Dependencies Configuration

# This file documents our external dependencies and their purposes

## Core Dependencies Analysis

### Solana Web3 Dependencies

- **solana: ^0.31.2+1**

  - Purpose: Primary Solana RPC client for blockchain communication
  - Publisher: cryptoplease.com (verified)
  - Features: JSON RPC API, WebSocket support, transaction handling
  - Status: Active, well-maintained

- **solana_web3: ^0.1.3** [TEMPORARILY DISABLED]
  - Purpose: Additional Solana utilities and program interfaces
  - Publisher: merigolabs.com (verified)
  - Features: Common program support, additional RPC methods
  - Status: Disabled due to pinenacl version conflicts with ed25519_hd_key
  - Note: Will be re-enabled when version conflicts are resolved

### Serialization Dependencies

- **borsh: ^0.3.2**

  - Purpose: Primary Borsh serialization implementation
  - Publisher: cryptoplease.com (verified)
  - Features: Binary Object Representation Serialization for Hashing
  - Status: Active, matches Anchor requirements

- **borsh_annotation: ^0.3.2** [TEMPORARILY DISABLED]
  - Purpose: Code generation annotations for Borsh serialization
  - Publisher: cryptoplease.com (verified)
  - Features: Automatic serialization code generation
  - Status: Disabled to avoid potential conflicts during initial development

### Cryptography Dependencies

- **cryptography: ^2.7.0**

  - Purpose: Primary cryptographic operations (ED25519, X25519)
  - Publisher: dint.dev (verified)
  - Features: Cross-platform crypto, good Dart 3 support
  - Downloads: 172k (very popular)
  - Status: Mature, well-maintained

- **ed25519_hd_key: ^2.3.0** [TEMPORARILY DISABLED]
  - Purpose: BIP32-like HD key derivation for ED25519
  - Publisher: alepop.dev (verified)
  - Features: Hierarchical deterministic key generation
  - Status: Disabled due to pinenacl version conflicts with solana_web3
  - Status: Active, specialized for ED25519

### Encoding Dependencies

- **bs58: ^1.0.2**

  - Purpose: Base58 encoding/decoding (Bitcoin-style)
  - Features: Standard Base58 implementation
  - Downloads: 11.2k
  - Status: Stable, widely used

- **base_codecs: ^1.0.1**
  - Purpose: Additional base encodings (base16, base32, base85)
  - Features: Comprehensive base encoding support
  - Downloads: 20.6k
  - Status: Mature, complete feature set

### Utility Dependencies

- **blockchain_utils: ^5.0.0** [TEMPORARILY DISABLED]
  - Purpose: Comprehensive blockchain utilities
  - Features: Addresses, mnemonics, cryptography
  - Downloads: 6.04k
  - Status: Disabled to avoid dependency conflicts during initial development phase
  - Note: Will be re-enabled when conflicts are resolved

### Mobile Integration (Optional)

- **solana_mobile_client: ^0.1.2** [TEMPORARILY DISABLED]
  - Purpose: Mobile Wallet Adapter implementation
  - Publisher: cryptoplease.com (verified)
  - Platform: Android only
  - Status: Disabled to simplify initial dependency resolution
  - Status: Active, specialized for mobile

### Development Dependencies

- **dart_code_metrics: ^5.7.6** [TEMPORARILY DISABLED]
  - Purpose: Code quality analysis and metrics
  - Status: Disabled due to http version conflicts
  - Note: Conflicted with http ^1.1.0 required by solana package

## Dependency Strategy

### Primary vs Secondary

- **Primary**: solana, borsh, cryptography, bs58 (core functionality)
- **Secondary**: Additional utilities and mobile support (optional)
- **Fallback**: blockchain_utils provides comprehensive alternatives when conflicts resolve

### Version Conflict Resolution

During initial development, some packages were temporarily disabled due to:

- HTTP version conflicts (dart_code_metrics vs solana)
- Cryptography version conflicts (pinenacl versions between packages)

These will be resolved by:

1. Waiting for package maintainers to update dependencies
2. Finding alternative packages with compatible versions
3. Implementing specific functionality directly if needed

### Version Pinning Strategy

- Pin major versions to avoid breaking changes
- Use ^ for minor/patch updates
- Monitor for security updates
- Re-evaluate disabled packages periodically

### Cross-Platform Considerations

- All core dependencies support major platforms (Android, iOS, Web, Desktop)
- Mobile-specific dependencies marked as optional
- Web compatibility maintained through pure Dart implementations
- Web compatibility verified for all core packages

### Future Considerations

- Monitor Solana ecosystem for newer packages
- Consider creating our own optimized implementations for critical paths
- Plan for potential dependency migrations

## Risk Assessment

### Low Risk

- cryptography: Mature, widely used, active maintenance
- Standard encoding packages: Stable implementations

### Medium Risk

- Solana packages: Relatively new ecosystem, but verified publishers
- Borsh packages: Specialized, but maintained by same team

### Mitigation Strategies

- Wrapper classes isolate external dependencies
- Interface-based design allows easy replacement
- Comprehensive test coverage for external integrations
- Regular dependency updates and security monitoring
