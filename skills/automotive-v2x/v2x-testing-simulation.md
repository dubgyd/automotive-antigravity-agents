# V2X Testing and Simulation

## Overview
Comprehensive V2X testing methodologies including CARLA, SUMO, NS-3 simulation environments, RF chamber testing, field trials, message validation, interoperability testing, and conformance test suites.

## Simulation Tool Comparison

| Tool | Domain | Strengths | Integration | License |
|------|--------|-----------|-------------|---------|
| CARLA | 3D vehicle & sensor sim | Realistic sensors, Unreal Engine graphics | Python/C++ API, ROS | MIT |
| SUMO | Traffic simulation | Large-scale traffic patterns, fast | Python TraCI API | EPL-2.0 |
| NS-3 | Network simulation | Detailed protocol modeling, validated models | C++, Python bindings | GPL |
| OMNeT++ | Discrete event sim | Modular, extensive libraries | C++, Veins for V2X | Academic free |
| VTD | Professional driving sim | Industry-grade, HIL ready | Commercial APIs | Commercial |

## CARLA V2X Integration

### CARLA Setup for V2X Testing

```python
# carla_v2x_test.py
"""
CARLA-based V2X scenario testing.
Simulates BSM broadcast, FCW, and EEBL scenarios.
"""

import carla
import time
import math
import random
from typing import List, Dict, Tuple

class V2XMessage:
    """Base V2X message."""
    def __init__(self, sender_id: int, timestamp: float):
        self.sender_id = sender_id
        self.timestamp = timestamp

class BSM(V2XMessage):
    """Basic Safety Message."""
    def __init__(self, sender_id: int, timestamp: float,
                 lat: float, lon: float, speed: float, heading: float,
                 accel_long: float, accel_lat: float):
        super().__init__(sender_id, timestamp)
        self.latitude = lat
        self.longitude = lon
        self.speed_mps = speed
        self.heading_deg = heading
        self.accel_long_mps2 = accel_long
        self.accel_lat_mps2 = accel_lat

class V2XVehicle:
    """Vehicle with V2X OBU in CARLA."""

    def __init__(self, carla_vehicle: carla.Vehicle, vehicle_id: int):
        self.vehicle = carla_vehicle
        self.id = vehicle_id
        self.message_history: List[BSM] = []
        self.received_messages: List[BSM] = []

        # V2X parameters
        self.transmission_range_m = 300.0
        self.message_rate_hz = 10.0
        self.last_transmission_time = 0.0

    def generate_bsm(self) -> BSM:
        """Generate BSM from current vehicle state."""
        transform = self.vehicle.get_transform()
        velocity = self.vehicle.get_velocity()
        accel = self.vehicle.get_acceleration()

        # Calculate speed
        speed = math.sqrt(velocity.x**2 + velocity.y**2 + velocity.z**2)

        # Calculate heading (yaw in degrees)
        heading = transform.rotation.yaw

        bsm = BSM(
            sender_id=self.id,
            timestamp=time.time(),
            lat=transform.location.x,
            lon=transform.location.y,
            speed=speed,
            heading=heading,
            accel_long=accel.x,
            accel_lat=accel.y
        )

        self.message_history.append(bsm)
        return bsm

    def should_transmit_bsm(self, current_time: float) -> bool:
        """Check if BSM should be transmitted based on message rate."""
        interval = 1.0 / self.message_rate_hz
        if current_time - self.last_transmission_time >= interval:
            self.last_transmission_time = current_time
            return True
        return False

    def receive_bsm(self, bsm: BSM, sender_position: Tuple[float, float]):
        """Receive BSM from another vehicle if in range."""
        my_pos = self.vehicle.get_transform().location
        distance = math.sqrt(
            (my_pos.x - sender_position[0])**2 +
            (my_pos.y - sender_position[1])**2
        )

        if distance <= self.transmission_range_m:
            self.received_messages.append(bsm)
            return True
        return False

class V2XTestScenario:
    """CARLA V2X test scenario framework."""

    def __init__(self, host='localhost', port=2000):
        self.client = carla.Client(host, port)
        self.client.set_timeout(10.0)
        self.world = self.client.get_world()
        self.blueprint_library = self.world.get_blueprint_library()

        self.vehicles: List[V2XVehicle] = []
        self.test_results = {
            'messages_sent': 0,
            'messages_received': 0,
            'packet_loss_rate': 0.0,
            'average_latency_ms': 0.0,
            'collision_warnings': 0
        }

    def spawn_v2x_vehicle(self, vehicle_type: str = 'vehicle.tesla.model3',
                         spawn_point: carla.Transform = None) -> V2XVehicle:
        """Spawn a vehicle with V2X capability."""
        if spawn_point is None:
            spawn_points = self.world.get_map().get_spawn_points()
            spawn_point = random.choice(spawn_points)

        blueprint = self.blueprint_library.filter(vehicle_type)[0]
        actor = self.world.spawn_actor(blueprint, spawn_point)

        # Enable autopilot
        actor.set_autopilot(True)

        v2x_vehicle = V2XVehicle(actor, len(self.vehicles))
        self.vehicles.append(v2x_vehicle)

        print(f"Spawned V2X vehicle {v2x_vehicle.id} at {spawn_point.location}")
        return v2x_vehicle

    def test_bsm_broadcast(self, duration_s: int = 60):
        """
        Test BSM broadcast functionality.

        Metrics:
        - Message delivery ratio
        - Latency distribution
        - Range verification
        """
        print(f"\n=== BSM Broadcast Test ({duration_s}s) ===")

        start_time = time.time()
        sent_messages = {}  # {msg_id: (timestamp, sender_id)}
        received_messages = {}  # {msg_id: [(receiver_id, timestamp)]}

        msg_id_counter = 0

        while time.time() - start_time < duration_s:
            current_time = time.time()

            # Each vehicle transmits BSM
            for sender in self.vehicles:
                if sender.should_transmit_bsm(current_time):
                    bsm = sender.generate_bsm()
                    msg_id = f"{sender.id}_{msg_id_counter}"
                    sent_messages[msg_id] = (current_time, sender.id)
                    msg_id_counter += 1

                    self.test_results['messages_sent'] += 1

                    # Broadcast to other vehicles in range
                    sender_pos = (bsm.latitude, bsm.longitude)
                    for receiver in self.vehicles:
                        if receiver.id != sender.id:
                            if receiver.receive_bsm(bsm, sender_pos):
                                self.test_results['messages_received'] += 1

                                if msg_id not in received_messages:
                                    received_messages[msg_id] = []
                                received_messages[msg_id].append((receiver.id, current_time))

            time.sleep(0.01)  # 10ms tick

        # Calculate metrics
        total_expected_receptions = 0
        total_actual_receptions = 0

        for msg_id, (send_time, sender_id) in sent_messages.items():
            # Expected: all vehicles except sender
            expected = len(self.vehicles) - 1
            total_expected_receptions += expected

            if msg_id in received_messages:
                actual = len(received_messages[msg_id])
                total_actual_receptions += actual

        if total_expected_receptions > 0:
            delivery_ratio = total_actual_receptions / total_expected_receptions
        else:
            delivery_ratio = 0.0

        packet_loss = 1.0 - delivery_ratio

        print(f"\nBSM Test Results:")
        print(f"  Messages sent: {self.test_results['messages_sent']}")
        print(f"  Expected receptions: {total_expected_receptions}")
        print(f"  Actual receptions: {total_actual_receptions}")
        print(f"  Delivery ratio: {delivery_ratio*100:.2f}%")
        print(f"  Packet loss rate: {packet_loss*100:.2f}%")

        self.test_results['packet_loss_rate'] = packet_loss

    def test_fcw_scenario(self):
        """
        Test Forward Collision Warning scenario.

        Scenario: Lead vehicle suddenly brakes, following vehicle receives warning.
        """
        print("\n=== FCW Scenario Test ===")

        # Spawn lead vehicle
        spawn_points = self.world.get_map().get_spawn_points()
        lead_spawn = spawn_points[0]
        lead = self.spawn_v2x_vehicle('vehicle.tesla.model3', lead_spawn)

        # Spawn following vehicle 30m behind
        following_spawn = carla.Transform(
            location=carla.Location(
                x=lead_spawn.location.x - 30,
                y=lead_spawn.location.y,
                z=lead_spawn.location.z
            ),
            rotation=lead_spawn.rotation
        )
        following = self.spawn_v2x_vehicle('vehicle.audi.a2', following_spawn)

        # Run scenario
        for i in range(100):  # 10 seconds at 10 Hz
            current_time = time.time()

            # Generate and broadcast BSMs
            lead_bsm = lead.generate_bsm()
            following_bsm = following.generate_bsm()

            # Simulate reception
            following.receive_bsm(lead_bsm, (lead_bsm.latitude, lead_bsm.longitude))
            lead.receive_bsm(following_bsm, (following_bsm.latitude, following_bsm.longitude))

            # Calculate relative parameters
            distance = math.sqrt(
                (lead_bsm.latitude - following_bsm.latitude)**2 +
                (lead_bsm.longitude - following_bsm.longitude)**2
            )

            relative_speed = following_bsm.speed_mps - lead_bsm.speed_mps

            # FCW logic
            if relative_speed > 0 and distance > 0:
                ttc = distance / relative_speed

                if ttc < 2.5:
                    print(f"[{i/10:.1f}s] FCW WARNING! TTC={ttc:.2f}s, Distance={distance:.1f}m, "
                          f"RelSpeed={relative_speed:.1f}m/s")
                    self.test_results['collision_warnings'] += 1

            # Emergency brake at t=5s
            if i == 50:
                print(f"[5.0s] Lead vehicle emergency braking!")
                lead.vehicle.apply_control(carla.VehicleControl(brake=1.0))

            time.sleep(0.1)

        print(f"\nFCW Test Results:")
        print(f"  Collision warnings issued: {self.test_results['collision_warnings']}")

    def cleanup(self):
        """Clean up spawned vehicles."""
        for v2x_vehicle in self.vehicles:
            v2x_vehicle.vehicle.destroy()
        self.vehicles.clear()
        print("\nCleaned up all vehicles")


# Example test execution
if __name__ == "__main__":
    try:
        # Initialize test scenario
        test = V2XTestScenario(host='localhost', port=2000)

        # Spawn test vehicles
        for i in range(5):
            test.spawn_v2x_vehicle()

        # Run BSM broadcast test
        test.test_bsm_broadcast(duration_s=30)

        # Run FCW scenario test
        test.cleanup()  # Clean previous vehicles
        test.test_fcw_scenario()

    except KeyboardInterrupt:
        print("\nTest interrupted by user")
    finally:
        test.cleanup()
```

## SUMO Integration for Traffic Simulation

```python
# sumo_v2x_integration.py
"""
SUMO traffic simulation with V2X message exchange.
"""

import traci
import sumolib
import time
from typing import Dict, List

class SUMOV2XSimulation:
    """SUMO simulation with V2X communication."""

    def __init__(self, sumo_cfg_file: str):
        self.sumo_cfg = sumo_cfg_file
        self.vehicle_states: Dict[str, dict] = {}

    def start_simulation(self, gui: bool = False):
        """Start SUMO simulation."""
        sumo_binary = "sumo-gui" if gui else "sumo"
        sumo_cmd = [sumo_binary, "-c", self.sumo_cfg]
        traci.start(sumo_cmd)

    def run_v2x_simulation(self, steps: int = 1000):
        """Run SUMO simulation with V2X message exchange."""
        for step in range(steps):
            traci.simulationStep()

            # Get all vehicle IDs
            vehicle_ids = traci.vehicle.getIDList()

            # Generate BSM for each vehicle
            for veh_id in vehicle_ids:
                position = traci.vehicle.getPosition(veh_id)
                speed = traci.vehicle.getSpeed(veh_id)
                angle = traci.vehicle.getAngle(veh_id)
                accel = traci.vehicle.getAcceleration(veh_id)

                bsm = {
                    'vehicle_id': veh_id,
                    'x': position[0],
                    'y': position[1],
                    'speed': speed,
                    'heading': angle,
                    'accel': accel,
                    'step': step
                }

                self.vehicle_states[veh_id] = bsm

                # V2V communication simulation
                self.process_v2v_messages(veh_id, bsm)

            time.sleep(0.1)  # Real-time factor

        traci.close()

    def process_v2v_messages(self, veh_id: str, bsm: dict):
        """Process V2V messages for vehicle."""
        # Find vehicles in communication range (300m)
        comm_range = 300.0

        for other_id, other_bsm in self.vehicle_states.items():
            if other_id == veh_id:
                continue

            distance = ((bsm['x'] - other_bsm['x'])**2 +
                       (bsm['y'] - other_bsm['y'])**2)**0.5

            if distance <= comm_range:
                # Vehicles can communicate
                # Check for FCW condition
                rel_speed = bsm['speed'] - other_bsm['speed']
                if rel_speed > 0 and distance < 50:
                    ttc = distance / rel_speed if rel_speed > 0.1 else 999
                    if ttc < 3.0:
                        print(f"Step {bsm['step']}: FCW for {veh_id}, "
                              f"TTC={ttc:.2f}s to {other_id}")


# Example SUMO configuration file (save as v2x_test.sumocfg)
SUMO_CONFIG = """<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <input>
        <net-file value="network.net.xml"/>
        <route-files value="routes.rou.xml"/>
    </input>
    <time>
        <begin value="0"/>
        <end value="1000"/>
    </time>
</configuration>
"""
```

## NS-3 Network Simulation

### NS-3 V2X Module

```cpp
// ns3_v2x_scenario.cc
/**
 * NS-3 V2X communication scenario.
 * Simulates DSRC/802.11p communication with channel model.
 */

#include "ns3/core-module.h"
#include "ns3/network-module.h"
#include "ns3/mobility-module.h"
#include "ns3/wifi-module.h"
#include "ns3/wave-module.h"
#include "ns3/internet-module.h"

using namespace ns3;

NS_LOG_COMPONENT_DEFINE("V2XScenario");

class V2XApplication : public Application {
public:
    V2XApplication();
    virtual ~V2XApplication();

    void Setup(Ptr<Socket> socket, uint32_t packetSize, uint32_t nPackets,
               DataRate dataRate);

private:
    virtual void StartApplication(void);
    virtual void StopApplication(void);

    void ScheduleTransmit(Time dt);
    void SendPacket(void);

    Ptr<Socket> m_socket;
    uint32_t m_packetSize;
    uint32_t m_nPackets;
    DataRate m_dataRate;
    EventId m_sendEvent;
    bool m_running;
    uint32_t m_packetsSent;
};

V2XApplication::V2XApplication()
    : m_socket(0),
      m_packetSize(0),
      m_nPackets(0),
      m_dataRate(0),
      m_running(false),
      m_packetsSent(0) {}

V2XApplication::~V2XApplication() {
    m_socket = 0;
}

void V2XApplication::Setup(Ptr<Socket> socket, uint32_t packetSize,
                          uint32_t nPackets, DataRate dataRate) {
    m_socket = socket;
    m_packetSize = packetSize;
    m_nPackets = nPackets;
    m_dataRate = dataRate;
}

void V2XApplication::StartApplication(void) {
    m_running = true;
    m_packetsSent = 0;
    m_socket->Bind();
    m_socket->Connect(InetSocketAddress(Ipv4Address("255.255.255.255"), 80));
    SendPacket();
}

void V2XApplication::StopApplication(void) {
    m_running = false;
    if (m_sendEvent.IsRunning()) {
        Simulator::Cancel(m_sendEvent);
    }
    if (m_socket) {
        m_socket->Close();
    }
}

void V2XApplication::SendPacket(void) {
    Ptr<Packet> packet = Create<Packet>(m_packetSize);
    m_socket->Send(packet);

    NS_LOG_INFO("Sent packet " << m_packetsSent << " at time "
                << Simulator::Now().GetSeconds());

    if (++m_packetsSent < m_nPackets) {
        ScheduleTransmit(Seconds(m_packetSize * 8 /
                        static_cast<double>(m_dataRate.GetBitRate())));
    }
}

void V2XApplication::ScheduleTransmit(Time dt) {
    if (m_running) {
        m_sendEvent = Simulator::Schedule(dt, &V2XApplication::SendPacket, this);
    }
}

// Main simulation
int main(int argc, char *argv[]) {
    uint32_t nVehicles = 10;
    double simTime = 100.0;  // seconds
    double distance = 300.0;  // meters

    CommandLine cmd;
    cmd.AddValue("nVehicles", "Number of vehicles", nVehicles);
    cmd.AddValue("simTime", "Simulation time", simTime);
    cmd.Parse(argc, argv);

    // Create nodes
    NodeContainer vehicles;
    vehicles.Create(nVehicles);

    // Configure WAVE/DSRC
    YansWifiChannelHelper waveChannel = YansWifiChannelHelper::Default();
    YansWavePhyHelper wavePhy = YansWavePhyHelper::Default();
    wavePhy.SetChannel(waveChannel.Create());

    QosWaveMacHelper waveMac = QosWaveMacHelper::Default();
    WaveHelper waveHelper = WaveHelper::Default();

    NetDeviceContainer devices = waveHelper.Install(wavePhy, waveMac, vehicles);

    // Mobility model
    MobilityHelper mobility;
    mobility.SetPositionAllocator("ns3::GridPositionAllocator",
                                 "MinX", DoubleValue(0.0),
                                 "MinY", DoubleValue(0.0),
                                 "DeltaX", DoubleValue(distance),
                                 "DeltaY", DoubleValue(0.0),
                                 "GridWidth", UintegerValue(nVehicles),
                                 "LayoutType", StringValue("RowFirst"));

    mobility.SetMobilityModel("ns3::ConstantVelocityMobilityModel");
    mobility.Install(vehicles);

    // Set velocities
    for (uint32_t i = 0; i < vehicles.GetN(); ++i) {
        Ptr<ConstantVelocityMobilityModel> mob =
            vehicles.Get(i)->GetObject<ConstantVelocityMobilityModel>();
        mob->SetVelocity(Vector(20.0, 0.0, 0.0));  // 20 m/s
    }

    // Internet stack
    InternetStackHelper internet;
    internet.Install(vehicles);

    Ipv4AddressHelper ipv4;
    ipv4.SetBase("10.1.1.0", "255.255.255.0");
    ipv4.Assign(devices);

    // V2X applications
    TypeId tid = TypeId::LookupByName("ns3::UdpSocketFactory");
    for (uint32_t i = 0; i < vehicles.GetN(); ++i) {
        Ptr<Socket> sink = Socket::CreateSocket(vehicles.Get(i), tid);

        Ptr<V2XApplication> app = CreateObject<V2XApplication>();
        app->Setup(sink, 200, 1000, DataRate("6Mbps"));  // BSM: 200 bytes @ 10 Hz
        vehicles.Get(i)->AddApplication(app);
        app->SetStartTime(Seconds(1.0));
        app->SetStopTime(Seconds(simTime));
    }

    // Run simulation
    Simulator::Stop(Seconds(simTime));
    Simulator::Run();
    Simulator::Destroy();

    return 0;
}
```

## RF Chamber Testing

### Conducted RF Test Setup

```
Test Equipment:
- Vector Spectrum Analyzer (VSA)
- Signal Generator (V2X signal source)
- OBU/RSU under test
- RF cables and attenuators
- Shielded chamber

Test Metrics:
1. Transmit power (-33 to +33 dBm)
2. Receiver sensitivity (< -85 dBm for 6 Mbps)
3. Adjacent channel rejection (> 23 dB)
4. Spectrum mask compliance
5. EVM (Error Vector Magnitude) < 17.5%
6. Packet error rate vs SNR
```

### Test Procedure

```python
# rf_chamber_test.py
"""
Automated RF chamber test control.
"""

class RFChamberTest:
    """Control RF chamber testing equipment."""

    def __init__(self, vsa_address: str, sig_gen_address: str):
        # SCPI connection to test equipment
        self.vsa_address = vsa_address
        self.sig_gen_address = sig_gen_address

    def test_transmit_power(self, obu_id: str) -> dict:
        """
        Measure transmit power compliance.

        Returns:
            dict with power levels per channel
        """
        results = {}

        # Test each DSRC channel
        for channel in [172, 174, 176, 178, 180, 182, 184]:
            freq_ghz = 5.860 + (channel - 172) * 0.005

            # Configure OBU to transmit on channel
            # Measure power with VSA
            measured_power_dbm = self._measure_power(freq_ghz)

            results[channel] = {
                'frequency_ghz': freq_ghz,
                'power_dbm': measured_power_dbm,
                'spec_min_dbm': 0,
                'spec_max_dbm': 33,
                'pass': 0 <= measured_power_dbm <= 33
            }

        return results

    def test_receiver_sensitivity(self, obu_id: str) -> float:
        """
        Measure receiver sensitivity (minimum detectable signal).

        Returns:
            Sensitivity in dBm
        """
        # Start at high power
        power_dbm = -50
        step_db = -1
        per_threshold = 0.1  # 10% PER

        while power_dbm > -95:
            # Set signal generator power
            per = self._measure_per(power_dbm)

            if per > per_threshold:
                # Exceeded threshold, sensitivity found
                return power_dbm + abs(step_db)

            power_dbm += step_db

        return power_dbm
```

## Field Trial Protocol

### Multi-Site Field Testing

```yaml
# field_trial_protocol.yaml
trial_name: "V2X Safety Applications Field Trial"
duration_days: 30
test_sites:
  - name: "Urban Intersection"
    location: "Main St & 5th Ave"
    scenarios:
      - BSM broadcast (continuous)
      - SPaT/MAP reception
      - IMA collision warnings
    metrics:
      - Message delivery ratio
      - Latency (95th percentile)
      - False positive rate

  - name: "Highway Segment"
    location: "I-405 Mile 15-20"
    scenarios:
      - FCW testing
      - CACC platooning
      - EEBL warnings
    metrics:
      - TTC distribution
      - Warning timing accuracy
      - Driver response time

test_vehicles:
  - vehicle_id: V001
    obu_type: "Cohda MK5"
    instrumentation:
      - GPS (RTK, <10cm accuracy)
      - CAN bus logger
      - Video cameras (forward/rear)
      - Driver HMI recorder

data_collection:
  - V2X message logs (PCAP format)
  - GPS traces (1 Hz)
  - CAN bus data (all messages)
  - Driver interactions (button presses, warnings)
  - Video synchronized with messages
```

## Conformance Testing

### SAE J2945/1 Test Cases

```python
# conformance_tests.py
"""
SAE J2945/1 conformance test suite.
"""

class ConformanceTestSuite:
    """SAE J2945/1 OBU conformance tests."""

    def test_bsm_generation_rate(self, obu):
        """
        Test: BSM generation rate (10 Hz for moving vehicles).
        Requirement: SAE J2945/1 Section 5.2
        """
        messages = obu.collect_bsm_messages(duration_s=10)
        rate_hz = len(messages) / 10.0

        assert 9.5 <= rate_hz <= 10.5, f"BSM rate {rate_hz} Hz out of spec"

    def test_bsm_content_validity(self, obu):
        """
        Test: BSM content validity.
        Requirement: SAE J2735
        """
        bsm = obu.get_latest_bsm()

        # Check mandatory fields
        assert bsm.has_field('latitude'), "Missing latitude"
        assert bsm.has_field('longitude'), "Missing longitude"
        assert bsm.has_field('speed'), "Missing speed"
        assert bsm.has_field('heading'), "Missing heading"

        # Check value ranges
        assert -90 <= bsm.latitude <= 90, "Invalid latitude"
        assert -180 <= bsm.longitude <= 180, "Invalid longitude"
        assert 0 <= bsm.speed <= 163.8, "Invalid speed (max 163.8 m/s)"

    def test_security_certificate_attached(self, obu):
        """
        Test: Security certificate attachment.
        Requirement: IEEE 1609.2
        """
        secured_msg = obu.get_secured_message()

        assert secured_msg.has_certificate(), "No certificate attached"
        assert secured_msg.verify_signature(), "Invalid signature"
```

## References

1. **CARLA Documentation**: https://carla.readthedocs.io
2. **SUMO Documentation**: https://sumo.dlr.de/docs
3. **NS-3 WAVE Module**: https://www.nsnam.org/docs/models/html/wave.html
4. **OMNeT++ Veins**: https://veins.car2x.org
5. **SAE J2945/1**: On-Board System Requirements for V2V Safety Communications
