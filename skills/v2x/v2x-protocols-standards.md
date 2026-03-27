# V2X Protocols and Standards

## Overview
Comprehensive guide to V2X (Vehicle-to-Everything) communication protocols, comparing DSRC/802.11p and C-V2X technologies, covering SAE J2735, ETSI ITS-G5, 5GAA specifications, and cooperative perception messages.

## Technology Comparison: DSRC vs C-V2X

### DSRC (Dedicated Short-Range Communications)

**Physical Layer:**
- **IEEE 802.11p**: Modified Wi-Fi for vehicular environments
- **Frequency**: 5.9 GHz band (5.855-5.925 GHz)
- **Channel bandwidth**: 10 MHz (half of 802.11a)
- **Data rates**: 3, 4.5, 6, 9, 12, 18, 24, 27 Mbps
- **Range**: 300-1000 meters (depending on power and environment)
- **Latency**: < 50ms (target), typically 20-100ms measured

**Key Characteristics:**
```
Advantages:
- No network infrastructure required (ad-hoc)
- Low latency for safety messages
- Proven technology with field deployments
- Direct vehicle-to-vehicle communication
- Works in areas without cellular coverage

Disadvantages:
- Limited range compared to cellular
- No network-level QoS guarantees
- Congestion issues in high vehicle density
- Limited penetration through obstacles
```

### C-V2X (Cellular Vehicle-to-Everything)

**Physical Layer:**
- **3GPP Release 14**: LTE-V2X (initial version)
- **3GPP Release 16/17**: 5G NR V2X (advanced features)
- **Frequency**: 5.9 GHz (same as DSRC) + cellular bands
- **Communication modes**:
  - **Mode 3**: Network-scheduled (infrastructure)
  - **Mode 4**: Direct D2D/sidelink (no infrastructure)

**Key Characteristics:**
```
Advantages:
- Better non-line-of-sight (NLOS) performance
- Longer range (up to 2-3 km with cellular)
- Evolution path to 5G (forward compatibility)
- Network slicing and QoS support
- Integration with MEC (Multi-access Edge Computing)

Disadvantages:
- Requires cellular network for Mode 3
- Higher complexity and cost
- Newer technology (less deployment history)
- Potential latency issues with network routing
```

## SAE J2735: Message Set for V2X Communications

### Core Message Types

**BSM (Basic Safety Message)**
```asn1
-- SAE J2735 BSM Definition (ASN.1)
BasicSafetyMessage ::= SEQUENCE {
    coreData BSMcoreData,
    partII SEQUENCE (SIZE(1..8)) OF PartIIcontent OPTIONAL,
    regional SEQUENCE (SIZE(1..4)) OF RegionalExtension OPTIONAL
}

BSMcoreData ::= SEQUENCE {
    msgCnt MsgCount,
    id TemporaryID,
    secMark DSecond,
    lat Latitude,
    long Longitude,
    elev Elevation,
    accuracy PositionalAccuracy,
    transmission TransmissionState,
    speed Speed,
    heading Heading,
    angle SteeringWheelAngle,
    accelSet AccelerationSet4Way,
    brakes BrakeSystemStatus,
    size VehicleSize
}
```

**BSM Transmission Requirements:**
- **Frequency**: 10 Hz (every 100ms) for moving vehicles
- **Frequency**: 1-2 Hz for stationary vehicles
- **Message size**: ~100-300 bytes (depending on Part II content)
- **Priority**: Highest (safety-critical)
- **Latency requirement**: < 100ms end-to-end

### C++ Implementation: BSM Encoder

```cpp
// bsm_encoder.hpp
#pragma once

#include <cstdint>
#include <vector>
#include <array>

namespace v2x {
namespace j2735 {

// Core data structures
struct PositionalAccuracy {
    uint8_t semiMajor;  // 0-255 (0.05m resolution)
    uint8_t semiMinor;
    uint16_t orientation;  // 0-65535 (0.0054 deg resolution)
};

struct AccelerationSet4Way {
    int16_t longitudinal;  // -2000 to 2001 (0.01 m/s^2)
    int16_t lateral;
    int16_t vertical;
    int16_t yawRate;  // -32767 to 32767 (0.01 deg/s)
};

struct BrakeSystemStatus {
    uint8_t wheelBrakes;  // Bit field: left/right front/rear
    uint8_t traction;  // 0=unavailable, 1=off, 2=on, 3=engaged
    uint8_t abs;
    uint8_t scs;  // Stability control
    uint8_t brakeBoost;
    uint8_t auxBrakes;
};

struct BSMcoreData {
    uint8_t msgCnt;  // 0-127, wraps
    uint32_t temporaryID;  // Random ID, changed periodically
    uint16_t secMark;  // Milliseconds within minute
    int32_t latitude;  // 1/10 micro-degree
    int32_t longitude;  // 1/10 micro-degree
    int32_t elevation;  // 10 cm resolution
    PositionalAccuracy accuracy;
    uint8_t transmission;  // Neutral, park, forward gears, reverse
    uint16_t speed;  // 0.02 m/s resolution
    uint16_t heading;  // 0.0125 deg resolution
    int8_t steeringAngle;  // 1.5 deg resolution
    AccelerationSet4Way accelSet;
    BrakeSystemStatus brakes;
    uint8_t vehicleWidth;  // cm
    uint8_t vehicleLength;  // cm
};

class BSMEncoder {
public:
    BSMEncoder();

    // Encode BSM to UPER (Unaligned Packed Encoding Rules)
    std::vector<uint8_t> encodeBSM(const BSMcoreData& coreData);

    // Decode BSM from UPER
    bool decodeBSM(const std::vector<uint8_t>& data, BSMcoreData& coreData);

    // Update BSM from vehicle state
    void updateFromVehicleState(
        BSMcoreData& bsm,
        double lat, double lon, double elevation,
        double speed_mps, double heading_deg,
        double accel_long, double accel_lat,
        double yaw_rate_degps,
        uint8_t brake_status
    );

private:
    uint8_t msgCounter_;

    // Helper functions for encoding
    void encodeLat(std::vector<uint8_t>& buffer, int32_t lat);
    void encodeLon(std::vector<uint8_t>& buffer, int32_t lon);
    void encodeSpeed(std::vector<uint8_t>& buffer, uint16_t speed);
};

} // namespace j2735
} // namespace v2x
```

```cpp
// bsm_encoder.cpp
#include "bsm_encoder.hpp"
#include <cmath>
#include <cstring>

namespace v2x {
namespace j2735 {

BSMEncoder::BSMEncoder() : msgCounter_(0) {}

void BSMEncoder::updateFromVehicleState(
    BSMcoreData& bsm,
    double lat, double lon, double elevation,
    double speed_mps, double heading_deg,
    double accel_long, double accel_lat,
    double yaw_rate_degps,
    uint8_t brake_status
) {
    bsm.msgCnt = msgCounter_++;
    if (msgCounter_ > 127) msgCounter_ = 0;

    // Convert to J2735 units
    bsm.latitude = static_cast<int32_t>(lat * 10000000.0);  // 1/10 micro-degree
    bsm.longitude = static_cast<int32_t>(lon * 10000000.0);
    bsm.elevation = static_cast<int32_t>(elevation * 10.0);  // 10 cm

    // Speed: 0.02 m/s resolution
    bsm.speed = static_cast<uint16_t>(speed_mps / 0.02);
    if (bsm.speed > 8191) bsm.speed = 8191;  // Max value

    // Heading: 0.0125 deg resolution
    bsm.heading = static_cast<uint16_t>(heading_deg / 0.0125);
    bsm.heading %= 28800;  // Wrap at 360 degrees

    // Acceleration: 0.01 m/s^2 resolution
    bsm.accelSet.longitudinal = static_cast<int16_t>(accel_long / 0.01);
    bsm.accelSet.lateral = static_cast<int16_t>(accel_lat / 0.01);
    bsm.accelSet.yawRate = static_cast<int16_t>(yaw_rate_degps / 0.01);

    // Brake status (simplified)
    bsm.brakes.wheelBrakes = brake_status;
}

std::vector<uint8_t> BSMEncoder::encodeBSM(const BSMcoreData& coreData) {
    std::vector<uint8_t> buffer;
    buffer.reserve(200);  // Typical BSM size

    // Message ID (0x14 for BSM)
    buffer.push_back(0x00);
    buffer.push_back(0x14);

    // Message count (7 bits)
    buffer.push_back(coreData.msgCnt & 0x7F);

    // Temporary ID (4 bytes)
    buffer.push_back((coreData.temporaryID >> 24) & 0xFF);
    buffer.push_back((coreData.temporaryID >> 16) & 0xFF);
    buffer.push_back((coreData.temporaryID >> 8) & 0xFF);
    buffer.push_back(coreData.temporaryID & 0xFF);

    // DSecond (milliseconds within minute, 16 bits)
    buffer.push_back((coreData.secMark >> 8) & 0xFF);
    buffer.push_back(coreData.secMark & 0xFF);

    // Latitude (32 bits, signed)
    encodeLat(buffer, coreData.latitude);

    // Longitude (32 bits, signed)
    encodeLon(buffer, coreData.longitude);

    // Elevation (16 bits)
    buffer.push_back((coreData.elevation >> 8) & 0xFF);
    buffer.push_back(coreData.elevation & 0xFF);

    // Positional accuracy
    buffer.push_back(coreData.accuracy.semiMajor);
    buffer.push_back(coreData.accuracy.semiMinor);
    buffer.push_back((coreData.accuracy.orientation >> 8) & 0xFF);
    buffer.push_back(coreData.accuracy.orientation & 0xFF);

    // Transmission state (3 bits) + padding
    buffer.push_back((coreData.transmission & 0x07) << 5);

    // Speed (13 bits)
    encodeSpeed(buffer, coreData.speed);

    // Heading (16 bits)
    buffer.push_back((coreData.heading >> 8) & 0xFF);
    buffer.push_back(coreData.heading & 0xFF);

    // Steering angle (8 bits, signed)
    buffer.push_back(static_cast<uint8_t>(coreData.steeringAngle));

    // Acceleration set (4 x 16 bits)
    buffer.push_back((coreData.accelSet.longitudinal >> 8) & 0xFF);
    buffer.push_back(coreData.accelSet.longitudinal & 0xFF);
    buffer.push_back((coreData.accelSet.lateral >> 8) & 0xFF);
    buffer.push_back(coreData.accelSet.lateral & 0xFF);
    buffer.push_back((coreData.accelSet.vertical >> 8) & 0xFF);
    buffer.push_back(coreData.accelSet.vertical & 0xFF);
    buffer.push_back((coreData.accelSet.yawRate >> 8) & 0xFF);
    buffer.push_back(coreData.accelSet.yawRate & 0xFF);

    // Brake system status (5 bytes)
    buffer.push_back(coreData.brakes.wheelBrakes);
    buffer.push_back(coreData.brakes.traction);
    buffer.push_back(coreData.brakes.abs);
    buffer.push_back(coreData.brakes.scs);
    buffer.push_back(coreData.brakes.brakeBoost);

    // Vehicle size
    buffer.push_back(coreData.vehicleWidth);
    buffer.push_back(coreData.vehicleLength);

    return buffer;
}

void BSMEncoder::encodeLat(std::vector<uint8_t>& buffer, int32_t lat) {
    buffer.push_back((lat >> 24) & 0xFF);
    buffer.push_back((lat >> 16) & 0xFF);
    buffer.push_back((lat >> 8) & 0xFF);
    buffer.push_back(lat & 0xFF);
}

void BSMEncoder::encodeLon(std::vector<uint8_t>& buffer, int32_t lon) {
    buffer.push_back((lon >> 24) & 0xFF);
    buffer.push_back((lon >> 16) & 0xFF);
    buffer.push_back((lon >> 8) & 0xFF);
    buffer.push_back(lon & 0xFF);
}

void BSMEncoder::encodeSpeed(std::vector<uint8_t>& buffer, uint16_t speed) {
    // 13-bit encoding
    buffer.push_back((speed >> 5) & 0xFF);
    buffer.push_back((speed & 0x1F) << 3);
}

} // namespace j2735
} // namespace v2x
```

## ETSI ITS-G5 Standards

### CAM (Cooperative Awareness Message)

**ETSI EN 302 637-2 CAM Format:**
```asn1
CAM ::= SEQUENCE {
    header ItsPduHeader,
    cam CoopAwareness
}

CoopAwareness ::= SEQUENCE {
    generationDeltaTime GenerationDeltaTime,
    camParameters CamParameters
}

CamParameters ::= SEQUENCE {
    basicContainer BasicContainer,
    highFrequencyContainer HighFrequencyContainer,
    lowFrequencyContainer LowFrequencyContainer OPTIONAL,
    specialVehicleContainer SpecialVehicleContainer OPTIONAL
}

BasicContainer ::= SEQUENCE {
    stationType StationType,
    referencePosition ReferencePosition
}

HighFrequencyContainer ::= CHOICE {
    basicVehicleContainerHighFrequency BasicVehicleContainerHighFrequency,
    rsuContainerHighFrequency RSUContainerHighFrequency
}
```

**CAM Generation Rules:**
- **Frequency**: 1-10 Hz (adaptive based on vehicle dynamics)
- **Triggering conditions**:
  - Position change > 4 meters
  - Speed change > 0.5 m/s
  - Heading change > 4 degrees
  - Maximum interval: 1 second

### DENM (Decentralized Environmental Notification Message)

**Use cases:**
- Emergency brake warning
- Road hazard notification
- Accident notification
- Weather warnings

## 5GAA Specifications

### Message Flow Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Application Layer                     │
│  (V2V Safety Apps, V2I Traffic Apps, V2N Cloud Apps)   │
└──────────────────┬──────────────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────────────┐
│              Facilities Layer (5GAA)                     │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────────┐  │
│  │   CAM    │  │   DENM   │  │  CPM (Collective     │  │
│  │ Manager  │  │ Manager  │  │  Perception Message) │  │
│  └──────────┘  └──────────┘  └──────────────────────┘  │
└──────────────────┬──────────────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────────────┐
│              Transport & Network Layer                   │
│  ┌────────────────────┐  ┌───────────────────────────┐  │
│  │  GeoNetworking     │  │   IPv6 / UDP / TCP        │  │
│  │  (ETSI EN 302 636) │  │   (for C-V2X)             │  │
│  └────────────────────┘  └───────────────────────────┘  │
└──────────────────┬──────────────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────────────┐
│              Access Layer (PHY/MAC)                      │
│  ┌────────────────────┐  ┌───────────────────────────┐  │
│  │  ITS-G5 (802.11p)  │  │   C-V2X PC5 (Mode 4)      │  │
│  │  DSRC              │  │   LTE-V / 5G NR-V         │  │
│  └────────────────────┘  └───────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

## Cooperative Perception Messages (CPM)

### CPM Structure (ETSI TR 103 324)

```cpp
// cpm.hpp - Collective Perception Message
#pragma once

#include <vector>
#include <cstdint>

namespace v2x {
namespace etsi {

enum class ObjectType : uint8_t {
    UNKNOWN = 0,
    VEHICLE = 1,
    PEDESTRIAN = 2,
    CYCLIST = 3,
    MOTORCYCLE = 4,
    ANIMAL = 5,
    ROAD_HAZARD = 6
};

struct PerceivedObject {
    uint16_t objectID;  // Unique ID within CPM
    uint16_t timeOfMeasurement;  // Delta time in ms

    // Position relative to reference point
    int16_t xDistance;  // cm
    int16_t yDistance;  // cm
    int16_t zDistance;  // cm (optional)

    // Object dimensions
    uint16_t objectLength;  // cm
    uint16_t objectWidth;   // cm
    uint16_t objectHeight;  // cm

    // Dynamics
    int16_t xSpeed;  // cm/s
    int16_t ySpeed;  // cm/s
    int16_t xAcceleration;  // cm/s^2 (optional)
    int16_t yAcceleration;  // cm/s^2 (optional)

    // Classification
    ObjectType objectType;
    uint8_t objectConfidence;  // 0-100%

    // Sensor that detected this object
    uint8_t sensorID;
};

struct SensorInformation {
    uint8_t sensorID;
    uint8_t sensorType;  // 0=camera, 1=radar, 2=lidar, 3=fusion
    int16_t xOffset;  // cm from reference point
    int16_t yOffset;  // cm
    uint16_t detectionRange;  // cm
    uint16_t horizontalOpeningAngle;  // 0.1 degree
};

struct CPM {
    uint8_t protocolVersion;
    uint16_t stationID;
    uint16_t generationDeltaTime;  // ms since last UTC second

    // Reference position (same as CAM)
    int32_t latitude;   // 1/10 micro-degree
    int32_t longitude;  // 1/10 micro-degree

    // Management container
    uint8_t messageRateHz;
    uint16_t perceptionRegionRadius;  // meters

    // Sensor information
    std::vector<SensorInformation> sensors;

    // Perceived objects
    std::vector<PerceivedObject> perceivedObjects;

    // Optional: Free space areas
    // std::vector<FreeSpaceArea> freeSpaceAreas;
};

class CPMManager {
public:
    CPMManager(uint16_t stationID);

    // Add perceived object from sensor
    void addPerceivedObject(const PerceivedObject& obj);

    // Generate CPM message
    CPM generateCPM();

    // Encode CPM to wire format
    std::vector<uint8_t> encodeCPM(const CPM& cpm);

    // Decode received CPM
    bool decodeCPM(const std::vector<uint8_t>& data, CPM& cpm);

    // Fusion: merge perceived objects from multiple sensors
    void fuseObjects(const std::vector<PerceivedObject>& objects);

    // Age out old objects
    void cleanupStaleObjects(uint32_t maxAge_ms);

private:
    uint16_t stationID_;
    std::vector<PerceivedObject> objectList_;
    std::vector<SensorInformation> sensorList_;

    // Object tracking and ID management
    uint16_t nextObjectID_;

    // Helper: match objects across time steps
    bool matchObjects(const PerceivedObject& obj1,
                     const PerceivedObject& obj2,
                     float threshold_m);
};

} // namespace etsi
} // namespace v2x
```

## Latency Requirements and QoS

### Message Priority Classes

| Message Type | Latency Requirement | Frequency | Range | Priority |
|-------------|---------------------|-----------|-------|----------|
| BSM/CAM | < 100 ms | 10 Hz | 300 m | Highest |
| DENM (Emergency) | < 50 ms | Event-triggered | 1000 m | Highest |
| CPM | < 100 ms | 1-4 Hz | 300 m | High |
| SPaT (Traffic signal) | < 100 ms | 10 Hz | 300 m | High |
| MAP | < 1 s | 1 Hz or static | 300 m | Medium |
| TIM (Traveler info) | < 1 s | Event-triggered | Variable | Low |

### DSRC Channel Allocation (US)

```
Channel 172 (5.860 GHz): Control channel (CCH)
  - BSM broadcast
  - Service announcements
  - Safety-critical messages

Channel 174 (5.870 GHz): Service channel (SCH)
  - Non-safety applications

Channel 176 (5.880 GHz): Service channel (SCH)
  - High-power long-range

Channel 178 (5.890 GHz): Service channel (SCH)
  - Public safety

Channel 180 (5.900 GHz): Service channel (SCH)
  - General purpose

Channel 182 (5.910 GHz): Service channel (SCH)
  - High availability

Channel 184 (5.920 GHz): Service channel (SCH)
  - Reserved
```

## Python: Message Rate Adapter

```python
# message_rate_adapter.py
"""
Adaptive message rate controller for V2X communications.
Adjusts BSM/CAM rate based on vehicle dynamics to optimize bandwidth.
"""

import time
import math
from dataclasses import dataclass
from typing import Optional

@dataclass
class VehicleState:
    latitude: float
    longitude: float
    speed_mps: float
    heading_deg: float
    timestamp: float

class MessageRateAdapter:
    """
    Adaptive message generation rate controller.

    ETSI EN 302 637-2 rules:
    - Position change > 4 meters
    - Speed change > 0.5 m/s
    - Heading change > 4 degrees
    - Maximum interval: 1 second
    - Minimum interval: 100 ms (10 Hz)
    """

    def __init__(self,
                 min_interval_s: float = 0.1,
                 max_interval_s: float = 1.0,
                 position_threshold_m: float = 4.0,
                 speed_threshold_mps: float = 0.5,
                 heading_threshold_deg: float = 4.0):
        self.min_interval = min_interval_s
        self.max_interval = max_interval_s
        self.position_threshold = position_threshold_m
        self.speed_threshold = speed_threshold_mps
        self.heading_threshold = heading_threshold_deg

        self.last_transmitted_state: Optional[VehicleState] = None
        self.last_transmission_time: float = 0.0

    def should_transmit(self, current_state: VehicleState) -> bool:
        """
        Determine if a message should be transmitted based on current vehicle state.

        Returns:
            True if message should be sent, False otherwise
        """
        current_time = current_state.timestamp

        # First message
        if self.last_transmitted_state is None:
            return True

        # Check maximum interval
        time_since_last = current_time - self.last_transmission_time
        if time_since_last >= self.max_interval:
            return True

        # Don't transmit faster than min interval
        if time_since_last < self.min_interval:
            return False

        # Check position change
        distance = self._calculate_distance(
            self.last_transmitted_state.latitude,
            self.last_transmitted_state.longitude,
            current_state.latitude,
            current_state.longitude
        )

        if distance >= self.position_threshold:
            return True

        # Check speed change
        speed_change = abs(current_state.speed_mps -
                          self.last_transmitted_state.speed_mps)
        if speed_change >= self.speed_threshold:
            return True

        # Check heading change
        heading_change = self._angle_difference(
            current_state.heading_deg,
            self.last_transmitted_state.heading_deg
        )

        if heading_change >= self.heading_threshold:
            return True

        return False

    def mark_transmitted(self, state: VehicleState):
        """Record that a message was transmitted with this state."""
        self.last_transmitted_state = state
        self.last_transmission_time = state.timestamp

    @staticmethod
    def _calculate_distance(lat1: float, lon1: float,
                           lat2: float, lon2: float) -> float:
        """
        Calculate distance between two GPS coordinates using Haversine formula.

        Returns:
            Distance in meters
        """
        R = 6371000  # Earth radius in meters

        phi1 = math.radians(lat1)
        phi2 = math.radians(lat2)
        delta_phi = math.radians(lat2 - lat1)
        delta_lambda = math.radians(lon2 - lon1)

        a = (math.sin(delta_phi / 2) ** 2 +
             math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2) ** 2)
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

        return R * c

    @staticmethod
    def _angle_difference(angle1: float, angle2: float) -> float:
        """
        Calculate minimum angular difference between two angles.

        Returns:
            Difference in degrees [0, 180]
        """
        diff = abs(angle1 - angle2) % 360
        if diff > 180:
            diff = 360 - diff
        return diff

# Example usage
if __name__ == "__main__":
    adapter = MessageRateAdapter()

    # Simulate vehicle states
    states = [
        VehicleState(37.7749, -122.4194, 15.0, 90.0, 0.0),
        VehicleState(37.7749, -122.4193, 15.0, 90.0, 0.1),  # Small change
        VehicleState(37.7750, -122.4190, 15.0, 90.0, 0.2),  # Position change
        VehicleState(37.7750, -122.4190, 20.0, 90.0, 0.3),  # Speed change
        VehicleState(37.7750, -122.4190, 20.0, 95.0, 0.4),  # Heading change
    ]

    for state in states:
        if adapter.should_transmit(state):
            print(f"TRANSMIT at t={state.timestamp:.1f}s: "
                  f"pos=({state.latitude:.6f},{state.longitude:.6f}), "
                  f"speed={state.speed_mps:.1f} m/s, "
                  f"heading={state.heading_deg:.1f}°")
            adapter.mark_transmitted(state)
        else:
            print(f"SKIP at t={state.timestamp:.1f}s")
```

## Standards Compliance Checklist

### SAE J2735 Compliance
- [ ] BSM generation at 10 Hz for moving vehicles
- [ ] Temporary ID rotation every 5 minutes
- [ ] Message counter wrapping at 127
- [ ] Proper coordinate system (WGS-84)
- [ ] Elevation relative to WGS-84 ellipsoid
- [ ] Speed, acceleration, and heading encodings per spec

### ETSI ITS-G5 Compliance
- [ ] CAM generation with adaptive rate
- [ ] DENM event-triggered transmission
- [ ] GeoNetworking header compliance
- [ ] Security header (if required)
- [ ] ITS PDU header format

### IEEE 1609 Family Compliance
- [ ] 1609.2: Security services
- [ ] 1609.3: Networking services (WSMP)
- [ ] 1609.4: Multi-channel operation
- [ ] 1609.12: Provider Service Identifier (PSID)

## References

1. **SAE J2735**: Dedicated Short Range Communications (DSRC) Message Set Dictionary
2. **ETSI EN 302 637-2**: Intelligent Transport Systems (ITS); Vehicular Communications; Basic Set of Applications; Part 2: Specification of Cooperative Awareness Basic Service
3. **ETSI EN 302 637-3**: Specification of Decentralized Environmental Notification Basic Service
4. **ETSI TR 103 324**: Collective Perception Service
5. **IEEE 802.11p**: Wireless LAN in Vehicular Environments
6. **3GPP TS 22.185**: Service requirements for V2X services
7. **5GAA**: Automotive Association specifications and white papers
