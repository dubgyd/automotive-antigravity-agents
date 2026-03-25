# V2V Safety Applications

## Overview
Comprehensive guide to Vehicle-to-Vehicle (V2V) safety applications including Cooperative Adaptive Cruise Control (CACC), Emergency Electronic Brake Light (EEBL), Intersection Movement Assist (IMA), Forward Collision Warning (FCW), and platooning algorithms.

## Safety Application Categories

### Priority Levels

| Application | Safety Impact | Latency Requirement | Message Rate | Range |
|------------|---------------|---------------------|--------------|-------|
| EEBL | Critical | < 50 ms | Event-triggered | 300 m |
| FCW | Critical | < 100 ms | 10 Hz | 200 m |
| IMA | Critical | < 100 ms | 10 Hz | 300 m |
| CACC | High | < 100 ms | 10 Hz | 150 m |
| LCW (Lane Change) | High | < 100 ms | 10 Hz | 100 m |
| BSW (Blind Spot) | Medium | < 200 ms | 5 Hz | 50 m |

## Emergency Electronic Brake Light (EEBL)

### Concept
Warns following vehicles when lead vehicle applies hard braking, providing early warning beyond visual brake lights.

### Triggering Conditions

```cpp
// eebl_detector.hpp
#pragma once

#include <cstdint>
#include <chrono>

namespace v2v {
namespace safety {

struct VehicleDynamics {
    double speed_mps;
    double acceleration_mps2;
    double deceleration_mps2;  // Positive value for braking
    bool brake_active;
    uint32_t timestamp_ms;
};

struct EEBLEvent {
    bool is_active;
    double severity;  // 0.0 - 1.0
    double deceleration_mps2;
    uint32_t duration_ms;
    double initial_speed_mps;
};

class EEBLDetector {
public:
    EEBLDetector(
        double hard_brake_threshold_mps2 = 4.0,  // ~ 0.4g
        double emergency_brake_threshold_mps2 = 6.0,  // ~ 0.6g
        uint32_t min_duration_ms = 200
    );

    // Process vehicle dynamics and detect EEBL condition
    EEBLEvent processVehicleDynamics(const VehicleDynamics& dynamics);

    // Check if received BSM from another vehicle triggers EEBL warning
    bool shouldWarnDriver(
        const EEBLEvent& remote_event,
        double distance_m,
        double own_speed_mps,
        double time_to_collision_s
    );

    // Calculate threat level
    double calculateThreatLevel(
        double distance_m,
        double relative_speed_mps,
        double remote_deceleration_mps2
    );

private:
    double hard_brake_threshold_;
    double emergency_brake_threshold_;
    uint32_t min_duration_;

    // State tracking
    EEBLEvent current_event_;
    uint32_t brake_start_time_;
    bool brake_in_progress_;
};

} // namespace safety
} // namespace v2v
```

```cpp
// eebl_detector.cpp
#include "eebl_detector.hpp"
#include <algorithm>
#include <cmath>

namespace v2v {
namespace safety {

EEBLDetector::EEBLDetector(
    double hard_brake_threshold_mps2,
    double emergency_brake_threshold_mps2,
    uint32_t min_duration_ms
) : hard_brake_threshold_(hard_brake_threshold_mps2),
    emergency_brake_threshold_(emergency_brake_threshold_mps2),
    min_duration_(min_duration_ms),
    brake_start_time_(0),
    brake_in_progress_(false) {

    current_event_.is_active = false;
}

EEBLEvent EEBLDetector::processVehicleDynamics(const VehicleDynamics& dynamics) {
    EEBLEvent event;
    event.is_active = false;

    // Check if hard braking is occurring
    if (dynamics.brake_active &&
        dynamics.deceleration_mps2 >= hard_brake_threshold_) {

        if (!brake_in_progress_) {
            // New braking event started
            brake_start_time_ = dynamics.timestamp_ms;
            brake_in_progress_ = true;
            current_event_.initial_speed_mps = dynamics.speed_mps;
        }

        uint32_t brake_duration = dynamics.timestamp_ms - brake_start_time_;

        if (brake_duration >= min_duration_) {
            // EEBL condition met
            event.is_active = true;
            event.deceleration_mps2 = dynamics.deceleration_mps2;
            event.duration_ms = brake_duration;
            event.initial_speed_mps = current_event_.initial_speed_mps;

            // Calculate severity (0.0 - 1.0)
            if (dynamics.deceleration_mps2 >= emergency_brake_threshold_) {
                event.severity = 1.0;
            } else {
                event.severity = (dynamics.deceleration_mps2 - hard_brake_threshold_) /
                               (emergency_brake_threshold_ - hard_brake_threshold_);
            }

            current_event_ = event;
        }
    } else {
        // Braking ended or not hard enough
        brake_in_progress_ = false;
    }

    return event;
}

bool EEBLDetector::shouldWarnDriver(
    const EEBLEvent& remote_event,
    double distance_m,
    double own_speed_mps,
    double time_to_collision_s
) {
    if (!remote_event.is_active) {
        return false;
    }

    // Warn if TTC is less than critical threshold
    const double TTC_WARNING_THRESHOLD = 4.0;  // seconds
    if (time_to_collision_s < TTC_WARNING_THRESHOLD) {
        return true;
    }

    // Warn if distance is close and severity is high
    const double CLOSE_DISTANCE = 50.0;  // meters
    if (distance_m < CLOSE_DISTANCE && remote_event.severity > 0.7) {
        return true;
    }

    return false;
}

double EEBLDetector::calculateThreatLevel(
    double distance_m,
    double relative_speed_mps,
    double remote_deceleration_mps2
) {
    // Calculate time to collision
    double ttc = (relative_speed_mps > 0.1) ?
                 (distance_m / relative_speed_mps) : 999.0;

    // Threat increases with: shorter TTC, higher relative speed, harder braking
    double ttc_factor = std::max(0.0, 1.0 - ttc / 5.0);  // 5 sec threshold
    double speed_factor = std::min(1.0, relative_speed_mps / 20.0);  // 20 m/s threshold
    double decel_factor = std::min(1.0, remote_deceleration_mps2 / 8.0);  // 8 m/s^2 threshold

    return (ttc_factor * 0.5 + speed_factor * 0.3 + decel_factor * 0.2);
}

} // namespace safety
} // namespace v2v
```

### EEBL Warning Message Format

```cpp
// eebl_message.hpp
#pragma once

#include <cstdint>
#include <vector>

namespace v2v {
namespace safety {

struct EEBLMessage {
    // Header
    uint8_t message_type;  // 0x01 for EEBL
    uint32_t sender_id;
    uint32_t timestamp_ms;

    // Location
    int32_t latitude;   // 1/10 micro-degree
    int32_t longitude;

    // Vehicle dynamics at brake event
    uint16_t speed_at_brake_mps;  // 0.01 m/s resolution
    uint16_t deceleration_mps2;   // 0.01 m/s^2 resolution
    uint8_t brake_severity;       // 0-100

    // Event information
    uint16_t event_duration_ms;
    uint8_t event_flags;  // Bit 0: ABS active, Bit 1: Stability control active

    // Encode to byte array for transmission
    std::vector<uint8_t> encode() const;

    // Decode from received byte array
    static bool decode(const std::vector<uint8_t>& data, EEBLMessage& msg);
};

} // namespace safety
} // namespace v2v
```

## Forward Collision Warning (FCW)

### Algorithm

```cpp
// fcw_calculator.hpp
#pragma once

#include <cstdint>
#include <cmath>

namespace v2v {
namespace safety {

struct FCWResult {
    bool warning_required;
    double time_to_collision_s;
    double collision_probability;
    uint8_t warning_level;  // 0: None, 1: Advisory, 2: Caution, 3: Imminent
};

class FCWCalculator {
public:
    FCWCalculator();

    // Calculate FCW based on own vehicle and lead vehicle states
    FCWResult calculateFCW(
        // Own vehicle
        double own_speed_mps,
        double own_acceleration_mps2,

        // Lead vehicle (from V2V)
        double lead_speed_mps,
        double lead_acceleration_mps2,
        double distance_m,

        // Road conditions
        double road_friction = 0.8,  // 0.0 - 1.0
        double driver_reaction_time_s = 1.5
    );

    // Time to collision calculation
    double calculateTTC(
        double distance_m,
        double own_speed_mps,
        double lead_speed_mps
    );

    // Required Safe Distance (RSD)
    double calculateRSD(
        double own_speed_mps,
        double lead_speed_mps,
        double own_decel_capability_mps2,
        double lead_decel_capability_mps2,
        double reaction_time_s
    );

private:
    // Thresholds
    double ttc_caution_threshold_;   // 2.5 seconds
    double ttc_warning_threshold_;   // 1.5 seconds
    double ttc_imminent_threshold_;  // 0.8 seconds

    // Vehicle parameters
    double max_deceleration_;  // 8.0 m/s^2 (emergency)
    double comfort_deceleration_;  // 4.0 m/s^2
};

} // namespace safety
} // namespace v2v
```

```cpp
// fcw_calculator.cpp
#include "fcw_calculator.hpp"
#include <algorithm>

namespace v2v {
namespace safety {

FCWCalculator::FCWCalculator()
    : ttc_caution_threshold_(2.5),
      ttc_warning_threshold_(1.5),
      ttc_imminent_threshold_(0.8),
      max_deceleration_(8.0),
      comfort_deceleration_(4.0) {}

FCWResult FCWCalculator::calculateFCW(
    double own_speed_mps,
    double own_acceleration_mps2,
    double lead_speed_mps,
    double lead_acceleration_mps2,
    double distance_m,
    double road_friction,
    double driver_reaction_time_s
) {
    FCWResult result;
    result.warning_required = false;
    result.warning_level = 0;

    // Calculate relative speed
    double relative_speed_mps = own_speed_mps - lead_speed_mps;

    // No warning if not closing in
    if (relative_speed_mps <= 0.0) {
        result.time_to_collision_s = 999.0;
        result.collision_probability = 0.0;
        return result;
    }

    // Calculate Time to Collision
    result.time_to_collision_s = calculateTTC(
        distance_m, own_speed_mps, lead_speed_mps
    );

    // Adjust max deceleration for road friction
    double available_decel = max_deceleration_ * road_friction;

    // Calculate Required Safe Distance
    double rsd = calculateRSD(
        own_speed_mps,
        lead_speed_mps,
        available_decel,
        max_deceleration_,  // Assume lead can brake harder
        driver_reaction_time_s
    );

    // Determine warning level
    if (result.time_to_collision_s < ttc_imminent_threshold_ ||
        distance_m < rsd * 0.5) {
        result.warning_level = 3;  // Imminent
        result.warning_required = true;
        result.collision_probability = 0.9;
    }
    else if (result.time_to_collision_s < ttc_warning_threshold_ ||
             distance_m < rsd * 0.7) {
        result.warning_level = 2;  // Warning
        result.warning_required = true;
        result.collision_probability = 0.6;
    }
    else if (result.time_to_collision_s < ttc_caution_threshold_ ||
             distance_m < rsd * 0.9) {
        result.warning_level = 1;  // Caution
        result.warning_required = true;
        result.collision_probability = 0.3;
    }

    return result;
}

double FCWCalculator::calculateTTC(
    double distance_m,
    double own_speed_mps,
    double lead_speed_mps
) {
    double relative_speed = own_speed_mps - lead_speed_mps;

    if (relative_speed <= 0.1) {
        return 999.0;  // Not closing in
    }

    return distance_m / relative_speed;
}

double FCWCalculator::calculateRSD(
    double own_speed_mps,
    double lead_speed_mps,
    double own_decel_capability_mps2,
    double lead_decel_capability_mps2,
    double reaction_time_s
) {
    // Distance traveled during reaction time
    double reaction_distance = own_speed_mps * reaction_time_s;

    // Braking distance for own vehicle
    double own_brake_distance = (own_speed_mps * own_speed_mps) /
                                (2.0 * own_decel_capability_mps2);

    // Braking distance for lead vehicle (could be braking too)
    double lead_brake_distance = (lead_speed_mps * lead_speed_mps) /
                                 (2.0 * lead_decel_capability_mps2);

    // Required safe distance
    double rsd = reaction_distance + own_brake_distance - lead_brake_distance;

    // Add safety margin (2 seconds at current speed)
    rsd += 2.0 * own_speed_mps;

    return std::max(5.0, rsd);  // Minimum 5 meters
}

} // namespace safety
} // namespace v2v
```

## Intersection Movement Assist (IMA)

### Concept
Warns drivers of potential collisions at intersections using V2V communication with crossing/turning vehicles.

### Implementation

```python
# ima_module.py
"""
Intersection Movement Assist (IMA) implementation.
Detects potential intersection collisions using V2V data.
"""

import math
from dataclasses import dataclass
from typing import List, Tuple, Optional
from enum import Enum

class IntersectionApproach(Enum):
    NORTH = 0
    EAST = 1
    SOUTH = 2
    WEST = 3

class TurnIntent(Enum):
    STRAIGHT = 0
    LEFT = 1
    RIGHT = 2
    U_TURN = 3

@dataclass
class VehicleState:
    vehicle_id: int
    latitude: float
    longitude: float
    speed_mps: float
    heading_deg: float  # 0=North, 90=East, 180=South, 270=West
    acceleration_mps2: float
    turn_signal: TurnIntent
    distance_to_intersection_m: float

@dataclass
class IntersectionGeometry:
    center_lat: float
    center_lon: float
    radius_m: float  # Intersection zone radius
    approach_lanes: int

class IMAModule:
    """
    Intersection Movement Assist module.
    """

    def __init__(self, intersection_geometry: IntersectionGeometry):
        self.intersection = intersection_geometry
        self.ttc_warning_threshold_s = 3.0
        self.ttc_critical_threshold_s = 1.5

    def assess_collision_risk(
        self,
        own_vehicle: VehicleState,
        remote_vehicles: List[VehicleState]
    ) -> List[Tuple[int, float, str]]:
        """
        Assess collision risk at intersection.

        Returns:
            List of (vehicle_id, collision_probability, warning_message)
        """
        warnings = []

        for remote in remote_vehicles:
            # Check if both vehicles are approaching intersection
            if not self._is_approaching_intersection(own_vehicle):
                continue
            if not self._is_approaching_intersection(remote):
                continue

            # Calculate time to intersection for both vehicles
            own_tti = self._time_to_intersection(own_vehicle)
            remote_tti = self._time_to_intersection(remote)

            if own_tti is None or remote_tti is None:
                continue

            # Check if paths will conflict
            conflict = self._check_path_conflict(
                own_vehicle, remote, own_tti, remote_tti
            )

            if conflict:
                time_diff = abs(own_tti - remote_tti)

                if time_diff < self.ttc_critical_threshold_s:
                    prob = 0.9
                    msg = f"CRITICAL: Collision imminent with vehicle {remote.vehicle_id}"
                    warnings.append((remote.vehicle_id, prob, msg))
                elif time_diff < self.ttc_warning_threshold_s:
                    prob = 0.6
                    msg = f"WARNING: Potential collision with vehicle {remote.vehicle_id}"
                    warnings.append((remote.vehicle_id, prob, msg))

        return warnings

    def _is_approaching_intersection(self, vehicle: VehicleState) -> bool:
        """Check if vehicle is approaching the intersection."""
        # Within approach zone (100m) and moving toward intersection
        if vehicle.distance_to_intersection_m > 100.0:
            return False
        if vehicle.speed_mps < 1.0:  # Essentially stopped
            return False
        return True

    def _time_to_intersection(self, vehicle: VehicleState) -> Optional[float]:
        """
        Calculate time for vehicle to reach intersection center.

        Returns:
            Time in seconds, or None if not approaching
        """
        if vehicle.speed_mps < 0.5:
            return None

        # Simple calculation assuming constant speed
        # In reality, should account for acceleration and traffic signals
        tti = vehicle.distance_to_intersection_m / vehicle.speed_mps

        # If decelerating significantly, may not reach intersection
        if vehicle.acceleration_mps2 < -2.0:
            # Check if vehicle will stop before intersection
            stop_distance = (vehicle.speed_mps ** 2) / (2 * abs(vehicle.acceleration_mps2))
            if stop_distance < vehicle.distance_to_intersection_m:
                return None  # Will stop before intersection

        return tti

    def _check_path_conflict(
        self,
        own: VehicleState,
        remote: VehicleState,
        own_tti: float,
        remote_tti: float
    ) -> bool:
        """
        Determine if vehicle paths will conflict in intersection.

        Simplified conflict detection based on approach directions and turn intents.
        """
        own_approach = self._get_approach_direction(own.heading_deg)
        remote_approach = self._get_approach_direction(remote.heading_deg)

        # Opposite approaches
        if abs(own_approach.value - remote_approach.value) == 2:
            # Straight vs straight: no conflict
            if own.turn_signal == TurnIntent.STRAIGHT and \
               remote.turn_signal == TurnIntent.STRAIGHT:
                return False
            # Left turn conflicts with opposite straight or left
            if own.turn_signal == TurnIntent.LEFT or \
               remote.turn_signal == TurnIntent.LEFT:
                return True

        # Perpendicular approaches
        elif abs(own_approach.value - remote_approach.value) % 2 == 1:
            # Always potential conflict for perpendicular
            return True

        # Same approach (following)
        else:
            # Usually no conflict unless one is turning
            return False

        return False

    @staticmethod
    def _get_approach_direction(heading_deg: float) -> IntersectionApproach:
        """Determine which approach direction based on heading."""
        heading_normalized = heading_deg % 360

        if 315 <= heading_normalized or heading_normalized < 45:
            return IntersectionApproach.NORTH
        elif 45 <= heading_normalized < 135:
            return IntersectionApproach.EAST
        elif 135 <= heading_normalized < 225:
            return IntersectionApproach.SOUTH
        else:
            return IntersectionApproach.WEST

    def calculate_stopping_distance(
        self,
        speed_mps: float,
        decel_mps2: float = 5.0,
        reaction_time_s: float = 1.0
    ) -> float:
        """Calculate total stopping distance."""
        reaction_distance = speed_mps * reaction_time_s
        brake_distance = (speed_mps ** 2) / (2 * decel_mps2)
        return reaction_distance + brake_distance


# Example usage
if __name__ == "__main__":
    # Define intersection
    intersection = IntersectionGeometry(
        center_lat=37.7749,
        center_lon=-122.4194,
        radius_m=20.0,
        approach_lanes=4
    )

    ima = IMAModule(intersection)

    # Own vehicle approaching from south
    own = VehicleState(
        vehicle_id=1,
        latitude=37.7745,
        longitude=-122.4194,
        speed_mps=15.0,  # ~33 mph
        heading_deg=0.0,  # North
        acceleration_mps2=0.0,
        turn_signal=TurnIntent.STRAIGHT,
        distance_to_intersection_m=40.0
    )

    # Remote vehicle approaching from east
    remote = VehicleState(
        vehicle_id=2,
        latitude=37.7749,
        longitude=-122.4190,
        speed_mps=12.0,  # ~27 mph
        heading_deg=270.0,  # West
        acceleration_mps2=0.0,
        turn_signal=TurnIntent.STRAIGHT,
        distance_to_intersection_m=35.0
    )

    warnings = ima.assess_collision_risk(own, [remote])

    for vehicle_id, prob, msg in warnings:
        print(f"Vehicle {vehicle_id}: Probability={prob:.2f}, Message={msg}")
```

## Cooperative Adaptive Cruise Control (CACC)

### Control Architecture

```
┌──────────────────────────────────────────────────────┐
│              CACC Controller Architecture             │
└──────────────────────────────────────────────────────┘
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
        ▼                 ▼                 ▼
┌──────────────┐  ┌──────────────┐  ┌─────────────┐
│  V2V Input   │  │ Radar/Camera │  │ Vehicle CAN │
│   (BSM)      │  │    Input     │  │   Bus Data  │
└──────┬───────┘  └──────┬───────┘  └──────┬──────┘
       │                 │                  │
       └────────┬────────┴──────────────────┘
                ▼
        ┌──────────────────┐
        │  Sensor Fusion   │
        │  & Estimation    │
        └────────┬─────────┘
                 ▼
        ┌──────────────────┐
        │  CACC Controller │
        │  (PID + Feedfwd) │
        └────────┬─────────┘
                 ▼
        ┌──────────────────┐
        │ Actuator Command │
        │ (Throttle/Brake) │
        └──────────────────┘
```

### CACC Controller Implementation

```cpp
// cacc_controller.hpp
#pragma once

#include <cstdint>
#include <deque>

namespace v2v {
namespace cacc {

struct LeadVehicleState {
    double position_m;      // Longitudinal position
    double velocity_mps;
    double acceleration_mps2;
    uint32_t timestamp_ms;
    bool v2v_available;     // True if from V2V, false if from radar
};

struct CACCConfig {
    double desired_time_gap_s;          // 0.6 - 2.0 seconds typical
    double min_following_distance_m;    // 5.0 meters minimum
    double max_acceleration_mps2;       // 2.0 m/s^2 comfort limit
    double max_deceleration_mps2;       // -4.0 m/s^2 comfort limit
    double max_jerk_mps3;              // 3.0 m/s^3 comfort limit

    // Controller gains
    double kp_spacing;                  // Proportional gain for spacing error
    double kd_spacing;                  // Derivative gain
    double kp_velocity;                 // Proportional gain for velocity error
    double feedforward_gain;            // Feedforward from lead acceleration
};

struct CACCOutput {
    double desired_acceleration_mps2;
    double desired_speed_mps;
    bool emergency_brake_required;
    double spacing_error_m;
};

class CACCController {
public:
    explicit CACCController(const CACCConfig& config);

    // Main control loop
    CACCOutput computeControl(
        const LeadVehicleState& lead,
        double own_velocity_mps,
        double own_acceleration_mps2,
        double measured_distance_m
    );

    // Update configuration (e.g., time gap adjustment)
    void updateConfig(const CACCConfig& config);

    // Reset controller state
    void reset();

    // Enable/disable string stability mode
    void setStringStabilityMode(bool enable);

private:
    CACCConfig config_;
    bool string_stability_mode_;

    // State history for derivative calculation
    std::deque<double> spacing_error_history_;
    std::deque<uint32_t> timestamp_history_;

    // Calculate desired spacing
    double calculateDesiredSpacing(double own_velocity_mps);

    // PID control
    double computePIDControl(
        double spacing_error,
        double velocity_error,
        uint32_t dt_ms
    );

    // String stability filter (Harmonic method)
    double applyStringStabilityFilter(
        double desired_accel,
        double lead_accel
    );

    // Safety bounds
    double applySafetyLimits(double accel_command);
};

} // namespace cacc
} // namespace v2v
```

```cpp
// cacc_controller.cpp
#include "cacc_controller.hpp"
#include <algorithm>
#include <cmath>

namespace v2v {
namespace cacc {

CACCController::CACCController(const CACCConfig& config)
    : config_(config), string_stability_mode_(true) {}

CACCOutput CACCController::computeControl(
    const LeadVehicleState& lead,
    double own_velocity_mps,
    double own_acceleration_mps2,
    double measured_distance_m
) {
    CACCOutput output;

    // Calculate desired spacing based on time gap policy
    double desired_spacing = calculateDesiredSpacing(own_velocity_mps);

    // Spacing error (positive = too far, negative = too close)
    double spacing_error = measured_distance_m - desired_spacing;
    output.spacing_error_m = spacing_error;

    // Velocity error (positive = lead is faster)
    double velocity_error = lead.velocity_mps - own_velocity_mps;

    // PID control
    double pid_accel = computePIDControl(
        spacing_error,
        velocity_error,
        100  // Assume 100ms update rate
    );

    // Feedforward from lead vehicle acceleration (if V2V available)
    double feedforward_accel = 0.0;
    if (lead.v2v_available) {
        feedforward_accel = config_.feedforward_gain * lead.acceleration_mps2;
    }

    // Combined control
    double desired_accel = pid_accel + feedforward_accel;

    // String stability filter
    if (string_stability_mode_) {
        desired_accel = applyStringStabilityFilter(desired_accel, lead.acceleration_mps2);
    }

    // Apply safety limits
    desired_accel = applySafetyLimits(desired_accel);

    output.desired_acceleration_mps2 = desired_accel;
    output.desired_speed_mps = own_velocity_mps + desired_accel * 0.1;  // Next step estimate

    // Emergency brake if critical spacing
    double critical_spacing = config_.min_following_distance_m;
    output.emergency_brake_required = (measured_distance_m < critical_spacing) &&
                                     (velocity_error < -2.0);  // Closing fast

    return output;
}

double CACCController::calculateDesiredSpacing(double own_velocity_mps) {
    // Constant time gap policy: d_des = d_min + h * v
    double spacing = config_.min_following_distance_m +
                    config_.desired_time_gap_s * own_velocity_mps;

    return std::max(spacing, config_.min_following_distance_m);
}

double CACCController::computePIDControl(
    double spacing_error,
    double velocity_error,
    uint32_t dt_ms
) {
    // Proportional term on spacing
    double p_term = config_.kp_spacing * spacing_error;

    // Derivative term on spacing (rate of change of error)
    double d_term = 0.0;
    if (spacing_error_history_.size() >= 2) {
        double error_rate = (spacing_error - spacing_error_history_.back()) /
                           (dt_ms / 1000.0);
        d_term = config_.kd_spacing * error_rate;
    }

    // Proportional term on velocity error
    double v_term = config_.kp_velocity * velocity_error;

    // Update history
    spacing_error_history_.push_back(spacing_error);
    if (spacing_error_history_.size() > 10) {
        spacing_error_history_.pop_front();
    }

    return p_term + d_term + v_term;
}

double CACCController::applyStringStabilityFilter(
    double desired_accel,
    double lead_accel
) {
    // Ensure acceleration doesn't amplify upstream
    // Simple low-pass filter for string stability
    const double alpha = 0.3;  // Filter coefficient
    double filtered_accel = alpha * desired_accel + (1.0 - alpha) * lead_accel;

    // Additional constraint: don't accelerate harder than lead
    if (desired_accel > lead_accel) {
        filtered_accel = std::min(filtered_accel, lead_accel * 1.1);
    }

    return filtered_accel;
}

double CACCController::applySafetyLimits(double accel_command) {
    // Clamp to comfort limits
    accel_command = std::clamp(
        accel_command,
        config_.max_deceleration_mps2,
        config_.max_acceleration_mps2
    );

    return accel_command;
}

void CACCController::updateConfig(const CACCConfig& config) {
    config_ = config;
}

void CACCController::reset() {
    spacing_error_history_.clear();
    timestamp_history_.clear();
}

void CACCController::setStringStabilityMode(bool enable) {
    string_stability_mode_ = enable;
}

} // namespace cacc
} // namespace v2v
```

## Platooning Algorithms

### String Stability Analysis

**Objective:** Ensure disturbances don't amplify upstream in a platoon.

**Transfer Function (Frequency Domain):**
```
H(jω) = |x_i(jω) / x_{i-1}(jω)|

String stable if: |H(jω)| ≤ 1 for all ω
```

### Platoon Formation Protocol

```python
# platoon_manager.py
"""
Cooperative vehicle platooning manager.
Handles platoon formation, maintenance, and dissolution.
"""

from enum import Enum
from dataclasses import dataclass
from typing import List, Optional
import time

class PlatoonRole(Enum):
    LEADER = 1
    FOLLOWER = 2
    JOINING = 3
    LEAVING = 4

class PlatoonState(Enum):
    FORMING = 1
    STABLE = 2
    SPLITTING = 3
    MERGING = 4

@dataclass
class PlatoonMember:
    vehicle_id: int
    position_in_platoon: int  # 0=leader, 1=first follower, etc.
    role: PlatoonRole
    spacing_m: float
    time_gap_s: float
    communication_quality: float  # 0.0-1.0

@dataclass
class PlatoonConfig:
    max_platoon_size: int = 8
    min_spacing_m: float = 5.0
    target_time_gap_s: float = 0.6
    max_join_speed_diff_mps: float = 2.0
    communication_timeout_s: float = 1.0

class PlatoonManager:
    """
    Manages cooperative platoon operations.
    """

    def __init__(self, vehicle_id: int, config: PlatoonConfig):
        self.vehicle_id = vehicle_id
        self.config = config
        self.platoon_id: Optional[int] = None
        self.role = PlatoonRole.LEADER  # Default until joining platoon
        self.members: List[PlatoonMember] = []
        self.state = PlatoonState.STABLE

    def request_join_platoon(self, platoon_id: int, leader_speed_mps: float,
                            own_speed_mps: float) -> bool:
        """
        Request to join an existing platoon.

        Returns:
            True if join request is feasible, False otherwise
        """
        # Check speed compatibility
        speed_diff = abs(leader_speed_mps - own_speed_mps)
        if speed_diff > self.config.max_join_speed_diff_mps:
            print(f"Speed difference {speed_diff:.1f} m/s too large")
            return False

        # Check platoon size
        if len(self.members) >= self.config.max_platoon_size:
            print("Platoon full")
            return False

        # Initiate join sequence
        self.role = PlatoonRole.JOINING
        self.platoon_id = platoon_id
        self.state = PlatoonState.MERGING

        print(f"Vehicle {self.vehicle_id} joining platoon {platoon_id}")
        return True

    def execute_join_maneuver(self, target_position: int,
                             current_speed_mps: float) -> dict:
        """
        Execute the join maneuver.

        Returns:
            Control commands dict with 'target_speed', 'target_spacing'
        """
        # Calculate target spacing for join maneuver
        # Use larger spacing initially, then tighten
        join_spacing = self.config.min_spacing_m * 2.0
        target_time_gap = self.config.target_time_gap_s * 1.5

        return {
            'target_speed_mps': current_speed_mps,
            'target_spacing_m': join_spacing,
            'target_time_gap_s': target_time_gap,
            'approach_rate_mps': 0.5  # Gentle approach
        }

    def confirm_join_complete(self) -> bool:
        """
        Confirm that join maneuver is complete and stable.
        """
        if self.role != PlatoonRole.JOINING:
            return False

        # Check if spacing is within tolerance
        # Check if V2V communication is stable
        # (Simplified for example)

        self.role = PlatoonRole.FOLLOWER
        self.state = PlatoonState.STABLE
        print(f"Vehicle {self.vehicle_id} successfully joined platoon")
        return True

    def request_leave_platoon(self, reason: str = "") -> bool:
        """
        Request to leave the platoon.
        """
        if self.role == PlatoonRole.LEADER:
            # Leader leaving requires handoff or dissolution
            return self._initiate_leader_handoff()
        else:
            self.role = PlatoonRole.LEAVING
            self.state = PlatoonState.SPLITTING
            print(f"Vehicle {self.vehicle_id} leaving platoon: {reason}")
            return True

    def execute_leave_maneuver(self) -> dict:
        """
        Execute the leave maneuver.

        Returns:
            Control commands for safe departure
        """
        # Gradually increase spacing
        # Move to adjacent lane when safe
        return {
            'target_spacing_m': self.config.min_spacing_m * 3.0,
            'lane_change_direction': 'right',
            'deceleration_mps2': -1.0  # Gentle deceleration
        }

    def confirm_leave_complete(self) -> bool:
        """
        Confirm that leave maneuver is complete.
        """
        self.role = PlatoonRole.LEADER  # Back to independent
        self.platoon_id = None
        self.members.clear()
        self.state = PlatoonState.STABLE
        print(f"Vehicle {self.vehicle_id} left platoon")
        return True

    def _initiate_leader_handoff(self) -> bool:
        """
        Hand off leadership to next vehicle in platoon.
        """
        if len(self.members) < 2:
            # No successor, just dissolve
            return self._dissolve_platoon()

        # Designate first follower as new leader
        next_leader = self.members[1]  # Position 1 is first follower
        print(f"Handing off leadership to vehicle {next_leader.vehicle_id}")

        # Send handoff command (via V2V)
        # ...

        self.role = PlatoonRole.LEAVING
        return True

    def _dissolve_platoon(self) -> bool:
        """
        Dissolve the platoon.
        """
        print(f"Dissolving platoon {self.platoon_id}")
        for member in self.members:
            # Send dissolution message to all members
            pass

        self.platoon_id = None
        self.members.clear()
        return True

    def calculate_fuel_savings(self, platoon_size: int, spacing_m: float) -> float:
        """
        Estimate fuel savings from platooning.

        Based on research: 5-15% savings for followers depending on spacing.
        """
        if platoon_size < 2:
            return 0.0

        # Leader: minimal savings
        if self.role == PlatoonRole.LEADER:
            return 0.02  # 2%

        # Followers: savings increase with closer spacing
        base_savings = 0.10  # 10% at 10m spacing
        spacing_factor = max(0.5, 1.0 - (spacing_m - 5.0) / 20.0)
        position_factor = 1.0 / (self.members[0].position_in_platoon + 1)

        return base_savings * spacing_factor * position_factor

# Example usage
if __name__ == "__main__":
    config = PlatoonConfig()
    vehicle = PlatoonManager(vehicle_id=42, config=config)

    # Request to join platoon
    can_join = vehicle.request_join_platoon(
        platoon_id=100,
        leader_speed_mps=25.0,
        own_speed_mps=24.0
    )

    if can_join:
        # Execute join maneuver
        commands = vehicle.execute_join_maneuver(
            target_position=3,
            current_speed_mps=24.5
        )
        print(f"Join commands: {commands}")

        # Simulate joining
        time.sleep(5)
        vehicle.confirm_join_complete()

        # Estimate fuel savings
        savings = vehicle.calculate_fuel_savings(platoon_size=4, spacing_m=8.0)
        print(f"Estimated fuel savings: {savings*100:.1f}%")
```

## Safety Application Integration

### Multi-Application Coordinator

```cpp
// v2v_app_coordinator.hpp
#pragma once

#include "eebl_detector.hpp"
#include "fcw_calculator.hpp"
#include "ima_module.hpp"
#include "cacc_controller.hpp"

namespace v2v {
namespace safety {

enum class WarningPriority {
    NONE = 0,
    LOW = 1,
    MEDIUM = 2,
    HIGH = 3,
    CRITICAL = 4
};

struct ApplicationWarning {
    std::string app_name;
    WarningPriority priority;
    std::string message;
    uint32_t timestamp_ms;
};

class V2VApplicationCoordinator {
public:
    V2VApplicationCoordinator();

    // Process all V2V applications
    void processApplications(
        const VehicleDynamics& own_dynamics,
        const std::vector<RemoteVehicle>& remote_vehicles
    );

    // Get highest priority warning for HMI
    ApplicationWarning getActiveWarning();

    // Enable/disable specific applications
    void setAppEnabled(const std::string& app_name, bool enabled);

private:
    EEBLDetector eebl_;
    FCWCalculator fcw_;
    // IMAModule ima_;
    // CACCController cacc_;

    std::vector<ApplicationWarning> active_warnings_;

    void processEEBL(const VehicleDynamics& dynamics);
    void processFCW(const VehicleDynamics& own, const RemoteVehicle& lead);

    ApplicationWarning selectHighestPriority();
};

} // namespace safety
} // namespace v2v
```

## Testing and Validation

### Hardware-in-Loop (HIL) Test Scenarios

```yaml
# v2v_hil_test_scenarios.yaml
scenarios:
  - name: EEBL_Hard_Braking
    description: Lead vehicle applies emergency brakes
    duration_s: 10
    steps:
      - time: 0
        action: Set lead vehicle speed to 25 m/s
        action: Set following vehicle speed to 25 m/s
        action: Set spacing to 30 m
      - time: 5
        action: Lead vehicle emergency brake at -8 m/s^2
      - time: 5.05
        expected: EEBL message transmitted
      - time: 5.15
        expected: Following vehicle receives warning
        expected: Following vehicle initiates braking

  - name: FCW_Closing_Speed
    description: Follower closing on slower lead vehicle
    duration_s: 15
    steps:
      - time: 0
        action: Set lead vehicle speed to 15 m/s
        action: Set following vehicle speed to 25 m/s
        action: Set spacing to 100 m
      - time: 5
        expected: FCW caution warning (TTC < 2.5s)
      - time: 8
        expected: FCW critical warning (TTC < 1.5s)
      - time: 10
        expected: Automatic emergency braking engaged

  - name: IMA_Crossing_Path
    description: Two vehicles on collision course at intersection
    duration_s: 8
    steps:
      - time: 0
        action: Vehicle A approaches from south at 15 m/s
        action: Vehicle B approaches from east at 12 m/s
      - time: 3
        expected: IMA warning issued to both vehicles
      - time: 5
        expected: One vehicle yields (protocol dependent)
```

## References

1. **SAE J2945/1**: On-Board System Requirements for V2V Safety Communications
2. **NHTSA**: Vehicle-to-Vehicle Communication Technology for Light Vehicles
3. **Shladover, S. et al.**: "Cooperative Adaptive Cruise Control: Testing Drivers' Choices and Reactions"
4. **Ploeg, J. et al.**: "Design and Experimental Evaluation of Cooperative Adaptive Cruise Control"
5. **Rajamani, R.**: "Vehicle Dynamics and Control" (Chapter on ACC/CACC)
