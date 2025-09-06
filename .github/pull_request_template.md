## Description
Provide a clear and concise description of what this PR does.

## Related Issues
- Fixes #(issue number)
- Relates to #(issue number)

## Type of Change
- [ ] 🐛 Bug fix (non-breaking change which fixes an issue)
- [ ] ✨ New feature (non-breaking change which adds functionality)
- [ ] 💥 Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] 📚 Documentation update
- [ ] 🔧 Maintenance (dependency updates, CI changes, etc.)
- [ ] ⚡ Performance improvement
- [ ] 🎨 Code style/formatting changes

## Changes Made
- Change 1
- Change 2
- Change 3

## TypeScript SDK Parity
- [ ] This change maintains parity with TypeScript `@coral-xyz/anchor` SDK
- [ ] This change improves upon TypeScript SDK functionality
- [ ] This change is Dart-specific and doesn't apply to TypeScript SDK
- [ ] N/A - This is not a functional change

If parity-related, provide TypeScript comparison:
```typescript
// TypeScript @coral-xyz/anchor equivalent
```

```dart
// coral_xyz (Dart) implementation
```

## Testing
- [ ] I have added tests that prove my fix is effective or that my feature works
- [ ] New and existing unit tests pass locally with my changes
- [ ] I have tested with real Solana programs (if applicable)

### Test Evidence
Provide evidence of testing:
```bash
# Test commands run
dart test
dart test test/specific_test.dart
```

## Code Quality
- [ ] My code follows the project's style guidelines
- [ ] I have performed a self-review of my own code
- [ ] I have commented my code, particularly in hard-to-understand areas
- [ ] I have made corresponding changes to the documentation
- [ ] My changes generate no new warnings
- [ ] I have run `dart analyze` and fixed all issues

## Performance Impact
- [ ] This change has no performance impact
- [ ] This change improves performance
- [ ] This change may impact performance (explain below)

If performance impact, describe:

## Breaking Changes
- [ ] This PR contains no breaking changes
- [ ] This PR contains breaking changes (document below)

If breaking changes, document migration path:

## Documentation
- [ ] Documentation is up to date
- [ ] README.md updated (if needed)
- [ ] API documentation updated (if needed)
- [ ] Examples updated (if needed)
- [ ] CHANGELOG.md updated

## Mobile/Platform Testing
- [ ] Tested on Android
- [ ] Tested on iOS  
- [ ] Tested on Web
- [ ] Tested on Desktop
- [ ] Not applicable (internal change)

## Battle-tested Integration
- [ ] Uses existing espresso-cash components where applicable
- [ ] No mock code - all implementations are production-ready
- [ ] Follows established patterns from the codebase
- [ ] Integration tested with real Solana programs

## Checklist
- [ ] My code follows the coding standards of this project
- [ ] I have read and understood the [Contributing Guidelines](../CONTRIBUTING.md)
- [ ] I have tested my changes thoroughly
- [ ] I have updated documentation as needed
- [ ] I have verified TypeScript SDK parity (if applicable)
- [ ] My commits follow the project's commit message conventions

## Additional Notes
Add any additional notes, concerns, or considerations here.

---

**Reviewer Guidelines**: Please verify TypeScript SDK parity, test coverage, and adherence to the 21 implementation rules from the project roadmap.
