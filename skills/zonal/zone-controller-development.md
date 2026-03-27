# Zone Controller Development

**Category:** automotive-zonal
**Version:** 1.0.0
**Maturity:** production
**Complexity:** advanced

## Overview

Expert knowledge in developing zone controller firmware and software for next-generation zonal E/E architectures. Covers hardware platforms (NXP S32K3, Renesas RH850, Infineon AURIX), I/O handling, sensor aggregation, actuator control, gateway functions, and AUTOSAR integration.

## Core Competencies

### 1. Zone Controller Hardware Platforms

#### NXP S32K3 (Entry to Mid-Range)

**S32K344 Specifications:**
```c
// NXP S32K344 - Low-cost zone controller
typedef struct {
    char model[32];
    struct {
        char core[16];          // ARM Cortex-M7
        uint32_t frequency_mhz; // 160 MHz
        uint8_t cores;          // 1
        bool lockstep;          // No (QM)
    } cpu;

    struct {
        uint32_t flash_kb;      // 4096 KB
        uint32_t ram_kb;        // 512 KB
        bool ecc;               // Optional
    } memory;

    struct {
        uint8_t can_fd;         // 6x CAN-FD
        uint8_t lin;            // 3x LIN
        uint8_t ethernet_100m;  // 1x 100BASE-T1
        uint8_t spi;            // 4x SPI
        uint8_t i2c;            // 2x I2C
    } communication;

    struct {
        uint8_t adc_12bit;      // 3x ADC (12-bit)
        uint8_t pwm_channels;   // 32x eMIOS PWM
        uint8_t gpio;           // 144 GPIO
    } io;

    uint8_t asil_rating;        // ASIL-B capable
    float cost_usd;             // $18-22
} S32K344_Spec_t;
```

**Use Cases:**
- Corner zones (FL, FR, RL, RR)
- Lighting control
- Window/mirror control
- Low-complexity body functions

#### Renesas RH850/U2A (Mid-Range)

**RH850/U2A8 Specifications:**
```c
// Renesas RH850/U2A8 - Standard zone controller
typedef struct {
    char model[32];
    struct {
        char core[16];          // RH850 G4MH
        uint32_t frequency_mhz; // 320 MHz
        uint8_t cores;          // 2 (lockstep option)
        bool lockstep;          // Yes (ASIL-D)
    } cpu;

    struct {
        uint32_t flash_kb;      // 8192 KB
        uint32_t ram_kb;        // 1024 KB
        bool ecc;               // Yes
    } memory;

    struct {
        uint8_t can_fd;         // 8x CAN-FD
        uint8_t lin;            // 8x LIN
        uint8_t ethernet_100m;  // 2x 100BASE-T1
        uint8_t flexray;        // 2x FlexRay
    } communication;

    struct {
        uint8_t adc_12bit;      // 4x ADC (12-bit)
        uint8_t pwm_channels;   // 48x PWM
        uint8_t gpio;           // 200+ GPIO
    } io;

    uint8_t asil_rating;        // ASIL-D
    float cost_usd;             // $28-35
} RH850_U2A8_Spec_t;
```

**Use Cases:**
- Front-center zone (HVAC, wipers)
- Rear-center zone (trunk, tailgate)
- Body domain consolidation
- HVAC control

#### Infineon AURIX TC397 (High-Performance)

**TC397 Specifications:**
```c
// Infineon AURIX TC397 - High-performance safety zone
typedef struct {
    char model[32];
    struct {
        char core[16];          // TriCore 1.8
        uint32_t frequency_mhz; // 300 MHz
        uint8_t cores;          // 3 lockstep pairs (6 total)
        bool lockstep;          // Yes (all cores)
    } cpu;

    struct {
        uint32_t flash_kb;      // 16384 KB
        uint32_t ram_kb;        // 1536 KB
        bool ecc;               // Yes (all memories)
    } memory;

    struct {
        uint8_t can_fd;         // 12x CAN-FD
        uint8_t lin;            // 4x LIN
        uint8_t ethernet_1g;    // 1x 1000BASE-T1
        uint8_t flexray;        // 2x FlexRay
    } communication;

    struct {
        uint8_t adc_12bit;      // 8x ADC (12-bit)
        uint8_t pwm_channels;   // 64x GTM PWM
        uint8_t gpio;           // 300+ GPIO
        bool hss_drivers;       // High-side switches
        bool lss_drivers;       // Low-side switches
    } io;

    uint8_t asil_rating;        // ASIL-D
    float cost_usd;             // $65-90
} TC397_Spec_t;
```

**Use Cases:**
- Gateway/central controller
- Safety-critical zones
- ADAS integration point
- Complex control algorithms

### 2. Zone Controller Firmware Architecture

```c
// Zone Controller Application Structure
typedef struct {
    char zone_id[16];           // "FL_ZONE", "FR_ZONE", etc.
    uint8_t hardware_platform;  // S32K3, RH850, AURIX
    uint8_t asil_rating;        // QM, ASIL-A/B/C/D

    // I/O Configuration
    struct {
        uint8_t num_digital_inputs;
        uint8_t num_digital_outputs;
        uint8_t num_analog_inputs;
        uint8_t num_pwm_outputs;
        uint8_t num_lin_slaves;
    } io_config;

    // Communication
    struct {
        bool ethernet_enabled;
        uint8_t can_channels;
        uint8_t lin_channels;
        uint16_t someip_port;
    } comm_config;

    // Functions
    void (*init)(void);
    void (*cyclic_10ms)(void);
    void (*cyclic_100ms)(void);
    void (*handle_ethernet_rx)(uint8_t* data, uint16_t len);
    void (*handle_lin_frame)(uint8_t node, uint8_t* data);
} ZoneController_t;

// Example: Front-Left Zone Controller
ZoneController_t fl_zone = {
    .zone_id = "FL_ZONE",
    .hardware_platform = HW_S32K344,
    .asil_rating = ASIL_B,

    .io_config = {
        .num_digital_inputs = 20,   // Door switches, buttons
        .num_digital_outputs = 12,  // Relays, LEDs
        .num_analog_inputs = 4,     // Temperature sensors
        .num_pwm_outputs = 8,       // Headlight dimming, motor control
        .num_lin_slaves = 4         // Window motor, mirror motors
    },

    .comm_config = {
        .ethernet_enabled = true,
        .can_channels = 2,          // CAN1: vehicle bus, CAN2: diagnostics
        .lin_channels = 2,          // LIN1: windows, LIN2: mirrors
        .someip_port = 30500
    },

    .init = FL_Zone_Init,
    .cyclic_10ms = FL_Zone_Cyclic10ms,
    .cyclic_100ms = FL_Zone_Cyclic100ms,
    .handle_ethernet_rx = FL_Zone_EthernetRx,
    .handle_lin_frame = FL_Zone_LinRx
};
```

### 3. Sensor Aggregation

```c
// Sensor Aggregation for Zone Controller
typedef struct {
    uint32_t timestamp_ms;
    float value;
    uint8_t quality;  // 0=Invalid, 1=Questionable, 2=Good, 3=Excellent
    uint8_t source;   // Sensor ID
} SensorValue_t;

typedef struct {
    char sensor_name[32];
    uint8_t num_sources;        // Number of redundant sensors
    SensorValue_t values[4];    // Up to 4 redundant sources
    float fused_value;          // Fused result
    uint8_t fusion_algorithm;   // AVERAGE, MEDIAN, VOTER, KALMAN
} SensorAggregator_t;

// Sensor fusion algorithms
float sensor_fusion_average(SensorAggregator_t* agg) {
    float sum = 0.0;
    uint8_t count = 0;

    for (uint8_t i = 0; i < agg->num_sources; i++) {
        if (agg->values[i].quality >= 2) {  // Good or Excellent
            sum += agg->values[i].value;
            count++;
        }
    }

    return (count > 0) ? (sum / count) : 0.0;
}

float sensor_fusion_median(SensorAggregator_t* agg) {
    float sorted[4];
    uint8_t count = 0;

    // Copy valid values
    for (uint8_t i = 0; i < agg->num_sources; i++) {
        if (agg->values[i].quality >= 2) {
            sorted[count++] = agg->values[i].value;
        }
    }

    if (count == 0) return 0.0;

    // Bubble sort
    for (uint8_t i = 0; i < count - 1; i++) {
        for (uint8_t j = 0; j < count - i - 1; j++) {
            if (sorted[j] > sorted[j + 1]) {
                float temp = sorted[j];
                sorted[j] = sorted[j + 1];
                sorted[j + 1] = temp;
            }
        }
    }

    // Return median
    if (count % 2 == 0) {
        return (sorted[count / 2 - 1] + sorted[count / 2]) / 2.0;
    } else {
        return sorted[count / 2];
    }
}

// 2-out-of-3 voter
float sensor_fusion_voter(SensorAggregator_t* agg) {
    if (agg->num_sources < 2) return agg->values[0].value;

    // Check if any two sensors agree within tolerance
    const float tolerance = 0.05;  // 5% tolerance

    for (uint8_t i = 0; i < agg->num_sources - 1; i++) {
        for (uint8_t j = i + 1; j < agg->num_sources; j++) {
            float diff = fabs(agg->values[i].value - agg->values[j].value);
            float avg = (agg->values[i].value + agg->values[j].value) / 2.0;

            if (diff / avg < tolerance) {
                return avg;  // Two sensors agree
            }
        }
    }

    // No agreement - use sensor with best quality
    uint8_t best_idx = 0;
    for (uint8_t i = 1; i < agg->num_sources; i++) {
        if (agg->values[i].quality > agg->values[best_idx].quality) {
            best_idx = i;
        }
    }

    return agg->values[best_idx].value;
}

// Example: Temperature sensor aggregation
SensorAggregator_t temp_sensor = {
    .sensor_name = "AmbientTemperature",
    .num_sources = 3,
    .values = {
        {.timestamp_ms = 1000, .value = 23.5, .quality = 3, .source = 1},
        {.timestamp_ms = 1000, .value = 23.7, .quality = 3, .source = 2},
        {.timestamp_ms = 1000, .value = 23.6, .quality = 2, .source = 3}
    },
    .fusion_algorithm = FUSION_MEDIAN
};

// Perform fusion
temp_sensor.fused_value = sensor_fusion_median(&temp_sensor);
// Result: 23.6°C
```

### 4. Actuator Control

```c
// PWM-based actuator control (e.g., headlight dimming)
typedef struct {
    char actuator_name[32];
    uint8_t pwm_channel;
    uint16_t frequency_hz;      // PWM frequency
    uint8_t duty_cycle;         // 0-100%
    bool enabled;
} PWM_Actuator_t;

void set_headlight_brightness(PWM_Actuator_t* headlight, uint8_t brightness_pct) {
    // Limit to valid range
    if (brightness_pct > 100) brightness_pct = 100;

    headlight->duty_cycle = brightness_pct;

    // Update hardware PWM register (example for S32K3)
    eMIOS_SetDutyCycle(headlight->pwm_channel, brightness_pct);
}

// LIN-based actuator control (e.g., window motor)
typedef struct {
    uint8_t lin_channel;
    uint8_t node_address;
    enum {
        WINDOW_STOP = 0,
        WINDOW_UP = 1,
        WINDOW_DOWN = 2
    } command;
    uint8_t position_pct;       // 0=closed, 100=fully open
} LIN_WindowMotor_t;

void control_window(LIN_WindowMotor_t* window, uint8_t target_position) {
    uint8_t lin_frame[8];

    // Build LIN frame
    lin_frame[0] = window->node_address;
    lin_frame[1] = (target_position > window->position_pct) ? WINDOW_UP : WINDOW_DOWN;
    lin_frame[2] = target_position;

    // Send LIN frame
    LIN_SendFrame(window->lin_channel, lin_frame, 3);

    // Update state
    window->position_pct = target_position;
}
```

### 5. Gateway Functions

```c
// Gateway functionality (message routing, filtering, security)
typedef struct {
    uint8_t src_network;    // CAN, LIN, Ethernet
    uint8_t dst_network;
    uint32_t msg_id;        // CAN ID or SOME/IP service ID
    bool translate;         // Needs translation (CAN<->Ethernet)
    bool secure;            // Requires MACsec/authentication
} GatewayRoute_t;

// Routing table
GatewayRoute_t routing_table[] = {
    // CAN → Ethernet
    {.src_network = NET_CAN1, .dst_network = NET_ETH, .msg_id = 0x123, .translate = true, .secure = false},
    // Ethernet → CAN
    {.src_network = NET_ETH, .dst_network = NET_CAN2, .msg_id = 0x12340001, .translate = true, .secure = true},
    // LIN → Ethernet
    {.src_network = NET_LIN1, .dst_network = NET_ETH, .msg_id = 0x3C, .translate = true, .secure = false}
};

void gateway_route_message(uint8_t src_net, uint32_t msg_id, uint8_t* data, uint16_t len) {
    // Find routing rule
    for (uint8_t i = 0; i < sizeof(routing_table) / sizeof(GatewayRoute_t); i++) {
        if (routing_table[i].src_network == src_net &&
            routing_table[i].msg_id == msg_id) {

            if (routing_table[i].translate) {
                // Translate message format
                if (src_net == NET_CAN1 && routing_table[i].dst_network == NET_ETH) {
                    translate_can_to_someip(msg_id, data, len);
                } else if (src_net == NET_ETH && routing_table[i].dst_network == NET_CAN1) {
                    translate_someip_to_can(msg_id, data, len);
                }
            }

            if (routing_table[i].secure) {
                // Apply security (MACsec, authentication)
                apply_security(data, len);
            }

            // Forward to destination network
            forward_message(routing_table[i].dst_network, data, len);
            break;
        }
    }
}
```

### 6. AUTOSAR Integration

```c
// AUTOSAR Classic BSW configuration for zone controller
// RTE (Runtime Environment) configuration

// Sender-Receiver Interface
Rte_Write_HeadlightBrightness(uint8_t brightness) {
    // Implemented by RTE generator
    // Routes to SOME/IP or CAN
}

Rte_Read_DoorStatus(boolean* isOpen) {
    // Read from sensor via RTE
    *isOpen = gpio_read(DOOR_SWITCH_PIN);
    return RTE_E_OK;
}

// Cyclic runnable (10ms task)
void Zone_Controller_10ms_Runnable(void) {
    boolean door_open;
    uint8_t brightness;

    // Read inputs
    Rte_Read_DoorStatus(&door_open);

    // Control logic
    if (door_open) {
        brightness = 100;  // Full brightness when door open
    } else {
        brightness = get_adaptive_brightness();  // Adaptive based on ambient light
    }

    // Write outputs
    Rte_Write_HeadlightBrightness(brightness);
}
```

## Performance Targets

| Function | Cycle Time | CPU Load | Memory |
|----------|-----------|----------|--------|
| I/O scan | 10 ms | <5% | 10 KB |
| Sensor aggregation | 100 ms | <10% | 20 KB |
| Gateway routing | <1 ms | <15% | 50 KB |
| SOME/IP handling | Event-driven | <20% | 100 KB |
| Safety monitoring | 10 ms | <10% | 30 KB |

## Tools & Development Environment

- **NXP S32 Design Studio** - IDE for S32K3 development
- **Renesas CS+ / e² studio** - IDE for RH850 development
- **Infineon AURIX Development Studio** - IDE for TC397
- **Vector DaVinci Configurator** - AUTOSAR BSW configuration
- **EB tresos Studio** - AUTOSAR configuration (Elektrobit)
- **PCAN-View** - CAN/LIN debugging
- **Wireshark** - Ethernet debugging

## References

- NXP S32K3 Reference Manual
- Renesas RH850/U2A User's Manual
- Infineon AURIX TC3xx User Manual
- AUTOSAR Adaptive Platform R22-11
- LIN Specification 2.2A
