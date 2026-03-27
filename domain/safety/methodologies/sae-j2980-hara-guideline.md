# SAE J2980:2023 HARA Guideline

This document provides guidelines for performing Hazard Analysis and Risk Assessment (HARA) according to SAE J2980 (revised October 2023). It focuses on standardizing the classification of Severity, Exposure, and Controllability to reduce subjectivity in ASIL determination.

## 1. Severity Classification (S)

Classification of the potential harm to the vehicle's occupants or other road users.

| Level | Classification | Description | Typical Injury |
| :--- | :--- | :--- | :--- |
| **S0** | No Injuries | No physical injury to individuals. | Emotional distress, discomfort. |
| **S1** | Light and Moderate | Light and moderate injuries; survival probable. | Whiplash, minor fractures, bruises. |
| **S2** | Severe and Life-Threatening | Severe and life-threatening injuries; survival probable. | Internal injuries, multiple rib fractures. |
| **S3** | Fatal | Life-threatening injuries; survival uncertain or fatal. | Severe head trauma, fatal impact. |

## 2. Exposure Classification (E)

Probability of being in an operational situation where the malfunctioning behavior can result in a hazard.

| Level | Probability | Definition | Occurrence Frequency |
| :--- | :--- | :--- | :--- |
| **E0** | Incredible | Extremely unlikely; occurrence less than once in vehicle life. | < 0.1% of operating time. |
| **E1** | Very Low | Rare; occurrence in few vehicles. | 0.1% to 1% of time. |
| **E2** | Low | Occasional; occurrence periodic in vehicle life. | 1% to 10% of time. |
| **E3** | Medium | Frequent; occurrence regularly in vehicle life. | 10% to 50% of time. |
| **E4** | High | Almost certain; occurrence in nearly all trips. | > 50% of operating time. |

## 3. Controllability Classification (C)

Likelihood that the driver or other road users can avert the hazard.

| Level | Classification | Description | Success Probability |
| :--- | :--- | :--- | :--- |
| **C0** | Simply Controllable | Controllable in all cases by an average driver. | ~100% |
| **C1** | Lightly Controllable | Controllable by a majority of drivers. | > 99% |
| **C2** | Normally Controllable | Controllable by a normal driver with common skills. | > 90% |
| **C3** | Difficult to Control | Difficult to control or uncontrollable by most drivers. | < 90% |

## 4. Derived ASIL Matrix

| S | E | C1 | C2 | C3 |
| :--- | :--- | :--- | :--- | :--- |
| **S1** | **E1** | QM | QM | QM |
| | **E2** | QM | QM | QM |
| | **E3** | QM | QM | ASIL A |
| | **E4** | QM | ASIL A | ASIL B |
| **S2** | **E1** | QM | QM | QM |
| | **E2** | QM | QM | ASIL A |
| | **E3** | QM | ASIL A | ASIL B |
| | **E4** | ASIL A | ASIL B | ASIL C |
| **S3** | **E1** | QM | QM | ASIL A |
| | **E2** | QM | ASIL A | ASIL B |
| | **E3** | ASIL A | ASIL B | ASIL C |
| | **E4** | ASIL B | ASIL C | ASIL D |

## 5. SAE J2980:2023 Specific Updates
- **Commercial Vehicles**: Guidance for Class 6-8 heavy-duty vehicles.
- **Autonomy Levels**: Considerations for Level 0-2 driver support systems.
- **Improved Calibration**: Refined success probability percentages for Controllability levels.
