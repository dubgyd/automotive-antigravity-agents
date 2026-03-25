# Safety Certification for Automotive HPC Platforms

**Category:** automotive-hpc
**Version:** 1.0.0
**Maturity:** production
**Complexity:** advanced

## Overview

Comprehensive guide to ISO 26262 safety certification for High-Performance Computing platforms. Covers ASIL-D partitioning, Freedom from Interference (FFI), safety mechanisms, certification strategies, and evidence documentation.

## Core Competencies

### 1. ISO 26262 for HPC Platforms

**ISO 26262 Part 6 - Software Development:**
- **Clause 7**: Freedom From Interference
- **Clause 8**: Software Unit Design and Implementation
- **Clause 9**: Software Unit Testing
- **Clause 10**: Software Integration and Testing

**ASIL Decomposition on HPC:**
```
Single HPC SoC replacing multiple ECUs:
┌─────────────────────────────────────────────┐
│        NVIDIA DRIVE Orin / Snapdragon       │
├─────────────────────────────────────────────┤
│ Partition 1: ADAS (ASIL-D)                  │
│ - Decomposed to: ASIL-B(B) + ASIL-B(B)     │
│ - Dual-core lockstep execution              │
│ - E2E protection for inter-core comm        │
├─────────────────────────────────────────────┤
│ Partition 2: Instrument Cluster (ASIL-A)   │
│ - Warning lamps, speedometer                │
│ - Independent from ADAS partition           │
├─────────────────────────────────────────────┤
│ Partition 3: Infotainment (QM)              │
│ - No safety requirements                    │
│ - Resource limits enforced by hypervisor    │
└─────────────────────────────────────────────┘
```

### 2. ASIL-D Partitioning Strategy

**Hardware Partitioning:**
```cpp
// HPC Safety Partition Configuration
#include <iso26262/partition_manager.h>
#include <iso26262/ffi_validator.h>

namespace safety {
namespace hpc {

enum class ASILLevel {
    QM,   // Quality Management
    A,    // Lowest ASIL
    B,
    C,
    D     // Highest ASIL
};

struct SafetyPartition {
    std::string name;
    ASILLevel asil;
    std::vector<uint32_t> cpu_cores;
    uint64_t memory_base;
    uint64_t memory_size;
    std::vector<uint32_t> allowed_interrupts;
    bool mpu_enabled;
    bool ecc_enabled;
    bool lockstep_enabled;
};

class HPC_SafetyPartitionManager {
public:
    HPC_SafetyPartitionManager() {
        InitializePartitions();
        ValidateFFI();
    }

    void InitializePartitions() {
        // ASIL-D ADAS Partition (decomposed to 2x ASIL-B)
        SafetyPartition adas_partition_1 {
            .name = "ADAS-Perception-1",
            .asil = ASILLevel::B,
            .cpu_cores = {0, 1},  // Lockstep pair
            .memory_base = 0x8000'0000,
            .memory_size = 2ULL * 1024 * 1024 * 1024,  // 2GB
            .allowed_interrupts = {IRQ_CAN0, IRQ_CAMERA0, IRQ_LIDAR},
            .mpu_enabled = true,
            .ecc_enabled = true,
            .lockstep_enabled = true
        };

        SafetyPartition adas_partition_2 {
            .name = "ADAS-Perception-2",
            .asil = ASILLevel::B,
            .cpu_cores = {2, 3},  // Lockstep pair
            .memory_base = 0xC000'0000,
            .memory_size = 2ULL * 1024 * 1024 * 1024,  // 2GB
            .allowed_interrupts = {IRQ_CAN1, IRQ_CAMERA1, IRQ_RADAR},
            .mpu_enabled = true,
            .ecc_enabled = true,
            .lockstep_enabled = true
        };

        // Configure MPU for spatial isolation
        ConfigureMPU(adas_partition_1);
        ConfigureMPU(adas_partition_2);

        // Enable ECC for temporal fault detection
        EnableECC(adas_partition_1);
        EnableECC(adas_partition_2);

        // Configure lockstep cores for fault detection
        ConfigureLockstep(adas_partition_1);
        ConfigureLockstep(adas_partition_2);

        partitions_.push_back(adas_partition_1);
        partitions_.push_back(adas_partition_2);
    }

    void ConfigureMPU(const SafetyPartition& partition) {
        // MPU Configuration for ARM Cortex-A78
        // Region 0: Partition memory (RW, Executable)
        MPU_RegionConfig region_config {
            .base_address = partition.memory_base,
            .size = partition.memory_size,
            .access_permission = MPU_ACCESS_RW_NONE,  // No access from other cores
            .execute_never = false,
            .shareable = false,
            .cacheable = true
        };

        for (auto core : partition.cpu_cores) {
            SetMPURegion(core, 0, region_config);
        }

        // Region 1: Shared communication region (RW, Non-executable)
        MPU_RegionConfig shared_region {
            .base_address = 0xE000'0000,
            .size = 64 * 1024 * 1024,  // 64MB
            .access_permission = MPU_ACCESS_RW_RW,
            .execute_never = true,
            .shareable = true,
            .cacheable = false  // Uncached for inter-partition comm
        };

        for (auto core : partition.cpu_cores) {
            SetMPURegion(core, 1, shared_region);
        }
    }

    void EnableECC(const SafetyPartition& partition) {
        // Enable ECC on LPDDR5 memory for partition
        for (auto core : partition.cpu_cores) {
            // Enable ECC in memory controller
            WriteMemoryControllerReg(
                MEMORY_ECC_ENABLE_REG,
                partition.memory_base,
                partition.memory_size
            );

            // Register ECC error handler
            RegisterECCHandler(core, [partition](uint64_t error_addr) {
                HandleECCError(partition, error_addr);
            });
        }
    }

    void ConfigureLockstep(const SafetyPartition& partition) {
        if (!partition.lockstep_enabled || partition.cpu_cores.size() != 2) {
            return;
        }

        // Configure ARM Split-Lock mode (lockstep)
        uint32_t primary_core = partition.cpu_cores[0];
        uint32_t shadow_core = partition.cpu_cores[1];

        // Enable lockstep mode in SCU (Snoop Control Unit)
        EnableCoreLockstep(primary_core, shadow_core);

        // Configure lockstep comparator
        SetLockstepComparator(primary_core, shadow_core, [](uint32_t core_a, uint32_t core_b) {
            // Lockstep mismatch detected
            LOG_FATAL("Lockstep mismatch between core %d and %d", core_a, core_b);
            TriggerSafeState();
        });
    }

    void ValidateFFI() {
        FFI_Validator validator;

        // Validate spatial interference (memory)
        if (!validator.ValidateMemoryIsolation(partitions_)) {
            throw std::runtime_error("Memory isolation validation failed");
        }

        // Validate temporal interference (CPU time)
        if (!validator.ValidateTemporalIsolation(partitions_)) {
            throw std::runtime_error("Temporal isolation validation failed");
        }

        // Validate interrupt isolation
        if (!validator.ValidateInterruptIsolation(partitions_)) {
            throw std::runtime_error("Interrupt isolation validation failed");
        }

        LOG_INFO("FFI validation passed for all partitions");
    }

private:
    std::vector<SafetyPartition> partitions_;

    static void HandleECCError(const SafetyPartition& partition, uint64_t error_addr) {
        LOG_ERROR("ECC error in partition %s at address 0x%lx",
                  partition.name.c_str(), error_addr);

        // For ASIL-B/D: Trigger safe state
        if (partition.asil >= ASILLevel::B) {
            TriggerSafeState();
        }
    }

    static void TriggerSafeState() {
        // Transition vehicle to safe state
        // - Reduce speed
        // - Activate hazard lights
        // - Pull over
        LOG_FATAL("Entering safe state due to safety partition failure");
        // Implementation depends on vehicle platform
    }

    void SetMPURegion(uint32_t core, uint32_t region, const MPU_RegionConfig& config) {
        // Platform-specific MPU configuration
    }

    void EnableCoreLockstep(uint32_t core_a, uint32_t core_b) {
        // Platform-specific lockstep enable
    }

    void SetLockstepComparator(uint32_t core_a, uint32_t core_b, std::function<void(uint32_t, uint32_t)> handler) {
        // Platform-specific lockstep comparator
    }
};

} // namespace hpc
} // namespace safety
```

### 3. Freedom From Interference (FFI)

**FFI Requirements per ISO 26262-6 Clause 7:**

| Interference Type | Mechanism | ASIL-D Requirement |
|-------------------|-----------|-------------------|
| **Spatial (Memory)** | MPU/MMU | Hardware isolation |
| **Temporal (CPU Time)** | Time partitioning | Guaranteed time slots |
| **Communication** | E2E protection | CRC + alive counter |
| **Peripheral Access** | Access control list | Exclusive device ownership |
| **Interrupt** | Interrupt masking | Per-partition IRQ routing |

**End-to-End (E2E) Protection for Inter-Partition Communication:**
```cpp
// ISO 26262 E2E Profile for Inter-Partition Messages
#include <iso26262/e2e_protection.h>

namespace safety {
namespace e2e {

// E2E Profile 4 (used for AUTOSAR Adaptive)
struct E2E_Profile4_Header {
    uint16_t length;          // Message length
    uint16_t counter;         // Rolling counter (0-65535)
    uint32_t data_id;         // Unique message identifier
    uint32_t crc;             // CRC-32
} __attribute__((packed));

class E2E_Protector {
public:
    E2E_Protector(uint32_t data_id)
        : data_id_(data_id), counter_(0) {}

    // Protect outgoing message
    std::vector<uint8_t> Protect(const std::vector<uint8_t>& payload) {
        std::vector<uint8_t> protected_msg;

        // Construct header
        E2E_Profile4_Header header;
        header.length = static_cast<uint16_t>(payload.size());
        header.counter = counter_++;
        header.data_id = data_id_;

        // Compute CRC over header (excluding CRC field) + payload
        header.crc = ComputeCRC32(header, payload);

        // Serialize header + payload
        protected_msg.resize(sizeof(header) + payload.size());
        std::memcpy(protected_msg.data(), &header, sizeof(header));
        std::memcpy(protected_msg.data() + sizeof(header), payload.data(), payload.size());

        return protected_msg;
    }

    // Check incoming message
    E2E_CheckResult Check(const std::vector<uint8_t>& protected_msg) {
        if (protected_msg.size() < sizeof(E2E_Profile4_Header)) {
            return E2E_CheckResult::ERROR;
        }

        // Deserialize header
        E2E_Profile4_Header header;
        std::memcpy(&header, protected_msg.data(), sizeof(header));

        // Extract payload
        std::vector<uint8_t> payload(
            protected_msg.begin() + sizeof(header),
            protected_msg.end()
        );

        // Verify length
        if (header.length != payload.size()) {
            return E2E_CheckResult::ERROR;
        }

        // Verify CRC
        uint32_t expected_crc = header.crc;
        header.crc = 0;  // Clear CRC field before computation
        uint32_t computed_crc = ComputeCRC32(header, payload);

        if (expected_crc != computed_crc) {
            LOG_ERROR("E2E CRC mismatch: expected 0x%08x, got 0x%08x",
                     expected_crc, computed_crc);
            return E2E_CheckResult::ERROR;
        }

        // Verify counter (detect loss and duplication)
        E2E_CheckResult counter_result = CheckCounter(header.counter);
        if (counter_result != E2E_CheckResult::OK) {
            return counter_result;
        }

        last_valid_counter_ = header.counter;
        return E2E_CheckResult::OK;
    }

private:
    uint32_t data_id_;
    uint16_t counter_;
    uint16_t last_valid_counter_ = 0;

    E2E_CheckResult CheckCounter(uint16_t received_counter) {
        uint16_t expected_counter = (last_valid_counter_ + 1) % 65536;

        if (received_counter == expected_counter) {
            return E2E_CheckResult::OK;
        } else if (received_counter == last_valid_counter_) {
            return E2E_CheckResult::REPEATED;
        } else {
            LOG_WARN("E2E counter gap: expected %d, got %d",
                    expected_counter, received_counter);
            return E2E_CheckResult::WRONG_SEQUENCE;
        }
    }

    uint32_t ComputeCRC32(const E2E_Profile4_Header& header,
                         const std::vector<uint8_t>& payload) {
        // CRC-32/AUTOSAR polynomial: 0xF4ACFB13
        uint32_t crc = 0xFFFFFFFF;

        // CRC over header (excluding CRC field)
        const uint8_t* header_bytes = reinterpret_cast<const uint8_t*>(&header);
        for (size_t i = 0; i < offsetof(E2E_Profile4_Header, crc); ++i) {
            crc = UpdateCRC32(crc, header_bytes[i]);
        }

        // CRC over payload
        for (uint8_t byte : payload) {
            crc = UpdateCRC32(crc, byte);
        }

        return crc ^ 0xFFFFFFFF;
    }

    uint32_t UpdateCRC32(uint32_t crc, uint8_t byte) {
        // CRC-32 table lookup (AUTOSAR polynomial)
        static const uint32_t crc_table[256] = { /* ... */ };
        return (crc >> 8) ^ crc_table[(crc ^ byte) & 0xFF];
    }
};

enum class E2E_CheckResult {
    OK,
    ERROR,
    REPEATED,
    WRONG_SEQUENCE
};

} // namespace e2e
} // namespace safety
```

### 4. Safety Mechanisms for HPC

**Platform-Level Safety Mechanisms:**
```yaml
# ISO 26262 Safety Mechanisms for HPC
safety_mechanisms:
  hardware_level:
    - mechanism: "CPU Lockstep"
      target_fault: "Random hardware faults"
      diagnostic_coverage: 99%
      asil: D

    - mechanism: "ECC on LPDDR5"
      target_fault: "Single-bit memory errors"
      diagnostic_coverage: 99%
      asil: C

    - mechanism: "MPU/MMU Protection"
      target_fault: "Memory corruption"
      diagnostic_coverage: 99%
      asil: D

    - mechanism: "Watchdog Timer"
      target_fault: "Software hang"
      diagnostic_coverage: 90%
      asil: B

  software_level:
    - mechanism: "E2E Protection"
      target_fault: "Communication errors"
      diagnostic_coverage: 99%
      asil: D

    - mechanism: "Diverse Redundancy"
      target_fault: "Systematic software errors"
      diagnostic_coverage: 60%
      asil: C

    - mechanism: "Plausibility Checks"
      target_fault: "Sensor data corruption"
      diagnostic_coverage: 90%
      asil: B

    - mechanism: "Program Flow Monitoring"
      target_fault: "Control flow errors"
      diagnostic_coverage: 90%
      asil: C

  system_level:
    - mechanism: "ASIL Decomposition"
      target_fault: "Single point of failure"
      diagnostic_coverage: N/A
      asil: D

    - mechanism: "Safe State Transition"
      target_fault: "Detected failures"
      diagnostic_coverage: 99%
      asil: D
```

**Watchdog Supervision:**
```cpp
// Multi-level Watchdog for ASIL-D
#include <watchdog/supervisor.h>

namespace safety {
namespace watchdog {

class ASIL_D_WatchdogSupervisor {
public:
    ASIL_D_WatchdogSupervisor()
        : expected_alive_period_ms_(100),
          window_watchdog_min_ms_(80),
          window_watchdog_max_ms_(120) {

        InitializeHardwareWatchdog();
        InitializeSoftwareWatchdog();
    }

    // Application reports alive
    void ReportAlive(uint32_t partition_id) {
        auto now = std::chrono::steady_clock::now();

        // Check if alive report is within window
        auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(
            now - last_alive_[partition_id]
        ).count();

        if (elapsed < window_watchdog_min_ms_) {
            LOG_ERROR("Watchdog violation: Alive too early (partition %d)", partition_id);
            TriggerWatchdogReset(partition_id);
            return;
        }

        if (elapsed > window_watchdog_max_ms_) {
            LOG_ERROR("Watchdog violation: Alive too late (partition %d)", partition_id);
            TriggerWatchdogReset(partition_id);
            return;
        }

        // Refresh hardware watchdog
        RefreshHardwareWatchdog();

        // Update timestamp
        last_alive_[partition_id] = now;
    }

    void MonitorLoop() {
        while (running_) {
            auto now = std::chrono::steady_clock::now();

            // Check each partition
            for (const auto& [partition_id, last_alive] : last_alive_) {
                auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(
                    now - last_alive
                ).count();

                if (elapsed > window_watchdog_max_ms_) {
                    LOG_ERROR("Watchdog timeout: Partition %d not responding", partition_id);
                    TriggerWatchdogReset(partition_id);
                }
            }

            std::this_thread::sleep_for(std::chrono::milliseconds(10));
        }
    }

private:
    uint32_t expected_alive_period_ms_;
    uint32_t window_watchdog_min_ms_;
    uint32_t window_watchdog_max_ms_;
    std::map<uint32_t, std::chrono::steady_clock::time_point> last_alive_;
    bool running_ = true;

    void InitializeHardwareWatchdog() {
        // Configure external watchdog IC (e.g., TI TPS3840)
        // Timeout: 200ms
        ConfigureExternalWatchdog(200);
    }

    void InitializeSoftwareWatchdog() {
        // Start monitoring thread
        std::thread([this]() { MonitorLoop(); }).detach();
    }

    void RefreshHardwareWatchdog() {
        // Toggle watchdog input pin
        ToggleWatchdogPin();
    }

    void TriggerWatchdogReset(uint32_t partition_id) {
        LOG_FATAL("Triggering watchdog reset for partition %d", partition_id);

        // Option 1: Reset only the partition (if hypervisor supports it)
        ResetPartition(partition_id);

        // Option 2: Reset entire ECU (if ASIL-D requires it)
        // TriggerECUReset();
    }

    void ConfigureExternalWatchdog(uint32_t timeout_ms) {
        // Platform-specific
    }

    void ToggleWatchdogPin() {
        // Platform-specific
    }

    void ResetPartition(uint32_t partition_id) {
        // Platform-specific
    }
};

} // namespace watchdog
} // namespace safety
```

### 5. Safety Certification Process

**ISO 26262 V-Model for HPC:**
```
Development (Left side):          Verification (Right side):
┌──────────────────────────┐     ┌──────────────────────────┐
│ System Requirements      │────>│ System Integration Test  │
│ (ASIL-D ADAS)            │     │ (HIL, Vehicle)           │
└──────────────────────────┘     └──────────────────────────┘
        │                                   ▲
        ▼                                   │
┌──────────────────────────┐     ┌──────────────────────────┐
│ Software Architecture    │────>│ Software Integration Test│
│ (Partition Design)       │     │ (SIL, Test Bench)        │
└──────────────────────────┘     └──────────────────────────┘
        │                                   ▲
        ▼                                   │
┌──────────────────────────┐     ┌──────────────────────────┐
│ Software Detailed Design │────>│ Software Unit Test       │
│ (C++ Modules)            │     │ (GoogleTest, Coverage)   │
└──────────────────────────┘     └──────────────────────────┘
        │                                   ▲
        ▼                                   │
┌──────────────────────────┐              │
│ Implementation (Code)    │──────────────┘
└──────────────────────────┘
```

**Safety Case Artifacts:**
```python
#!/usr/bin/env python3
"""
Safety Case Evidence Generator for HPC Platform
Generates artifacts required for ISO 26262 certification
"""

from dataclasses import dataclass
from typing import List
from datetime import datetime

@dataclass
class SafetyRequirement:
    req_id: str
    description: str
    asil: str
    source: str  # ISO 26262 clause

@dataclass
class SafetyMechanism:
    mechanism_id: str
    name: str
    target_fault: str
    diagnostic_coverage: float
    verification_method: str

@dataclass
class TestCase:
    test_id: str
    requirement_id: str
    test_method: str  # Unit, Integration, System
    pass_criteria: str
    result: str  # PASS/FAIL
    evidence_path: str

class SafetyCaseGenerator:
    def __init__(self, project_name: str):
        self.project_name = project_name
        self.requirements: List[SafetyRequirement] = []
        self.mechanisms: List[SafetyMechanism] = []
        self.test_cases: List[TestCase] = []

    def add_requirement(self, req: SafetyRequirement):
        self.requirements.append(req)

    def add_safety_mechanism(self, mech: SafetyMechanism):
        self.mechanisms.append(mech)

    def add_test_case(self, test: TestCase):
        self.test_cases.append(test)

    def generate_safety_case(self, output_file: str):
        """Generate comprehensive safety case document"""
        with open(output_file, 'w') as f:
            f.write(f"# Safety Case for {self.project_name}\n\n")
            f.write(f"Generated: {datetime.now().isoformat()}\n\n")

            # Section 1: Safety Requirements
            f.write("## 1. Safety Requirements\n\n")
            f.write("| Req ID | Description | ASIL | Source |\n")
            f.write("|--------|-------------|------|--------|\n")
            for req in self.requirements:
                f.write(f"| {req.req_id} | {req.description} | {req.asil} | {req.source} |\n")

            # Section 2: Safety Mechanisms
            f.write("\n## 2. Safety Mechanisms\n\n")
            f.write("| Mechanism ID | Name | Target Fault | DC | Verification |\n")
            f.write("|--------------|------|--------------|----|--------------|\n")
            for mech in self.mechanisms:
                f.write(f"| {mech.mechanism_id} | {mech.name} | {mech.target_fault} | "
                       f"{mech.diagnostic_coverage*100:.0f}% | {mech.verification_method} |\n")

            # Section 3: Verification Results
            f.write("\n## 3. Verification Results\n\n")
            f.write("| Test ID | Requirement | Method | Pass Criteria | Result | Evidence |\n")
            f.write("|---------|-------------|--------|---------------|--------|----------|\n")
            for test in self.test_cases:
                f.write(f"| {test.test_id} | {test.requirement_id} | {test.test_method} | "
                       f"{test.pass_criteria} | {test.result} | {test.evidence_path} |\n")

            # Section 4: Traceability Matrix
            f.write("\n## 4. Requirements Traceability\n\n")
            self._generate_traceability_matrix(f)

            # Section 5: FMEA Results
            f.write("\n## 5. Failure Modes and Effects Analysis\n\n")
            self._generate_fmea_table(f)

    def _generate_traceability_matrix(self, f):
        f.write("| Requirement | Safety Mechanism | Test Cases | Coverage |\n")
        f.write("|-------------|------------------|------------|----------|\n")

        for req in self.requirements:
            # Find related mechanisms
            mechanisms = [m.mechanism_id for m in self.mechanisms]

            # Find related tests
            tests = [t.test_id for t in self.test_cases if t.requirement_id == req.req_id]

            coverage = f"{len(tests)} tests" if tests else "No coverage"
            f.write(f"| {req.req_id} | {', '.join(mechanisms[:2])} | "
                   f"{', '.join(tests[:3])} | {coverage} |\n")

    def _generate_fmea_table(self, f):
        f.write("| Failure Mode | Effect | Severity | Detection | Mitigation |\n")
        f.write("|--------------|--------|----------|-----------|------------|\n")
        f.write("| CPU core failure | Loss of ADAS | S3 | Lockstep | Redundant partition |\n")
        f.write("| Memory corruption | Data integrity | S3 | ECC | CRC checks |\n")
        f.write("| Hypervisor fault | System crash | S3 | Watchdog | Safe state |\n")

# Example usage
if __name__ == '__main__':
    generator = SafetyCaseGenerator("ADAS HPC Platform")

    # Add requirements
    generator.add_requirement(SafetyRequirement(
        req_id="SR-001",
        description="FFI between ASIL-D and QM partitions",
        asil="D",
        source="ISO 26262-6:7.4.2"
    ))

    generator.add_requirement(SafetyRequirement(
        req_id="SR-002",
        description="Diagnostic coverage >99% for hardware faults",
        asil="D",
        source="ISO 26262-5:8.4.3"
    ))

    # Add safety mechanisms
    generator.add_safety_mechanism(SafetyMechanism(
        mechanism_id="SM-001",
        name="CPU Lockstep",
        target_fault="Random hardware faults in CPU",
        diagnostic_coverage=0.99,
        verification_method="Fault injection testing"
    ))

    generator.add_safety_mechanism(SafetyMechanism(
        mechanism_id="SM-002",
        name="Memory ECC",
        target_fault="Single-bit memory errors",
        diagnostic_coverage=0.99,
        verification_method="ECC error injection"
    ))

    # Add test cases
    generator.add_test_case(TestCase(
        test_id="TC-001",
        requirement_id="SR-001",
        test_method="Integration Test",
        pass_criteria="No memory access violations detected",
        result="PASS",
        evidence_path="test_results/tc001_ffi_validation.log"
    ))

    # Generate safety case document
    generator.generate_safety_case("safety_case.md")
    print("Safety case generated: safety_case.md")
```

## Use Cases

1. **ASIL-D ADAS Platform Certification**: Certify perception/planning on HPC SoC
2. **Zonal Controller Safety**: Multi-ASIL partitioning for zone ECU
3. **OTA Update Safety**: Demonstrate safe software updates without re-certification
4. **Mixed-Criticality Cockpit**: ASIL-A cluster + QM IVI on single platform

## Automotive Standards

- **ISO 26262-6:2018**: Software development at the component level
- **ISO 26262-8:2018**: Supporting processes (safety analysis)
- **ISO 26262-9:2018**: ASIL-oriented and safety-oriented analyses
- **ISO 26262-11:2018**: Application of ISO 26262 to semiconductors

## Tools Required

- **medini analyze**: FMEA and FTA tool
- **LDRA**: Static analysis and unit test (TÜV certified)
- **Vector CANoe**: HIL testing with fault injection
- **QNX Safety Hypervisor**: Pre-certified hypervisor (ASIL-D)

## Performance Metrics

- **Diagnostic Coverage**: >99% for ASIL-D single-point faults
- **Fault Latency**: <10ms detection and reaction time
- **Safe State Transition**: <100ms from fault detection to safe state
- **MPU Overhead**: <1% CPU utilization

## References

- ISO 26262-6:2018 Software Development
- "Safety Certification for Multi-Core Automotive Systems" (SAE Paper 2020-01-0729)
- NVIDIA DRIVE OS Safety Manual
- QNX Hypervisor 2.2 Safety Manual (ISO 26262 ASIL-D)

---

**Version:** 1.0.0
**Last Updated:** 2026-03-19
**Author:** Automotive Claude Code Agents
