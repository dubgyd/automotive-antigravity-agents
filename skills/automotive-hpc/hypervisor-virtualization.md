# Hypervisor Virtualization for Automotive HPC

**Category:** automotive-hpc
**Version:** 1.0.0
**Maturity:** production
**Complexity:** advanced

## Overview

Expert knowledge in automotive hypervisor technologies for High-Performance Computing platforms. Covers QNX Hypervisor, ACRN, Xen, and other automotive-grade virtualization solutions for mixed-criticality systems, safety partitioning, and resource management.

## Core Competencies

### 1. Automotive Hypervisor Technologies

#### QNX Hypervisor 2.2
- Type 1 bare-metal hypervisor for safety-critical systems
- ASIL-D certified for ISO 26262 compliance
- Microkernel architecture with minimal TCB (Trusted Computing Base)
- Hardware virtualization using ARM VE or Intel VT-x/VT-d
- Real-time guarantee preservation across VMs

**QNX Hypervisor Configuration Example:**
```xml
<?xml version="1.0"?>
<system>
    <hypervisor>
        <name>qnx-hypervisor</name>
        <version>2.2</version>
        <scheduler type="partition">
            <major_frame>10ms</major_frame>
        </scheduler>
    </hypervisor>

    <!-- ASIL-D Safety VM for ADAS -->
    <guest id="0" name="safety-vm" asil="D">
        <os>qnx-710</os>
        <vcpus>2</vcpus>
        <memory>2GB</memory>
        <safety_partition>
            <interference_freedom>guaranteed</interference_freedom>
            <watchdog>enabled</watchdog>
            <memory_protection>mpu</memory_protection>
        </safety_partition>
        <schedule>
            <partition_window>6ms</partition_window>
            <priority>255</priority>
        </schedule>
        <devices>
            <pci bus="0" dev="2" func="0" /> <!-- CAN controller -->
            <interrupt line="45" />
        </devices>
    </guest>

    <!-- QM Non-Safety VM for Infotainment -->
    <guest id="1" name="infotainment-vm" asil="QM">
        <os>android-automotive-13</os>
        <vcpus>4</vcpus>
        <memory>4GB</memory>
        <schedule>
            <partition_window>4ms</partition_window>
            <priority>128</priority>
        </schedule>
        <gpu>
            <passthrough device="/dev/gpu0" />
            <sriov vf="1" />
        </gpu>
    </guest>
</system>
```

#### ACRN Hypervisor (Intel)
- Open-source Type 1 hypervisor optimized for IoT and automotive
- Safety VM (Service VM) + User VMs architecture
- Device Model for I/O virtualization
- ACRN-DM (Device Model) for para-virtualized devices
- Real-time VM support for safety workloads

**ACRN Launch Configuration:**
```python
# ACRN VM Launch Script - Safety VM
import sys
import acrn_vm

# Safety VM Configuration (ASIL-D)
safety_vm = acrn_vm.VM({
    'name': 'RTLinux-Safety',
    'vcpu_num': 2,
    'memory_size': '2G',
    'vm_type': 'RTVM',  # Real-time VM
    'lapic_passthrough': True,
    'ivshmem_regions': [
        {
            'name': 'sensor-data-region',
            'size': '64M',
            'shared_with': ['adas-vm', 'gateway-vm']
        }
    ],
    'cpu_affinity': [0, 1],  # Pin to cores 0-1
    'vpci_devices': [
        {'bus': 0, 'dev': 2, 'func': 0, 'type': 'CAN'}
    ],
    'boot_args': 'root=/dev/sda1 rw console=ttyS0 isolcpus=0,1'
})

# Configure virtio devices
safety_vm.add_virtio_net(
    tap_device='tap0',
    mac='52:54:00:12:34:56'
)

safety_vm.add_virtio_blk(
    image_path='/var/vms/safety-rootfs.img'
)

# Launch VM with real-time priority
safety_vm.launch(priority='rt', policy='FIFO')
```

#### Xen Hypervisor (ARM/x86)
- Type 1 hypervisor with strong isolation
- Dom0 (privileged domain) for device drivers
- DomU (unprivileged domains) for guest VMs
- PV (paravirtualization) and HVM (hardware virtual machine) modes
- IOMMU support for device assignment

**Xen VM Configuration (xl toolstack):**
```python
# Xen DomU Configuration - ADAS Processing VM
name = "adas-processing"
type = "hvm"
memory = 4096
vcpus = 4
cpus = "4-7"  # Pin to cores 4-7

# Boot configuration
kernel = "/boot/vmlinuz-rt"
ramdisk = "/boot/initrd.img-rt"
extra = "root=/dev/xvda1 console=hvc0 isolcpus=4-7"

# Virtual devices
disk = [
    'phy:/dev/vg_vms/adas-root,xvda1,w',
    'file:/var/vms/adas-data.img,xvdb,w'
]

vif = ['bridge=xenbr0,mac=00:16:3e:12:34:56']

# PCI passthrough for GPU
pci = ['0000:01:00.0']  # NVIDIA GPU

# IOMMU settings
iommu = 1
permissive = 0

# Virtual framebuffer for display
vfb = ['vnc=1,vnclisten=0.0.0.0']

# Security settings
on_poweroff = 'destroy'
on_reboot = 'restart'
on_crash = 'coredump-restart'
```

### 2. Mixed-Criticality System Design

**ASIL Decomposition and Isolation:**
```cpp
// C++14 - Safety Partition Manager
#include <hypervisor/partition.h>
#include <safety/asil.h>

namespace automotive {
namespace hpc {

class SafetyPartitionManager {
public:
    struct PartitionConfig {
        std::string name;
        ASIL asil_level;
        uint64_t memory_base;
        uint64_t memory_size;
        std::vector<uint32_t> cpu_affinity;
        uint32_t time_slice_us;
        bool interference_free;
    };

    SafetyPartitionManager() : major_frame_us_(10000) {}

    // Create isolated partition for specific ASIL level
    bool CreatePartition(const PartitionConfig& config) {
        // Validate ASIL requirements
        if (config.asil_level >= ASIL::D) {
            if (!ValidateFFI(config)) {
                LOG_ERROR("FFI validation failed for ASIL-D partition");
                return false;
            }
        }

        // Configure MPU/MMU for memory isolation
        if (!ConfigureMemoryProtection(config)) {
            return false;
        }

        // Setup temporal isolation (time partitioning)
        if (!ConfigureTimeSlice(config)) {
            return false;
        }

        // Register partition
        partitions_.push_back(config);
        return true;
    }

    // Freedom From Interference validation
    bool ValidateFFI(const PartitionConfig& config) {
        // Check memory interference
        for (const auto& existing : partitions_) {
            if (MemoryOverlap(config, existing)) {
                return false;
            }
        }

        // Check CPU affinity conflicts
        for (const auto& existing : partitions_) {
            if (CPUAffinityConflict(config, existing)) {
                return false;
            }
        }

        // Validate time budget doesn't exceed major frame
        uint64_t total_time = 0;
        for (const auto& p : partitions_) {
            total_time += p.time_slice_us;
        }
        if (total_time + config.time_slice_us > major_frame_us_) {
            return false;
        }

        return true;
    }

private:
    std::vector<PartitionConfig> partitions_;
    uint64_t major_frame_us_;

    bool ConfigureMemoryProtection(const PartitionConfig& config) {
        // Setup MPU regions for ARM or EPT for x86
        return hypervisor_api::SetMemoryRegion(
            config.memory_base,
            config.memory_size,
            MPU_ATTR_NO_ACCESS_FROM_OTHER_PARTITIONS
        );
    }

    bool ConfigureTimeSlice(const PartitionConfig& config) {
        return hypervisor_api::SetPartitionSchedule(
            config.name,
            config.time_slice_us,
            major_frame_us_,
            SCHEDULE_POLICY_STRICT_PARTITION
        );
    }

    bool MemoryOverlap(const PartitionConfig& a, const PartitionConfig& b) {
        uint64_t a_end = a.memory_base + a.memory_size;
        uint64_t b_end = b.memory_base + b.memory_size;
        return !(a_end <= b.memory_base || b_end <= a.memory_base);
    }

    bool CPUAffinityConflict(const PartitionConfig& a, const PartitionConfig& b) {
        for (auto cpu_a : a.cpu_affinity) {
            for (auto cpu_b : b.cpu_affinity) {
                if (cpu_a == cpu_b && a.asil_level >= ASIL::C && b.asil_level >= ASIL::C) {
                    return true;  // ASIL-C/D partitions cannot share CPUs
                }
            }
        }
        return false;
    }
};

} // namespace hpc
} // namespace automotive
```

### 3. Inter-VM Communication

**IVSHMEM (Inter-VM Shared Memory):**
```cpp
// High-performance zero-copy IPC using shared memory
#include <ivshmem/shared_region.h>
#include <atomic>
#include <cstring>

namespace automotive {
namespace ipc {

// Lock-free ring buffer for inter-VM sensor data
template<typename T, size_t Capacity>
class IVSHMEMRingBuffer {
public:
    explicit IVSHMEMRingBuffer(void* shmem_base)
        : region_(static_cast<SharedRegion*>(shmem_base)) {
        region_->write_idx.store(0, std::memory_order_release);
        region_->read_idx.store(0, std::memory_order_release);
    }

    // Producer: Write sensor data (from sensor VM to ADAS VM)
    bool Push(const T& item) {
        size_t current_write = region_->write_idx.load(std::memory_order_relaxed);
        size_t next_write = (current_write + 1) % Capacity;

        if (next_write == region_->read_idx.load(std::memory_order_acquire)) {
            return false;  // Buffer full
        }

        std::memcpy(&region_->buffer[current_write], &item, sizeof(T));
        region_->write_idx.store(next_write, std::memory_order_release);

        // Signal consumer VM via doorbell interrupt
        SignalDoorbell();
        return true;
    }

    // Consumer: Read sensor data
    bool Pop(T& item) {
        size_t current_read = region_->read_idx.load(std::memory_order_relaxed);

        if (current_read == region_->write_idx.load(std::memory_order_acquire)) {
            return false;  // Buffer empty
        }

        std::memcpy(&item, &region_->buffer[current_read], sizeof(T));
        size_t next_read = (current_read + 1) % Capacity;
        region_->read_idx.store(next_read, std::memory_order_release);
        return true;
    }

private:
    struct SharedRegion {
        std::atomic<size_t> write_idx;
        std::atomic<size_t> read_idx;
        alignas(64) T buffer[Capacity];
    };

    SharedRegion* region_;

    void SignalDoorbell() {
        // Write to doorbell register to trigger interrupt in consumer VM
        volatile uint32_t* doorbell = reinterpret_cast<uint32_t*>(0xFEDC0000);
        *doorbell = 1;
    }
};

// Usage example: Camera frame sharing
struct CameraFrame {
    uint64_t timestamp_us;
    uint32_t frame_id;
    uint32_t width;
    uint32_t height;
    uint8_t data[1920 * 1080 * 3];  // RGB888
};

// In Sensor VM (producer)
void SensorVMMain() {
    void* shmem = MapIVSHMEM("/dev/ivshmem0", 128 * 1024 * 1024);
    IVSHMEMRingBuffer<CameraFrame, 4> frame_queue(shmem);

    while (true) {
        CameraFrame frame = CaptureCamera();
        if (!frame_queue.Push(frame)) {
            LOG_WARN("Frame queue full, dropping frame");
        }
    }
}

// In ADAS VM (consumer)
void ADASVMMain() {
    void* shmem = MapIVSHMEM("/dev/ivshmem0", 128 * 1024 * 1024);
    IVSHMEMRingBuffer<CameraFrame, 4> frame_queue(shmem);

    CameraFrame frame;
    while (true) {
        if (frame_queue.Pop(frame)) {
            ProcessFrameForObjectDetection(frame);
        }
    }
}

} // namespace ipc
} // namespace automotive
```

### 4. Resource Management and Scheduling

**CPU Partitioning and Real-Time Scheduling:**
```python
#!/usr/bin/env python3
"""
HPC Platform Resource Manager
Manages CPU, memory, and I/O bandwidth across VMs
"""

import yaml
from dataclasses import dataclass
from typing import List, Dict
from enum import Enum

class VMType(Enum):
    SAFETY_CRITICAL = "safety_critical"  # ASIL-C/D
    PERFORMANCE = "performance"          # ADAS, autonomous
    GENERAL_PURPOSE = "general_purpose"  # Infotainment, telematics

@dataclass
class CPUAllocation:
    vm_name: str
    physical_cores: List[int]
    vcpu_count: int
    scheduler: str  # 'rt-fifo', 'rt-rr', 'cfs'
    priority: int
    cpu_quota_percent: float

@dataclass
class MemoryAllocation:
    vm_name: str
    size_gb: float
    numa_node: int
    hugepages: bool
    swap_disabled: bool

class HPCResourceManager:
    def __init__(self, platform_config: str):
        with open(platform_config, 'r') as f:
            self.config = yaml.safe_load(f)

        self.total_cores = self.config['platform']['cpu_cores']
        self.total_memory_gb = self.config['platform']['memory_gb']
        self.allocations: Dict[str, Dict] = {}

    def allocate_vm_resources(self, vm_name: str, vm_type: VMType,
                             cpu_cores: int, memory_gb: float):
        """Allocate resources following ASIL requirements"""

        if vm_type == VMType.SAFETY_CRITICAL:
            # ASIL-C/D VMs get dedicated cores
            cpu_alloc = self._allocate_dedicated_cores(vm_name, cpu_cores)
            mem_alloc = self._allocate_locked_memory(vm_name, memory_gb)
        elif vm_type == VMType.PERFORMANCE:
            # Performance VMs get isolated cores with high priority
            cpu_alloc = self._allocate_isolated_cores(vm_name, cpu_cores)
            mem_alloc = self._allocate_hugepages_memory(vm_name, memory_gb)
        else:
            # General purpose VMs share remaining cores
            cpu_alloc = self._allocate_shared_cores(vm_name, cpu_cores)
            mem_alloc = self._allocate_standard_memory(vm_name, memory_gb)

        self.allocations[vm_name] = {
            'type': vm_type,
            'cpu': cpu_alloc,
            'memory': mem_alloc
        }

        return cpu_alloc, mem_alloc

    def _allocate_dedicated_cores(self, vm_name: str, count: int) -> CPUAllocation:
        """Dedicated cores for safety-critical VMs (ASIL-D)"""
        # Allocate from first available cores
        available = self._find_available_cores(count, dedicated=True)

        return CPUAllocation(
            vm_name=vm_name,
            physical_cores=available,
            vcpu_count=count,
            scheduler='rt-fifo',
            priority=99,  # Highest RT priority
            cpu_quota_percent=100.0
        )

    def _allocate_isolated_cores(self, vm_name: str, count: int) -> CPUAllocation:
        """Isolated cores for performance VMs (ADAS)"""
        available = self._find_available_cores(count, dedicated=False)

        return CPUAllocation(
            vm_name=vm_name,
            physical_cores=available,
            vcpu_count=count,
            scheduler='rt-rr',
            priority=50,
            cpu_quota_percent=90.0
        )

    def _allocate_locked_memory(self, vm_name: str, size_gb: float) -> MemoryAllocation:
        """Locked, non-swappable memory for safety VMs"""
        return MemoryAllocation(
            vm_name=vm_name,
            size_gb=size_gb,
            numa_node=0,
            hugepages=True,
            swap_disabled=True
        )

    def generate_systemd_config(self, vm_name: str) -> str:
        """Generate systemd unit file with resource limits"""
        alloc = self.allocations[vm_name]
        cpu = alloc['cpu']
        mem = alloc['memory']

        cores_list = ','.join(map(str, cpu.physical_cores))

        config = f"""
[Unit]
Description={vm_name} Virtual Machine
After=hypervisor.service

[Service]
Type=simple
ExecStart=/usr/bin/qemu-system-x86_64 \\
    -name {vm_name} \\
    -cpu host \\
    -smp {cpu.vcpu_count} \\
    -m {int(mem.size_gb * 1024)}M \\
    -mem-path /dev/hugepages \\
    -mem-prealloc \\
    -rtc base=utc,clock=host \\
    -drive file=/var/vms/{vm_name}.qcow2,if=virtio \\
    -netdev tap,id=net0,ifname=tap-{vm_name},script=no \\
    -device virtio-net-pci,netdev=net0

# CPU affinity
CPUAffinity={cores_list}

# CPU quota ({cpu.cpu_quota_percent}% of allocated cores)
CPUQuota={cpu.cpu_quota_percent * cpu.vcpu_count}%

# Memory limits
MemoryLimit={int(mem.size_gb * 1024)}M
MemorySwapMax=0

# Real-time scheduling (if safety critical)
{"CPUSchedulingPolicy=fifo" if cpu.scheduler == 'rt-fifo' else ""}
{"CPUSchedulingPriority=" + str(cpu.priority) if cpu.scheduler.startswith('rt-') else ""}

# Security
PrivateTmp=yes
NoNewPrivileges=yes

[Install]
WantedBy=multi-user.target
"""
        return config

# Example usage
if __name__ == '__main__':
    manager = HPCResourceManager('platform_config.yaml')

    # Allocate ASIL-D ADAS VM
    cpu, mem = manager.allocate_vm_resources(
        'adas-safety',
        VMType.SAFETY_CRITICAL,
        cpu_cores=4,
        memory_gb=8.0
    )

    # Generate systemd service
    config = manager.generate_systemd_config('adas-safety')
    with open('/etc/systemd/system/vm-adas-safety.service', 'w') as f:
        f.write(config)

    print(f"Allocated cores {cpu.physical_cores} to ADAS VM")
    print(f"Memory: {mem.size_gb}GB, NUMA node: {mem.numa_node}")
```

## Use Cases

1. **Centralized ADAS Platform**: Run L3+ autonomous driving workloads in safety VMs alongside infotainment in QM VMs
2. **Gateway ECU Consolidation**: Combine multiple network domains (CAN, Ethernet, FlexRay) in isolated VMs
3. **Cockpit Domain Controller**: Instrument cluster, HMI, and Android Automotive on single SoC with GPU sharing
4. **OTA Update Isolation**: Separate update VM from running system for fail-safe updates

## Automotive Standards

- **ISO 26262**: ASIL-D certification for hypervisor TCB
- **ISO 21434**: Cybersecurity isolation between VMs
- **ASPICE CL3**: Process compliance for hypervisor development
- **AUTOSAR Adaptive**: Ara::exec for VM lifecycle management

## Tools Required

- **QNX Momentics IDE**: For QNX Hypervisor development
- **ACRN Configuration Tool**: Web-based hypervisor configurator
- **Xen Orchestra**: Management interface for Xen
- **libvirt/virsh**: VM lifecycle management
- **perf/ftrace**: Performance profiling and latency analysis

## Constraints

- **Real-time Latency**: <100µs interrupt latency for ASIL-D VMs
- **Memory Overhead**: <5% hypervisor overhead
- **FFI Guarantees**: ISO 26262 Part 6 clause 7 compliance
- **Deterministic Scheduling**: WCET guarantees for safety partitions

## Performance Metrics

- **VM Boot Time**: <500ms for safety VM cold boot
- **Context Switch**: <5µs VM-to-VM switch
- **Shared Memory Throughput**: >10GB/s IVSHMEM bandwidth
- **Interrupt Delivery**: <20µs doorbell latency

## References

- QNX Hypervisor 2.2 User Guide
- ACRN Hypervisor Documentation (projectacrn.org)
- Xen ARM Virtualization Extensions
- ISO 26262-6:2018 Clause 7 (Freedom from Interference)
- "Mixed-Criticality Systems on Multi-core" (WATERS 2019)

---

**Version:** 1.0.0
**Last Updated:** 2026-03-19
**Author:** Automotive Claude Code Agents
