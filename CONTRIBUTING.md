# Contributing to Automotive Claude Code

Thank you for your interest in contributing! This document provides guidelines for contributing to the project.

## 🎯 Vision

Democratize automotive expertise through AI, enabling every engineer to work at expert level with complete standards compliance.

## 🤝 Ways to Contribute

### 1. Add New Skills
- Navigate to `skills/` directory
- Create YAML file following existing patterns
- Include complete implementation, not TODOs
- Add tests in `tests/unit/`
- Document in `knowledge-base/`

### 2. Implement Tool Adapters
- Create adapter in `tools/adapters/<category>/`
- Inherit from `BaseToolAdapter`
- Implement all abstract methods
- Add integration tests
- Update `tool_router.py`

### 3. Create Agents
- Define agent in `agents/<domain>/`
- Specify capabilities and tools
- Add collaboration patterns
- Document usage examples

### 4. Improve Documentation
- Fix typos and clarify explanations
- Add tutorials and examples
- Expand knowledge base articles
- Translate to other languages

### 5. Report Bugs
- Search existing issues first
- Provide reproduction steps
- Include environment details
- Share logs and error messages

## 📝 Development Workflow

### Setup Development Environment

```bash
# Clone repository
git clone https://github.com/automotive-opensource/automotive-claude-code-agents.git
cd automotive-claude-code-agents

# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install in development mode
pip install -e ".[dev]"

# Install pre-commit hooks
pre-commit install
```

### Code Quality Standards

```bash
# Format code
make format

# Run linters
make lint

# Run tests
make test

# Check coverage
make coverage
```

### Commit Message Convention

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes
- `refactor`: Code refactoring
- `test`: Test additions/changes
- `chore`: Build/tooling changes

**Examples:**
```
feat(autosar): add SWC generation skill
fix(battery): correct SOC estimation algorithm
docs(api): update tool adapter API reference
```

### Pull Request Process

1. **Create Branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make Changes**
   - Write production-ready code
   - Add comprehensive tests (80%+ coverage)
   - Update documentation
   - Follow coding standards

3. **Test Locally**
   ```bash
   make test
   make lint
   make coverage
   ```

4. **Push and Create PR**
   ```bash
   git push origin feature/your-feature-name
   ```
   - Fill out PR template completely
   - Link related issues
   - Request reviews from maintainers

5. **Address Review Feedback**
   - Make requested changes
   - Push updates to same branch
   - Mark conversations as resolved

6. **Merge**
   - Squash commits when merging
   - Ensure CI passes
   - Delete branch after merge

## 🎨 Code Style

### Python
- Follow [PEP 8](https://pep8.org/)
- Use type hints for all functions
- Maximum line length: 88 characters (Black default)
- Docstrings: Google style
- Format with Black: `make format`

### YAML
- Use 2-space indentation
- No trailing whitespace
- Use lowercase with hyphens for keys
- Quote strings when ambiguous

### Shell Scripts
- Use `#!/usr/bin/env bash`
- Set `-euo pipefail`
- Quote all variables
- Use `readonly` for constants
- Add comments for complex logic

## 🧪 Testing Guidelines

### Test Coverage Requirements
- **Minimum**: 80% for new code
- **Safety-critical**: 100% for ISO 26262 ASIL-D
- **Security**: 100% for ISO 21434 features

### Test Structure
```python
def test_<what>_<when>_<expected>():
    """Clear description of what is being tested."""
    # Arrange
    setup_test_conditions()

    # Act
    result = function_under_test()

    # Assert
    assert result == expected_value
```

### Running Tests
```bash
# All tests
pytest

# Specific file
pytest tests/unit/test_tool_router.py

# With coverage
pytest --cov=tools --cov-report=html

# Verbose output
pytest -vv
```

## 📚 Documentation Guidelines

### Code Documentation
- All public functions must have docstrings
- Include parameter types and return types
- Provide usage examples
- Document exceptions raised

### Knowledge Base
- Follow 5-level structure (overview → advanced)
- Use clear headings and hierarchy
- Include code examples
- Add cross-references
- Keep automotive context in mind

## 🔒 Security

### Reporting Vulnerabilities
- **DO NOT** open public issues for security vulnerabilities
- Email: security@automotive-claude-code.org
- Include detailed reproduction steps
- Allow 90 days for fix before public disclosure

### Security Best Practices
- Never commit secrets or credentials
- Validate all external input
- Use parameterized queries
- Follow OWASP Top 10 guidelines
- Implement least-privilege access

## 📜 License

By contributing, you agree that your contributions will be licensed under the MIT License.

## 💬 Getting Help

- **Discord**: [Join our community](https://discord.gg/automotive-claude)
- **GitHub Discussions**: Ask questions and share ideas
- **Email**: contributors@automotive-claude-code.org

## 🙏 Recognition

Contributors are recognized in:
- `CONTRIBUTORS.md` file
- Release notes
- Project website
- Annual contributor spotlight

Thank you for making automotive development accessible to everyone! 🚗✨
