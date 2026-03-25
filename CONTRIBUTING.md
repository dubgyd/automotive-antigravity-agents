# Contributing to Automotive Antigravity Workspace

Thank you for your interest in contributing to the automotive engineering expert ecosystem! This document provides guidelines for maintaining and expanding our domain-specific intelligence.

## 🎯 Vision

Democratize automotive expertise through the Antigravity platform, enabling every engineer to work at the same level as hardware, software, and functional safety experts while ensuring complete ISO 26262 and ISO 21434 compliance.

## 🤝 Ways to Contribute

### 1. Develop New Expert Skills
- **Location**: `.agents/skills/`
- **Format**: `SKILL.md` (Native Antigravity format)
- **Requirement**: Use the migration script or follow the template to define domain expert personas (e.g., BMS Engineer, SoC Architect).
- **Knowledge Linking**: Always include mandatory references to our `knowledge-base/` and `rules/` folders.

### 2. Standardize Engineering Workflows
- **Location**: `.agents/workflows/`
- **Format**: Markdown with YAML frontmatter.
- **Requirement**: Break down complex automotive tasks (e.g., "ASIL-D FSC Review") into repeatable, tool-enabled steps.

### 3. Maintain the Automotive Knowledge Base
- **Location**: `knowledge-base/`
- **Focus Areas**: ISO 26262, MISRA C/C++, AUTOSAR documents, and toolchain migration guides.
- **Contribution**: Keep technical documentation up-to-date and cross-reference them in `SKILL.md` files to ground AI logic in reality.

### 4. Expand the Command Arsenal
- **Location**: `commands/`
- **Format**: Shell scripts (`.sh`) or Python utilities.
- **Focus**: Automotive analysis tools like FMEA generators, ASIL checkers, and CAN-FD matrix exporters.

---

## 📝 Development Workflow

### Setup Your Workspace

```bash
# Clone the repository
git clone https://github.com/dubgyd/automotive-antigravity-agents.git
cd automotive-antigravity-agents

# Use Antigravity to load the skills
# Antigravity will automatically detect .agents/skills/
```

### Contribution Standards

#### Skills (`SKILL.md`)
- Must explicitly state the `Domain` and `Mandatory Knowledge References`.
- Avoid placeholders; provided capabilities must be executable by the AI.

#### Workflows
- Every step should be actionable.
- Use `// turbo` annotations for automation-safe commands.

#### Documentation
- Use GitHub Alerts (`> [!IMPORTANT]`, `> [!WARNING]`) for critical safety info.
- All automotive engineering documents must cite the specific ISO 26262 part number where applicable.

---

## 🔒 Safety & Ethics

Given the safety-critical nature of automotive engineering:
1. **No Hallucinations**: Never submit a skill or knowledge item that generates fake safety metrics.
2. **Review Hierarchy**: Any changes to `rules/` or `knowledge-base/standards/` must be reviewed by the Safety Officer persona before merging.
3. **Data Privacy**: Never commit private vehicle fleet telemetry or OEM-proprietary source code.

## 📜 License

By contributing, you agree that your contributions will be licensed under the MIT License.

## 🙏 Recognition

Contributors help build the future of Software Defined Vehicles (SDV). Thank you for making automotive engineering more accessible and safer! 🚗✨
