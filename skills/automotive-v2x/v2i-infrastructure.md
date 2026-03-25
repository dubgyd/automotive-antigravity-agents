# V2I Infrastructure

## Overview
Comprehensive guide to Vehicle-to-Infrastructure (V2I) communication including Roadside Unit (RSU) deployment, Signal Phase and Timing (SPaT), MAP messages, traffic light optimization, parking availability, and work zone warnings.

## Roadside Unit (RSU) Architecture

### RSU Hardware Components

```
┌─────────────────────────────────────────────────────────┐
│                  Roadside Unit (RSU)                     │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌────────────────┐         ┌─────────────────────┐    │
│  │  DSRC/C-V2X    │         │   GPS/GNSS          │    │
│  │  Radio Module  │         │   Receiver          │    │
│  │  (5.9 GHz)     │         │                     │    │
│  └────────┬───────┘         └──────────┬──────────┘    │
│           │                            │                │
│           └──────────┬─────────────────┘                │
│                      │                                  │
│           ┌──────────▼────────────┐                     │
│           │   Main Processor      │                     │
│           │   (ARM / x86)         │                     │
│           │   - Message encoding  │                     │
│           │   - Security (1609.2) │                     │
│           │   - Application logic │                     │
│           └──────────┬────────────┘                     │
│                      │                                  │
│      ┌───────────────┼───────────────┐                  │
│      │               │               │                  │
│      ▼               ▼               ▼                  │
│  ┌────────┐    ┌─────────┐    ┌──────────┐            │
│  │Ethernet│    │  CAN    │    │ Serial   │            │
│  │  Port  │    │  Bus    │    │  Port    │            │
│  └───┬────┘    └────┬────┘    └────┬─────┘            │
│      │              │              │                    │
└──────┼──────────────┼──────────────┼────────────────────┘
       │              │              │
       ▼              ▼              ▼
┌──────────┐   ┌───────────┐  ┌──────────────┐
│ Traffic  │   │ Traffic   │  │ Other Sensors│
│ Control  │   │ Camera    │  │ (radar, etc.)│
│ Cabinet  │   │           │  │              │
└──────────┘   └───────────┘  └──────────────┘
```

### RSU Specifications

| Parameter | DSRC RSU | C-V2X RSU |
|-----------|----------|-----------|
| Transmit power | 20-33 dBm | 23 dBm |
| Range | 300-1000 m | 500-1500 m |
| Antenna gain | 5-9 dBi | 8 dBi |
| Operating temp | -40°C to +75°C | -40°C to +85°C |
| Message rate | 10 Hz (BSM), 1 Hz (MAP) | Configurable |
| Latency | < 50 ms | < 100 ms |
| Power consumption | 20-40 W | 30-50 W |

## Signal Phase and Timing (SPaT)

### SPaT Message Format (SAE J2735)

```asn1
-- SAE J2735 SPaT Message
SPAT ::= SEQUENCE {
    timeStamp MinuteOfTheYear OPTIONAL,
    name DescriptiveName OPTIONAL,
    intersections IntersectionStateList,
    regional SEQUENCE (SIZE(1..4)) OF RegionalExtension OPTIONAL
}

IntersectionStateList ::= SEQUENCE (SIZE(1..32)) OF IntersectionState

IntersectionState ::= SEQUENCE {
    name DescriptiveName OPTIONAL,
    id IntersectionReferenceID,
    revision MsgCount,
    status IntersectionStatusObject,
    moy MinuteOfTheYear OPTIONAL,
    timeStamp DSecond OPTIONAL,
    enabledLanes LaneList OPTIONAL,
    states MovementList,
    maneuverAssistList ManeuverAssistList OPTIONAL,
    regional SEQUENCE (SIZE(1..4)) OF RegionalExtension OPTIONAL
}

MovementList ::= SEQUENCE (SIZE(1..255)) OF MovementState

MovementState ::= SEQUENCE {
    movementName DescriptiveName OPTIONAL,
    signalGroup SignalGroupID,
    state-time-speed MovementEventList,
    maneuverAssistList ManeuverAssistList OPTIONAL
}

MovementEventList ::= SEQUENCE (SIZE(1..16)) OF MovementEvent

MovementEvent ::= SEQUENCE {
    eventState MovementPhaseState,
    timing TimeChangeDetails OPTIONAL,
    speeds AdvisorySpeedList OPTIONAL,
    regional SEQUENCE (SIZE(1..4)) OF RegionalExtension OPTIONAL
}

MovementPhaseState ::= ENUMERATED {
    unavailable (0),
    dark (1),
    stop-Then-Proceed (2),  -- Flashing red
    stop-And-Remain (3),    -- Red
    pre-Movement (4),       -- Yellow
    permissive-Movement-Allowed (5),  -- Green
    protected-Movement-Allowed (6),   -- Protected green arrow
    permissive-clearance (7),
    protected-clearance (8),
    caution-Conflicting-Traffic (9)  -- Flashing yellow
}
```

### C++ SPaT Implementation

```cpp
// spat_manager.hpp
#pragma once

#include <cstdint>
#include <vector>
#include <map>
#include <string>

namespace v2i {
namespace spat {

enum class MovementPhaseState : uint8_t {
    UNAVAILABLE = 0,
    DARK = 1,
    STOP_THEN_PROCEED = 2,  // Flashing red
    STOP_AND_REMAIN = 3,    // Solid red
    PRE_MOVEMENT = 4,       // Yellow
    PERMISSIVE_GREEN = 5,   // Green ball
    PROTECTED_GREEN = 6,    // Green arrow
    PERMISSIVE_CLEARANCE = 7,
    PROTECTED_CLEARANCE = 8,
    CAUTION = 9  // Flashing yellow
};

struct TimeChangeDetails {
    uint16_t minEndTime;  // Deciseconds (0.1s) until phase ends (min)
    uint16_t maxEndTime;  // Deciseconds until phase ends (max)
    uint16_t likelyTime;  // Deciseconds until phase ends (most likely)
    uint8_t confidence;   // 0-100%
    uint16_t nextTime;    // Time to next phase (optional)
};

struct MovementEvent {
    MovementPhaseState eventState;
    TimeChangeDetails timing;
    uint16_t speedAdvisory_mps;  // Optional: recommended speed (0.02 m/s units)
};

struct MovementState {
    uint8_t signalGroup;  // Lane/movement ID
    std::string movementName;  // e.g., "NB Left Turn"
    std::vector<MovementEvent> stateTimeSpeed;
};

struct IntersectionState {
    uint16_t intersectionID;
    std::string name;
    uint8_t revision;  // Message counter
    uint16_t minuteOfYear;
    uint16_t msOfMinute;
    std::vector<MovementState> movements;
    uint16_t status;  // Bit field: timing valid, manual control, etc.
};

struct SPaTMessage {
    uint32_t timestamp_ms;
    std::vector<IntersectionState> intersections;
};

class SPaTManager {
public:
    SPaTManager(uint16_t intersectionID);

    // Update phase state from traffic controller
    void updateMovementState(
        uint8_t signalGroup,
        MovementPhaseState newState,
        uint16_t timeToChange_ds  // Deciseconds
    );

    // Generate SPaT message for broadcast
    SPaTMessage generateSPaTMessage();

    // Encode SPaT to wire format (UPER)
    std::vector<uint8_t> encodeSPaT(const SPaTMessage& spat);

    // Decode received SPaT
    static bool decodeSPaT(const std::vector<uint8_t>& data, SPaTMessage& spat);

    // Get time remaining for specific movement
    uint16_t getTimeRemaining(uint8_t signalGroup) const;

    // Get current phase state
    MovementPhaseState getCurrentState(uint8_t signalGroup) const;

    // Predict phase change time with confidence
    TimeChangeDetails predictPhaseChange(uint8_t signalGroup) const;

private:
    uint16_t intersectionID_;
    IntersectionState currentState_;
    std::map<uint8_t, MovementState> movementStates_;

    uint8_t messageRevision_;
    uint32_t lastUpdateTime_ms_;

    // Helper to encode timing information
    void encodeTimeChangeDetails(
        std::vector<uint8_t>& buffer,
        const TimeChangeDetails& timing
    );
};

} // namespace spat
} // namespace v2i
```

```cpp
// spat_manager.cpp
#include "spat_manager.hpp"
#include <chrono>
#include <algorithm>

namespace v2i {
namespace spat {

SPaTManager::SPaTManager(uint16_t intersectionID)
    : intersectionID_(intersectionID),
      messageRevision_(0),
      lastUpdateTime_ms_(0) {

    currentState_.intersectionID = intersectionID;
    currentState_.name = "Intersection_" + std::to_string(intersectionID);
    currentState_.revision = 0;
}

void SPaTManager::updateMovementState(
    uint8_t signalGroup,
    MovementPhaseState newState,
    uint16_t timeToChange_ds
) {
    auto now = std::chrono::system_clock::now();
    auto now_ms = std::chrono::duration_cast<std::chrono::milliseconds>(
        now.time_since_epoch()).count();

    // Find or create movement state
    if (movementStates_.find(signalGroup) == movementStates_.end()) {
        MovementState movement;
        movement.signalGroup = signalGroup;
        movement.movementName = "Movement_" + std::to_string(signalGroup);
        movementStates_[signalGroup] = movement;
    }

    auto& movement = movementStates_[signalGroup];

    // Create new event
    MovementEvent event;
    event.eventState = newState;
    event.timing.minEndTime = timeToChange_ds;
    event.timing.maxEndTime = timeToChange_ds + 10;  // +1 second tolerance
    event.timing.likelyTime = timeToChange_ds;
    event.timing.confidence = 95;  // High confidence from controller

    // Update movement state
    movement.stateTimeSpeed.clear();
    movement.stateTimeSpeed.push_back(event);

    lastUpdateTime_ms_ = now_ms;
    messageRevision_++;
}

SPaTMessage SPaTManager::generateSPaTMessage() {
    SPaTMessage spat;

    auto now = std::chrono::system_clock::now();
    auto now_ms = std::chrono::duration_cast<std::chrono::milliseconds>(
        now.time_since_epoch()).count();

    spat.timestamp_ms = now_ms;

    // Build intersection state
    currentState_.revision = messageRevision_;

    // Calculate minute of year and ms of minute for timestamp
    auto now_time_t = std::chrono::system_clock::to_time_t(now);
    struct tm* tm_info = gmtime(&now_time_t);

    // Simplified calculation (should use proper day-of-year)
    currentState_.minuteOfYear = (tm_info->tm_yday * 24 * 60) +
                                 (tm_info->tm_hour * 60) +
                                 tm_info->tm_min;
    currentState_.msOfMinute = (tm_info->tm_sec * 1000) +
                               (now_ms % 1000);

    // Copy movement states
    currentState_.movements.clear();
    for (const auto& pair : movementStates_) {
        currentState_.movements.push_back(pair.second);
    }

    spat.intersections.push_back(currentState_);

    return spat;
}

std::vector<uint8_t> SPaTManager::encodeSPaT(const SPaTMessage& spat) {
    std::vector<uint8_t> buffer;
    buffer.reserve(512);

    // Message ID (0x13 for SPaT)
    buffer.push_back(0x00);
    buffer.push_back(0x13);

    // Timestamp (optional, 4 bytes)
    uint32_t ts = spat.timestamp_ms;
    buffer.push_back((ts >> 24) & 0xFF);
    buffer.push_back((ts >> 16) & 0xFF);
    buffer.push_back((ts >> 8) & 0xFF);
    buffer.push_back(ts & 0xFF);

    // Number of intersections (typically 1)
    buffer.push_back(static_cast<uint8_t>(spat.intersections.size()));

    for (const auto& intersection : spat.intersections) {
        // Intersection ID (2 bytes)
        buffer.push_back((intersection.intersectionID >> 8) & 0xFF);
        buffer.push_back(intersection.intersectionID & 0xFF);

        // Revision (1 byte)
        buffer.push_back(intersection.revision);

        // Status (2 bytes)
        buffer.push_back((intersection.status >> 8) & 0xFF);
        buffer.push_back(intersection.status & 0xFF);

        // Minute of year (2 bytes)
        buffer.push_back((intersection.minuteOfYear >> 8) & 0xFF);
        buffer.push_back(intersection.minuteOfYear & 0xFF);

        // Ms of minute (2 bytes)
        buffer.push_back((intersection.msOfMinute >> 8) & 0xFF);
        buffer.push_back(intersection.msOfMinute & 0xFF);

        // Number of movements
        buffer.push_back(static_cast<uint8_t>(intersection.movements.size()));

        for (const auto& movement : intersection.movements) {
            // Signal group ID
            buffer.push_back(movement.signalGroup);

            // Number of events (typically 1-2)
            buffer.push_back(static_cast<uint8_t>(movement.stateTimeSpeed.size()));

            for (const auto& event : movement.stateTimeSpeed) {
                // Event state (1 byte)
                buffer.push_back(static_cast<uint8_t>(event.eventState));

                // Timing
                encodeTimeChangeDetails(buffer, event.timing);
            }
        }
    }

    return buffer;
}

void SPaTManager::encodeTimeChangeDetails(
    std::vector<uint8_t>& buffer,
    const TimeChangeDetails& timing
) {
    // Min end time (2 bytes, deciseconds)
    buffer.push_back((timing.minEndTime >> 8) & 0xFF);
    buffer.push_back(timing.minEndTime & 0xFF);

    // Max end time (2 bytes)
    buffer.push_back((timing.maxEndTime >> 8) & 0xFF);
    buffer.push_back(timing.maxEndTime & 0xFF);

    // Likely time (2 bytes)
    buffer.push_back((timing.likelyTime >> 8) & 0xFF);
    buffer.push_back(timing.likelyTime & 0xFF);

    // Confidence (1 byte, 0-100)
    buffer.push_back(timing.confidence);
}

uint16_t SPaTManager::getTimeRemaining(uint8_t signalGroup) const {
    auto it = movementStates_.find(signalGroup);
    if (it == movementStates_.end() || it->second.stateTimeSpeed.empty()) {
        return 0;
    }

    return it->second.stateTimeSpeed[0].timing.likelyTime;
}

MovementPhaseState SPaTManager::getCurrentState(uint8_t signalGroup) const {
    auto it = movementStates_.find(signalGroup);
    if (it == movementStates_.end() || it->second.stateTimeSpeed.empty()) {
        return MovementPhaseState::UNAVAILABLE;
    }

    return it->second.stateTimeSpeed[0].eventState;
}

TimeChangeDetails SPaTManager::predictPhaseChange(uint8_t signalGroup) const {
    auto it = movementStates_.find(signalGroup);
    if (it == movementStates_.end() || it->second.stateTimeSpeed.empty()) {
        return TimeChangeDetails{0, 0, 0, 0, 0};
    }

    return it->second.stateTimeSpeed[0].timing;
}

} // namespace spat
} // namespace v2i
```

## MAP (Geographic Intersection Description) Message

### MAP Message Format

```asn1
-- SAE J2735 MAP Message
MapData ::= SEQUENCE {
    timeStamp MinuteOfTheYear OPTIONAL,
    msgIssueRevision MsgCount,
    layerType LayerType OPTIONAL,
    layerID LayerID OPTIONAL,
    intersections IntersectionGeometryList OPTIONAL,
    roadSegments RoadSegmentList OPTIONAL,
    dataParameters DataParameters OPTIONAL,
    restrictionList RestrictionClassList OPTIONAL,
    regional SEQUENCE (SIZE(1..4)) OF RegionalExtension OPTIONAL
}

IntersectionGeometry ::= SEQUENCE {
    name DescriptiveName OPTIONAL,
    id IntersectionReferenceID,
    revision MsgCount,
    refPoint Position3D,
    laneWidth LaneWidth OPTIONAL,
    speedLimits SpeedLimitList OPTIONAL,
    laneSet LaneList,
    preemptPriorityData PreemptPriorityList OPTIONAL,
    regional SEQUENCE (SIZE(1..4)) OF RegionalExtension OPTIONAL
}
```

### Python MAP Generator

```python
# map_generator.py
"""
Generate MAP (Geographic Intersection Description) messages.
"""

from dataclasses import dataclass
from typing import List, Tuple, Optional
import json
import math

@dataclass
class Position3D:
    latitude: float   # Degrees
    longitude: float  # Degrees
    elevation: float  # Meters (optional)

@dataclass
class LaneNode:
    """Node point in lane geometry."""
    offset_x_cm: int  # Offset from reference point
    offset_y_cm: int
    offset_z_cm: int = 0

@dataclass
class ConnectsTo:
    """Lane connection information."""
    connecting_lane_id: int
    signal_group: int  # Associated signal group
    maneuver: str  # "straight", "left", "right", "uturn"

@dataclass
class Lane:
    lane_id: int
    lane_type: str  # "vehicle", "bike", "pedestrian", "parking"
    lane_attributes: int  # Bit field
    lane_width_cm: int
    nodes: List[LaneNode]
    connects_to: List[ConnectsTo]
    speed_limit_mps: Optional[float] = None

@dataclass
class IntersectionGeometry:
    intersection_id: int
    name: str
    reference_point: Position3D
    lanes: List[Lane]
    revision: int = 1

class MAPGenerator:
    """
    Generate MAP messages for intersections.
    """

    def __init__(self):
        self.intersections: List[IntersectionGeometry] = []

    def create_four_way_intersection(
        self,
        intersection_id: int,
        center_lat: float,
        center_lon: float,
        lane_width_m: float = 3.5
    ) -> IntersectionGeometry:
        """
        Create a standard 4-way intersection geometry.

        Args:
            intersection_id: Unique intersection ID
            center_lat: Latitude of intersection center
            center_lon: Longitude of intersection center
            lane_width_m: Standard lane width in meters

        Returns:
            IntersectionGeometry object
        """
        ref_point = Position3D(center_lat, center_lon, 0.0)
        lanes = []

        # Approach distances
        approach_distance_m = 100.0

        # Create 4 approaches (North, East, South, West)
        # Each approach has 3 lanes: left turn, straight, right turn

        lane_id = 1

        # North approach (lanes coming from south, heading north)
        for lane_offset in [-1, 0, 1]:  # Left, straight, right lanes
            lane = self._create_approach_lane(
                lane_id=lane_id,
                approach_direction=0,  # North
                lateral_offset=lane_offset,
                approach_distance_m=approach_distance_m,
                lane_width_m=lane_width_m,
                ref_point=ref_point
            )

            # Add connection information
            if lane_offset == -1:  # Left turn lane
                lane.connects_to.append(
                    ConnectsTo(connecting_lane_id=21, signal_group=1, maneuver="left")
                )
            elif lane_offset == 0:  # Straight lane
                lane.connects_to.append(
                    ConnectsTo(connecting_lane_id=20, signal_group=2, maneuver="straight")
                )
            else:  # Right turn lane
                lane.connects_to.append(
                    ConnectsTo(connecting_lane_id=22, signal_group=2, maneuver="right")
                )

            lanes.append(lane)
            lane_id += 1

        # East approach
        for lane_offset in [-1, 0, 1]:
            lane = self._create_approach_lane(
                lane_id=lane_id,
                approach_direction=90,  # East
                lateral_offset=lane_offset,
                approach_distance_m=approach_distance_m,
                lane_width_m=lane_width_m,
                ref_point=ref_point
            )

            if lane_offset == -1:
                lane.connects_to.append(
                    ConnectsTo(connecting_lane_id=11, signal_group=3, maneuver="left")
                )
            elif lane_offset == 0:
                lane.connects_to.append(
                    ConnectsTo(connecting_lane_id=10, signal_group=4, maneuver="straight")
                )
            else:
                lane.connects_to.append(
                    ConnectsTo(connecting_lane_id=12, signal_group=4, maneuver="right")
                )

            lanes.append(lane)
            lane_id += 1

        # South and West approaches (similar pattern)
        # ... (code structure similar to above)

        intersection = IntersectionGeometry(
            intersection_id=intersection_id,
            name=f"Intersection_{intersection_id}",
            reference_point=ref_point,
            lanes=lanes,
            revision=1
        )

        self.intersections.append(intersection)
        return intersection

    def _create_approach_lane(
        self,
        lane_id: int,
        approach_direction: float,  # 0=North, 90=East, etc.
        lateral_offset: int,  # -1, 0, 1 for left, center, right
        approach_distance_m: float,
        lane_width_m: float,
        ref_point: Position3D
    ) -> Lane:
        """Create a single approach lane geometry."""

        lane_width_cm = int(lane_width_m * 100)

        # Calculate lane centerline nodes
        nodes = []

        # Start point (far from intersection)
        angle_rad = math.radians(approach_direction + 180)  # Coming from opposite direction
        lateral_angle_rad = math.radians(approach_direction + 90)

        for distance in [approach_distance_m, approach_distance_m / 2, 10.0, 2.0]:
            x = distance * math.cos(angle_rad) + lateral_offset * lane_width_m * math.cos(lateral_angle_rad)
            y = distance * math.sin(angle_rad) + lateral_offset * lane_width_m * math.sin(lateral_angle_rad)

            node = LaneNode(
                offset_x_cm=int(x * 100),
                offset_y_cm=int(y * 100)
            )
            nodes.append(node)

        lane = Lane(
            lane_id=lane_id,
            lane_type="vehicle",
            lane_attributes=0x0001,  # Vehicle traffic allowed
            lane_width_cm=lane_width_cm,
            nodes=nodes,
            connects_to=[],
            speed_limit_mps=13.9  # ~30 mph
        )

        return lane

    def encode_map_message(self, intersection: IntersectionGeometry) -> dict:
        """
        Encode intersection geometry to MAP message format.

        Returns:
            Dictionary representing MAP message (can be converted to JSON/UPER)
        """
        map_msg = {
            "MessageFrame": {
                "messageId": 18,  # MAP message
                "value": {
                    "MapData": {
                        "msgIssueRevision": intersection.revision,
                        "intersections": {
                            "IntersectionGeometry": [{
                                "id": {
                                    "id": intersection.intersection_id
                                },
                                "revision": intersection.revision,
                                "refPoint": {
                                    "lat": int(intersection.reference_point.latitude * 10000000),
                                    "long": int(intersection.reference_point.longitude * 10000000),
                                    "elevation": int(intersection.reference_point.elevation * 10)
                                },
                                "laneWidth": int(3.5 * 100),  # Default 3.5m
                                "laneSet": {
                                    "GenericLane": [
                                        self._encode_lane(lane) for lane in intersection.lanes
                                    ]
                                }
                            }]
                        }
                    }
                }
            }
        }

        return map_msg

    def _encode_lane(self, lane: Lane) -> dict:
        """Encode a single lane to MAP format."""
        return {
            "laneID": lane.lane_id,
            "laneAttributes": {
                "directionalUse": "11",  # Both directions (bit string)
                "sharedWith": "0000000000",
                "laneType": {
                    "vehicle": {}
                }
            },
            "laneWidth": lane.lane_width_cm,
            "nodeList": {
                "nodes": {
                    "NodeXY": [
                        {
                            "delta": {
                                "node-XY1": {
                                    "x": node.offset_x_cm,
                                    "y": node.offset_y_cm
                                }
                            }
                        }
                        for node in lane.nodes
                    ]
                }
            },
            "connectsTo": {
                "Connection": [
                    {
                        "connectingLane": {
                            "lane": conn.connecting_lane_id
                        },
                        "signalGroup": conn.signal_group,
                        "maneuver": self._encode_maneuver(conn.maneuver)
                    }
                    for conn in lane.connects_to
                ]
            }
        }

    @staticmethod
    def _encode_maneuver(maneuver: str) -> str:
        """Encode maneuver as bit string."""
        maneuver_bits = {
            "straight": "100000000000",
            "left": "010000000000",
            "right": "001000000000",
            "uturn": "000100000000"
        }
        return maneuver_bits.get(maneuver, "000000000000")

    def export_to_json(self, filename: str):
        """Export all intersections to JSON file."""
        map_messages = [
            self.encode_map_message(intersection)
            for intersection in self.intersections
        ]

        with open(filename, 'w') as f:
            json.dump(map_messages, f, indent=2)

        print(f"Exported {len(map_messages)} MAP messages to {filename}")


# Example usage
if __name__ == "__main__":
    generator = MAPGenerator()

    # Create intersection
    intersection = generator.create_four_way_intersection(
        intersection_id=1001,
        center_lat=37.7749,
        center_lon=-122.4194,
        lane_width_m=3.5
    )

    print(f"Created intersection with {len(intersection.lanes)} lanes")

    # Export to JSON
    generator.export_to_json("intersection_map.json")
```

## Traffic Light Optimization with V2I

### Green Light Optimal Speed Advisory (GLOSA)

```python
# glosa_calculator.py
"""
Green Light Optimal Speed Advisory (GLOSA) calculator.
Recommends optimal speed to reach green light.
"""

from dataclasses import dataclass
from typing import Optional
import math

@dataclass
class SPaTData:
    current_phase: str  # "red", "green", "yellow"
    time_to_change_s: float
    next_phase: str
    time_to_next_change_s: float

@dataclass
class GLOSARecommendation:
    recommended_speed_mps: float
    can_make_green: bool
    time_savings_s: float
    confidence: float  # 0.0-1.0
    recommendation_type: str  # "speed_up", "slow_down", "maintain", "stop"

class GLOSACalculator:
    """
    Calculate optimal speed to reach green light.
    """

    def __init__(self,
                 min_speed_mps: float = 5.0,   # ~10 mph
                 max_speed_mps: float = 22.2,  # ~50 mph
                 comfort_accel_mps2: float = 1.5,
                 comfort_decel_mps2: float = 2.0):
        self.min_speed = min_speed_mps
        self.max_speed = max_speed_mps
        self.comfort_accel = comfort_accel_mps2
        self.comfort_decel = comfort_decel_mps2

    def calculate_glosa(
        self,
        distance_to_intersection_m: float,
        current_speed_mps: float,
        speed_limit_mps: float,
        spat: SPaTData
    ) -> GLOSARecommendation:
        """
        Calculate GLOSA recommendation.

        Args:
            distance_to_intersection_m: Distance to stop line
            current_speed_mps: Current vehicle speed
            speed_limit_mps: Posted speed limit
            spat: Signal phase and timing data

        Returns:
            GLOSARecommendation with optimal speed
        """

        # If already at intersection or very close
        if distance_to_intersection_m < 5.0:
            return GLOSARecommendation(
                recommended_speed_mps=current_speed_mps,
                can_make_green=(spat.current_phase == "green"),
                time_savings_s=0.0,
                confidence=1.0,
                recommendation_type="maintain"
            )

        # Calculate time to reach intersection at current speed
        if current_speed_mps > 0.5:
            tta_current = distance_to_intersection_m / current_speed_mps
        else:
            tta_current = 999.0

        # Current phase is green
        if spat.current_phase == "green":
            return self._handle_green_phase(
                distance_to_intersection_m,
                current_speed_mps,
                speed_limit_mps,
                spat.time_to_change_s
            )

        # Current phase is red
        elif spat.current_phase == "red":
            return self._handle_red_phase(
                distance_to_intersection_m,
                current_speed_mps,
                speed_limit_mps,
                spat.time_to_change_s,
                spat.time_to_next_change_s
            )

        # Yellow phase - treat as red (stop if safe)
        else:
            return GLOSARecommendation(
                recommended_speed_mps=0.0,
                can_make_green=False,
                time_savings_s=0.0,
                confidence=0.9,
                recommendation_type="stop"
            )

    def _handle_green_phase(
        self,
        distance_m: float,
        current_speed_mps: float,
        speed_limit_mps: float,
        time_to_yellow_s: float
    ) -> GLOSARecommendation:
        """Handle green phase scenario."""

        # Can we make it through at current speed?
        tta_current = distance_m / max(current_speed_mps, 1.0)

        # Add buffer for yellow and clearance (3 seconds typical)
        safe_time = time_to_yellow_s - 3.0

        if tta_current < safe_time:
            # Can make it comfortably
            return GLOSARecommendation(
                recommended_speed_mps=current_speed_mps,
                can_make_green=True,
                time_savings_s=0.0,
                confidence=0.95,
                recommendation_type="maintain"
            )
        else:
            # Need to speed up (within limits)
            required_speed = distance_m / safe_time
            recommended_speed = min(required_speed, speed_limit_mps, self.max_speed)

            # Check if acceleration is comfortable
            speed_change = recommended_speed - current_speed_mps
            accel_required = speed_change / max(safe_time, 1.0)

            if accel_required <= self.comfort_accel:
                return GLOSARecommendation(
                    recommended_speed_mps=recommended_speed,
                    can_make_green=True,
                    time_savings_s=safe_time - tta_current,
                    confidence=0.85,
                    recommendation_type="speed_up"
                )
            else:
                # Can't make it comfortably, prepare to stop
                return GLOSARecommendation(
                    recommended_speed_mps=current_speed_mps * 0.7,
                    can_make_green=False,
                    time_savings_s=0.0,
                    confidence=0.8,
                    recommendation_type="slow_down"
                )

    def _handle_red_phase(
        self,
        distance_m: float,
        current_speed_mps: float,
        speed_limit_mps: float,
        time_to_green_s: float,
        green_duration_s: float
    ) -> GLOSARecommendation:
        """Handle red phase scenario."""

        # Calculate speed needed to arrive at green
        if time_to_green_s > 0:
            optimal_speed = distance_m / time_to_green_s
        else:
            optimal_speed = 0.0

        # Check if optimal speed is within bounds
        if self.min_speed <= optimal_speed <= min(speed_limit_mps, self.max_speed):
            # Can time arrival for green light
            speed_change = optimal_speed - current_speed_mps
            time_to_adjust = max(time_to_green_s - 5.0, 1.0)  # Leave buffer
            accel_required = speed_change / time_to_adjust

            # Check if comfortable
            if abs(accel_required) <= self.comfort_accel:
                # Calculate time savings vs. stopping
                stop_time = time_to_green_s + 3.0  # Restart delay
                tta_optimal = distance_m / optimal_speed
                time_savings = stop_time - tta_optimal

                return GLOSARecommendation(
                    recommended_speed_mps=optimal_speed,
                    can_make_green=True,
                    time_savings_s=time_savings,
                    confidence=0.9,
                    recommendation_type="slow_down" if speed_change < 0 else "speed_up"
                )

        # Can't time it well, prepare to stop
        # Calculate comfortable deceleration distance
        stopping_distance = (current_speed_mps ** 2) / (2 * self.comfort_decel)

        if distance_m > stopping_distance * 1.2:  # Have room to slow comfortably
            return GLOSARecommendation(
                recommended_speed_mps=current_speed_mps * 0.5,
                can_make_green=False,
                time_savings_s=0.0,
                confidence=0.85,
                recommendation_type="slow_down"
            )
        else:
            # Must stop more urgently
            return GLOSARecommendation(
                recommended_speed_mps=0.0,
                can_make_green=False,
                time_savings_s=0.0,
                confidence=0.95,
                recommendation_type="stop"
            )


# Example usage
if __name__ == "__main__":
    calculator = GLOSACalculator()

    # Scenario: Approaching red light that will turn green
    spat_data = SPaTData(
        current_phase="red",
        time_to_change_s=15.0,  # 15 seconds until green
        next_phase="green",
        time_to_next_change_s=30.0  # 30 seconds of green
    )

    recommendation = calculator.calculate_glosa(
        distance_to_intersection_m=200.0,  # 200m away
        current_speed_mps=16.7,  # ~60 km/h
        speed_limit_mps=16.7,
        spat=spat_data
    )

    print(f"Recommendation: {recommendation.recommendation_type}")
    print(f"Optimal speed: {recommendation.recommended_speed_mps * 3.6:.1f} km/h")
    print(f"Can make green: {recommendation.can_make_green}")
    print(f"Time savings: {recommendation.time_savings_s:.1f} seconds")
    print(f"Confidence: {recommendation.confidence*100:.0f}%")
```

## RSU Deployment Strategy

### Coverage Analysis

```python
# rsu_deployment_optimizer.py
"""
Optimize RSU deployment for coverage and cost.
"""

import math
from dataclasses import dataclass
from typing import List, Tuple
import matplotlib.pyplot as plt

@dataclass
class RSU:
    id: int
    latitude: float
    longitude: float
    range_m: float
    cost_usd: float

@dataclass
class Intersection:
    id: int
    latitude: float
    longitude: float
    traffic_volume_vpd: int  # Vehicles per day
    priority: int  # 1-5, 5=highest

class RSUDeploymentOptimizer:
    """
    Optimize RSU placement for V2I coverage.
    """

    def __init__(self, budget_usd: float, rsu_cost_usd: float = 15000):
        self.budget = budget_usd
        self.rsu_cost = rsu_cost_usd
        self.rsu_range_m = 300.0  # Conservative urban range

    def optimize_deployment(
        self,
        intersections: List[Intersection],
        road_segments: List[Tuple[float, float, float, float]]  # lat1,lon1,lat2,lon2
    ) -> List[RSU]:
        """
        Determine optimal RSU placement.

        Strategy:
        1. Prioritize high-traffic intersections
        2. Ensure coverage of critical road segments
        3. Minimize overlap
        4. Stay within budget

        Returns:
            List of RSU positions
        """
        max_rsus = int(self.budget / self.rsu_cost)
        print(f"Budget allows for {max_rsus} RSUs")

        # Sort intersections by priority and traffic
        sorted_intersections = sorted(
            intersections,
            key=lambda x: (x.priority, x.traffic_volume_vpd),
            reverse=True
        )

        deployed_rsus = []
        covered_intersections = set()

        rsu_id = 1

        for intersection in sorted_intersections:
            if len(deployed_rsus) >= max_rsus:
                break

            # Check if already covered by existing RSU
            if self._is_covered(intersection, deployed_rsus):
                covered_intersections.add(intersection.id)
                continue

            # Deploy new RSU at this intersection
            rsu = RSU(
                id=rsu_id,
                latitude=intersection.latitude,
                longitude=intersection.longitude,
                range_m=self.rsu_range_m,
                cost_usd=self.rsu_cost
            )

            deployed_rsus.append(rsu)
            covered_intersections.add(intersection.id)
            rsu_id += 1

            print(f"Deployed RSU {rsu.id} at intersection {intersection.id} "
                  f"(Priority {intersection.priority}, "
                  f"Traffic {intersection.traffic_volume_vpd} vpd)")

        # Calculate coverage statistics
        coverage_pct = (len(covered_intersections) / len(intersections)) * 100
        total_cost = len(deployed_rsus) * self.rsu_cost

        print(f"\nDeployment Summary:")
        print(f"  RSUs deployed: {len(deployed_rsus)}")
        print(f"  Intersections covered: {len(covered_intersections)}/{len(intersections)} "
              f"({coverage_pct:.1f}%)")
        print(f"  Total cost: ${total_cost:,}")
        print(f"  Remaining budget: ${self.budget - total_cost:,}")

        return deployed_rsus

    def _is_covered(self, intersection: Intersection, rsus: List[RSU]) -> bool:
        """Check if intersection is within range of any RSU."""
        for rsu in rsus:
            distance = self._calculate_distance(
                intersection.latitude, intersection.longitude,
                rsu.latitude, rsu.longitude
            )
            if distance <= rsu.range_m:
                return True
        return False

    @staticmethod
    def _calculate_distance(lat1: float, lon1: float,
                           lat2: float, lon2: float) -> float:
        """Calculate distance between two GPS coordinates (Haversine)."""
        R = 6371000  # Earth radius in meters

        phi1 = math.radians(lat1)
        phi2 = math.radians(lat2)
        delta_phi = math.radians(lat2 - lat1)
        delta_lambda = math.radians(lon2 - lon1)

        a = (math.sin(delta_phi / 2) ** 2 +
             math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2) ** 2)
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

        return R * c

    def visualize_deployment(self, rsus: List[RSU],
                           intersections: List[Intersection]):
        """Visualize RSU coverage map."""
        fig, ax = plt.subplots(figsize=(12, 10))

        # Plot intersections
        for intersection in intersections:
            color = 'red' if intersection.priority >= 4 else 'orange'
            size = intersection.traffic_volume_vpd / 100
            ax.scatter(intersection.longitude, intersection.latitude,
                      c=color, s=size, alpha=0.5, label='Intersection')

        # Plot RSUs with coverage circles
        for rsu in rsus:
            ax.scatter(rsu.longitude, rsu.latitude,
                      c='blue', s=200, marker='^', label='RSU')

            # Coverage circle
            circle = plt.Circle(
                (rsu.longitude, rsu.latitude),
                rsu.range_m / 111000,  # Approximate degrees
                color='blue',
                fill=False,
                linestyle='--',
                alpha=0.3
            )
            ax.add_patch(circle)

            # RSU ID label
            ax.text(rsu.longitude, rsu.latitude + 0.001,
                   f"RSU {rsu.id}",
                   fontsize=8,
                   ha='center')

        ax.set_xlabel('Longitude')
        ax.set_ylabel('Latitude')
        ax.set_title('RSU Deployment Map')
        ax.grid(True, alpha=0.3)

        # Remove duplicate labels
        handles, labels = ax.get_legend_handles_labels()
        by_label = dict(zip(labels, handles))
        ax.legend(by_label.values(), by_label.keys())

        plt.savefig('rsu_deployment_map.png', dpi=150, bbox_inches='tight')
        print("Saved deployment map to rsu_deployment_map.png")


# Example usage
if __name__ == "__main__":
    # Define intersections in a city
    intersections = [
        Intersection(1, 37.7749, -122.4194, 25000, 5),  # High priority
        Intersection(2, 37.7750, -122.4180, 18000, 4),
        Intersection(3, 37.7760, -122.4200, 15000, 3),
        Intersection(4, 37.7740, -122.4210, 12000, 3),
        Intersection(5, 37.7755, -122.4175, 20000, 5),
        Intersection(6, 37.7735, -122.4185, 8000, 2),
    ]

    # Deployment optimizer
    optimizer = RSUDeploymentOptimizer(budget_usd=100000)

    # Optimize deployment
    rsus = optimizer.optimize_deployment(intersections, [])

    # Visualize (requires matplotlib)
    # optimizer.visualize_deployment(rsus, intersections)
```

## Work Zone Warnings and Parking Management

### Work Zone Warning System

```cpp
// work_zone_warning.hpp
#pragma once

#include <string>
#include <vector>
#include <cstdint>

namespace v2i {

enum class WorkZoneType {
    CONSTRUCTION,
    MAINTENANCE,
    UTILITY_WORK,
    EMERGENCY_RESPONSE
};

enum class LaneClosureType {
    NONE,
    RIGHT_LANE,
    LEFT_LANE,
    CENTER_LANE,
    MULTIPLE_LANES,
    ROAD_CLOSED
};

struct WorkZoneInfo {
    uint32_t zone_id;
    WorkZoneType type;
    LaneClosureType lane_closure;
    double start_latitude;
    double start_longitude;
    double end_latitude;
    double end_longitude;
    uint16_t length_meters;
    uint8_t reduced_speed_limit_mph;
    uint32_t start_time_epoch;
    uint32_t end_time_epoch;
    bool workers_present;
    std::string description;
};

struct TravelerInformationMessage {
    uint8_t message_id;  // TIM = 0x1F
    uint16_t msg_count;
    std::vector<WorkZoneInfo> work_zones;
    uint32_t timestamp_ms;
};

class WorkZoneWarningSystem {
public:
    WorkZoneWarningSystem();

    // Add work zone
    void addWorkZone(const WorkZoneInfo& zone);

    // Remove work zone
    void removeWorkZone(uint32_t zone_id);

    // Generate TIM message for broadcast
    TravelerInformationMessage generateTIM();

    // Check if vehicle is approaching work zone
    bool isApproachingWorkZone(
        double vehicle_lat,
        double vehicle_lon,
        double vehicle_heading_deg,
        double& distance_to_zone_m
    );

    // Get recommended speed for work zone
    uint8_t getRecommendedSpeed(uint32_t zone_id);

private:
    std::vector<WorkZoneInfo> active_zones_;
    uint16_t message_counter_;
};

} // namespace v2i
```

## References

1. **SAE J2735**: Dedicated Short Range Communications (DSRC) Message Set Dictionary
2. **SAE J2945**: On-Board System Requirements for V2V Safety Communications
3. **USDOT**: Connected Vehicle Pilot Deployment Program
4. **FHWA**: V2I Deployment Coalition guidance documents
5. **ITE**: Traffic Signal Timing Manual (GLOSA algorithms)
