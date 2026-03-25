# New Automotive Skills Domains

## Overview

This directory contains **65 comprehensive skill files** across **3 new automotive domains**, created on 2026-03-19 to extend the automotive-claude-code-agents repository with advanced materials science, OEM strategic decision-making, and global regulatory compliance expertise.

## Directory Structure

```
skills/
├── advanced-materials/          (25 files) - Materials science & engineering
├── oem-decision-making/         (20 files) - Executive strategy & operations
├── regulatory-compliance/       (20 files) - Global automotive regulations
├── NEW_DOMAINS_SUMMARY.md       - Detailed domain breakdown
└── SKILLS_INVENTORY.txt         - Complete file listing
```

## Domain Summaries

### 1. Advanced Materials (25 files)

**Path**: `skills/advanced-materials/`

Comprehensive coverage of automotive materials science, from smart materials to structural components.

**Categories**:
- **Smart Materials** (4): Shape memory alloys, piezoelectric, magneto-rheological fluids, electroactive polymers
- **Structural Materials** (4): CFRP composites, AHSS steel, magnesium/aluminum alloys and joining
- **Functional Materials** (5): Thermoelectric, graphene, aerogel, self-healing coatings, metamaterials
- **Sustainable Materials** (3): Bio-based plastics, anti-microbial surfaces, nanomaterials
- **Engineering Analysis** (4): Multi-material design, corrosion, fatigue, crashworthiness
- **Specialty Materials** (5): Thermal interface, acoustic, glass, rubber, adhesives

**Key Applications**:
- Active aerodynamic actuators (SMA grille shutters)
- Energy harvesting (piezo TPMS, TEG exhaust recovery)
- Adaptive suspension (MR fluid dampers)
- Lightweight structures (CFRP, Mg alloys)
- Battery thermal management (TIM, aerogel insulation)

**Standards Covered**: LV 124, ISO 16750, USCAR-2, ASTM D standards, SAE materials specs

**Tools**: ANSYS, COMSOL Multiphysics, MATLAB, Python (SciPy, NumPy), MTS/Instron test equipment

---

### 2. OEM Decision Making (20 files)

**Path**: `skills/oem-decision-making/`

Strategic frameworks and decision methodologies for automotive OEMs and Tier-1 suppliers navigating industry transformation.

**Categories**:
- **Strategic Planning** (4): Platform strategy, stage-gate, make-vs-buy, PLM
- **Financial Analysis** (4): CapEx/OpEx optimization, M&A strategy, S&OP, warranty analytics
- **Innovation & IP** (3): IP management, digital transformation, monetization models
- **Supply Chain** (3): Supply chain strategy, talent/workforce, competitive benchmarking
- **Market & Brand** (2): Brand positioning, regional adaptation
- **Governance** (4): ESG, data sovereignty, cybersecurity governance, JV partnerships

**Key Applications**:
- Platform and modular architecture strategies
- Technology roadmapping for electrification/autonomy
- TCO modeling for make-vs-buy decisions
- Subscription and features-on-demand monetization
- Carbon neutrality roadmap and ESG reporting

**Standards Covered**: ISO 9001, IATF 16949, APQP, PPAP, GRI sustainability reporting

**Tools**: Excel/Python (financial modeling), PowerBI/Tableau (dashboards), MS Project/Jira, SAP/Oracle ERP

---

### 3. Regulatory Compliance (20 files)

**Path**: `skills/regulatory-compliance/`

Global automotive regulations covering emissions, safety, cybersecurity, and type approval processes.

**Categories**:
- **Battery & EV** (4): EU Battery Regulation, Battery Passport (DPP), EPR, EV safety (UN R100/R136)
- **Emissions & Environment** (6): WLTP, Euro 7, EPA CAFE, China NEV, noise (R51), ELV Directive
- **Type Approval** (3): Homologation process, type approval workflow, functional safety homologation
- **Cybersecurity & Software** (3): UN R155 (CSMS), UN R156 (SUMS), data privacy (GDPR)
- **ADAS & Autonomous** (3): UN R157 (ALKS), ADAS regulation (Euro NCAP, GSR), AV frameworks
- **Material Compliance** (1): RoHS/REACH restricted substances

**Key Applications**:
- Digital Battery Passport (DPP) implementation per GBA standard
- CSMS certification for UN R155 type approval
- WLTP test procedure execution and CO2 reporting
- Euro 7 RDE testing and OBD monitoring
- Battery regulation 2023/1542 compliance roadmap

**Standards Covered**: UNECE WP.29, EU Type Approval, FMVSS, GB Standards (China), ISO 26262, ISO 21434

**Tools**: WLTP chassis dyno, PEMS (RDE), CANalyzer/CANoe, document management systems, regulatory tracking software

---

## File Structure

Each skill file follows this standardized YAML format:

```yaml
name: skill-name
version: 1.0.0
category: domain-category
domain: automotive
subcategory: specific-area
description: Brief description of the skill
use_cases:
- Practical application 1
- Practical application 2
- ...
automotive_standards:
- Standard 1
- Standard 2
- ...
instructions: |
  ## Core Competencies
  [Detailed technical content 80-150 lines]

  ### Key Topics
  - Topic 1 with details
  - Topic 2 with details

  ## Approach
  1. Step-by-step methodology
  2. ...

  ## Deliverables
  - Report/document 1
  - ...

  ## Best Practices
  - Practice 1
  - ...

constraints:
- Real-world limitation 1
- Real-world limitation 2
- ...
tools_required:
- Tool/software 1
- Tool/software 2
- ...
metadata:
  author: Automotive Claude Code Agents
  last_updated: '2026-03-19'
  maturity: production
  complexity: advanced
tags:
- category
- specific-tag-1
- specific-tag-2
- automotive
```

## Content Highlights

### Advanced Materials - Code Examples

Several skills include production-ready Python code:

**Shape Memory Alloys** (`shape-memory-alloys.yaml`):
- Thermal dynamics simulation for SMA wire actuators
- Force-displacement modeling with temperature dependency
- Control algorithm examples (PWM, PID)

**Piezoelectric Materials** (`piezoelectric-materials.yaml`):
- Power output calculation with impedance matching
- Optimal load resistance for energy harvesting
- TPMS energy harvester design example

**Thermoelectric Materials** (`thermoelectric-materials.yaml`):
- TEG performance modeling with figure of merit (ZT)
- Efficiency calculations based on Carnot limits
- Exhaust waste heat recovery optimization

**Magneto-Rheological Fluids** (`magneto-rheological-fluids.yaml`):
- Bingham plastic model for damper force
- Skyhook control algorithm for adaptive suspension
- Electromagnetic FEA optimization workflow

### OEM Decision Making - Frameworks

**Strategic Planning** includes:
- Porter's Five Forces industry analysis
- PESTLE framework for macro-environmental scanning
- Scenario planning for mobility trends (electrification, autonomy, shared mobility)
- Technology roadmapping aligned with regulatory drivers

**Financial Analysis** covers:
- NPV, IRR, payback period calculations
- Real options valuation for flexibility in uncertain environments
- Monte Carlo simulation for risk assessment
- Sensitivity analysis for business case stress-testing

**Make vs Buy Analysis** provides:
- Core competency assessment matrices
- TCO modeling with hidden costs (quality, logistics, IP)
- Vertical integration decision trees
- Risk-adjusted return on investment (RAROI) frameworks

### Regulatory Compliance - Standards

**UN R155 Cybersecurity** (`un-r155-compliance.yaml`):
- CSMS (Cyber Security Management System) certification workflow
- Annex 5 threat catalog mapping to vehicle architecture
- Evidence documentation for type approval submission
- Ongoing monitoring and incident response procedures

**Battery Passport** (`battery-passport-compliance.yaml`):
- Digital Product Passport (DPP) data model per GBA standard
- QR code and NFC implementation for battery traceability
- API integration for supply chain data exchange
- Compliance with EU Battery Regulation 2023/1542

**WLTP Testing** (`wltp-testing.yaml`):
- WLTP cycle phase breakdown (low, medium, high, extra-high)
- CO2 calculation methodology and reporting
- Correlation between WLTP and real-world fuel consumption
- Test facility requirements and witness testing procedures

## Integration with Existing Skills

These new domains complement the existing automotive skills ecosystem:

| New Domain | Existing Domains | Integration Points |
|------------|------------------|-------------------|
| **Advanced Materials** | `ev-tools`, `vehicle-dynamics`, `powertrain` | Battery thermal materials, suspension damping, lightweight structures |
| **OEM Decision Making** | `project-management`, `system-architecture`, `cost-optimization` | Platform strategy, modular design, TCO analysis |
| **Regulatory Compliance** | `functional-safety`, `cybersecurity`, `diagnostics` | ISO 26262 homologation, UN R155, OBD emissions |

## Usage Examples

### Example 1: MR Damper Design Workflow

Combine multiple skills:
1. `magneto-rheological-fluids.yaml` - MR damper design and control
2. `vehicle-dynamics/suspension-control.yaml` - Skyhook control tuning
3. `functional-safety/iso-26262-asil.yaml` - ASIL assessment for safety-critical damper
4. `regulatory-compliance/type-approval-workflow.yaml` - Homologation submission

### Example 2: Battery Passport Implementation

Skill sequence:
1. `eu-battery-regulation-compliance.yaml` - Understand Regulation 2023/1542 requirements
2. `battery-passport-compliance.yaml` - Implement DPP data model and QR codes
3. `epr-extended-producer.yaml` - Set up recycling compliance and reporting
4. `data-sovereignty.yaml` - Ensure GDPR compliance for battery data exchange

### Example 3: Lightweight Vehicle Program

Materials selection workflow:
1. `multi-material-design.yaml` - Material selection matrices (steel, aluminum, CFRP, Mg)
2. `cfrp-composites.yaml` - CFRP structural design and RTM manufacturing
3. `aluminum-joining.yaml` - Friction stir welding for Al body-in-white
4. `crashworthiness-materials.yaml` - LS-DYNA simulation for crash energy absorption
5. `corrosion-engineering.yaml` - Galvanic corrosion prevention for dissimilar materials

## Standards Reference

### Materials Standards
- **LV 124**: Electrical environmental conditions for automotive components
- **ISO 16750**: Environmental conditions and testing for electrical/electronic equipment
- **USCAR-2**: Performance requirements for automotive components
- **ASTM D**: Plastics, rubber, and composite material testing standards
- **SAE J**: Materials, actuators, and component specifications

### Quality & Process Standards
- **ISO 9001**: Quality management systems
- **IATF 16949**: Automotive quality management system requirements
- **APQP**: Advanced Product Quality Planning
- **PPAP**: Production Part Approval Process
- **VDA**: German automotive industry standards (VDA 6.3, VDA 6.5)

### Regulatory Standards
- **UNECE WP.29**: World Forum for Harmonization of Vehicle Regulations
  - UN R100: Electric vehicle safety
  - UN R155: Cybersecurity Management System (CSMS)
  - UN R156: Software Update Management System (SUMS)
  - UN R157: Automated Lane Keeping Systems (ALKS)
- **EU Type Approval**: European vehicle homologation framework
- **FMVSS**: Federal Motor Vehicle Safety Standards (USA)
- **GB Standards**: Chinese national standards (GB/T, GB)

### Emissions & Environmental
- **WLTP**: Worldwide harmonized Light vehicles Test Procedure
- **RDE**: Real Driving Emissions testing (Euro 6d)
- **EPA/CAFE**: Corporate Average Fuel Economy (USA)
- **China 6**: Chinese emission standards (6a, 6b)
- **ELV Directive**: End-of-Life Vehicles 2000/53/EC

## Tools & Software Ecosystem

### Materials Simulation
- **ANSYS**: Structural FEA, thermal, electromagnetic, fluids (CFD)
- **COMSOL Multiphysics**: Coupled physics simulation (thermal-electrical, magneto-mechanical)
- **LS-DYNA**: Explicit dynamics for crash and impact simulation
- **MATLAB/Simulink**: Control algorithms, material modeling, data analysis
- **Python**: NumPy, SciPy, Matplotlib for custom material models

### Mechanical Testing
- **MTS**: Servo-hydraulic test systems for fatigue, impact, damper characterization
- **Instron**: Universal testing machines for tensile, compression, flexure
- **Thermal chamber**: Environmental testing (-40°C to +150°C)
- **Vibration table**: Random and sine vibration per LV 124
- **SEM/EDX**: Scanning electron microscopy for microstructure analysis

### Strategic Planning & Analysis
- **Excel/Python**: Financial models, scenario analysis, Monte Carlo simulation
- **PowerBI/Tableau**: KPI dashboards, data visualization, executive reporting
- **MS Project/Jira**: Roadmap planning, task tracking, gate reviews
- **SAP/Oracle**: ERP systems for financial data, supply chain, procurement
- **Decision tree software**: PrecisionTree, TreeAge for multi-criteria analysis

### Regulatory & Testing
- **WLTP chassis dyno**: AVL Zöllner, Horiba STARS for emissions testing
- **PEMS**: Portable Emissions Measurement System for RDE testing
- **CANalyzer/CANoe**: Vector tools for vehicle diagnostics and data logging
- **Document management**: SharePoint, ENOVIA for type approval documentation
- **Regulatory tracking**: LexisNexis, DecisionEngine for regulatory monitoring

### PLM & Collaboration
- **Teamcenter**: Siemens PLM for BOM management, change control
- **Windchill**: PTC PLM platform for product data management
- **CATIA/NX**: 3D CAD for vehicle design and digital mockup
- **JIRA/Confluence**: Agile project management and knowledge base
- **GitHub/GitLab**: Version control for software and documentation

## Validation & Testing

All skill files have been validated for:
- ✓ YAML syntax correctness
- ✓ Required field completeness (name, version, category, standards, instructions, constraints, tools, metadata, tags)
- ✓ Instruction length (80-150 lines of substantive content)
- ✓ Automotive standards relevance
- ✓ Tools/software applicability

## Contributing

To add new skills or enhance existing ones:

1. Follow the established YAML structure (see template above)
2. Include 80-150 lines of technical instructions with:
   - Core competencies section
   - Approach (10-step methodology)
   - Deliverables list
   - Best practices
   - Integration with automotive systems
3. Reference 4+ relevant automotive standards
4. List 5 industry-standard tools/software
5. Add 4 real-world constraints
6. Include code examples where applicable (Python preferred)
7. Tag appropriately for searchability

## Future Enhancements

Planned additions:
- **Example projects**: Full implementations (MR damper design, battery passport, WLTP test plan)
- **Agent integration**: Link skills to specialized agents (materials-engineer, regulatory-specialist, strategy-consultant)
- **Workflow automation**: Commands for common workflows (homologation-submit, material-selection, TCO-analysis)
- **Knowledge base**: Standards reference documents, regulatory timelines, supplier databases

## Statistics

- **Total skill files**: 65 (25 materials + 20 strategy + 20 regulatory)
- **Total lines of content**: ~6,500 lines
- **Standards referenced**: 40+ (ISO, UNECE, SAE, ASTM, VDA, EU, GB)
- **Tools covered**: 50+ (simulation, testing, PLM, financial, regulatory)
- **Use cases**: 325 (5 per skill)
- **Maturity level**: Production-ready
- **Complexity**: Advanced (expert-level content)

## Support & Resources

- **Repository**: automotive-claude-code-agents
- **Created**: 2026-03-19
- **Author**: Automotive Claude Code Agents
- **License**: See repository LICENSE file
- **Issues**: Report via repository issue tracker

---

**Last Updated**: 2026-03-19
**Version**: 1.0.0
**Status**: Production
