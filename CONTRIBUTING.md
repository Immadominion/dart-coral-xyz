# Contributing to Coral XYZ Anchor for Dart

We love your input! We want to make contributing to this project as easy and transparent as possible, whether it's:

- Reporting a bug
- Discussing the current state of the code
- Submitting a fix
- Proposing new features
- Becoming a maintainer

## Development Process

We use GitHub to host code, to track issues and feature requests, as well as accept pull requests.

## Pull Requests

Pull requests are the best way to propose changes to the codebase. We actively welcome your pull requests:

1. Fork the repo and create your branch from `main`.
2. If you've added code that should be tested, add tests.
3. If you've changed APIs, update the documentation.
4. Ensure the test suite passes.
5. Make sure your code lints.
6. Issue that pull request!

## Any contributions you make will be under the MIT Software License

In short, when you submit code changes, your submissions are understood to be under the same [MIT License](http://choosealicense.com/licenses/mit/) that covers the project. Feel free to contact the maintainers if that's a concern.

## Report bugs using GitHub's [issues](https://github.com/your-username/dart-coral-xyz/issues)

We use GitHub issues to track public bugs. Report a bug by [opening a new issue](https://github.com/your-username/dart-coral-xyz/issues/new); it's that easy!

## Write bug reports with detail, background, and sample code

**Great Bug Reports** tend to have:

- A quick summary and/or background
- Steps to reproduce
  - Be specific!
  - Give sample code if you can
- What you expected would happen
- What actually happens
- Notes (possibly including why you think this might be happening, or stuff you tried that didn't work)

## Development Setup

1. **Clone the repository**

   ```bash
   git clone https://github.com/your-username/dart-coral-xyz.git
   cd dart-coral-xyz
   ```

2. **Install Dart SDK**

   - Install Dart 3.0+ from [dart.dev](https://dart.dev/get-dart)
   - Or use Flutter which includes Dart

3. **Install dependencies**

   ```bash
   dart pub get
   ```

4. **Run tests**

   ```bash
   dart test
   ```

5. **Run linting**
   ```bash
   dart analyze
   dart format --set-exit-if-changed .
   ```

## Development Guidelines

### Code Style

- Follow the [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- Use `dart format` to format your code
- Ensure `dart analyze` passes with no issues
- Write meaningful commit messages

### Testing

- Write tests for all new functionality
- Ensure existing tests continue to pass
- Aim for high test coverage
- Use descriptive test names

### Documentation

- Update documentation for any API changes
- Include code examples in doc comments
- Keep the README.md up to date
- Update the CHANGELOG.md for notable changes

### Roadmap Adherence

- Follow the established [roadmap](roadmap.md)
- Complete tasks in the correct order
- Mark tasks as complete when finished
- Discuss major deviations from the roadmap

## Commit Message Format

We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

Types:

- `feat`: A new feature
- `fix`: A bug fix
- `docs`: Documentation only changes
- `style`: Changes that do not affect the meaning of the code
- `refactor`: A code change that neither fixes a bug nor adds a feature
- `test`: Adding missing tests or correcting existing tests
- `chore`: Changes to the build process or auxiliary tools

Examples:

```
feat(provider): add connection pooling support
fix(coder): resolve borsh serialization issue with nested structs
docs(readme): update installation instructions
```

## License

By contributing, you agree that your contributions will be licensed under its MIT License.
