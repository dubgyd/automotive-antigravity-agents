# Battery Lifecycle Skills

Comprehensive battery recycling and second-life skills for automotive EV batteries covering full end-of-life value chain.

## Overview

20 expert-level skills organized into:
- **Battery Recycling (12 skills)**: Complete recycling value chain from collection to material recovery
- **Second-Life Batteries (8 skills)**: Repurposing EV batteries for stationary energy storage

## Battery Recycling Skills

1. **recycling-overview.yaml** (168 lines)
   - Battery recycling landscape: collection, logistics, pre-processing, material recovery routes
   - Regulatory drivers: EU Regulation, EPR, collection/recycling targets
   - Economics: Cost models, break-even analysis, environmental impact

2. **pyrometallurgy-process.yaml** (265 lines)
   - Smelting-based recycling: rotary kiln, blast furnace processes
   - Copper-cobalt-nickel alloy recovery (95-99% efficiency)
   - Slag treatment, energy balance (15-25 MWh/ton), off-gas abatement
   - Pros/cons vs other routes

3. **hydrometallurgy-process.yaml** (339 lines)
   - Acid leaching (H2SO4, HCl), solvent extraction circuits
   - Selective Co/Ni/Mn/Li separation using Cyanex 272
   - Precipitation: Battery-grade CoSO4, NiSO4, Li2CO3
   - Energy: 5-10 MWh/ton, 90-98% recovery efficiency

4. **direct-recycling.yaml** (324 lines)
   - Cathode-to-cathode recycling preserving crystal structure
   - Relithiation: Solid-state, molten salt, electrochemical routes
   - 70-85% energy savings vs conventional recycling
   - Chemistry-specific (NMC811 ideal, LFP not economical)

5. **black-mass-processing.yaml** (320 lines)
   - Mechanical shredding: Primary/secondary/tertiary stages
   - Fire prevention: Cryogenic (LN2), inert atmosphere, water immersion
   - Separation: Magnetic, eddy current, air classification
   - Quality grading: Premium (>55% cathode) vs standard vs low grade

6. **lithium-recovery.yaml** (330 lines)
   - Lithium extraction from brine, spodumene, recycled batteries
   - Li2CO3 precipitation from leach raffinate (94% yield)
   - LiOH production via Ca(OH)2 or electrochemical routes
   - Battery-grade specs: >99.5% purity, <20 ppm Na

7. **cobalt-nickel-recovery.yaml** (356 lines)
   - Solvent extraction with Cyanex 272 (pH-selective)
   - Co-Ni co-extraction then differential stripping (Co at pH 3.2, Ni at pH 1.8)
   - Crystallization: CoSO4·7H2O, NiSO4·6H2O to battery-grade
   - Economics: $12k revenue per ton NMC811 black mass

8. **battery-disassembly-automation.yaml** (313 lines)
   - Robotic disassembly: Pack opening, module extraction, cell removal
   - High-voltage safety: Discharge, lockout, voltage verification
   - Vision systems: Barcode, X-ray, 3D cameras for pack inspection
   - Economics: $10-19 per pack automated vs $30-60 manual

9. **eu-battery-regulation.yaml** (259 lines)
   - EU Regulation 2023/1542 compliance roadmap
   - Battery passport (mandatory 2027), recycled content targets (12% Co by 2027)
   - Carbon footprint declaration (2024), EPR collection targets
   - Implementation costs: €1-3M one-time, €60-175 per battery

10. **battery-passport-implementation.yaml** (45 lines)
    - GBA data model, QR code generation, blockchain traceability
    - MES/PLM integration for automated data capture
    - Multi-level access control (public, OEM, recycler)
    - Cost: €10-30 per battery

11. **recycling-economics.yaml** (42 lines)
    - CAPEX/OPEX models: Mechanical, hydro, pyro routes
    - Break-even analysis by chemistry (NMC vs LFP)
    - Commodity price sensitivity (Co ±50%/year volatility)
    - NPV, IRR, Monte Carlo uncertainty quantification

12. **recycling-environmental-impact.yaml** (44 lines)
    - LCA: Recycled Co/Ni/Li carbon footprint 60-70% lower vs virgin
    - Energy balance: Pyro 15-25 MWh/ton, hydro 5-10, direct 2-5
    - Water usage: Hydro 10-50 m³/ton vs brine 500+ m³/ton Li
    - ISO 14040/14067 compliance for battery passport

## Second-Life Battery Skills

13. **second-life-overview.yaml** (44 lines)
    - Repurposing 70-85% SOH EV batteries for stationary ESS
    - Market: 75-150 GWh/year by 2030, $15-30B opportunity
    - Applications: Grid services, C&I peak shaving, residential backup
    - Business models: Sale, lease, BaaS, revenue sharing

14. **soh-grading-classification.yaml** (45 lines)
    - SOH assessment: EIS (15-30 min, ±5%), HPPC (2-4 hr, ±8%), capacity test (3-5 hr, ±2%)
    - Grading: A (80-90% SOH), B (65-80%), C (50-65%), F (<50% recycle)
    - Automated testing: Robot handling, CAN communication, ML prediction
    - Cost-accuracy tradeoff: EIS $20/module vs capacity $50/module

15. **stationary-ess-integration.yaml** (44 lines)
    - Grid-scale ESS: Frequency regulation, peak shaving, renewable firming
    - Containerized design: 500-2000 kWh per 20/40-foot container
    - Economics: $150-300/kWh CAPEX, $50-200/kW-year revenue
    - NFPA 855, UL 9540, IEEE 1547 compliance

16. **residential-ess.yaml** (44 lines)
    - Home storage: 5-20 kWh systems, solar self-consumption, TOU arbitrage
    - AC vs DC coupling, 48V vs 400V systems
    - DIY: $100-200/kWh vs commercial $600-900/kWh
    - UL 1973, UL 1741, NEC Article 706 requirements

17. **module-remanufacturing.yaml** (45 lines)
    - Cell replacement: Remove weak cells, spot weld new cells
    - BMS reprogramming: Voltage limits, SOC recalibration
    - Cost: $30-60/kWh remanufacturing, sell $100-180/kWh
    - Warranty: 3-5 years or 2000 cycles

18. **v2g-second-life.yaml** (44 lines)
    - Aggregated VPP: 100-1000 second-life packs as stationary V2G nodes
    - Degradation-aware dispatch: Bid when revenue > degradation cost
    - Revenue: $70-150/kW-year (frequency + capacity + energy)
    - Cloud platform: Real-time telemetry, predictive SOH

19. **capacity-fade-prediction.yaml** (44 lines)
    - RUL prediction: LSTM, GPR, XGBoost models (±3-7% accuracy)
    - Knee-point detection: Sudden fade acceleration at 70-85% SOH
    - Online prognostics: Edge deployment, 100-cycle updates
    - Use cases: Warranty reserves, residual value, fleet optimization

20. **circular-economy-models.yaml** (44 lines)
    - BaaS: Customer pays per kWh, OEM retains ownership
    - Cascade use: EV (8-12 yr) → stationary (5-10 yr) → recycling
    - Material flow analysis: 5% current circularity, 12-26% Co by 2035
    - Metrics: Collection rate, recovery efficiency, carbon footprint

## Technical Depth

- **168-356 line skills**: Full technical detail with Python examples, process flow diagrams, chemical reactions, economic models
- **42-45 line skills**: Condensed format with comprehensive coverage in compact form
- All skills include: name, version, category, domain, subcategory, description, use_cases, automotive_standards, instructions, constraints, tools_required, metadata, tags

## Standards Covered

- EU Battery Regulation 2023/1542
- ISO 14040/14044 (LCA), ISO 14067 (Carbon Footprint)
- IEC 62933, UL 9540, NFPA 855 (Energy Storage Safety)
- ISO 9001 (Quality), ISO 14001 (Environmental)
- GBA Battery Passport, IEEE 1547, IEC 61850

## Total Content

- 3159 lines across 20 skills
- Python code examples for process modeling
- Real-world case studies (Redwood, Li-Cycle, Northvolt, Nissan xStorage, etc.)
- Economic models (CAPEX, OPEX, NPV, break-even)
- Comprehensive automotive battery lifecycle expertise
