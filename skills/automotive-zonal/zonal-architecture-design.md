# Zonal Architecture Design

**Category:** automotive-zonal
**Version:** 1.0.0
**Maturity:** production
**Complexity:** advanced

## Overview

Expert knowledge in designing next-generation vehicle E/E zonal architectures. Covers zone controller placement, domain consolidation, topology optimization, cable harness reduction strategies, and migration from traditional domain architectures to zonal designs.

## Core Competencies

### 1. Zone Controller Placement Strategy

#### Optimal Zone Count
Typical modern vehicles use **4-8 zones**:
- **4 zones**: Entry-level vehicles (FL, FR, RL, RR corners)
- **6 zones**: Mid-range (4 corners + front-center + rear-center)
- **8 zones**: Premium (4 corners + FC, RC, left-center, right-center)

**Placement Criteria:**
```python
class ZonePlacementOptimizer:
    def __init__(self, vehicle_model):
        self.vehicle = vehicle_model
        self.sensors = []
        self.actuators = []

    def optimize_zones(self, max_cable_length=2.0):
        """
        Optimize zone placement to minimize cable length.

        Args:
            max_cable_length: Maximum cable run in meters (default 2m)

        Returns:
            List of zone controller locations
        """
        from sklearn.cluster import KMeans
        import numpy as np

        # Get all sensor/actuator positions
        positions = np.array([
            [comp.x, comp.y, comp.z]
            for comp in self.sensors + self.actuators
        ])

        # Cluster to find optimal zone centers
        n_zones = self._estimate_zone_count(positions, max_cable_length)
        kmeans = KMeans(n_clusters=n_zones, random_state=42)
        kmeans.fit(positions)

        zones = []
        for i, center in enumerate(kmeans.cluster_centers_):
            zone = {
                'id': f'ZCU_{i+1}',
                'location': center.tolist(),
                'components': [],
                'cable_savings': 0.0
            }

            # Assign components to zones
            labels = kmeans.labels_
            zone_components = [
                comp for idx, comp in enumerate(self.sensors + self.actuators)
                if labels[idx] == i
            ]
            zone['components'] = zone_components
            zones.append(zone)

        return zones

    def _estimate_zone_count(self, positions, max_length):
        """Estimate optimal number of zones based on component density."""
        bbox = positions.max(axis=0) - positions.min(axis=0)
        vehicle_length = bbox[0]
        vehicle_width = bbox[1]

        # Coverage area per zone (circle of radius max_length)
        zone_coverage = np.pi * (max_length ** 2)
        vehicle_area = vehicle_length * vehicle_width

        return max(4, int(np.ceil(vehicle_area / zone_coverage)))
```

#### Zone Controller Hardware Selection

| Zone Type | Hardware Platform | Cost | Use Case |
|-----------|------------------|------|----------|
| **Low-cost Corner** | NXP S32K344 | $15-20 | Lighting, windows, mirrors |
| **Standard Zone** | Renesas RH850/U2A | $25-35 | Body control, HVAC, doors |
| **Gateway/Central** | NXP S32G274A | $80-120 | Ethernet switch, firewall, routing |
| **High-performance** | Infineon AURIX TC397 | $60-90 | ADAS integration, safety |

**Selection Decision Tree:**
```
Is zone safety-critical (ASIL-C/D)?
├─ Yes → AURIX TC397 (lockstep cores, ECC RAM)
└─ No → Does zone need Ethernet switching?
    ├─ Yes → S32G274A (4x Gb Ethernet, TSN)
    └─ No → Component count?
        ├─ <20 → S32K344 (low-cost)
        └─ >20 → RH850/U2A (more I/O)
```

### 2. Cable Harness Reduction

**Traditional Domain Architecture:**
```
Total cable length: 4,500 meters
Total weight: 45 kg
Cost: $450 per vehicle
```

**Zonal Architecture Benefits:**
```python
class CableHarnessAnalyzer:
    def calculate_savings(self, domain_arch, zonal_arch):
        """
        Calculate cable harness savings from domain-to-zonal migration.

        Returns:
            dict: Savings in length, weight, and cost
        """
        # Domain architecture stats
        domain_cables = {
            'sensor_to_ecu': 2800,  # meters
            'inter_ecu': 1200,
            'power_distribution': 500
        }

        # Zonal architecture stats
        zonal_cables = {
            'sensor_to_zone': 1500,  # <2m each, drastically shorter
            'zone_to_gateway': 150,  # Ethernet backbone only
            'power_distribution': 300  # Zonal PDUs
        }

        total_domain = sum(domain_cables.values())
        total_zonal = sum(zonal_cables.values())

        reduction_meters = total_domain - total_zonal
        reduction_percent = (reduction_meters / total_domain) * 100

        # Weight savings (0.01 kg/meter average)
        weight_savings = reduction_meters * 0.01  # kg

        # Cost savings ($0.10/meter cable + installation)
        cost_savings = reduction_meters * 0.15  # USD

        return {
            'cable_reduction_m': reduction_meters,
            'cable_reduction_pct': reduction_percent,
            'weight_savings_kg': weight_savings,
            'cost_savings_usd': cost_savings
        }

# Example output:
# {
#     'cable_reduction_m': 2550,
#     'cable_reduction_pct': 56.7%,
#     'weight_savings_kg': 25.5 kg,
#     'cost_savings_usd': $382.50
# }
```

**Actual OEM Results:**
- **VW MEB Platform**: 30% cable reduction
- **Tesla Model 3**: 1.5 km total harness (vs 3 km traditional)
- **Rivian R1T**: 40% weight reduction in harness

### 3. Network Topology Design

#### Topology Options

**A. Star Topology (Recommended for Safety)**
```
                    ┌─────────────┐
                    │   Gateway   │
                    │   S32G274   │
                    └──────┬──────┘
                           │
        ┌──────────────┬───┴───┬──────────────┐
        │              │       │              │
    ┌───┴───┐      ┌───┴───┐ ┌┴─────┐    ┌───┴───┐
    │ FL ZCU│      │ FR ZCU│ │RC ZCU│    │ RL ZCU│
    └───────┘      └───────┘ └──────┘    └───────┘

Pros:
+ Direct gateway connection (low latency)
+ Simple fault isolation
+ Easy TSN configuration
+ No cascading failures

Cons:
- More cable to gateway
- Single point of failure (mitigated with redundant gateway)
```

**B. Ring Topology (High Availability)**
```
    ┌─────────┐──────┐Gateway│──────┐─────────┐
    │         │      └────────┘      │         │
    │         │                      │         │
┌───┴───┐ ┌───┴───┐              ┌───┴───┐ ┌───┴───┐
│FL ZCU │ │FR ZCU │              │RR ZCU │ │RL ZCU │
└───────┘ └───────┘              └───────┘ └───────┘

Pros:
+ Redundant paths (fault tolerance)
+ Load balancing possible
+ Cable length optimization

Cons:
- Complex TSN configuration
- Potential for loops (need STP/RSTP)
```

**C. Daisy Chain (Cost-Optimized)**
```
┌────────┐    ┌──────┐    ┌──────┐    ┌──────┐    ┌──────┐
│Gateway │────│FL ZCU│────│FR ZCU│────│RR ZCU│────│RL ZCU│
└────────┘    └──────┘    └──────┘    └──────┘    └──────┘

Pros:
+ Minimal cable length
+ Lowest cost

Cons:
- Cascading failures
- Higher latency for distant zones
- Not suitable for safety-critical
```

#### Ethernet Physical Layer Selection

```c
// 100BASE-T1 Configuration (Standard zones)
struct ethernet_phy_config {
    uint8_t standard;        // 100BASE-T1
    uint16_t max_distance;   // 15 meters
    uint32_t bandwidth;      // 100 Mbps
    uint8_t pair_count;      // 1 twisted pair
    float cost_per_meter;    // $0.50
};

// 1000BASE-T1 Configuration (High-bandwidth zones - cameras, ADAS)
struct ethernet_phy_1g {
    uint8_t standard;        // 1000BASE-T1
    uint16_t max_distance;   // 40 meters
    uint32_t bandwidth;      // 1 Gbps
    uint8_t pair_count;      // 1 twisted pair
    float cost_per_meter;    // $0.80
};

// 10BASE-T1S Configuration (Low-cost multidrop sensors)
struct ethernet_phy_10base {
    uint8_t standard;        // 10BASE-T1S
    uint16_t max_distance;   // 25 meters (multidrop bus)
    uint32_t bandwidth;      // 10 Mbps
    uint8_t topology;        // Multidrop (up to 8 nodes per segment)
    float cost_per_meter;    // $0.30
};
```

### 4. Power Distribution Architecture

**Zonal Power Distribution Units (PDUs):**

```c
typedef struct {
    char zone_id[16];
    uint8_t num_power_rails;
    float voltage_12v;
    float voltage_5v;
    float voltage_3v3;
    uint8_t load_shedding_priority[8];  // 0=critical, 7=lowest
    bool intelligent_fusing;
} ZonalPDU_Config_t;

// Example: Front-Left Zone PDU
ZonalPDU_Config_t fl_pdu = {
    .zone_id = "FL_ZONE",
    .num_power_rails = 8,
    .voltage_12v = 12.0,
    .voltage_5v = 5.0,
    .voltage_3v3 = 3.3,
    .load_shedding_priority = {
        0,  // Headlights (critical)
        1,  // Turn signals (safety)
        2,  // DRL (legal requirement)
        5,  // Fog lights
        6,  // Puddle lights
        7,  // Ambient lighting
    },
    .intelligent_fusing = true
};

// Load shedding during low battery
void perform_load_shedding(ZonalPDU_Config_t *pdu, uint8_t battery_soc) {
    if (battery_soc < 20) {
        // Shed priority 7 loads (ambient lighting)
        disable_loads_by_priority(pdu, 7);
    }
    if (battery_soc < 10) {
        // Shed priority 6 loads (puddle lights)
        disable_loads_by_priority(pdu, 6);
    }
    if (battery_soc < 5) {
        // Shed priority 5 loads (fog lights)
        disable_loads_by_priority(pdu, 5);
        // Keep only priority 0-2 (critical/safety)
    }
}
```

**Power Budget per Zone:**
| Zone | Typical Power | Peak Power | Components |
|------|--------------|-----------|------------|
| FL Corner | 150W | 300W | Headlights, turn signals, window, mirror |
| FR Corner | 150W | 300W | Headlights, turn signals, window, mirror |
| RL Corner | 100W | 200W | Taillights, window |
| RR Corner | 100W | 200W | Taillights, window |
| Front Center | 200W | 400W | Wipers, HVAC blower, sensors |
| Rear Center | 80W | 150W | Trunk, license plate light |

### 5. Domain-to-Zonal Migration Strategy

**Phase 1: Hybrid Architecture (18-24 months)**
- Keep existing domain ECUs
- Add zone controllers for new sensors
- Use gateway to bridge domains and zones
- Validate zonal concept

**Phase 2: Partial Migration (24-36 months)**
- Migrate body domain to zonal
- Keep powertrain/ADAS domains
- 40-50% cable reduction achieved

**Phase 3: Full Zonal (36-48 months)**
- All functions on zone controllers
- Domain ECUs eliminated
- 50-60% cable reduction
- Central compute for ADAS/infotainment

```python
class MigrationPlanner:
    def create_migration_roadmap(self):
        """Generate phased migration from domain to zonal architecture."""

        phases = [
            {
                'phase': 1,
                'name': 'Hybrid Introduction',
                'duration_months': 18,
                'zones_added': ['FL', 'FR'],
                'functions_migrated': ['Lighting', 'Windows'],
                'cable_reduction': '15%',
                'cost': '$2M NRE',
                'risk': 'Low'
            },
            {
                'phase': 2,
                'name': 'Body Domain Migration',
                'duration_months': 24,
                'zones_added': ['RL', 'RR', 'FC', 'RC'],
                'functions_migrated': ['All body', 'HVAC', 'Doors'],
                'cable_reduction': '45%',
                'cost': '$5M NRE',
                'risk': 'Medium'
            },
            {
                'phase': 3,
                'name': 'Full Zonal',
                'duration_months': 36,
                'zones_added': ['LC', 'RC'],
                'functions_migrated': ['All functions'],
                'cable_reduction': '60%',
                'cost': '$8M NRE',
                'risk': 'High',
                'payback': '2.5 years at 100k units/year'
            }
        ]

        return phases
```

## ROI Calculation

**Per-Vehicle Savings:**
```
Cable harness reduction: $250
Weight reduction (fuel economy): $50/vehicle lifetime
Assembly time reduction: $100
Service diagnostics improvement: $30

Total savings: $430 per vehicle
```

**NRE Investment:**
```
Zone controller development: $3M
Software architecture: $2M
Testing & validation: $2M
Production tooling: $1M

Total NRE: $8M
```

**Payback Period:**
```
At 50,000 units/year:
$8M / ($430 × 50,000) = 0.37 years (4.5 months)

At 100,000 units/year:
Immediate positive ROI
```

## Best Practices

1. **Start with body domain** - Lowest safety criticality, highest cable savings
2. **Use star topology** for safety-critical zones
3. **Implement intelligent power management** - Load shedding, priority-based
4. **Plan for redundancy** - Dual Ethernet links to gateway
5. **Use TSN** for deterministic latency (<10ms p99)
6. **Leverage 10BASE-T1S** for low-cost sensors (multidrop)
7. **Plan thermal management** - Zone controllers generate more heat than distributed ECUs

## Tools & Frameworks

- **Capital Harness Designer** - Cable routing and optimization
- **PREEvision** - E/E architecture design
- **SystemDesk** - AUTOSAR Adaptive configuration
- **Vector CANoe** - Network simulation and testing

## References

- VDA Recommendation on Zonal E/E Architecture
- IEEE 802.1 TSN Standards
- AUTOSAR Adaptive Platform R22-11
- SAE J3161 On-Board Ethernet Communication
