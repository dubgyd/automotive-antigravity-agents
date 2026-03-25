<h1 align="center">Automotive Antigravity Workspace</h1>

<p align="center">
  <strong>Native Automotive Domain AI Engineering Copilot</strong>
</p>

---

## 🚀 The Next-Generation Automotive AI Platform

Automotive software engineering (ISO 26262, AUTOSAR, MISRA, Cybersecurity) is highly complex. The **Automotive Antigravity Workspace** provides you with a fully localized, intelligent engineering matrix.

This project has been fully migrated from its legacy "Claude Code" Python wrapper framework. It now runs natively on the **Antigravity Platform**, bringing **86+ Automotive Expert AI Personas** and professional workflows natively into your IDE/terminal.

Instead of writing REST API wrappers for AI, the native Antigravity agent possesses supreme OS-level execution rights and semantic understanding.

---

## 📂 Current Optimized Project Structure

The project has been aggressively streamlined. All obsolete AI generation scripts, docker containers, and python wrappers have been moved to `.claude_archive/`.

```text
automotive-antigravity-workspace/
├── .agents/                 # [CORE] The Antigravity AI Engine
│   ├── skills/              # 86 Native Auto Domain Experts (e.g., ADAS, Safety, AUTOSAR)
│   └── workflows/           # 86 Native SOPs & Workflows (e.g., FMEA, HIL Testing)
├── knowledge-base/          # [KNOWLEDGE] Domain reference documents (ISO 26262/SOTIF papers)
├── rules/                   # [RULES] Strict C/C++ coding rules (MISRA, CERT)
├── examples/                # [DEMOS] High-quality scaffolding code and templates
└── commands/                # [EXECUTION] Engineering Bash/Python scripts
```

### Why is this powerful?
Every time an Antigravity AI Agent is invoked to write code or review a document, its `SKILL.md` persona **forces** the AI to cross-reference the `knowledge-base/` ISO documents and the `rules/` MISRA strictures. This guarantees automotive-grade compliance without generic AI hallucinations.

---

## ⚡ Domains Covered

1. **ADAS / Autonomous Driving**: Sensor fusion, perception pipelines, path planning, L0-L5 control.
2. **AUTOSAR Classic & Adaptive**: SWC scaffolding, RTE generation, BSW config.
3. **Functional Safety**: ISO 26262 HARA templates, FMEA/FTA generation, ASIL decomposition.
4. **Cybersecurity**: ISO/SAE 21434 TARA analysis, secure boot chains.
5. **Battery & EV Systems**: BMS algorithms, SOC/SOH estimation.

---

## 🔧 Deprecation Notice
If you are coming from the V1 `automotive-claude-code-agents` branch:
* `install.sh`, `scripts/generate_all.py`, and Dockerfiles are strictly **DEPRECATED**. 
* Do not run `npm install` or configure Anthropic API keys. Your Antigravity environment is zero-setup.
