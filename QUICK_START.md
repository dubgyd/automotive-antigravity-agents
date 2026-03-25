# Quick Start Guide - Automotive Antigravity Workspace

Welcome to the newly ported Automotive Engineering Antigravity Workspace. Because you are running natively on Antigravity, **Zero configuration or installation is required.**

---

## 1. How to use an Automotive Expert (Persona)

You now have 86 Automotive expert agents available to you. You do not need to "run" or "generate" them anymore—they are seamlessly integrated into the Antigravity `/.agents/skills/` infrastructure.

Just talk to Antigravity normally, and mention the domain you want:
> *"Using your functional safety auditor skill, please conduct a technical review of this ISO 26262 Concept Document..."*
> 
> *"Act as the AUTOSAR Adaptive Expert and write the `ara::com` service bindings for a Camera module."*

The system will automatically load the appropriate `.agents/skills/SKILL.md`, reading its associated MISRA rules and reference architectures.

---

## 2. Triggering Professional Automotive Workflows

We have securely ported 86 Automotive Standard Operating Procedures (SOPs) into the platform.

You can instantly trigger complex, multi-step engineering reviews by referencing them via Slash Commands or conversational prompts:

- `/adas-perception-validation`: Runs the comprehensive ADAS algorithms test protocol.
- `/safety-compliance-iso26262-v-model`: Starts the rigorous V-Model safety process.
- `/diagnostics-uds-service-implementation`: Begins ISO 14229 UDS diagnostic code generation.

### Example Workflow:
> *"Please execute the `/battery-thermal-analysis` workflow on the attached battery pack specification PDF."*

The platform will autonomously read the markdown workflow step-by-step from `.agents/workflows/` and process it.

---

## 3. Extending the Knowledge Base

Because Antigravity operates directly on your local file system, if you want to teach your AI experts a new automotive skill:
1. Drop the PDF/Markdown reference into the `knowledge-base/` folder.
2. The AI will instantly factor it in the next time it plans an execution phase.

Enjoy your ultimate Automotive AI Copilot! 🏎️⚡
