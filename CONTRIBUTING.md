# Contributing to ActionWebPush

Thank you for your interest in contributing to ActionWebPush! This document provides guidelines and information for contributors.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Making Changes](#making-changes)
- [Testing](#testing)
- [Submitting Changes](#submitting-changes)
- [Release Process](#release-process)

## Code of Conduct

This project adheres to the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

## Getting Started

1. Fork the repository on GitHub
2. Clone your fork locally
3. Set up the development environment
4. Create a feature branch for your changes

## Development Setup

### Prerequisites

- Ruby 2.6.0 or higher
- Rails 6.0 or higher
- Redis (for rate limiting tests)
- Git

### Setup

```bash
# Clone your fork
git clone https://github.com/yourusername/actionwebpush.git
cd actionwebpush

# Install dependencies
bundle install

# Run tests to ensure everything works
bundle exec rake test
```

### Development Dependencies

The gem uses these development tools:
- **Minitest** for testing
- **SQLite3** for test database
- **Resque** for background job testing
- **WebMock** for HTTP mocking in tests

## Making Changes

### Branch Naming

Use descriptive branch names:
- `feature/add-batch-delivery`
- `fix/rate-limiter-race-condition`
- `docs/update-readme`

### Code Style

- Follow Ruby community standards
- Use 2 spaces for indentation
- Keep lines under 120 characters
- Add comments for complex logic
- Use descriptive variable and method names

### Commit Messages

Write clear, descriptive commit messages:
```
Add batch delivery optimization for large subscription lists

- Implement batching logic in BatchDelivery class
- Add configuration option for batch size
- Include tests for batch processing
- Update documentation with batch delivery examples

Fixes #42
```

## Testing

### Running Tests

```bash
# Run all tests
bundle exec rake test

# Run specific test file
bundle exec ruby test/notification_test.rb

# Run tests with coverage
bundle exec rake test:coverage
```

### Test Structure

- **Unit tests**: Test individual classes and methods
- **Integration tests**: Test component interactions
- **System tests**: Test end-to-end functionality

### Writing Tests

- Write tests for new features
- Ensure edge cases are covered
- Mock external dependencies (WebPush API calls)
- Use descriptive test names

Example:
```ruby
def test_notification_delivery_with_expired_subscription
  # Test setup
  # Test execution
  # Assertions
end
```

### Test Requirements

- All new code must have tests
- Maintain or improve test coverage
- Tests must pass on Ruby 2.6+ and Rails 6.0+

## Submitting Changes

### Pull Request Process

1. **Update documentation** if your changes affect the public API
2. **Add tests** for new functionality
3. **Update CHANGELOG.md** with your changes
4. **Ensure all tests pass**
5. **Create a pull request** with:
   - Clear title and description
   - Reference to related issues
   - Screenshots/examples if applicable

### Pull Request Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Tests added/updated
- [ ] All tests pass
- [ ] Manual testing completed

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
```

### Review Process

- Maintainers will review your PR
- Address feedback promptly
- Be open to suggestions and changes
- Once approved, your PR will be merged

## Types of Contributions

### Bug Reports

When reporting bugs, include:
- Ruby and Rails versions
- Gem version
- Steps to reproduce
- Expected vs actual behavior
- Error messages/stack traces

### Feature Requests

For new features:
- Describe the use case
- Explain why it's valuable
- Consider backwards compatibility
- Provide implementation ideas if possible

### Documentation

Documentation improvements are always welcome:
- Fix typos and grammar
- Add examples
- Improve clarity
- Translate content

### Code Contributions

Areas where contributions are especially welcome:
- Performance optimizations
- Additional delivery methods
- Better error handling
- Enhanced configuration options
- More comprehensive tests

## Release Process

1. Update version in `lib/actionwebpush/version.rb`
2. Update `CHANGELOG.md` with release notes
3. Create git tag for version
4. Build and push gem to RubyGems
5. Create GitHub release with notes

## Development Guidelines

### Adding New Features

1. **Discuss first**: Open an issue to discuss major features
2. **Design consideration**: Consider impact on existing API
3. **Documentation**: Update README and API docs
4. **Tests**: Comprehensive test coverage required
5. **Examples**: Add usage examples

### Maintaining Backward Compatibility

- Avoid breaking changes in minor versions
- Deprecate features before removing them
- Provide migration paths for breaking changes
- Document any compatibility requirements

### Performance Considerations

- Profile performance-critical code
- Consider memory usage in long-running processes
- Test with realistic data volumes
- Document performance characteristics

## Getting Help

- **Issues**: Use GitHub issues for bugs and feature requests
- **Discussions**: Use GitHub discussions for questions
- **Email**: Contact maintainers for security issues

## Recognition

Contributors will be:
- Listed in the gem's credits
- Mentioned in release notes for significant contributions
- Invited to be maintainers for consistent, high-quality contributions

Thank you for contributing to ActionWebPush! 🚀