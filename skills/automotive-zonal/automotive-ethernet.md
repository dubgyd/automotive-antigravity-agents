# Automotive Ethernet - TSN & AVB

**Category:** automotive-zonal
**Version:** 1.0.0
**Maturity:** production
**Complexity:** advanced

## Overview

Expert knowledge in automotive Ethernet technologies including Time-Sensitive Networking (TSN), Audio Video Bridging (AVB), physical layer standards (100BASE-T1, 1000BASE-T1), switch configuration, VLAN management, and Quality of Service (QoS) for deterministic vehicle networks.

## Core Competencies

### 1. Physical Layer Standards

#### 100BASE-T1 (IEEE 802.3bw)
```c
// 100BASE-T1 PHY Configuration
typedef struct {
    uint8_t standard;           // IEEE 802.3bw
    uint16_t data_rate_mbps;    // 100 Mbps full-duplex
    uint8_t wire_pairs;         // 1 twisted pair
    uint16_t max_length_m;      // 15 meters (typ), 40m (max)
    float voltage_p2p;          // 2.4V peak-to-peak
    uint8_t encoding;           // PAM3 (3-level)
    bool pma_master;            // Master/Slave negotiation
} BASE100_T1_Config;

// Example configuration for zone controller
BASE100_T1_Config zcu_phy = {
    .standard = IEEE_802_3bw,
    .data_rate_mbps = 100,
    .wire_pairs = 1,
    .max_length_m = 15,
    .voltage_p2p = 2.4,
    .encoding = PAM3,
    .pma_master = true  // Zone controller is master
};
```

#### 1000BASE-T1 (IEEE 802.3bp)
```c
// 1000BASE-T1 PHY Configuration (for cameras, ADAS)
typedef struct {
    uint8_t standard;           // IEEE 802.3bp
    uint16_t data_rate_mbps;    // 1000 Mbps full-duplex
    uint8_t wire_pairs;         // 1 unshielded twisted pair
    uint16_t max_length_m;      // 15m (standard), 40m (extended)
    uint8_t encoding;           // PAM3
    bool automotive_grade;      // AEC-Q100 qualified
    float temp_range[2];        // -40°C to +125°C
} BASE1000_T1_Config;

// Camera link configuration
BASE1000_T1_Config camera_phy = {
    .standard = IEEE_802_3bp,
    .data_rate_mbps = 1000,
    .wire_pairs = 1,
    .max_length_m = 15,
    .encoding = PAM3,
    .automotive_grade = true,
    .temp_range = {-40.0, 125.0}
};
```

#### 10BASE-T1S (IEEE 802.3cg) - Multidrop Bus
```c
// 10BASE-T1S for low-cost sensor networks
typedef struct {
    uint8_t standard;           // IEEE 802.3cg
    uint16_t data_rate_mbps;    // 10 Mbps half-duplex
    uint8_t topology;           // Multidrop bus
    uint8_t max_nodes;          // 8 nodes per segment
    uint16_t max_length_m;      // 25 meters
    uint8_t collision_detection; // CSMA/CD
    bool plca_mode;             // Physical Layer Collision Avoidance
} BASE10_T1S_Config;

// Sensor bus configuration
BASE10_T1S_Config sensor_bus = {
    .standard = IEEE_802_3cg,
    .data_rate_mbps = 10,
    .topology = MULTIDROP_BUS,
    .max_nodes = 8,
    .max_length_m = 25,
    .collision_detection = CSMA_CD,
    .plca_mode = true  // Enables deterministic access
};
```

### 2. Time-Sensitive Networking (TSN)

#### IEEE 802.1 TSN Standards

**Key Standards:**
- **802.1AS** - Precision Time Protocol (gPTP) for time synchronization
- **802.1Qbv** - Time-Aware Shaper (TAS) for scheduled traffic
- **802.1Qav** - Credit-Based Shaper (CBS) for AVB streams
- **802.1Qbu** - Frame Preemption for low-latency
- **802.1Qci** - Per-Stream Filtering and Policing
- **802.1CB** - Frame Replication and Elimination for Reliability (FRER)

```python
# TSN Configuration Example
class TSNSwitchConfig:
    def __init__(self):
        self.gptp_domain = 0  # Time domain for sync
        self.sync_interval_ms = 125  # gPTP sync every 125ms
        self.time_aware_shaper = True
        self.frame_preemption = True
        self.stream_reservation = True

    def configure_tas_schedule(self):
        """
        Configure Time-Aware Shaper (802.1Qbv) for deterministic scheduling.
        Divides time into repeating cycles with gates for each priority queue.
        """

        # 1ms cycle time (1,000,000 ns)
        cycle_time_ns = 1_000_000

        schedule = {
            'cycle_time_ns': cycle_time_ns,
            'gates': [
                # Time slot 0-100μs: Priority 7 (Safety-critical)
                {
                    'start_ns': 0,
                    'duration_ns': 100_000,
                    'open_gates': [7],  # Only priority 7 queue open
                    'traffic_class': 'Safety'
                },
                # Time slot 100-300μs: Priority 6 (ADAS)
                {
                    'start_ns': 100_000,
                    'duration_ns': 200_000,
                    'open_gates': [6],
                    'traffic_class': 'Control'
                },
                # Time slot 300-800μs: Priority 4-5 (Video streams)
                {
                    'start_ns': 300_000,
                    'duration_ns': 500_000,
                    'open_gates': [4, 5],
                    'traffic_class': 'AVB'
                },
                # Time slot 800-1000μs: Priority 0-3 (Best effort)
                {
                    'start_ns': 800_000,
                    'duration_ns': 200_000,
                    'open_gates': [0, 1, 2, 3],
                    'traffic_class': 'BestEffort'
                }
            ]
        }

        return schedule

    def configure_stream_reservation(self, stream_id, bandwidth_mbps, latency_us):
        """
        Configure stream reservation for AVB/TSN streams (802.1Qat/Qcc).

        Args:
            stream_id: Unique stream identifier
            bandwidth_mbps: Required bandwidth in Mbps
            latency_us: Maximum latency in microseconds
        """

        stream_config = {
            'stream_id': stream_id,
            'talker_mac': '00:11:22:33:44:55',
            'listener_mac': ['00:11:22:33:44:66'],
            'vlan_id': 100,
            'priority': 6,  # SR Class A
            'max_frame_size': 1522,
            'max_interval_frames': 1,
            'bandwidth_mbps': bandwidth_mbps,
            'max_latency_us': latency_us,
            'redundancy': 'FRER'  # Frame Replication
        }

        return stream_config
```

#### gPTP Time Synchronization (802.1AS)

```c
// gPTP Time Synchronization Configuration
typedef struct {
    uint8_t domain_number;           // 0 for automotive
    uint32_t sync_interval_ns;       // 125ms = 125,000,000 ns
    uint32_t pdelay_interval_ns;     // Peer delay measurement
    int8_t clock_class;              // 248 for automotive grandmaster
    int8_t clock_accuracy;           // 0xFE (unknown)
    uint16_t offset_scaled_log_var;  // Variance of clock
    uint8_t priority1;               // 248
    uint8_t priority2;               // 248
    bool as_capable;                 // TSN-capable port
} gPTP_Config_t;

// Grandmaster clock (gateway)
gPTP_Config_t grandmaster = {
    .domain_number = 0,
    .sync_interval_ns = 125000000,  // 125ms
    .pdelay_interval_ns = 1000000000,  // 1 second
    .clock_class = 248,  // Automotive default application-specific
    .clock_accuracy = 0xFE,
    .offset_scaled_log_var = 0x4E5D,
    .priority1 = 248,
    .priority2 = 248,
    .as_capable = true
};

// Typical time sync accuracy: ±500ns between nodes
```

### 3. VLAN Configuration

```python
class VLANManager:
    """
    Manage VLANs for traffic segregation in zonal architecture.
    """

    def __init__(self):
        self.vlans = {
            100: {'name': 'Safety', 'priority': 7, 'color': 'RED'},
            200: {'name': 'ADAS', 'priority': 6, 'color': 'ORANGE'},
            300: {'name': 'Infotainment', 'priority': 5, 'color': 'YELLOW'},
            400: {'name': 'Body', 'priority': 4, 'color': 'GREEN'},
            500: {'name': 'Diagnostics', 'priority': 3, 'color': 'BLUE'},
            999: {'name': 'Management', 'priority': 7, 'color': 'PURPLE'}
        }

    def configure_switch_ports(self):
        """
        Configure switch ports with VLAN memberships.
        """

        port_config = {
            'port_1': {  # Gateway uplink
                'mode': 'trunk',
                'allowed_vlans': [100, 200, 300, 400, 500, 999],
                'native_vlan': 999,
                'pvid': 999
            },
            'port_2': {  # Front-left ZCU
                'mode': 'trunk',
                'allowed_vlans': [100, 400],  # Safety + Body
                'native_vlan': 400,
                'pvid': 400
            },
            'port_3': {  # Front camera (ADAS)
                'mode': 'access',
                'vlan': 200,  # ADAS VLAN only
                'pvid': 200
            },
            'port_4': {  # Rear camera (infotainment)
                'mode': 'access',
                'vlan': 300,  # Infotainment VLAN
                'pvid': 300
            },
            'port_5': {  # Diagnostic connector (OBD-II)
                'mode': 'access',
                'vlan': 500,
                'pvid': 500
            }
        }

        return port_config
```

### 4. Quality of Service (QoS)

#### Priority Mapping (IEEE 802.1Q)

```c
// 8 priority levels (0-7)
typedef enum {
    PRIORITY_0_BEST_EFFORT = 0,     // Background
    PRIORITY_1_BACKGROUND = 1,      // Backup data
    PRIORITY_2_EXCELLENT_EFFORT = 2, // Business-critical
    PRIORITY_3_CRITICAL_APPS = 3,    // Call signaling
    PRIORITY_4_VIDEO = 4,            // Streaming video
    PRIORITY_5_VOICE = 5,            // Interactive voice/video
    PRIORITY_6_CONTROL = 6,          // Control plane (ADAS)
    PRIORITY_7_NETWORK_CONTROL = 7   // Safety-critical
} EthernetPriority_t;

// Traffic class mapping
typedef struct {
    EthernetPriority_t priority;
    uint8_t traffic_class;
    uint16_t max_latency_us;
    char description[32];
} QoS_Mapping_t;

QoS_Mapping_t qos_table[] = {
    {PRIORITY_7_NETWORK_CONTROL, 7, 100, "Safety (ABS, ESC)"},
    {PRIORITY_6_CONTROL, 6, 500, "ADAS (Braking, Steering)"},
    {PRIORITY_5_VOICE, 5, 2000, "Camera streams"},
    {PRIORITY_4_VIDEO, 4, 10000, "Infotainment video"},
    {PRIORITY_3_CRITICAL_APPS, 3, 20000, "Diagnostics"},
    {PRIORITY_2_EXCELLENT_EFFORT, 2, 50000, "SW updates"},
    {PRIORITY_1_BACKGROUND, 1, 100000, "Telemetry"},
    {PRIORITY_0_BEST_EFFORT, 0, 1000000, "General data"}
};
```

#### Credit-Based Shaper (802.1Qav)

```python
def configure_cbs(port, stream_class):
    """
    Configure Credit-Based Shaper for AVB traffic (SR Class A/B).

    Args:
        port: Ethernet port number
        stream_class: 'A' for Class A (2ms), 'B' for Class B (50ms)
    """

    if stream_class == 'A':
        config = {
            'idle_slope': 0x3FFF,      # 75% of link bandwidth
            'send_slope': -0x2AAA,     # -25% of link bandwidth
            'hi_credit': 0x186A0,      # 100,000 credits
            'lo_credit': -0x186A0,     # -100,000 credits
            'priority': 6
        }
    elif stream_class == 'B':
        config = {
            'idle_slope': 0x1FFF,      # 50% of link bandwidth
            'send_slope': -0x1FFF,     # -50% of link bandwidth
            'hi_credit': 0xC350,       # 50,000 credits
            'lo_credit': -0xC350,      # -50,000 credits
            'priority': 5
        }

    return config
```

### 5. Automotive Ethernet Switch Configuration

```yaml
# Example switch configuration (YAML)
switch:
  model: "NXP SJA1110"
  ports: 10
  tsn_capable: true

  global_config:
    gptp_domain: 0
    management_vlan: 999

  port_1:  # Uplink to gateway
    speed: "1000BASE-T1"
    mode: "trunk"
    vlans: [100, 200, 300, 400, 500, 999]
    tsn:
      tas_enabled: true
      frame_preemption: true

  port_2:  # Front-left zone controller
    speed: "100BASE-T1"
    mode: "trunk"
    vlans: [100, 400]
    tsn:
      tas_enabled: true

  port_3:  # Front camera
    speed: "1000BASE-T1"
    mode: "access"
    vlan: 200
    qos:
      priority: 6
      cbs_enabled: true
      stream_reservation: true

  port_4:  # Rear camera
    speed: "1000BASE-T1"
    mode: "access"
    vlan: 200
    qos:
      priority: 6
      cbs_enabled: true
```

## Network Performance Targets

| Traffic Type | Priority | Max Latency | Jitter | Packet Loss |
|--------------|----------|-------------|--------|-------------|
| Safety (ABS, ESC) | 7 | <100 μs | <10 μs | 0% |
| ADAS Control | 6 | <500 μs | <50 μs | <10^-9 |
| Camera Streams | 5-6 | <2 ms | <100 μs | <10^-6 |
| Infotainment | 4 | <10 ms | <1 ms | <10^-4 |
| Diagnostics | 3 | <50 ms | N/A | <10^-3 |
| Best Effort | 0-2 | <1 s | N/A | <10^-2 |

## Tools & Testing

**Network Analyzers:**
- **Vector VN5600** - TSN-capable network interface
- **Wireshark with Automotive plugins** - Packet capture and analysis
- **Ixia/Keysight IxNetwork** - TSN traffic generation and testing

**Configuration Tools:**
- **NXP SJA1110 Config Tool** - Switch configuration
- **Vector CANoe.Ethernet** - Network simulation
- **Marvell TSN Studio** - TSN stream configuration

## References

- IEEE 802.1 TSN Task Group Standards
- SAE J3161 On-Board Ethernet Communication
- OPEN Alliance BroadR-Reach Specification
- AUTOSAR Ethernet Communication Specification
