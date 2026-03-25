# Automotive Zonal Architecture Skills

This directory contains comprehensive skills for designing and implementing next-generation zonal E/E architectures in vehicles.

## Overview

Zonal architectures replace traditional domain ECUs with geographically-placed zone controllers, providing:
- **20-30% cable harness weight reduction** (15-20 kg lighter)
- **< 5ms network latency** via Ethernet TSN (vs 10-50ms CAN)
- **Software-Defined Vehicle capability** with full OTA updates
- **Scalability for ADAS/AD** (add sensors without redesign)
- **Cost savings** of $200-300 per vehicle at scale

## Skills Included

### 1. zonal-architecture-design.yaml
**Zone controller placement, topology design, cable reduction**

**Key Topics:**
- Zone placement strategies (4-8 zones typical)
- Hardware platform selection (NXP S32K3/S32G, Renesas RH850, Infineon AURIX)
- Network topology (star, ring, daisy-chain)
- Cable harness reduction (before/after comparison)
- Power distribution architecture
- Migration roadmap (Domain → Hybrid → Full Zonal)
- Cost-benefit analysis with ROI

**Example Use Cases:**
- Design 7-zone architecture for new EV platform
- Migrate existing sedan from 15 domain ECUs to 7 zones
- Calculate cable weight savings (typically 15-20 kg)
- Select zone controller hardware per zone (cost vs performance)

**Production Examples:**
- Tesla Model 3/Y (5 zones)
- VW.OS (6 zones, AUTOSAR Adaptive)
- GM Ultifi (5 zones, Linux-based)
- Mercedes EQS (8 zones, luxury)

---

### 2. automotive-ethernet.yaml
**Physical layer, TSN, AVB, switch configuration, QoS**

**Key Topics:**
- Physical layer standards:
  - 100BASE-T1 (100 Mbps, 15m max)
  - 1000BASE-T1 (1 Gbps, 15m max)
  - 10BASE-T1S (10 Mbps, multidrop bus)
- TSN (Time-Sensitive Networking):
  - IEEE 802.1Qbv (Time-Aware Shaper)
  - IEEE 802.1Qav (Credit-Based Shaper)
  - IEEE 802.1CB (Frame Replication)
  - IEEE 802.1Qci (Per-Stream Filtering)
  - IEEE 802.1AS (gPTP time sync)
- VLAN segmentation (security domains)
- QoS policies (8 priority levels)
- Switch configuration (NXP SJA1110, Marvell, Broadcom)
- Bandwidth allocation and latency budgeting

**Example Use Cases:**
- Configure TSN switch with 10ms cycle time
- Set up VLAN 10 (safety), VLAN 20 (ADAS), VLAN 30 (infotainment)
- Calculate camera bandwidth (1920×1080 @ 30fps with H.264)
- Configure Time-Aware Shaper (GCL per port)
- Test network latency (target: < 5ms p99)

**Test Commands:**
```bash
# Latency test
ping -c 1000 -i 0.01 192.168.10.10

# Bandwidth test
iperf3 -c 192.168.10.1 -u -b 80M -t 60

# TSN validation
tc qdisc show dev eth0
ptp4l -i eth0 -m
```

---

### 3. service-oriented-communication.yaml
**SOME/IP, DDS, service discovery, pub-sub, event-driven**

**Key Topics:**
- SOME/IP (Scalable Service-Oriented Middleware over IP):
  - Service definition (Franca IDL)
  - ARXML configuration
  - ara::com implementation (AUTOSAR Adaptive)
  - Service discovery (SOME/IP-SD)
- DDS (Data Distribution Service):
  - Topic-based pub-sub
  - 23 QoS policies (Reliability, Durability, History, etc.)
  - IDL definitions
  - RTI Connext, Fast DDS, OpenDDS
- Event-driven architecture patterns
- Migration from CAN signals to SOA services

**Example Use Cases:**
- Define SOME/IP service for VehicleSpeed (method + event)
- Implement ara::com skeleton/proxy (C++)
- Configure DDS pub-sub for camera frames (ADAS)
- Design event aggregation (4 wheel speeds → vehicle speed)
- Migrate CAN message (0x100) to SOME/IP service (0x1234)

**Performance Benchmarks:**
- SOME/IP method call: 1-3 ms (request-response)
- SOME/IP event: 0.5-2 ms (pub-sub)
- DDS pub-sub: 0.1-1 ms (with zero-copy)

---

### 4. zone-controller-development.yaml
**Firmware, I/O handling, sensor aggregation, gateway functions**

**Key Topics:**
- Hardware platforms:
  - NXP S32K344 ($15-20, ASIL-B, corners)
  - Renesas RH850/U2A ($25-35, ASIL-D, central)
  - Infineon AURIX TC397 ($60-90, ASIL-D, gateway)
- I/O handling:
  - Digital input (door switches, debouncing)
  - Analog input (temperature sensors, NTC thermistor)
  - PWM output (LED dimming, motor control)
- Sensor aggregation (4 wheel speeds → vehicle speed)
- Actuator control with safety (window motor anti-pinch)
- Gateway routing (CAN ↔ Ethernet, SOME/IP)
- AUTOSAR integration (Classic/Adaptive, RTE, MCAL)
- Build system (CMake, GCC ARM)

**Example Use Cases:**
- Read door switch with debouncing (50ms)
- Read NTC thermistor via ADC (Steinhart-Hart equation)
- Control LED brightness via PWM (0-100%)
- Aggregate wheel speeds from 4 CAN sensors
- Implement window motor control with anti-pinch (3A threshold)
- Gateway: Translate CAN 0x100 → SOME/IP 0x1234:0x8001

**Code Examples:**
- C code for AUTOSAR MCAL (Dio, Adc, Pwm, Can)
- ARXML configuration (SWC, RTE, BSW)
- CMakeLists.txt for S32K344
- Safety checks (overcurrent, timeout, validity)

---

### 5. network-security-zonal.yaml
**MACsec, IPsec, firewalls, IDS, ISO 21434**

**Key Topics:**
- Defense-in-depth strategy (6 layers):
  1. Physical security (tamper-resistant, secure boot)
  2. Network segmentation (VLANs per domain)
  3. Encryption (MACsec hop-by-hop, IPsec end-to-end)
  4. Firewalls (nftables, rate limiting)
  5. Intrusion detection (IDS signatures, ML anomaly)
  6. Security monitoring (SIEM, logging)
- MACsec (IEEE 802.1AE):
  - AES-256-GCM encryption
  - Key rotation (MKA)
  - Hardware offload (< 500µs latency)
- IPsec VPN (vehicle ↔ cloud):
  - IKEv2 key exchange
  - Tunnel mode with ESP
  - strongSwan configuration
- Firewall rules (nftables):
  - Default DENY policy
  - Whitelist per zone
  - Rate limiting (token bucket)
- IDS (Intrusion Detection System):
  - Suricata rules (signature-based)
  - ML anomaly detection (Isolation Forest)
- ISO 21434 TARA (Threat Analysis and Risk Assessment)

**Example Use Cases:**
- Configure MACsec on all inter-zone links (AES-256)
- Set up IPsec tunnel to cloud backend (OTA updates)
- Write firewall rules for FC zone (allow SOME/IP, block CAN injection)
- Deploy IDS with Suricata (detect SOME/IP flood, unauthorized UDS)
- Perform TARA for zone controller (identify threats, assess risk)
- Implement secure gateway (HMAC authentication, rate limiting)

**Security Tools:**
- MACsec: Linux `ip macsec` command, NXP S32G hardware offload
- IPsec: strongSwan, Libreswan
- Firewall: nftables, iptables
- IDS: Suricata, Snort, Zeek
- SIEM: Splunk, ELK stack, Wazuh
- Pentesting: Metasploit, Kali Linux

---

## Related Agents

### zonal-architect.md
E/E architect for designing zonal architectures, selecting hardware, and planning migration strategies.

**Deliverables:**
- Zone placement diagrams
- BOM with costs
- Cable harness comparison (before/after)
- Network topology (star/ring)
- ARXML configuration
- Cost-benefit analysis with ROI

### ethernet-network-engineer.md
Automotive Ethernet specialist for TSN configuration, switch setup, VLAN design, and network optimization.

**Deliverables:**
- Switch configuration (YAML/JSON)
- VLAN assignment table
- TSN GCL (Gate Control List)
- Bandwidth allocation spreadsheet
- Latency budget analysis (p50, p95, p99)
- Test results (ping, iperf3, PTP)
- MACsec configuration

---

## Production Examples

### Tesla Model 3/Y
- 5 controllers (simplified zonal)
- Ethernet backbone (100BASE-T1)
- Central FSD computer (144 TOPS)
- 18 kg lighter harness vs Model S

### VW.OS (ID.4, ID.7, Trinity)
- 6 zone controllers + 2 ADAS ECUs
- AUTOSAR Adaptive R23-11
- SOME/IP service communication
- 1 Gbps TSN ring topology
- Timeline: 2025+ for full rollout

### GM Ultifi
- 5 zone controllers
- Linux-based middleware (not AUTOSAR)
- DDS pub-sub + SOME/IP discovery
- Kubernetes orchestration
- Deployment: 2025+ (Cadillac Lyriq first)

### Mercedes EQS
- 8 zone controllers (most granular)
- 1000BASE-T1 backbone (1 Gbps)
- NVIDIA Orin (250 TOPS)
- Premium components (Infineon AURIX)
- Cost: $3,000+ E/E architecture

---

## Migration Roadmap

### Phase 1: Hybrid (Years 1-2)
- Keep existing domain ECUs
- Add 2-3 zones for new features (ADAS, infotainment)
- Install Ethernet backbone
- Gateway for CAN ↔ Ethernet

### Phase 2: Consolidation (Years 3-4)
- Merge domains into zones (Body+Comfort → Central Zone)
- Remove 40% of domain ECUs
- Increase Ethernet usage to 60%

### Phase 3: Full Zonal (Years 5+)
- 6-8 zone controllers
- 100% service-oriented (SOME/IP, DDS)
- 30% cable weight reduction
- Central high-performance compute (NVIDIA, Qualcomm, NXP)

---

## Quick Start

### 1. Design a 7-Zone Architecture
```yaml
# Use zonal-architecture-design.yaml skill
Zones:
  - FL: Front Left (headlight, wheel, door)
  - FC: Front Center (ADAS sensors, gateway)
  - FR: Front Right (symmetric to FL)
  - C: Central (dashboard, infotainment, HVAC)
  - RL: Rear Left (door, wheel, tail light)
  - RC: Rear Center (trunk, rear camera)
  - RR: Rear Right (symmetric to RL)

Hardware:
  - FL, FR, RL, RR: NXP S32K344 ($15-20)
  - FC: NXP S32G274A ($80-120, gateway)
  - C: Renesas RH850/U2A ($25-35)
  - RC: NXP S32K344 ($15-20)

Network:
  - Star topology (central switch in FC)
  - 100BASE-T1 to all zones (< 15m)
  - 1000BASE-T1 from FC to central compute
```

### 2. Configure TSN Switch
```yaml
# Use automotive-ethernet.yaml skill
switch:
  model: NXP_SJA1110
  ports: 10

  port_config:
    - port_id: 0
      name: central_compute
      speed: 1000BASE-T1
      vlan_mode: trunk
      allowed_vlans: [10, 20, 30, 40, 50, 60]
      tsn_enabled: true

    - port_id: 2
      name: fc_zone
      speed: 100BASE-T1
      vlan_mode: trunk
      allowed_vlans: [10, 20]  # Safety + ADAS
      tsn_enabled: true

  tsn_tas:
    port: 0
    cycle_time_ns: 10000000  # 10 ms
    gcl:
      - gate_mask: 0x80  # Priority 7 only (safety)
        time_interval_ns: 100000  # 100 µs
      - gate_mask: 0xC0  # Priority 6-7 (ADAS)
        time_interval_ns: 500000  # 500 µs
      - gate_mask: 0xFF  # All priorities
        time_interval_ns: 8400000  # 8.4 ms
```

### 3. Implement SOME/IP Service
```cpp
// Use service-oriented-communication.yaml skill
// VehicleSpeed.fidl
package vehicle.chassis

interface VehicleSpeed {
    version { major 1 minor 0 }

    method getSpeed {
        out { Float speed_kmh }
    }

    broadcast speedChanged {
        out { Float speed_kmh, UInt64 timestamp_us }
    }
}

// C++ implementation (ara::com)
class VehicleSpeedService : public VehicleSpeedInterface::Skeleton {
    void UpdateSpeed(float speed_kmh) {
        VehicleSpeedInterface::SpeedChangedEvent event;
        event.speed_kmh = speed_kmh;
        event.timestamp_us = GetTimestampUs();
        speedChanged.Send(event);
    }
};
```

### 4. Develop Zone Controller Firmware
```c
// Use zone-controller-development.yaml skill
// door_switch.c
void DoorSwitch_MainFunction(void) {
    Dio_LevelType pin_level = Dio_ReadChannel(DOOR_SWITCH_PIN);

    if (Debounce(pin_level, 50)) {  // 50ms debounce
        if (pin_level == STD_LOW) {
            SendDoorOpenEvent();  // Publish to Ethernet
        }
    }
}
```

### 5. Secure Network with MACsec
```bash
# Use network-security-zonal.yaml skill
# Configure MACsec on eth0
ip link add link eth0 macsec0 type macsec \
    sci 00049f1234560001 \
    encrypt on \
    replay on window 32

ip macsec add macsec0 tx sa 0 pn 1 on key 00 $KEY
ip macsec add macsec0 rx port 1 address 00:04:9f:76:54:32
ip macsec add macsec0 rx port 1 address 00:04:9f:76:54:32 sa 0 pn 1 on key 00 $KEY

ip link set macsec0 up
```

---

## Testing

### Latency Test
```bash
# Target: < 5 ms p99
ping -c 1000 -i 0.01 192.168.10.10 | tail -1
# Expected: rtt min/avg/max/mdev = 0.5/1.0/2.5/0.3 ms
```

### Bandwidth Test
```bash
# iperf3 server
iperf3 -s

# iperf3 client (80 Mbps target for 100BASE-T1)
iperf3 -c 192.168.10.1 -u -b 80M -t 60
# Expected: 75-80 Mbps throughput
```

### TSN Validation
```bash
# Check Time-Aware Shaper
tc qdisc show dev eth0

# Check PTP synchronization
ptp4l -i eth0 -m | grep "master offset"
# Expected: < 1 µs offset
```

---

## Standards Compliance

### ISO 26262 (Functional Safety)
- ASIL-D for safety zones (brake, steering)
- ASIL-B for body zones (lighting, comfort)
- Redundant communication paths (FRER)
- Watchdog and ECC memory

### ISO 21434 (Cybersecurity)
- MACsec on all inter-zone links
- IPsec for cloud connectivity
- Firewall default DENY policy
- IDS/IPS deployment
- TARA (Threat Analysis and Risk Assessment)

### AUTOSAR
- Classic R4.4 for legacy ECUs
- Adaptive R23-11 for zone controllers
- SOME/IP for service communication
- DDS for real-time pub-sub

### IEEE 802.1 TSN
- Qbv (Time-Aware Shaper)
- Qav (Credit-Based Shaper for AVB)
- AS (gPTP time synchronization)
- CB (Frame Replication)
- Qci (Per-Stream Filtering)

---

## Resources

### Official Standards
- AUTOSAR: https://www.autosar.org/
- IEEE 802.1: https://1.ieee802.org/tsn/
- ISO 26262: https://www.iso.org/standard/68383.html
- ISO 21434: https://www.iso.org/standard/70918.html

### Open Source Tools
- vsomeip: https://github.com/COVESA/vsomeip
- Fast DDS: https://github.com/eProsima/Fast-DDS
- linuxptp: https://github.com/richardcochran/linuxptp
- Suricata: https://suricata.io/

### Industry Groups
- OPEN Alliance: https://opensig.org/
- COVESA (Connected Vehicle Systems Alliance): https://covesa.global/
- AUTOSAR: https://www.autosar.org/

---

**Status:** Production-ready
**Authentication:** None required
**Last Updated:** 2026-03-19
