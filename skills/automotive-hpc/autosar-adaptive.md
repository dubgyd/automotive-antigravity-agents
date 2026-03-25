# AUTOSAR Adaptive Platform for HPC

**Category:** automotive-hpc
**Version:** 1.0.0
**Maturity:** production
**Complexity:** advanced

## Overview

Comprehensive guide to AUTOSAR Adaptive Platform (AP) for high-performance computing in Software-Defined Vehicles. Covers service-oriented architecture, ara::com communication, execution management, state management, and C++14 framework development.

## Core Competencies

### 1. AUTOSAR Adaptive Architecture

**AUTOSAR Adaptive Platform Stack:**
```
┌─────────────────────────────────────────────────┐
│         Adaptive Applications (C++14)           │
├─────────────────────────────────────────────────┤
│  ara::com  │  ara::exec │  ara::log │  ara::per│
│  ara::diag │  ara::sm   │  ara::ucm │  ara::phm│
├─────────────────────────────────────────────────┤
│          Adaptive Platform Foundation           │
│  - Communication Management (SOME/IP)           │
│  - Execution Management (Process Control)       │
│  - State Management (Function Groups)           │
│  - Update & Config Management                   │
├─────────────────────────────────────────────────┤
│       Operating System (POSIX PSE51)            │
│  - Linux with PREEMPT_RT patch                  │
│  - QNX 7.1 (Safety-certified option)            │
└─────────────────────────────────────────────────┘
```

### 2. Service-Oriented Communication (ara::com)

**Service Interface Definition (ARXML):**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<AUTOSAR xmlns="http://autosar.org/schema/r4.0">
    <AR-PACKAGES>
        <AR-PACKAGE>
            <SHORT-NAME>RadarServices</SHORT-NAME>
            <ELEMENTS>
                <!-- Service Interface Definition -->
                <SERVICE-INTERFACE>
                    <SHORT-NAME>RadarFusion</SHORT-NAME>
                    <MAJOR-VERSION>1</MAJOR-VERSION>
                    <MINOR-VERSION>0</MINOR-VERSION>

                    <!-- Events (pub/sub) -->
                    <EVENTS>
                        <VARIABLE-DATA-PROTOTYPE>
                            <SHORT-NAME>ObjectList</SHORT-NAME>
                            <TYPE-TREF DEST="IMPLEMENTATION-DATA-TYPE">/DataTypes/ObjectListType</TYPE-TREF>
                        </VARIABLE-DATA-PROTOTYPE>
                        <VARIABLE-DATA-PROTOTYPE>
                            <SHORT-NAME>FreeSpaceMap</SHORT-NAME>
                            <TYPE-TREF DEST="IMPLEMENTATION-DATA-TYPE">/DataTypes/FreeSpaceMapType</TYPE-TREF>
                        </VARIABLE-DATA-PROTOTYPE>
                    </EVENTS>

                    <!-- Methods (client/server) -->
                    <METHODS>
                        <CLIENT-SERVER-OPERATION>
                            <SHORT-NAME>SetRadarMode</SHORT-NAME>
                            <ARGUMENTS>
                                <ARGUMENT-DATA-PROTOTYPE>
                                    <SHORT-NAME>mode</SHORT-NAME>
                                    <TYPE-TREF DEST="IMPLEMENTATION-DATA-TYPE">/DataTypes/RadarModeType</TYPE-TREF>
                                    <DIRECTION>IN</DIRECTION>
                                </ARGUMENT-DATA-PROTOTYPE>
                                <ARGUMENT-DATA-PROTOTYPE>
                                    <SHORT-NAME>success</SHORT-NAME>
                                    <TYPE-TREF DEST="IMPLEMENTATION-DATA-TYPE">/DataTypes/BooleanType</TYPE-TREF>
                                    <DIRECTION>OUT</DIRECTION>
                                </ARGUMENT-DATA-PROTOTYPE>
                            </ARGUMENTS>
                            <POSSIBLE-ERROR-REFS>
                                <POSSIBLE-ERROR-REF DEST="APPLICATION-ERROR">/Errors/InvalidModeError</POSSIBLE-ERROR-REF>
                            </POSSIBLE-ERROR-REFS>
                        </CLIENT-SERVER-OPERATION>
                    </METHODS>

                    <!-- Fields (getter/setter) -->
                    <FIELDS>
                        <FIELD>
                            <SHORT-NAME>RadarStatus</SHORT-NAME>
                            <TYPE-TREF DEST="IMPLEMENTATION-DATA-TYPE">/DataTypes/RadarStatusType</TYPE-TREF>
                            <HAS-GETTER>true</HAS-GETTER>
                            <HAS-SETTER>false</HAS-SETTER>
                            <HAS-NOTIFIER>true</HAS-NOTIFIER>
                        </FIELD>
                    </FIELDS>
                </SERVICE-INTERFACE>

                <!-- Service Instance Deployment -->
                <SOMEIP-SERVICE-INSTANCE-TO-MACHINE-MAPPING>
                    <SHORT-NAME>RadarFusionInstance</SHORT-NAME>
                    <COMMUNICATION-CONNECTOR-REF DEST="ETHERNET-COMMUNICATION-CONNECTOR">
                        /Network/EthernetConnector
                    </COMMUNICATION-CONNECTOR-REF>
                    <SERVICE-INTERFACE-DEPLOYMENT-REF DEST="SOMEIP-SERVICE-INTERFACE-DEPLOYMENT">
                        /Deployments/RadarFusionDeployment
                    </SERVICE-INTERFACE-DEPLOYMENT-REF>
                    <SOMEIP-SERVICE-INSTANCE-CONFIG>
                        <SERVICE-ID>0x1234</SERVICE-ID>
                        <INSTANCE-ID>0x0001</INSTANCE-ID>
                        <MAJOR-VERSION>1</MAJOR-VERSION>
                        <MINOR-VERSION>0</MINOR-VERSION>
                        <UDP-PORT>30490</UDP-PORT>
                        <TCP-PORT>30491</TCP-PORT>
                    </SOMEIP-SERVICE-INSTANCE-CONFIG>
                </SOMEIP-SERVICE-INSTANCE-TO-MACHINE-MAPPING>
            </ELEMENTS>
        </AR-PACKAGE>
    </AR-PACKAGES>
</AUTOSAR>
```

**C++14 Service Implementation (Provider):**
```cpp
// radar_fusion_service_impl.hpp
#include <ara/com/types.h>
#include <ara/com/instance_identifier.h>
#include <ara/com/skeleton.h>
#include "radar_fusion_skeleton.h"  // Generated from ARXML

namespace radar {
namespace fusion {

class RadarFusionServiceImpl {
public:
    RadarFusionServiceImpl()
        : skeleton_(ara::com::InstanceIdentifier("RadarFusion/Instance1")) {

        // Register method handler
        skeleton_.SetRadarMode.SetMethodCallHandler(
            [this](const RadarModeType& mode) -> ara::core::Future<SetRadarModeOutput> {
                return HandleSetRadarMode(mode);
            }
        );

        // Offer service on network
        skeleton_.OfferService();
    }

    ~RadarFusionServiceImpl() {
        skeleton_.StopOfferService();
    }

    // Publish object list event (10Hz)
    void PublishObjectList(const ObjectListType& objects) {
        skeleton_.ObjectList.Send(objects);
    }

    // Update field value with notification
    void UpdateRadarStatus(const RadarStatusType& status) {
        skeleton_.RadarStatus.Update(status);
    }

private:
    RadarFusionSkeleton skeleton_;

    ara::core::Future<SetRadarModeOutput> HandleSetRadarMode(const RadarModeType& mode) {
        ara::core::Promise<SetRadarModeOutput> promise;

        if (mode < RadarModeType::MIN || mode > RadarModeType::MAX) {
            // Return application error
            promise.SetError(ara::com::ApplicationErrorDomain::Errc::kInvalidMode);
        } else {
            // Apply mode change
            ApplyRadarMode(mode);

            SetRadarModeOutput output;
            output.success = true;
            promise.set_value(output);
        }

        return promise.get_future();
    }

    void ApplyRadarMode(const RadarModeType& mode) {
        // Hardware-specific mode configuration
        // ...
    }
};

} // namespace fusion
} // namespace radar

// Main application
int main() {
    ara::log::InitLogging("RadarFusion", ara::log::LogLevel::kInfo);
    ara::exec::ExecutionClient exec_client;

    // Report Execution State
    exec_client.ReportExecutionState(ara::exec::ExecutionState::kRunning);

    // Create service
    radar::fusion::RadarFusionServiceImpl service;

    // Main processing loop
    while (!ShutdownRequested()) {
        // Process radar data
        auto objects = ProcessRadarData();
        service.PublishObjectList(objects);

        std::this_thread::sleep_for(std::chrono::milliseconds(100));
    }

    // Clean shutdown
    exec_client.ReportExecutionState(ara::exec::ExecutionState::kTerminating);
    return 0;
}
```

**C++14 Service Consumer (Proxy):**
```cpp
// adas_controller.cpp
#include <ara/com/proxy.h>
#include "radar_fusion_proxy.h"

namespace adas {

class AdasController {
public:
    AdasController() {
        // Find service instances
        auto find_handle = RadarFusionProxy::StartFindService(
            [this](ara::com::ServiceHandleContainer<RadarFusionProxy::HandleType> handles,
                   ara::com::FindServiceHandle find_handle) {
                this->OnServiceAvailable(std::move(handles));
            }
        );
    }

    void OnServiceAvailable(ara::com::ServiceHandleContainer<RadarFusionProxy::HandleType> handles) {
        if (!handles.empty()) {
            // Create proxy to first available service
            proxy_ = std::make_unique<RadarFusionProxy>(handles[0]);

            // Subscribe to ObjectList event
            proxy_->ObjectList.Subscribe(10 /* queue size */);
            proxy_->ObjectList.SetReceiveHandler(
                [this]() { this->OnObjectListReceived(); }
            );

            // Subscribe to RadarStatus field changes
            proxy_->RadarStatus.Subscribe(1);
            proxy_->RadarStatus.SetReceiveHandler(
                [this]() { this->OnRadarStatusChanged(); }
            );

            // Call method
            SetRadarMode(RadarModeType::LONG_RANGE);
        }
    }

    void OnObjectListReceived() {
        proxy_->ObjectList.GetNewSamples(
            [this](auto sample) {
                // Process object list
                for (const auto& obj : sample->objects) {
                    ProcessDetectedObject(obj);
                }
            }
        );
    }

    void OnRadarStatusChanged() {
        auto status = proxy_->RadarStatus.Get();
        ara::log::LogInfo() << "Radar status: " << status.value();
    }

    void SetRadarMode(RadarModeType mode) {
        // Async method call
        auto future = proxy_->SetRadarMode(mode);

        future.then([](ara::core::Future<SetRadarModeOutput> result) {
            if (result.HasValue()) {
                auto output = result.GetResult();
                if (output.value().success) {
                    ara::log::LogInfo() << "Mode change successful";
                }
            } else {
                auto error = result.GetError();
                ara::log::LogError() << "Mode change failed: " << error;
            }
        });
    }

private:
    std::unique_ptr<RadarFusionProxy> proxy_;

    void ProcessDetectedObject(const ObjectType& obj) {
        // ADAS processing logic
        // ...
    }
};

} // namespace adas
```

### 3. Execution Management (ara::exec)

**Application Manifest (JSON):**
```json
{
  "ApplicationManifest": {
    "shortName": "RadarFusionApp",
    "executableName": "radar_fusion",
    "version": "1.0.0",

    "processDesign": {
      "executable": "/opt/autosar/bin/radar_fusion",
      "arguments": ["--config", "/etc/autosar/radar_fusion.yaml"],
      "environmentVariables": {
        "LD_LIBRARY_PATH": "/opt/autosar/lib",
        "LOG_LEVEL": "INFO"
      }
    },

    "resourceGroups": [
      {
        "name": "RadarFusionResources",
        "cpuCores": [4, 5, 6, 7],
        "memoryMB": 512,
        "priority": 80,
        "schedulingPolicy": "SCHED_FIFO"
      }
    ],

    "startupConfig": {
      "functionGroup": "DrivingMode",
      "startupTimeout": 5000,
      "dependsOn": [
        "SensorAcquisition",
        "NetworkStack"
      ]
    },

    "stateManagement": {
      "functionGroup": "DrivingMode",
      "states": [
        {
          "name": "Startup",
          "timeout": 2000
        },
        {
          "name": "Running",
          "timeout": -1
        },
        {
          "name": "Degraded",
          "timeout": -1
        },
        {
          "name": "Shutdown",
          "timeout": 5000
        }
      ]
    },

    "healthMonitoring": {
      "checkpoints": [
        {
          "name": "DataProcessing",
          "maxInterval": 200
        },
        {
          "name": "NetworkCommunication",
          "maxInterval": 1000
        }
      ],
      "aliveSupervision": {
        "expectedAliveIndications": 10,
        "minInterval": 50,
        "maxInterval": 150
      }
    }
  }
}
```

**Execution Client Implementation:**
```cpp
// execution_manager.cpp
#include <ara/exec/execution_client.h>
#include <ara/exec/state_client.h>
#include <ara/phm/supervised_entity.h>

namespace radar {
namespace exec {

class ExecutionManager {
public:
    ExecutionManager()
        : exec_client_(),
          state_client_(),
          supervised_entity_("RadarFusion") {

        // Register state transition handler
        state_client_.SetStateTransitionHandler(
            [this](ara::exec::StateTransition transition) {
                this->HandleStateTransition(transition);
            }
        );
    }

    void Initialize() {
        // Report to Execution Management that we're starting
        exec_client_.ReportExecutionState(ara::exec::ExecutionState::kRunning);

        // Report checkpoint during initialization
        supervised_entity_.ReportCheckpoint(
            ara::phm::CheckpointIdentifier("Initialization")
        );

        // Load configuration
        LoadConfiguration();

        // Initialize hardware
        InitializeRadarHardware();

        // Start alive supervision
        StartAlivenessMonitoring();
    }

    void Run() {
        while (!shutdown_requested_) {
            // Report alive indication
            supervised_entity_.ReportAlive();

            // Main processing
            ProcessRadarData();

            // Report data processing checkpoint
            supervised_entity_.ReportCheckpoint(
                ara::phm::CheckpointIdentifier("DataProcessing")
            );

            std::this_thread::sleep_for(std::chrono::milliseconds(100));
        }
    }

    void Shutdown() {
        // Stop processing
        StopRadarHardware();

        // Report terminating state
        exec_client_.ReportExecutionState(ara::exec::ExecutionState::kTerminating);
    }

private:
    ara::exec::ExecutionClient exec_client_;
    ara::exec::StateClient state_client_;
    ara::phm::SupervisedEntity supervised_entity_;
    std::atomic<bool> shutdown_requested_{false};

    void HandleStateTransition(ara::exec::StateTransition transition) {
        ara::log::LogInfo() << "State transition: "
                           << transition.from_state << " -> "
                           << transition.to_state;

        if (transition.to_state == "Shutdown") {
            shutdown_requested_ = true;
        } else if (transition.to_state == "Degraded") {
            EnterDegradedMode();
        }
    }

    void StartAlivenessMonitoring() {
        // Start thread for periodic alive reporting
        alive_thread_ = std::thread([this]() {
            while (!shutdown_requested_) {
                supervised_entity_.ReportAlive();
                std::this_thread::sleep_for(std::chrono::milliseconds(100));
            }
        });
    }

    void ProcessRadarData() {
        // Radar processing logic
    }

    void EnterDegradedMode() {
        // Reduce functionality for degraded operation
        ara::log::LogWarn() << "Entering degraded mode";
    }

    std::thread alive_thread_;
};

} // namespace exec
} // namespace radar

int main() {
    radar::exec::ExecutionManager manager;

    try {
        manager.Initialize();
        manager.Run();
        manager.Shutdown();
    } catch (const std::exception& e) {
        ara::log::LogFatal() << "Fatal error: " << e.what();
        return EXIT_FAILURE;
    }

    return EXIT_SUCCESS;
}
```

### 4. State Management (ara::sm)

**Function Group State Machine:**
```cpp
// state_machine.cpp
#include <ara/sm/state_client.h>
#include <ara/sm/trigger_out.h>

namespace vehicle {
namespace sm {

enum class VehicleMode {
    OFF,
    STANDBY,
    DRIVING,
    PARKING,
    CHARGING,
    DIAGNOSTIC
};

class VehicleStateManager {
public:
    VehicleStateManager() {
        // Subscribe to function group state changes
        state_client_.SetStateTransitionHandler(
            [this](const ara::sm::FunctionGroupState& state) {
                this->OnStateChange(state);
            }
        );

        // Register trigger providers
        RegisterTriggers();
    }

    void RequestModeChange(VehicleMode target_mode) {
        ara::sm::FunctionGroupState target_state;

        switch (target_mode) {
            case VehicleMode::DRIVING:
                target_state = ara::sm::FunctionGroupState("DrivingMode");
                break;
            case VehicleMode::PARKING:
                target_state = ara::sm::FunctionGroupState("ParkingMode");
                break;
            case VehicleMode::CHARGING:
                target_state = ara::sm::FunctionGroupState("ChargingMode");
                break;
            default:
                ara::log::LogError() << "Invalid mode requested";
                return;
        }

        // Request state transition
        auto result = state_client_.SetState(target_state);
        result.then([target_mode](ara::core::Future<void> future) {
            if (future.has_value()) {
                ara::log::LogInfo() << "Mode change to "
                                   << static_cast<int>(target_mode)
                                   << " successful";
            } else {
                ara::log::LogError() << "Mode change failed: "
                                    << future.GetError().Message();
            }
        });
    }

private:
    ara::sm::StateClient state_client_;
    std::unique_ptr<ara::sm::TriggerOut> ignition_trigger_;
    std::unique_ptr<ara::sm::TriggerOut> charging_trigger_;

    void RegisterTriggers() {
        // Register ignition trigger
        ignition_trigger_ = std::make_unique<ara::sm::TriggerOut>(
            ara::sm::TriggerIdentifier("IgnitionOn")
        );

        // Register charging trigger
        charging_trigger_ = std::make_unique<ara::sm::TriggerOut>(
            ara::sm::TriggerIdentifier("ChargingConnected")
        );
    }

    void OnStateChange(const ara::sm::FunctionGroupState& state) {
        ara::log::LogInfo() << "Function group state changed to: " << state;

        if (state == "DrivingMode") {
            EnableDrivingFunctions();
        } else if (state == "ParkingMode") {
            EnableParkingFunctions();
        } else if (state == "ChargingMode") {
            EnableChargingFunctions();
        }
    }

    void EnableDrivingFunctions() {
        // Activate ADAS, powertrain control, etc.
        ara::log::LogInfo() << "Driving functions enabled";
    }

    void EnableParkingFunctions() {
        // Activate parking assist, surround view, etc.
        ara::log::LogInfo() << "Parking functions enabled";
    }

    void EnableChargingFunctions() {
        // Activate battery management, charging control
        ara::log::LogInfo() << "Charging functions enabled";
    }
};

} // namespace sm
} // namespace vehicle
```

### 5. Platform Health Management (ara::phm)

**Health Monitoring Implementation:**
```cpp
// health_monitor.cpp
#include <ara/phm/recovery_action.h>
#include <ara/phm/health_channel.h>

namespace platform {
namespace health {

class HealthMonitor {
public:
    HealthMonitor() {
        // Create health channels
        sensor_health_ = std::make_unique<ara::phm::HealthChannel>(
            ara::phm::HealthChannelId("SensorHealth")
        );

        computation_health_ = std::make_unique<ara::phm::HealthChannel>(
            ara::phm::HealthChannelId("ComputationHealth")
        );

        // Register recovery actions
        RegisterRecoveryActions();
    }

    void MonitorSensorHealth(const SensorData& data) {
        if (!ValidateSensorData(data)) {
            // Report health status degraded
            sensor_health_->ReportHealthStatus(
                ara::phm::HealthStatus::kDegraded,
                ara::phm::HealthStatusCause::kInvalidData
            );

            // Trigger recovery action
            recovery_action_->Invoke();
        } else {
            sensor_health_->ReportHealthStatus(
                ara::phm::HealthStatus::kOk
            );
        }
    }

    void MonitorComputationLoad() {
        float cpu_usage = GetCPUUsage();
        float memory_usage = GetMemoryUsage();

        if (cpu_usage > 95.0 || memory_usage > 90.0) {
            computation_health_->ReportHealthStatus(
                ara::phm::HealthStatus::kDegraded,
                ara::phm::HealthStatusCause::kResourceExhaustion
            );

            // Reduce processing load
            ReduceComputationLoad();
        }
    }

private:
    std::unique_ptr<ara::phm::HealthChannel> sensor_health_;
    std::unique_ptr<ara::phm::HealthChannel> computation_health_;
    std::unique_ptr<ara::phm::RecoveryAction> recovery_action_;

    void RegisterRecoveryActions() {
        recovery_action_ = std::make_unique<ara::phm::RecoveryAction>(
            ara::phm::RecoveryActionId("SensorRecovery"),
            [this]() {
                // Recovery logic: restart sensor, use fallback data, etc.
                ara::log::LogWarn() << "Executing sensor recovery";
                RestartSensorInterface();
            }
        );
    }

    bool ValidateSensorData(const SensorData& data) {
        return data.timestamp_valid &&
               data.crc_valid &&
               data.alive_counter_sequential;
    }

    void RestartSensorInterface() {
        // Sensor restart logic
    }

    void ReduceComputationLoad() {
        // Temporarily disable non-critical features
    }

    float GetCPUUsage() { return 0.0; }  // Implementation
    float GetMemoryUsage() { return 0.0; }  // Implementation
};

} // namespace health
} // namespace platform
```

## Use Cases

1. **L3+ Autonomous Driving**: ADAS applications using ara::com for sensor fusion
2. **OTA Updates**: ara::ucm for safe software updates with rollback
3. **Zone Controllers**: Service-oriented communication between domain controllers
4. **Cloud Connectivity**: ara::rest for vehicle-to-cloud data exchange

## Automotive Standards

- **AUTOSAR R22-11**: Latest Adaptive Platform specification
- **ISO 26262 ASIL-D**: Safety-critical application development
- **ISO 21434**: Cybersecurity for service communication
- **ASPICE CL3**: Software development process compliance

## Tools Required

- **Vector DaVinci**: ARXML editing and code generation
- **EB tresos AdaptiveCore**: AUTOSAR Adaptive middleware
- **Elektrobit EB corbos**: Adaptive Platform implementation
- **COVESA VSS**: Vehicle Signal Specification integration

## Performance Metrics

- **Service Discovery**: <100ms to find and bind to service
- **Event Throughput**: >10,000 events/sec via SOME/IP
- **Method Call Latency**: <2ms round-trip for local services
- **Memory Footprint**: <50MB for Adaptive Platform runtime

## References

- AUTOSAR Adaptive Platform Release 22-11 Specification
- "AUTOSAR Adaptive Platform Explained" (AUTOSAR Whitepaper)
- ISO 26262-6:2018 Software Development Guidelines
- COVESA Vehicle Signal Specification

---

**Version:** 1.0.0
**Last Updated:** 2026-03-19
**Author:** Automotive Claude Code Agents
