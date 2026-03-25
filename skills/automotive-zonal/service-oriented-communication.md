# Service-Oriented Communication - SOME/IP & DDS

**Category:** automotive-zonal
**Version:** 1.0.0
**Maturity:** production
**Complexity:** advanced

## Overview

Expert knowledge in service-oriented middleware for automotive zonal architectures. Covers SOME/IP (Scalable Service-Oriented Middleware over IP), DDS (Data Distribution Service), service discovery, publish-subscribe patterns, event-driven architecture, and method invocations over Ethernet.

## Core Competencies

### 1. SOME/IP (AUTOSAR Standard)

#### Protocol Overview

**SOME/IP = Scalable Service-Oriented Middleware over IP**
- Used in AUTOSAR Adaptive Platform
- Transport: UDP or TCP over IPv4/IPv6
- Serialization: SOME/IP binary format
- Discovery: SOME/IP-SD (Service Discovery)

```c
// SOME/IP Message Header (16 bytes)
typedef struct __attribute__((packed)) {
    uint32_t message_id;      // Service ID (16 bits) + Method ID (16 bits)
    uint32_t length;          // Payload length + 8
    uint32_t request_id;      // Client ID (16 bits) + Session ID (16 bits)
    uint8_t  protocol_version; // 0x01
    uint8_t  interface_version; // Service interface version
    uint8_t  message_type;    // REQUEST=0x00, RESPONSE=0x80, ERROR=0x81, NOTIFICATION=0x02
    uint8_t  return_code;     // E_OK=0x00, E_NOT_OK=0x01, etc.
} SOMEIP_Header_t;

// Example: Request message
SOMEIP_Header_t request = {
    .message_id = 0x12340001,  // Service 0x1234, Method 0x0001
    .length = 24,              // Header (16) + Payload (8)
    .request_id = 0x00010001,  // Client 0x0001, Session 0x0001
    .protocol_version = 0x01,
    .interface_version = 0x01,
    .message_type = 0x00,      // REQUEST
    .return_code = 0x00        // E_OK
};
```

#### Service Definition (FIDL)

```fidl
// Franca IDL (FIDL) - SOME/IP Service Definition
package org.genivi.battery

interface BatteryManagementService {
    version { major 1 minor 0 }

    // Methods (Request/Response)
    method GetBatteryStatus {
        out {
            UInt8 stateOfCharge    // 0-100%
            Float voltage           // Volts
            Float current           // Amps
            Int8 temperature        // Celsius
        }
    }

    method SetChargingLimit {
        in {
            UInt8 targetSoC        // Target SOC %
        }
        out {
            Boolean success
        }
    }

    // Events (Notifications)
    broadcast BatteryAlarm {
        out {
            UInt16 alarmCode
            String description
        }
    }

    // Attributes (Getter/Setter/Notification)
    attribute UInt8 stateOfCharge readonly

    // Error codes
    enumeration BatteryError {
        OK = 0
        INVALID_PARAMETER = 1
        HARDWARE_FAULT = 2
        COMMUNICATION_ERROR = 3
    }
}
```

#### SOME/IP Service Implementation

```cpp
#include <CommonAPI/CommonAPI.hpp>
#include <v1/org/genivi/battery/BatteryManagementServiceProxy.hpp>

using namespace v1::org::genivi::battery;

class BatteryClient {
public:
    BatteryClient() {
        runtime_ = CommonAPI::Runtime::get();
        proxy_ = runtime_->buildProxy<BatteryManagementServiceProxy>(
            "local", "BatteryService");

        // Wait for service availability
        while (!proxy_->isAvailable()) {
            std::this_thread::sleep_for(std::chrono::milliseconds(100));
        }

        // Subscribe to battery alarms
        proxy_->getBatteryAlarmEvent().subscribe(
            [](uint16_t alarmCode, std::string description) {
                std::cout << "Alarm " << alarmCode << ": "
                          << description << std::endl;
            });
    }

    void getBatteryStatus() {
        // Synchronous method call
        CommonAPI::CallStatus callStatus;
        uint8_t soc;
        float voltage, current;
        int8_t temperature;

        proxy_->GetBatteryStatus(callStatus, soc, voltage, current, temperature);

        if (callStatus == CommonAPI::CallStatus::SUCCESS) {
            std::cout << "SOC: " << (int)soc << "%" << std::endl;
            std::cout << "Voltage: " << voltage << "V" << std::endl;
            std::cout << "Current: " << current << "A" << std::endl;
            std::cout << "Temperature: " << (int)temperature << "°C" << std::endl;
        }
    }

    void setChargingLimit(uint8_t targetSoC) {
        // Asynchronous method call with callback
        proxy_->SetChargingLimitAsync(
            targetSoC,
            [](const CommonAPI::CallStatus& status, bool success) {
                if (status == CommonAPI::CallStatus::SUCCESS && success) {
                    std::cout << "Charging limit set successfully" << std::endl;
                }
            });
    }

private:
    std::shared_ptr<CommonAPI::Runtime> runtime_;
    std::shared_ptr<BatteryManagementServiceProxy<>> proxy_;
};
```

#### SOME/IP-SD (Service Discovery)

```python
class SOMEIPServiceDiscovery:
    """
    SOME/IP Service Discovery (SOME/IP-SD) implementation.
    Uses UDP multicast (224.244.224.245:30490) for service advertisement.
    """

    def __init__(self):
        self.multicast_group = '224.244.224.245'
        self.multicast_port = 30490
        self.services = {}

    def offer_service(self, service_id, instance_id, endpoint):
        """
        Offer a service via SOME/IP-SD.

        Args:
            service_id: Service identifier (16-bit)
            instance_id: Instance identifier (16-bit)
            endpoint: (IP, port, protocol)  protocol='UDP' or 'TCP'
        """

        offer_message = {
            'message_type': 'OfferService',
            'service_id': service_id,
            'instance_id': instance_id,
            'major_version': 1,
            'minor_version': 0,
            'ttl': 3,  # Time-to-live in seconds (0xFFFFFF = infinite)
            'endpoint': {
                'ipv4': endpoint[0],
                'port': endpoint[1],
                'protocol': endpoint[2]  # UDP or TCP
            }
        }

        # Send cyclic offers (every 1 second)
        # Until service is stopped
        return offer_message

    def find_service(self, service_id, instance_id=None):
        """
        Find a service via SOME/IP-SD.

        Args:
            service_id: Service to find
            instance_id: Specific instance (None = any)

        Returns:
            List of available service endpoints
        """

        find_message = {
            'message_type': 'FindService',
            'service_id': service_id,
            'instance_id': instance_id if instance_id else 0xFFFF,  # ANY
            'major_version': 0xFF,  # ANY
            'minor_version': 0xFFFFFFFF  # ANY
        }

        # Wait for OfferService responses
        # Return list of endpoints
        return []

# Example usage:
sd = SOMEIPServiceDiscovery()

# Offer battery service
sd.offer_service(
    service_id=0x1234,
    instance_id=0x0001,
    endpoint=('192.168.1.10', 30500, 'UDP')
)

# Find battery service
endpoints = sd.find_service(service_id=0x1234)
```

### 2. DDS (Data Distribution Service)

#### DDS Quality of Service (QoS)

```python
from dataclasses import dataclass
from enum import Enum

class ReliabilityKind(Enum):
    BEST_EFFORT = 0  # UDP-like, lossy
    RELIABLE = 1      # TCP-like, guaranteed delivery

class DurabilityKind(Enum):
    VOLATILE = 0          # Only for live data
    TRANSIENT_LOCAL = 1   # Store last value for late joiners
    TRANSIENT = 2         # Persist across processes
    PERSISTENT = 3        # Persist to disk

@dataclass
class DDSQoS:
    """DDS Quality of Service configuration."""

    reliability: ReliabilityKind
    durability: DurabilityKind
    history_depth: int  # Number of samples to keep
    max_blocking_time_ms: int  # Max time to block writer
    latency_budget_ms: int  # Hint for latency optimization
    lifespan_ms: int  # Sample validity duration

# Example QoS profiles for different use cases

# Safety-critical real-time data (ESC, ABS)
SAFETY_QOS = DDSQoS(
    reliability=ReliabilityKind.RELIABLE,
    durability=DurabilityKind.VOLATILE,
    history_depth=1,  # Only latest value matters
    max_blocking_time_ms=10,
    latency_budget_ms=5,
    lifespan_ms=100
)

# Sensor data (high-rate, best-effort)
SENSOR_QOS = DDSQoS(
    reliability=ReliabilityKind.BEST_EFFORT,
    durability=DurabilityKind.VOLATILE,
    history_depth=5,
    max_blocking_time_ms=0,  # Non-blocking
    latency_budget_ms=1,
    lifespan_ms=50
)

# Configuration data (late-joiner support)
CONFIG_QOS = DDSQoS(
    reliability=ReliabilityKind.RELIABLE,
    durability=DurabilityKind.TRANSIENT_LOCAL,
    history_depth=1,
    max_blocking_time_ms=1000,
    latency_budget_ms=100,
    lifespan_ms=0  # No expiration
)
```

#### DDS Topic Definition (IDL)

```idl
// OMG IDL for DDS topics
module automotive {
    module battery {

        struct BatteryStatus {
            unsigned long timestamp;    // Unix timestamp (ms)
            octet stateOfCharge;        // 0-100%
            float voltage;              // Volts
            float current;              // Amps
            char temperature;           // Celsius
            boolean charging;
        };

        struct BatteryAlarm {
            unsigned long timestamp;
            unsigned short alarmCode;
            string<256> description;
            octet severity;  // 0=Info, 1=Warning, 2=Error, 3=Critical
        };

    };
};
```

#### DDS Publisher/Subscriber (C++)

```cpp
#include <dds/dds.hpp>
#include "BatteryStatus.hpp"

using namespace automotive::battery;

class BatteryPublisher {
public:
    BatteryPublisher() {
        // Create DDS participant (one per application)
        participant_ = dds::domain::DomainParticipant(0);

        // Create topic
        topic_ = dds::topic::Topic<BatteryStatus>(
            participant_, "BatteryStatusTopic");

        // Create publisher with QoS
        dds::pub::qos::PublisherQos pub_qos;
        publisher_ = dds::pub::Publisher(participant_, pub_qos);

        // Create data writer
        dds::pub::qos::DataWriterQos writer_qos;
        writer_qos << SAFETY_QOS;  // Use safety QoS profile
        writer_ = dds::pub::DataWriter<BatteryStatus>(publisher_, topic_, writer_qos);
    }

    void publishStatus(uint8_t soc, float voltage, float current, int8_t temp) {
        BatteryStatus status;
        status.timestamp(std::chrono::system_clock::now().time_since_epoch().count());
        status.stateOfCharge(soc);
        status.voltage(voltage);
        status.current(current);
        status.temperature(temp);
        status.charging(current > 0);

        writer_.write(status);
    }

private:
    dds::domain::DomainParticipant participant_;
    dds::topic::Topic<BatteryStatus> topic_;
    dds::pub::Publisher publisher_;
    dds::pub::DataWriter<BatteryStatus> writer_;
};

class BatterySubscriber {
public:
    BatterySubscriber() {
        participant_ = dds::domain::DomainParticipant(0);
        topic_ = dds::topic::Topic<BatteryStatus>(
            participant_, "BatteryStatusTopic");

        dds::sub::qos::SubscriberQos sub_qos;
        subscriber_ = dds::sub::Subscriber(participant_, sub_qos);

        dds::sub::qos::DataReaderQos reader_qos;
        reader_qos << SAFETY_QOS;
        reader_ = dds::sub::DataReader<BatteryStatus>(subscriber_, topic_, reader_qos);

        // Register listener for data arrival
        reader_.listener(
            new BatteryStatusListener(),
            dds::core::status::StatusMask::data_available());
    }

private:
    class BatteryStatusListener : public dds::sub::NoOpDataReaderListener<BatteryStatus> {
    public:
        void on_data_available(dds::sub::DataReader<BatteryStatus>& reader) override {
            auto samples = reader.take();
            for (const auto& sample : samples) {
                if (sample.info().valid()) {
                    std::cout << "SOC: " << (int)sample.data().stateOfCharge() << "%"
                              << " Voltage: " << sample.data().voltage() << "V"
                              << std::endl;
                }
            }
        }
    };

    dds::domain::DomainParticipant participant_;
    dds::topic::Topic<BatteryStatus> topic_;
    dds::sub::Subscriber subscriber_;
    dds::sub::DataReader<BatteryStatus> reader_;
};
```

### 3. Service Discovery Mechanisms

#### Comparison

| Feature | SOME/IP-SD | DDS Discovery |
|---------|-----------|---------------|
| Transport | UDP multicast | UDP/TCP multicast + unicast |
| Discovery time | 1-3 seconds | <100ms |
| Overhead | Low (periodic offers) | Medium (SPDP + SEDP) |
| Dynamic reconfiguration | Yes | Yes |
| QoS negotiation | Limited | Extensive |
| Best for | AUTOSAR Adaptive | Complex data flows |

### 4. Event-Driven Architecture Patterns

```python
class EventBus:
    """
    Automotive event bus for service-oriented communication.
    Supports both SOME/IP and DDS backends.
    """

    def __init__(self, backend='someip'):
        self.backend = backend
        self.subscribers = {}

    def publish(self, topic, data, qos='reliable'):
        """
        Publish event to topic.

        Args:
            topic: Event topic name
            data: Event payload
            qos: 'reliable' or 'best_effort'
        """

        if self.backend == 'someip':
            # SOME/IP notification
            self._someip_notify(topic, data)
        elif self.backend == 'dds':
            # DDS publish
            self._dds_publish(topic, data, qos)

    def subscribe(self, topic, callback, qos='reliable'):
        """
        Subscribe to topic with callback.

        Args:
            topic: Topic name
            callback: Function to call on event
            qos: QoS requirements
        """

        if topic not in self.subscribers:
            self.subscribers[topic] = []

        self.subscribers[topic].append({
            'callback': callback,
            'qos': qos
        })

        if self.backend == 'someip':
            self._someip_subscribe(topic)
        elif self.backend == 'dds':
            self._dds_subscribe(topic, qos)

# Usage example:
bus = EventBus(backend='someip')

# Subscribe to battery alarms
bus.subscribe('battery/alarm', lambda alarm: print(f"Alarm: {alarm}"))

# Publish alarm event
bus.publish('battery/alarm', {
    'code': 0x1234,
    'severity': 'critical',
    'description': 'Over-temperature detected'
})
```

## Performance Characteristics

### SOME/IP
- **Latency**: 1-5ms (local), 10-50ms (remote)
- **Throughput**: Up to 100 Mbps per service
- **Overhead**: ~16 bytes header per message
- **Discovery time**: 1-3 seconds (configurable)

### DDS
- **Latency**: <1ms (local), 5-20ms (remote)
- **Throughput**: Up to 1 Gbps aggregate
- **Overhead**: ~20 bytes RTPS header
- **Discovery time**: <100ms

## Best Practices

1. **Use SOME/IP** for AUTOSAR Adaptive services, ECU-to-ECU communication
2. **Use DDS** for high-throughput sensor data, complex QoS requirements
3. **Choose UDP** for time-critical best-effort data (sensors)
4. **Choose TCP** for reliable control commands, configuration
5. **Minimize service interfaces** - Fewer, richer services better than many small ones
6. **Use service versioning** - Major version in service ID, minor in header

## Tools

- **Vector MICROSAR** - SOME/IP stack for AUTOSAR Classic/Adaptive
- **RTI Connext DDS** - High-performance DDS implementation
- **Eclipse Cyclone DDS** - Open-source DDS (used in ROS 2)
- **vsomeip** - Open-source SOME/IP implementation (BMW/GENIVI)
- **CommonAPI** - Language bindings for SOME/IP and DDS

## References

- AUTOSAR Specification of SOME/IP Protocol (PRS_SOMEIPPROTOCOL)
- OMG Data Distribution Service (DDS) Specification v1.4
- AUTOSAR Adaptive Platform R22-11
- SOME/IP Protocol Specification v1.3.0
