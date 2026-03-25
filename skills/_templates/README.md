## Automotive Agent Templates

This directory contains templates for creating new automotive domain skills, agents, and workflows.

### Templates

1. **skill-template.yaml** - Base template for automotive skills
   - Comprehensive structure for domain expertise
   - Includes automotive standards and compliance
   - Example code snippets and usage patterns

2. **agent-template.yaml** - Base template for automotive agents
   - Complete agent definition with system prompts
   - Workflow and collaboration patterns
   - Performance metrics and quality gates

3. **workflow-template.yaml** - Base template for automotive workflows
   - Multi-stage development lifecycle
   - Quality gates and compliance mapping
   - ISO 26262 and ASPICE alignment

### Using Templates

#### Create a New Skill

1. Copy skill-template.yaml to appropriate category directory
2. Update name, category, subcategory
3. Fill in domain-specific knowledge areas
4. Provide detailed instructions with examples
5. Define constraints and tools required
6. Add related skills and integration points

Example:
```bash
cp skills/_templates/skill-template.yaml skills/powertrain/battery-thermal-management.yaml
# Edit battery-thermal-management.yaml with specific content
```

#### Create a New Agent

1. Copy agent-template.yaml to appropriate agent directory
2. Define agent role and expertise
3. Craft comprehensive system prompt
4. Specify skills and proficiency levels
5. Define workflows and collaboration patterns

Example:
```bash
cp skills/_templates/agent-template.yaml agents/battery/bms-architect.yaml
# Edit bms-architect.yaml with role-specific details
```

#### Create a New Workflow

1. Copy workflow-template.yaml to workflows directory
2. Define workflow stages and dependencies
3. Specify quality gates at each stage
4. Map to compliance requirements (ISO 26262, ASPICE)
5. Define inputs, outputs, and deliverables

Example:
```bash
cp skills/_templates/workflow-template.yaml workflows/adas-development-lifecycle.yaml
# Edit with ADAS-specific stages and gates
```

### Automated Generation

For bulk skill/agent creation, use the generation scripts:

```bash
# Generate all skills across automotive domains
python3 scripts/generate_skills.py

# Generate orchestration pattern agents
python3 scripts/generate_orchestration_agents.py

# Generate domain-specific perspective agents
python3 scripts/generate_domain_agents.py

# Generate everything
python3 scripts/generate_all.py
```

### Skill Taxonomy

Skills are organized by automotive domain:
- **dynamics** - Vehicle dynamics, handling, stability
- **powertrain** - ICE, hybrid, EV propulsion
- **adas** - Advanced driver assistance systems
- **body** - Body control and comfort
- **infotainment** - HMI, connectivity, audio
- **lighting** - Exterior/interior lighting
- **hvac** - Climate control systems
- **chassis** - Brake, suspension, steering
- **safety** - Functional safety (ISO 26262)
- **security** - Cybersecurity (ISO 21434)
- **diagnostics** - OBD, UDS, diagnostics
- **network** - CAN, Ethernet, FlexRay
- **autosar** - Classic and Adaptive AUTOSAR
- **testing** - HIL, SIL, validation
- **calibration** - Parameter tuning
- **v2x** - Vehicle-to-everything communication
- **cloud** - Cloud connectivity and services
- **mbd** - Model-based design
- **embedded** - RTOS, microcontroller
- **battery** - BMS, thermal, charging

### Agent Categories

Agents are organized by function:
- **adas** - ADAS specialists
- **autosar** - AUTOSAR experts
- **battery** - Battery system experts
- **calibration** - Calibration engineers
- **core** - Core system agents
- **diagnostics** - Diagnostic specialists
- **orchestration** - Workflow orchestrators
- **safety** - Safety engineers
- **security** - Security experts
- **testing** - Test engineers
- **tools** - Tool specialists
- **oem** - OEM perspective agents
- **tier1** - Tier 1 supplier agents
- **tier2** - Tier 2 supplier agents
- **product-owner** - Product owners
- **specialists** - Domain specialists

### Quality Standards

All skills and agents must:
- Follow ISO 26262 functional safety principles
- Align with ASPICE process requirements
- Support AUTOSAR architecture patterns
- Address ISO 21434 cybersecurity concerns
- Include traceability and compliance evidence
- Provide validation and verification criteria

### Contribution Guidelines

When creating new skills/agents:
1. Use templates as starting point
2. Fill all required sections completely
3. Provide concrete examples with code
4. Reference automotive standards
5. Define clear success criteria
6. Include related skills/agents
7. Add appropriate tags for discoverability

### Version Control

- Template version: 1.0.0
- Update templates when adding new required fields
- Maintain backward compatibility
- Document breaking changes in CHANGELOG.md
