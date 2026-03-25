# Changelog

All notable changes to Automotive Claude Code Agents will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial project structure and core framework
- Comprehensive skill library for automotive domains
- Multi-model LLM Council for critical decisions
- Support for ADAS/autonomous driving development
- Battery management system tools and skills
- AUTOSAR Classic and Adaptive support
- Diagnostic protocol implementations (UDS, DoIP, XCP)
- Infotainment and connectivity skills
- Safety and compliance validation tools
- CI/CD pipelines with GitHub Actions
- Docker containerization support
- Comprehensive documentation with MkDocs

### Categories of Skills
- **ADAS & Autonomous**: Camera/LiDAR object detection, sensor fusion, path planning
- **Battery Management**: SOC estimation, thermal management, cell balancing
- **AUTOSAR**: Configuration generation, RTE analysis, SWC development
- **Diagnostics**: UDS implementation, DoIP communication, XCP calibration
- **Infotainment**: HMI development, media processing, connectivity
- **Safety**: ISO 26262 compliance, FMEA generation, safety analysis

### Development Tools
- Python 3.8+ support with type hints
- Black code formatting
- Ruff linting
- MyPy type checking
- Pytest testing framework
- Pre-commit hooks
- Comprehensive test coverage

### Documentation
- User guide and tutorials
- API reference documentation
- Automotive domain guides
- Standards compliance documentation
- Example projects and use cases

## [0.1.0] - 2024-03-19

### Added
- Initial alpha release
- Core platform infrastructure
- Basic skill routing and execution
- LLM Council integration
- Documentation foundation

### Known Issues
- Limited test coverage for some automotive-specific features
- Documentation needs expansion
- Some skills require additional validation

## Release Process

Releases follow semantic versioning:
- **MAJOR**: Breaking changes to API or architecture
- **MINOR**: New features, backward compatible
- **PATCH**: Bug fixes, backward compatible

### Version Tags
- `v0.1.0` - Initial alpha release
- `v0.2.0` - Beta release with expanded skill library
- `v1.0.0` - First stable release (planned)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on contributing to this project.

## Links
- [Documentation](https://automotive-claude-code.readthedocs.io/)
- [GitHub Repository](https://github.com/automotive-opensource/automotive-claude-code-agents)
- [Issue Tracker](https://github.com/automotive-opensource/automotive-claude-code-agents/issues)
