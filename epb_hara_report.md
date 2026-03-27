# Hazard Analysis and Risk Assessment (HARA) Report: Electronic Parking Brake (EPB)

**Date:** 2026-03-27
**System:** Electronic Parking Brake (EPB)
**Standards:** ISO 26262:2018 Part 3, SAE J2980:2023
**Analyst:** Functional Safety HARA Specialist

## 1. Item Definition

### 1.1 Overview
The Electronic Parking Brake (EPB) system is responsible for vehicle immobilization and secondary braking. It replaces traditional mechanical levers with an electronic switch and motorized calipers or drum-in-hat actuators.

### 1.2 Core Functions
- **Static Apply (SA):** Clamping the rear brakes when the vehicle is stationary.
- **Static Release (SR):** Releasing the clamping force when requested by the driver.
- **Auto-Release (AR):** Automatically releasing the brake during drive-away based on engine torque and clutch position/tilt.
- **Dynamic Braking (DB):** Controlled deceleration using the parking brake switch while the vehicle is in motion (typically via hydraulic demand to ESC).
- **Secondary Braking (SB):** Emergency mechanical application if the primary hydraulic system fails.

### 1.3 System Boundaries
- **In-Scope:** EPB Switch, EPB ECU (may be integrated with ESC), Actuators (Left/Right Rear), Wiring Harness.
- **Interfaces:** CAN/LIN (Wheel Speed, Accelerometer, Shift Position, Engine Torque), Power Supply, Diagnostic Interface.

## 2. Hazard Identification

### 2.1 Malfunctioning Behaviors (MB)
| ID | Malfunctioning Behavior | Description |
| :--- | :--- | :--- |
| **MB_01** | Unintended Application | EPB applies clamping force without driver request while moving. |
| **MB_02** | Failure to Apply | EPB fails to apply clamping force when requested or needed. |
| **MB_03** | Unintended Release | EPB releases clamping force while vehicle is parked. |
| **MB_04** | Insufficient Force | EPB applies force but fails to meet minimum clamping requirements (e.g., thermal fade). |

## 3. Risk Assessment and ASIL Determination

The following assessment uses the SAE J2980:2023 criteria for Severity (S), Exposure (E), and Controllability (C).

### 3.1 Hazardous Events Table

| HE ID | MB ID | Operational Situation | Hazard Description | S | E | C | ASIL | Safety Goal (SG) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **HE_01** | MB_01 | Highway driving (> 100 km/h) | Sudden lock-up of rear wheels leading to loss of stability or rollover. | S3 | E4 | C3 | **ASIL D** | Prevent unintended EPB application while driving. |
| **HE_02** | MB_01 | Urban driving (20-50 km/h) | Unexpected deceleration leading to rear-end collision. | S2 | E3 | C1 | **ASIL B** | Prevent unintended EPB application while driving. |
| **HE_03** | MB_02 | Parking on steep slope (> 20%) | Vehicle rollaway due to failure to secure wheels. | S3 | E2 | C3 | **ASIL C** | Ensure EPB application capability on request. |
| **HE_04** | MB_03 | Vehicle parked on slope | Unintended rollaway of an unattended vehicle. | S3 | E2 | C3 | **ASIL C** | Prevent unintended release of EPB while parked. |
| **HE_05** | MB_04 | Dynamic Braking during failure | Insufficient secondary braking performance during primary brake failure. | S2 | E1 | C2 | **QM** | Provide secondary braking performance (Non-safety critical in this context). |

### 3.2 Rationale for Classifications

- **HE_01 (ASIL D):** At highway speeds, a full rear lock-up causes immediate yaw instability that an average driver cannot control (C3). Survival is uncertain in rollover or high-speed barrier impacts (S3). Motorway driving is a persistent state (E4).
- **HE_03/HE_04 (ASIL C):** Rollaway of a heavy vehicle on a public slope can lead to fatal injuries to pedestrians (S3). While steep slopes are less frequent than flat ground (E2), the situation is uncontrollable if the driver is not inside (C3).

## 4. Derived Safety Goals

| SG ID | Safety Goal Description | ASIL | Safe State | FTTI |
| :--- | :--- | :--- | :--- | :--- |
| **SG_01** | The EPB system shall prevent unintended application of clamping force while the vehicle velocity is above 5 km/h. | D | Actuator power cut-off / H-bridge inhibition | 500 ms |
| **SG_02** | The EPB system shall prevent unintended release of the parking brake while the vehicle is stationary and parked. | C | Maintain current clamp state | 100 ms |
| **SG_03** | The EPB system shall ensure the ability to apply the parking brake within 2.0s of a valid driver request. | C | N/A (Functional availability) | N/A |

## 5. Summary and Conclusion
Based on the HARA, the most critical hazard for the EPB is **unintended engagement at high speed**, resulting in a safety integrity level of **ASIL D**. Strict architectural partitioning and redundant monitoring are required to prevent this failure mode. Safety goals SG_01 through SG_03 must be decomposed and traced to technical safety requirements.
