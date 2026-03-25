# Automotive Middleware Skills

Production-ready skills for automotive middleware protocols and integration patterns.

## Overview

This directory contains 6 expert-level skills covering the primary middleware technologies used in automotive systems:

| Skill | Protocol | Use Case | Maturity |
|-------|----------|----------|----------|
| `dds-middleware` | DDS (Data Distribution Service) | ADAS sensor fusion, real-time ECU communication | Production |
| `mqtt-middleware` | MQTT | Vehicle-to-cloud telemetry, IoT | Production |
| `amqp-middleware` | AMQP | Manufacturing integration, enterprise messaging | Production |
| `ros2-dds-middleware` | ROS 2 with DDS | Autonomous driving, robotics | Production |
| `coap-middleware` | CoAP | Constrained devices, low-power IoT | Production |
| `opcua-middleware` | OPC UA | Factory automation, PLC integration | Production |

## Skill Details

### 1. DDS Middleware (`dds-middleware.yaml`)

**Target**: Real-time pub/sub for ADAS and V2X

**Key Features**:
- QoS policies (Reliability, Durability, History, Deadline, Liveliness)
- DDS Security (authentication, encryption)
- Fast DDS, Cyclone DDS, RTI Connext support
- AUTOSAR Adaptive integration

**Example Use Case**:
```
8 cameras @ 30fps → DDS topic 'vehicle/adas/camera'
4 radars @ 20Hz → DDS topic 'vehicle/adas/radar'
1 LiDAR @ 10Hz → DDS topic 'vehicle/adas/lidar'
Central ECU subscribes to all → sensor fusion
```

**QoS Profile**:
- ADAS sensors: RELIABLE, TRANSIENT_LOCAL, DEADLINE=50ms
- V2X: BEST_EFFORT, VOLATILE, LIVELINESS=50ms

### 2. MQTT Middleware (`mqtt-middleware.yaml`)

**Target**: Vehicle-to-cloud telemetry and remote commands

**Key Features**:
- QoS 0/1/2 for different criticality levels
- TLS with client certificates
- Last Will Testament (LWT) for online/offline status
- AWS IoT Core / Azure IoT Hub integration
- NB-IoT / LTE-M optimized

**Topic Design**:
```
vehicle/{vin}/telemetry/battery/soc     (QoS 0, 1Hz)
vehicle/{vin}/telemetry/location        (QoS 1, 10Hz)
vehicle/{vin}/cmd/remote_lock           (QoS 2, commands)
vehicle/{vin}/status/ota/progress       (QoS 1, updates)
```

**Payload Size**: ~50 bytes vs ~150 bytes MQTT CONNECT (optimized)

### 3. AMQP Middleware (`amqp-middleware.yaml`)

**Target**: Manufacturing execution systems (MES) and enterprise integration

**Key Features**:
- Exchange types: direct, topic, fanout, headers
- Publisher confirms for reliability
- Dead letter queues (DLX)
- Priority queues
- RabbitMQ and Azure Service Bus support

**Exchange Patterns**:
- **Direct**: Station-to-station commands
- **Topic**: Multi-subscriber vehicle configs (`vehicle.*.premium`)
- **Fanout**: OTA broadcasts to all vehicles

**Example**:
```
Exchange: vehicle.config (topic)
Routing Key: vehicle.model_s.premium
Queues: paint_shop, interior_line, final_assembly
```

### 4. ROS 2 DDS Middleware (`ros2-dds-middleware.yaml`)

**Target**: Autonomous driving software stack

**Key Features**:
- Fast DDS / Cyclone DDS backends
- Topics, services, actions
- TF (transform) system for coordinate frames
- SROS2 security
- Integration with Gazebo / CARLA simulators

**Node Architecture**:
```
/sensor/camera_front → Image (30Hz)
/sensor/lidar → PointCloud2 (10Hz)
/perception/objects → DetectedObjects
/planning/trajectory → Path
/control/vehicle_commands → AckermannDrive
```

**QoS Profiles**:
- Sensors: `SensorDataQoS()` (BEST_EFFORT, VOLATILE)
- Control: `SystemDefaultQoS()` (RELIABLE, KEEP_LAST(10))

### 5. CoAP Middleware (`coap-middleware.yaml`)

**Target**: Constrained devices and low-power IoT

**Key Features**:
- UDP-based (4-byte header)
- REST semantics (GET/POST/PUT/DELETE)
- Observe pattern for pub/sub
- Block-wise transfer for large payloads
- DTLS security

**Message Types**:
- CON (Confirmable): Requires ACK
- NON (Non-confirmable): Fire-and-forget

**Example Use Cases**:
- TPMS (Tire Pressure Monitoring): CoAP NON @ 10s intervals
- Battery cell monitoring: 96 cells → CoAP NON @ 1Hz
- V2X over 6LoWPAN: <100 bytes per message

**Comparison vs MQTT**:
- CoAP: 4-byte header, UDP, ~50 bytes total
- MQTT: TCP overhead, ~150 bytes CONNECT

### 6. OPC UA Middleware (`opcua-middleware.yaml`)

**Target**: Industrial automation and factory integration

**Key Features**:
- Platform-independent (vs OPC Classic)
- Information models (DI, PLCopen, PackML)
- Methods (RPC), events, alarms
- Historical data access (HDA)
- SignAndEncrypt security

**Address Space**:
```
Objects
  └─ ProductionLine
      ├─ Station01_CellLoading
      │   ├─ Status (Running/Idle/Error)
      │   ├─ CycleTime (Float, seconds)
      │   ├─ BatteryID (String)
      │   └─ StartCycle() [Method]
      ├─ Station02_Welding
      ...
```

**Integration**:
- PLC → OPC UA → MES (factory floor to cloud)
- OPC UA → MQTT gateway (Sparkplug B)
- OPC UA → DDS bridge (factory-to-vehicle testing)

## Selection Matrix

| Requirement | Recommended Middleware |
|-------------|------------------------|
| Real-time ADAS (< 10ms latency) | DDS |
| Autonomous driving stack | ROS 2 DDS |
| Vehicle telemetry to cloud | MQTT |
| Fleet management (10K+ vehicles) | MQTT with shared subscriptions |
| Manufacturing MES integration | AMQP or OPC UA |
| PLC / robot controller | OPC UA |
| Battery monitoring (low power) | CoAP |
| TPMS wireless sensors | CoAP |
| V2X communication | DDS |
| OTA updates | MQTT (AWS IoT Core / Azure IoT Hub) |

## Security Requirements

| Middleware | Security | Production Requirements |
|------------|----------|-------------------------|
| DDS | DDS Security 1.1 | PKI, AES-256-GCM, governance XML |
| MQTT | TLS 1.2+ | Client certificates, mTLS |
| AMQP | TLS 1.2+ | SASL, username/password or certificates |
| ROS 2 | SROS2 | DDS Security, keystore, enclave policies |
| CoAP | DTLS 1.2 | PSK or X.509 certificates |
| OPC UA | SignAndEncrypt | X.509 certificates, user auth |

## Performance Characteristics

| Middleware | Latency (p95) | Throughput | Overhead | Use Case |
|------------|---------------|------------|----------|----------|
| DDS | < 10ms | 10 Gbps | Low | Real-time |
| ROS 2 DDS | < 10ms | High | Low | Robotics |
| MQTT | 50-100ms | Moderate | Very Low | IoT |
| AMQP | 10-50ms | High | Moderate | Enterprise |
| CoAP | 50-200ms | Low | Very Low | Constrained |
| OPC UA | 10-100ms | Moderate | Moderate | Industrial |

## Automotive Standards Compliance

- **ISO 26262** (Functional Safety): DDS, ROS 2 DDS
- **ISO 21434** (Cybersecurity): All protocols with security enabled
- **AUTOSAR Adaptive**: DDS (ara::com binding)
- **ASPICE**: Process compliance for all implementations

## Getting Started

### 1. Read the Skill
```bash
cat dds-middleware.yaml
```

### 2. Use with Claude Code Agents
```bash
# Activate skill via agent command
/use-skill dds-middleware

# Ask for implementation
"Implement DDS publisher for camera data at 30Hz with RELIABLE QoS"
```

### 3. Example Queries

**DDS**:
- "Configure DDS QoS for ADAS camera: RELIABLE, 50ms deadline, KEEP_LAST(5)"
- "Implement DDS Security with governance and permissions XML"
- "Set up static discovery for deterministic ECU startup"

**MQTT**:
- "Design MQTT topic hierarchy for 10,000 vehicle fleet"
- "Implement LWT (Last Will Testament) for vehicle online/offline status"
- "Configure AWS IoT policy restricting publish by VIN"

**AMQP**:
- "Set up topic exchange for vehicle configuration distribution"
- "Implement dead letter queue for failed manufacturing messages"
- "Configure priority queue for urgent production line alerts"

**ROS 2**:
- "Create ROS 2 node publishing LiDAR point clouds at 10Hz"
- "Implement SROS2 security for autonomous driving stack"
- "Set up launch file for multi-node sensor fusion"

**CoAP**:
- "Implement CoAP server for battery cell monitoring (96 cells)"
- "Configure DTLS with PSK for TPMS wireless sensors"
- "Use Observe pattern for real-time SOC updates"

**OPC UA**:
- "Browse OPC UA server and read Station01.CycleTime"
- "Implement method call for StartCycle() on PLC"
- "Subscribe to data changes on all station status variables"

## Integration Patterns

### Factory-to-Vehicle
```
PLC (OPC UA) → Gateway (OPC UA to DDS) → Vehicle ECU (DDS)
```

### Vehicle-to-Cloud
```
Vehicle ECU (CAN) → Gateway (CAN to MQTT) → AWS IoT Core → Lambda
```

### Autonomous Vehicle
```
Sensors → ROS 2 Nodes → Perception → Planning → Control → AUTOSAR Adaptive
```

### Manufacturing
```
MES (AMQP) → Production Line (OPC UA) → Robots → Quality DB
```

## Tools and Libraries

### DDS
- **Fast DDS** (eProsima): Opensource, high performance
- **Cyclone DDS** (Eclipse): Lightweight, excellent throughput
- **RTI Connext DDS**: Commercial, safety-certified

### MQTT
- **Paho MQTT**: Python, C, C++, Java clients
- **Mosquitto**: Opensource broker
- **AWS IoT Core**: Managed cloud service

### AMQP
- **RabbitMQ**: Opensource broker
- **Pika**: Python client
- **Azure Service Bus**: Managed cloud service

### ROS 2
- **ROS 2 Humble/Iron**: LTS distributions
- **colcon**: Build system
- **rviz2**: Visualization

### CoAP
- **aiocoap**: Python async CoAP
- **libcoap**: C library
- **Copper**: Browser plugin

### OPC UA
- **opcua-asyncio**: Python client/server
- **open62541**: C library
- **UaExpert**: GUI client (Unified Automation)

## Testing

Each skill includes:
- Unit test patterns
- Integration test examples
- Performance benchmarking
- Security validation
- Automotive use case examples

## References

- DDS: https://www.omg.org/spec/DDS/1.4/
- MQTT: https://mqtt.org/mqtt-specification/
- AMQP: https://www.amqp.org/
- ROS 2: https://docs.ros.org/en/humble/
- CoAP: https://datatracker.ietf.org/doc/html/rfc7252
- OPC UA: https://reference.opcfoundation.org/

## License

All skills are part of the Automotive Claude Code Agents project.
See LICENSE file in repository root.

## Author

Automotive Claude Code Agents
Last Updated: 2026-03-19
