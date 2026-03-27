# HAZOP Analysis Guideline for Automotive Safety

This guideline provides the methodology for systematic hazard identification using HAZOP (Hazard and Operability Study) in accordance with the spirit of ISO 26262.

## 1. HAZOP Guide Words

Apply these guide words to each function of the system to identify malfunctioning behaviors.

| Guide Word | Interpretation in Automotive Context | Examples |
| :--- | :--- | :--- |
| **No / Loss** | Function is not provided when requested | Failure to apply brake, No steering assist |
| **More / Unintended** | Function is provided without request or in excess | Unintended acceleration, Excess clamping torque |
| **Less / Insufficient** | Function is provided but below required threshold | Partial braking power, Weak steering assist |
| **As Well As** | Function is provided along with unintended actions | Braking with unintended lane keeping intervention |
| **Part Of** | Only a portion of the intended function is achieved | Braking on only one wheel instead of four |
| **Reverse** | Function acts in the opposite intended direction | Electronic throttle opens when closing commanded |
| **Other Than** | Completely different behavior from intended | Infotainment audio playing in safety-critical speakers |
| **Early / Late** | Timing issue: operation starts before or after needed | Airbag deployed after collision event |
| **Intermittent** | Function cycles on and off unintentionally | Pulsing brake pressure without ABS request |

## 2. HAZOP Workflow

1.  **Define Items & Functions**: List every function of the system (from Item Definition).
2.  **Apply Guide Words**: For each function, apply every guide word to generate potential malfunctioning behaviors (MB).
3.  **Filter MBs**: Remove duplicates or physically impossible behaviors.
4.  **HARA Mapping**: Each validated MB becomes a candidate for Hazard Analysis.

## 3. Example: EPB Clamping Function

- **Function**: Apply mechanical clamping force to rear wheels to hold vehicle stationary.
- **No**: Failure to apply clamping force (H-EPB-002).
- **More**: Unintended application of clamping force (H-EPB-001).
- **Less**: Insufficient clamping force (H-EPB-004).
- **Late**: Delayed clamping (H-EPB-005).
- **Intermittent**: Oscillating clamping force.
