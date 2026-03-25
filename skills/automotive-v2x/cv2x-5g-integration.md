# C-V2X and 5G Integration

## Overview
C-V2X (Cellular V2X) integration with 5G networks including PC5 sidelink communication modes, network slicing, Multi-access Edge Computing (MEC), Ultra-Reliable Low-Latency Communication (URLLC), and 5G NR V2X features.

## C-V2X Communication Modes

### Mode 3 vs Mode 4 Comparison

| Feature | Mode 3 (Network Scheduled) | Mode 4 (Autonomous/D2D) |
|---------|---------------------------|------------------------|
| Infrastructure Required | Yes (eNodeB/gNodeB) | No (direct sidelink) |
| Resource Allocation | Network-scheduled (centralized) | Distributed sensing |
| Coverage Dependency | Requires cellular coverage | Works without network |
| Typical Latency | 20-50 ms (via network) | 10-20 ms (direct) |
| QoS Guarantee | Network-enforced QoS | Best-effort coordination |
| Ideal Use Case | Urban with good coverage | Rural, tunnels, emergencies |
| Handover | Network-managed | Autonomous |
| Power Consumption | Higher (constant network sync) | Lower (periodic only) |

### 5G NR-V2X Physical Layer

**Frequency Bands:**
```
5.9 GHz ITS Band:
- 5.855-5.925 GHz (US, EU, Asia harmonized)
- Channel bandwidth: 10/20 MHz
- Supports both DSRC coexistence and C-V2X

Licensed Spectrum:
- Band n78 (3.5 GHz): High capacity urban
- Band n79 (4.7 GHz): Regional deployments
- Mmwave (28/39 GHz): Ultra-high data rate applications
```

**Numerology:**
```
Subcarrier spacing: 15/30/60 kHz
- 15 kHz: Long range, low mobility
- 30 kHz: Standard V2X (recommended)
- 60 kHz: High mobility scenarios

Symbol duration: 66.7/33.3/16.7 μs
Cyclic prefix: 4.7/2.3/1.2 μs
```

## Network Slicing for V2X

### Slice Configuration

```python
# network_slicing.py
"""
5G Network slicing for differentiated V2X services.
"""

from dataclasses import dataclass
from enum import Enum
from typing import List

class SliceServiceType(Enum):
    """Service and Slice Differentiator (SST)"""
    URLLC = 1  # Ultra-reliable low-latency
    EMBB = 2   # Enhanced mobile broadband
    MMTC = 3   # Massive machine-type communications

@dataclass
class NetworkSliceDescriptor:
    """5G Network Slice Selection Assistance Information (NSSAI)"""
    sst: SliceServiceType  # Slice/Service Type
    sd: int  # Slice Differentiator (24 bits)

    # Performance KPIs
    target_latency_ms: int
    reliability_percent: float
    max_data_rate_mbps: int
    connection_density_per_km2: int

    # Resource allocation
    guaranteed_bit_rate_mbps: int
    priority_level: int  # 1 (highest) to 15 (lowest)

# V2V Safety Communications Slice
SLICE_V2V_SAFETY = NetworkSliceDescriptor(
    sst=SliceServiceType.URLLC,
    sd=0x000001,  # V2V safety specific
    target_latency_ms=5,
    reliability_percent=99.9999,  # Six nines
    max_data_rate_mbps=10,
    connection_density_per_km2=10000,
    guaranteed_bit_rate_mbps=2,
    priority_level=1
)

# V2I Traffic Management Slice
SLICE_V2I_TRAFFIC = NetworkSliceDescriptor(
    sst=SliceServiceType.URLLC,
    sd=0x000002,
    target_latency_ms=20,
    reliability_percent=99.99,
    max_data_rate_mbps=5,
    connection_density_per_km2=5000,
    guaranteed_bit_rate_mbps=1,
    priority_level=3
)

# V2N Infotainment Slice
SLICE_V2N_INFOTAINMENT = NetworkSliceDescriptor(
    sst=SliceServiceType.EMBB,
    sd=0x000003,
    target_latency_ms=100,
    reliability_percent=99.0,
    max_data_rate_mbps=100,
    connection_density_per_km2=1000,
    guaranteed_bit_rate_mbps=10,
    priority_level=10
)

class NetworkSliceManager:
    """Manage network slice selection for V2X traffic."""

    def __init__(self):
        self.available_slices = [
            SLICE_V2V_SAFETY,
            SLICE_V2I_TRAFFIC,
            SLICE_V2N_INFOTAINMENT
        ]
        self.current_slice = None

    def select_slice_for_message(self, message_type: str, qos_requirement: str) -> NetworkSliceDescriptor:
        """
        Select appropriate network slice based on message type and QoS.

        Args:
            message_type: "BSM", "DENM", "CAM", "SPaT", "MAP", etc.
            qos_requirement: "critical", "high", "medium", "low"

        Returns:
            NetworkSliceDescriptor
        """
        # Safety-critical messages
        if message_type in ["BSM", "CAM", "DENM", "EEBL"] or qos_requirement == "critical":
            return SLICE_V2V_SAFETY

        # Infrastructure messages
        elif message_type in ["SPaT", "MAP", "TIM"] or qos_requirement == "high":
            return SLICE_V2I_TRAFFIC

        # Non-critical services
        else:
            return SLICE_V2N_INFOTAINMENT

    def request_slice_activation(self, nssai: NetworkSliceDescriptor) -> bool:
        """
        Request slice activation from 5G core.

        In production: NGAP signaling to AMF (Access and Mobility Management Function)
        """
        print(f"Requesting slice activation:")
        print(f"  SST: {nssai.sst.name}")
        print(f"  SD: {nssai.sd:#08x}")
        print(f"  Latency: {nssai.target_latency_ms} ms")
        print(f"  Reliability: {nssai.reliability_percent}%")

        # Simulate AMF response
        self.current_slice = nssai
        return True
```

## Multi-access Edge Computing (MEC)

### MEC Architecture for V2X

```
┌─────────────────────────────────────────────────────┐
│              5G Core Network (5GC)                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────┐  │
│  │   AMF    │  │   SMF    │  │      UPF         │  │
│  │ (Access) │  │ (Session)│  │ (User Plane)     │  │
│  └──────────┘  └──────────┘  └────────┬─────────┘  │
└──────────────────────────────────────────┼──────────┘
                                          │
        ┌─────────────────────────────────┼───────────────┐
        │          MEC Platform           │               │
        │  ┌──────────────────────────────▼────────────┐ │
        │  │  MEC Host (Co-located with gNodeB)        │ │
        │  │                                            │ │
        │  │  ┌────────────┐    ┌─────────────────┐   │ │
        │  │  │ V2X Server │    │ CPM Fusion      │   │ │
        │  │  │ (SPaT/MAP) │    │ Service         │   │ │
        │  │  └────────────┘    └─────────────────┘   │ │
        │  │                                            │ │
        │  │  ┌────────────┐    ┌─────────────────┐   │ │
        │  │  │ GLOSA      │    │ Misbehavior     │   │ │
        │  │  │ Calculator │    │ Detection       │   │ │
        │  │  └────────────┘    └─────────────────┘   │ │
        │  └────────────────────────────────────────── │ │
        └──────────────────────────────────────────────┘ │
                            │
        ┌───────────────────┼───────────────────────┐
        │                   ▼                       │
        │         ┌──────────────────┐              │
        │         │    gNodeB 5G     │              │
        │         │   Base Station   │              │
        │         └────────┬─────────┘              │
        │                  │                        │
        │    ┌─────────────┼─────────────┐          │
        │    │             │             │          │
        │    ▼             ▼             ▼          │
        │  Vehicle      Vehicle      Vehicle        │
        │  (UE)         (UE)         (UE)          │
        └──────────────────────────────────────────┘
```

### MEC Application: Collective Perception Fusion

```python
# mec_cpm_fusion.py
"""
MEC-based Collective Perception Message fusion service.
Aggregates CPMs from multiple vehicles for enhanced situational awareness.
"""

import time
from dataclasses import dataclass
from typing import List, Dict, Set
import math

@dataclass
class PerceivedObject:
    """Object detected by vehicle sensor."""
    object_id: int
    object_type: str  # "vehicle", "pedestrian", "cyclist"
    x_position_m: float
    y_position_m: float
    velocity_x_mps: float
    velocity_y_mps: float
    confidence: float
    source_vehicle_id: int
    timestamp_ms: int

@dataclass
class FusedObject:
    """Fused object from multiple vehicle observations."""
    fused_id: int
    object_type: str
    x_position_m: float
    y_position_m: float
    velocity_x_mps: float
    velocity_y_mps: float
    confidence: float
    contributing_vehicles: Set[int]
    last_update_ms: int

class MECCPMFusionService:
    """
    MEC service for fusing Collective Perception Messages.
    Runs at edge computing node near base station.
    """

    def __init__(self, fusion_radius_m: float = 500.0):
        self.fusion_radius = fusion_radius_m
        self.perceived_objects: Dict[int, PerceivedObject] = {}
        self.fused_objects: Dict[int, FusedObject] = {}
        self.next_fused_id = 1

    def ingest_cpm(self, vehicle_id: int, objects: List[PerceivedObject]):
        """
        Ingest CPM from vehicle.

        Args:
            vehicle_id: Source vehicle ID
            objects: List of perceived objects
        """
        current_time = int(time.time() * 1000)

        for obj in objects:
            obj.source_vehicle_id = vehicle_id
            obj.timestamp_ms = current_time

            # Store in perceived objects
            key = (vehicle_id, obj.object_id)
            self.perceived_objects[key] = obj

        # Trigger fusion
        self.fuse_perceptions()

    def fuse_perceptions(self):
        """
        Fuse perceived objects from multiple vehicles.
        Uses spatial clustering and Kalman filter fusion.
        """
        current_time = int(time.time() * 1000)

        # Remove stale observations (> 1 second old)
        stale_keys = [k for k, v in self.perceived_objects.items()
                     if current_time - v.timestamp_ms > 1000]
        for key in stale_keys:
            del self.perceived_objects[key]

        # Group objects by proximity
        ungrouped = list(self.perceived_objects.values())
        fused_groups = []

        while ungrouped:
            seed = ungrouped.pop(0)
            group = [seed]

            # Find nearby objects
            i = 0
            while i < len(ungrouped):
                obj = ungrouped[i]
                if self._are_same_object(seed, obj):
                    group.append(ungrouped.pop(i))
                else:
                    i += 1

            fused_groups.append(group)

        # Create fused objects
        self.fused_objects.clear()
        for group in fused_groups:
            fused = self._fuse_group(group)
            self.fused_objects[fused.fused_id] = fused

    def _are_same_object(self, obj1: PerceivedObject, obj2: PerceivedObject) -> bool:
        """Determine if two perceived objects are the same physical object."""
        # Distance threshold (3 meters)
        distance = math.sqrt(
            (obj1.x_position_m - obj2.x_position_m)**2 +
            (obj1.y_position_m - obj2.y_position_m)**2
        )

        if distance > 3.0:
            return False

        # Type must match
        if obj1.object_type != obj2.object_type:
            return False

        # Velocity similarity (5 m/s threshold)
        vel_diff = math.sqrt(
            (obj1.velocity_x_mps - obj2.velocity_x_mps)**2 +
            (obj1.velocity_y_mps - obj2.velocity_y_mps)**2
        )

        if vel_diff > 5.0:
            return False

        return True

    def _fuse_group(self, group: List[PerceivedObject]) -> FusedObject:
        """Fuse group of observations into single object."""
        # Weighted average by confidence
        total_weight = sum(obj.confidence for obj in group)

        x_fused = sum(obj.x_position_m * obj.confidence for obj in group) / total_weight
        y_fused = sum(obj.y_position_m * obj.confidence for obj in group) / total_weight
        vx_fused = sum(obj.velocity_x_mps * obj.confidence for obj in group) / total_weight
        vy_fused = sum(obj.velocity_y_mps * obj.confidence for obj in group) / total_weight

        # Confidence increases with multiple observations
        confidence_fused = min(1.0, sum(obj.confidence for obj in group) / len(group) * 1.2)

        fused = FusedObject(
            fused_id=self.next_fused_id,
            object_type=group[0].object_type,
            x_position_m=x_fused,
            y_position_m=y_fused,
            velocity_x_mps=vx_fused,
            velocity_y_mps=vy_fused,
            confidence=confidence_fused,
            contributing_vehicles={obj.source_vehicle_id for obj in group},
            last_update_ms=max(obj.timestamp_ms for obj in group)
        )

        self.next_fused_id += 1
        return fused

    def get_fused_objects_for_region(self, center_x: float, center_y: float,
                                    radius_m: float) -> List[FusedObject]:
        """
        Get fused objects within a region.
        Used to send enhanced CPM to vehicles in area.
        """
        result = []
        for fused in self.fused_objects.values():
            distance = math.sqrt(
                (fused.x_position_m - center_x)**2 +
                (fused.y_position_m - center_y)**2
            )
            if distance <= radius_m:
                result.append(fused)

        return result


# Example usage
if __name__ == "__main__":
    mec_service = MECCPMFusionService()

    # Vehicle 1 reports object
    obj1 = PerceivedObject(
        object_id=1,
        object_type="vehicle",
        x_position_m=100.0,
        y_position_m=50.0,
        velocity_x_mps=15.0,
        velocity_y_mps=0.0,
        confidence=0.85,
        source_vehicle_id=1,
        timestamp_ms=0
    )

    # Vehicle 2 reports same object (slightly different position)
    obj2 = PerceivedObject(
        object_id=1,
        object_type="vehicle",
        x_position_m=101.5,
        y_position_m=50.5,
        velocity_x_mps=14.8,
        velocity_y_mps=0.2,
        confidence=0.80,
        source_vehicle_id=2,
        timestamp_ms=0
    )

    # Ingest CPMs
    mec_service.ingest_cpm(1, [obj1])
    mec_service.ingest_cpm(2, [obj2])

    # Get fused result
    fused_objects = mec_service.get_fused_objects_for_region(100.0, 50.0, 200.0)

    print(f"Fused {len(fused_objects)} objects:")
    for obj in fused_objects:
        print(f"  ID={obj.fused_id}, Type={obj.object_type}, "
              f"Pos=({obj.x_position_m:.1f}, {obj.y_position_m:.1f}), "
              f"Confidence={obj.confidence:.2f}, "
              f"Sources={obj.contributing_vehicles}")
```

## URLLC (Ultra-Reliable Low-Latency Communication)

### URLLC Techniques for V2X

```
Packet Duplication (PDCP):
- Transmit same packet on multiple paths
- Diversity: PC5 + Uu interface
- Latency reduction: 20-30%

Mini-slot Scheduling:
- Sub-millisecond TTI (Transmission Time Interval)
- Reduced latency: 2-4 ms vs 14 ms (LTE)

Grant-free Transmission:
- Pre-configured resources for V2X
- No scheduling request overhead
- Latency: < 10 ms

Edge Computing (MEC):
- Process data locally at base station
- Avoid core network round-trip
- Latency reduction: 40-50 ms
```

## C-V2X Coexistence with DSRC

```python
# cv2x_dsrc_coexistence.py
"""
C-V2X and DSRC coexistence strategies.
"""

class CoexistenceMode(Enum):
    DSRC_ONLY = 1
    CV2X_ONLY = 2
    DUAL_MODE = 3  # Both technologies
    HYBRID_MODE = 4  # Adaptive selection

class V2XRadioManager:
    """Manage dual-mode V2X radio (DSRC + C-V2X)."""

    def __init__(self, mode: CoexistenceMode):
        self.mode = mode
        self.dsrc_active = False
        self.cv2x_active = False

    def select_technology(self, message_type: str, network_available: bool) -> str:
        """
        Select appropriate V2X technology.

        Strategy:
        - Safety messages: DSRC (if dual-mode) for low latency
        - Network services: C-V2X Mode 3
        - No network: DSRC or C-V2X Mode 4
        """
        if self.mode == CoexistenceMode.DSRC_ONLY:
            return "DSRC"
        elif self.mode == CoexistenceMode.CV2X_ONLY:
            return "C-V2X"
        elif self.mode == CoexistenceMode.DUAL_MODE:
            # Broadcast on both for safety messages
            if message_type in ["BSM", "DENM", "EEBL"]:
                return "BOTH"
            elif network_available:
                return "C-V2X"
            else:
                return "DSRC"
        else:  # HYBRID_MODE
            if network_available and message_type not in ["BSM", "CAM"]:
                return "C-V2X"
            else:
                return "DSRC"
```

## References

1. **3GPP TS 22.186**: Enhancement of 3GPP support for V2X scenarios
2. **3GPP TS 23.287**: Architecture enhancements for 5G System (5GS) to support Vehicle-to-Everything (V2X) services
3. **5GAA**: C-V2X Use Cases and Service Level Requirements
4. **ETSI EN 303 613**: LTE-V2X; User Equipment (UE) radio transmission and reception
