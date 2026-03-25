# Digital Twin Vehicles — Virtual Vehicle Representations

Expert knowledge of digital twin architecture, real-time synchronization, simulation for testing, predictive maintenance, virtual testing environments, and CI/CD for vehicle software.

## Core Concepts

### Digital Twin Architecture

1. **Physical Twin**: Actual vehicle with sensors and actuators
2. **Digital Twin**: Virtual representation in cloud/edge
3. **Bi-directional Sync**: Real-time data flow both ways
4. **Simulation Engine**: Physics-based vehicle model
5. **Analytics Layer**: ML/AI for predictions

### Use Cases

- **Predictive Maintenance**: Predict failures before they occur
- **Virtual Testing**: Test software without physical vehicle
- **Fleet Optimization**: Optimize routing, charging, maintenance
- **Development**: Rapid prototyping and testing
- **Training**: Train ML models on simulated data

## Production-Ready Implementation

### 1. Digital Twin Engine (Python)

```python
#!/usr/bin/env python3
"""
Digital Twin Engine for vehicle simulation and synchronization.
"""

import json
import time
from dataclasses import dataclass, asdict
from datetime import datetime
from typing import Dict, List, Optional
import numpy as np
from scipy.integrate import odeint
import paho.mqtt.client as mqtt


@dataclass
class VehicleState:
    """Complete vehicle state."""
    vin: str
    timestamp: float

    # Powertrain
    battery_soc: float  # State of charge (%)
    battery_voltage: float  # Volts
    battery_current: float  # Amps
    battery_temperature: float  # Celsius
    motor_speed: float  # RPM
    motor_torque: float  # Nm

    # Dynamics
    speed: float  # km/h
    acceleration: float  # m/s^2
    position: tuple  # (latitude, longitude)
    heading: float  # degrees

    # Environment
    ambient_temperature: float  # Celsius
    road_grade: float  # %

    # Diagnostics
    odometer: float  # km
    energy_consumed: float  # kWh
    regeneration_energy: float  # kWh


class VehiclePhysicsModel:
    """
    Physics-based vehicle simulation model.

    Models:
    - Battery dynamics (charge/discharge, thermal)
    - Electric motor efficiency
    - Vehicle dynamics (acceleration, drag, rolling resistance)
    - Energy consumption
    """

    def __init__(self, vehicle_params: dict):
        self.params = vehicle_params

        # Vehicle parameters
        self.mass = vehicle_params['mass']  # kg
        self.drag_coefficient = vehicle_params['drag_coefficient']  # Cd
        self.frontal_area = vehicle_params['frontal_area']  # m^2
        self.rolling_resistance = vehicle_params['rolling_resistance']  # Crr
        self.wheel_radius = vehicle_params['wheel_radius']  # m

        # Battery parameters
        self.battery_capacity = vehicle_params['battery_capacity']  # kWh
        self.battery_resistance = vehicle_params['battery_resistance']  # Ohms
        self.battery_thermal_mass = vehicle_params['battery_thermal_mass']  # J/K

        # Motor parameters
        self.motor_max_power = vehicle_params['motor_max_power']  # kW
        self.motor_efficiency_map = vehicle_params['motor_efficiency_map']

        # Constants
        self.air_density = 1.225  # kg/m^3
        self.gravity = 9.81  # m/s^2

    def simulate_step(self, state: VehicleState, throttle: float,
                     dt: float) -> VehicleState:
        """
        Simulate one time step.

        Args:
            state: Current vehicle state
            throttle: Throttle input (-1 to 1, negative for regen)
            dt: Time step (seconds)

        Returns:
            Updated vehicle state
        """
        # Convert speed to m/s
        speed_mps = state.speed / 3.6

        # Calculate forces
        drag_force = 0.5 * self.air_density * self.drag_coefficient * \
                     self.frontal_area * speed_mps**2

        rolling_resistance_force = self.rolling_resistance * self.mass * \
                                  self.gravity * np.cos(np.radians(state.road_grade))

        grade_force = self.mass * self.gravity * np.sin(np.radians(state.road_grade))

        # Calculate required power
        if throttle > 0:
            # Acceleration
            motor_torque = throttle * self._calculate_max_torque(state.motor_speed)
            motor_power = motor_torque * state.motor_speed * 2 * np.pi / 60 / 1000  # kW

            # Motor efficiency
            efficiency = self._get_motor_efficiency(motor_power, state.motor_speed)
            battery_power = motor_power / efficiency

        else:
            # Regenerative braking
            regen_power = abs(throttle) * self.motor_max_power * 0.7  # 70% max regen
            battery_power = -regen_power * 0.85  # 85% regen efficiency
            motor_power = -regen_power

        # Battery dynamics
        battery_current = battery_power * 1000 / state.battery_voltage
        voltage_drop = battery_current * self.battery_resistance
        state.battery_voltage = self._calculate_ocv(state.battery_soc) - voltage_drop

        # Energy consumed/regenerated
        energy_delta = battery_power * dt / 3600  # kWh
        state.battery_soc -= (energy_delta / self.battery_capacity) * 100

        if battery_power > 0:
            state.energy_consumed += energy_delta
        else:
            state.regeneration_energy += abs(energy_delta)

        # Battery thermal model
        heat_generation = battery_current**2 * self.battery_resistance  # Watts
        cooling_rate = (state.battery_temperature - state.ambient_temperature) * 50  # W
        temp_delta = (heat_generation - cooling_rate) * dt / self.battery_thermal_mass
        state.battery_temperature += temp_delta

        # Vehicle dynamics
        net_force = (motor_power * 1000 / max(speed_mps, 0.1)) - \
                   drag_force - rolling_resistance_force - grade_force

        acceleration = net_force / self.mass
        speed_mps += acceleration * dt
        speed_mps = max(0, speed_mps)  # Can't go backwards

        state.speed = speed_mps * 3.6  # Convert to km/h
        state.acceleration = acceleration

        # Update position (simplified)
        distance_delta = speed_mps * dt / 1000  # km
        state.odometer += distance_delta

        # Update motor state
        state.motor_speed = speed_mps / (2 * np.pi * self.wheel_radius) * 60  # RPM
        state.motor_torque = motor_power * 1000 / (state.motor_speed * 2 * np.pi / 60) \
                           if state.motor_speed > 0 else 0

        state.battery_current = battery_current
        state.timestamp = time.time()

        return state

    def _calculate_max_torque(self, motor_speed: float) -> float:
        """Calculate maximum available torque at given speed."""
        if motor_speed < 3000:
            return 400  # Nm (constant torque region)
        else:
            # Constant power region
            max_power = self.motor_max_power * 1000  # W
            return max_power / (motor_speed * 2 * np.pi / 60)

    def _get_motor_efficiency(self, power: float, speed: float) -> float:
        """Get motor efficiency from efficiency map."""
        # Simplified efficiency model
        # In production, use lookup table
        if power < 0.1 * self.motor_max_power:
            return 0.85
        elif power < 0.5 * self.motor_max_power:
            return 0.93
        elif power < 0.8 * self.motor_max_power:
            return 0.95
        else:
            return 0.92

    def _calculate_ocv(self, soc: float) -> float:
        """Calculate open-circuit voltage from SOC."""
        # Simplified polynomial fit
        # In production, use actual OCV curve
        return 300 + 100 * (soc / 100)


class DigitalTwin:
    """
    Digital twin of vehicle with bi-directional synchronization.

    Features:
    - Real-time sync with physical vehicle
    - Physics-based simulation
    - Predictive analytics
    - Virtual testing
    """

    def __init__(self, vin: str, vehicle_params: dict, cloud_config: dict):
        self.vin = vin
        self.physics_model = VehiclePhysicsModel(vehicle_params)
        self.cloud_config = cloud_config

        # Initialize state
        self.state = VehicleState(
            vin=vin,
            timestamp=time.time(),
            battery_soc=100.0,
            battery_voltage=400.0,
            battery_current=0.0,
            battery_temperature=25.0,
            motor_speed=0.0,
            motor_torque=0.0,
            speed=0.0,
            acceleration=0.0,
            position=(0.0, 0.0),
            heading=0.0,
            ambient_temperature=25.0,
            road_grade=0.0,
            odometer=0.0,
            energy_consumed=0.0,
            regeneration_energy=0.0
        )

        # MQTT connection
        self.mqtt_client = None
        self.sync_enabled = True
        self.simulation_mode = False

        # Analytics
        self.state_history = []
        self.predictions = {}

    def connect_to_cloud(self):
        """Connect to cloud platform for synchronization."""
        self.mqtt_client = mqtt.Client(client_id=f"twin-{self.vin}")

        self.mqtt_client.username_pw_set(
            self.cloud_config['mqtt_username'],
            self.cloud_config['mqtt_password']
        )

        self.mqtt_client.on_connect = self._on_connect
        self.mqtt_client.on_message = self._on_message

        self.mqtt_client.connect(
            self.cloud_config['mqtt_broker'],
            self.cloud_config['mqtt_port']
        )

        self.mqtt_client.loop_start()

    def _on_connect(self, client, userdata, flags, rc):
        """Handle MQTT connection."""
        print(f"[Twin] Connected to cloud (VIN: {self.vin})")

        # Subscribe to physical vehicle telemetry
        client.subscribe(f"vehicles/{self.vin}/telemetry/#")

        # Subscribe to commands
        client.subscribe(f"twins/{self.vin}/commands/#")

    def _on_message(self, client, userdata, msg):
        """Handle incoming messages."""
        topic_parts = msg.topic.split('/')

        if 'telemetry' in topic_parts:
            # Update from physical vehicle
            self._sync_from_physical(json.loads(msg.payload))

        elif 'commands' in topic_parts:
            # Command from cloud
            command = topic_parts[-1]
            self._handle_command(command, json.loads(msg.payload))

    def _sync_from_physical(self, telemetry: dict):
        """Synchronize state from physical vehicle."""
        if not self.sync_enabled:
            return

        print(f"[Twin] Syncing from physical vehicle")

        # Update state from telemetry
        message_type = telemetry.get('message_type')
        data = telemetry.get('data', {})

        if message_type == 'battery':
            self.state.battery_soc = data.get('soc', self.state.battery_soc)
            self.state.battery_voltage = data.get('voltage', self.state.battery_voltage)
            self.state.battery_current = data.get('current', self.state.battery_current)
            self.state.battery_temperature = data.get('temperature',
                                                     self.state.battery_temperature)

        elif message_type == 'speed':
            self.state.speed = data.get('speed', self.state.speed)
            self.state.odometer = data.get('odometer', self.state.odometer)

        elif message_type == 'location':
            self.state.position = (data.get('latitude', 0), data.get('longitude', 0))
            self.state.heading = data.get('heading', self.state.heading)

        # Publish updated twin state
        self._publish_twin_state()

    def _publish_twin_state(self):
        """Publish digital twin state to cloud."""
        if self.mqtt_client and self.mqtt_client.is_connected():
            topic = f"twins/{self.vin}/state"
            payload = json.dumps(asdict(self.state))
            self.mqtt_client.publish(topic, payload, qos=0)

    def run_simulation(self, drive_cycle: List[dict], dt: float = 0.1):
        """
        Run simulation with given drive cycle.

        Args:
            drive_cycle: List of {'time': t, 'throttle': x, 'grade': y}
            dt: Time step (seconds)
        """
        print(f"[Twin] Starting simulation (duration: {drive_cycle[-1]['time']}s)")

        self.simulation_mode = True
        self.state_history = []

        for i, cycle_point in enumerate(drive_cycle[:-1]):
            next_point = drive_cycle[i + 1]

            # Interpolate throttle
            throttle = cycle_point['throttle']
            self.state.road_grade = cycle_point.get('grade', 0)

            # Simulate
            self.state = self.physics_model.simulate_step(self.state, throttle, dt)

            # Store history
            self.state_history.append(asdict(self.state))

            # Publish periodically
            if i % 10 == 0:
                self._publish_twin_state()

            time.sleep(dt)

        self.simulation_mode = False
        print(f"[Twin] Simulation complete")

        # Analyze results
        self._analyze_simulation()

    def _analyze_simulation(self):
        """Analyze simulation results."""
        if not self.state_history:
            return

        final_state = self.state_history[-1]

        print(f"\n[Twin] Simulation Results:")
        print(f"  Distance: {final_state['odometer']:.2f} km")
        print(f"  Energy consumed: {final_state['energy_consumed']:.2f} kWh")
        print(f"  Regeneration: {final_state['regeneration_energy']:.2f} kWh")
        print(f"  Final SOC: {final_state['battery_soc']:.1f}%")
        print(f"  Efficiency: {final_state['odometer'] / final_state['energy_consumed']:.2f} km/kWh")

    def predict_range(self) -> float:
        """
        Predict remaining range based on current state and driving pattern.

        Returns:
            Predicted range in km
        """
        # Simple model: current SOC * typical efficiency
        # In production, use ML model trained on historical data

        typical_efficiency = 5.0  # km/kWh
        remaining_energy = self.state.battery_soc / 100 * self.physics_model.battery_capacity

        predicted_range = remaining_energy * typical_efficiency

        print(f"[Twin] Predicted range: {predicted_range:.1f} km")
        return predicted_range

    def predict_maintenance(self) -> Dict:
        """
        Predict maintenance needs using anomaly detection.

        Returns:
            Dictionary of predicted maintenance items
        """
        predictions = {
            'battery_health': 95.0,  # %
            'estimated_degradation': 5.0,  # %
            'cycles_remaining': 1500,
            'recommendations': []
        }

        # Check battery temperature trends
        if len(self.state_history) > 100:
            recent_temps = [s['battery_temperature'] for s in self.state_history[-100:]]
            avg_temp = np.mean(recent_temps)

            if avg_temp > 45:
                predictions['recommendations'].append(
                    "Battery running hot. Check cooling system."
                )

        # Check energy consumption anomalies
        if self.state.energy_consumed > 0:
            efficiency = self.state.odometer / self.state.energy_consumed

            if efficiency < 4.0:  # Below expected
                predictions['recommendations'].append(
                    "Low efficiency detected. Check tire pressure and alignment."
                )

        return predictions

    def _handle_command(self, command: str, params: dict):
        """Handle commands from cloud."""
        print(f"[Twin] Received command: {command}")

        if command == 'simulate':
            # Run simulation with provided drive cycle
            drive_cycle = params.get('drive_cycle', [])
            self.run_simulation(drive_cycle)

        elif command == 'predict_range':
            # Predict range
            range_km = self.predict_range()
            self.mqtt_client.publish(
                f"twins/{self.vin}/predictions/range",
                json.dumps({'range_km': range_km})
            )

        elif command == 'predict_maintenance':
            # Predict maintenance
            predictions = self.predict_maintenance()
            self.mqtt_client.publish(
                f"twins/{self.vin}/predictions/maintenance",
                json.dumps(predictions)
            )

    def export_state_history(self, filename: str):
        """Export state history to file for analysis."""
        with open(filename, 'w') as f:
            json.dump(self.state_history, f, indent=2)

        print(f"[Twin] State history exported to {filename}")


# Example usage
def main():
    """Example digital twin usage."""

    # Vehicle parameters (Tesla Model 3 Long Range approximate)
    vehicle_params = {
        'mass': 1847,  # kg
        'drag_coefficient': 0.23,
        'frontal_area': 2.22,  # m^2
        'rolling_resistance': 0.01,
        'wheel_radius': 0.368,  # m (18" wheels)
        'battery_capacity': 82,  # kWh
        'battery_resistance': 0.05,  # Ohms
        'battery_thermal_mass': 50000,  # J/K
        'motor_max_power': 258,  # kW (combined front+rear)
        'motor_efficiency_map': {}
    }

    cloud_config = {
        'mqtt_broker': 'mqtt.example.com',
        'mqtt_port': 8883,
        'mqtt_username': 'twin-client',
        'mqtt_password': 'password'
    }

    # Create digital twin
    twin = DigitalTwin('VIN123456789', vehicle_params, cloud_config)
    twin.connect_to_cloud()

    # Example drive cycle (WLTP-like)
    drive_cycle = []
    for t in range(0, 1800, 10):  # 30 minutes
        if t < 600:
            throttle = 0.3  # City driving
        elif t < 1200:
            throttle = 0.5  # Highway
        else:
            throttle = 0.2  # Slow down

        drive_cycle.append({
            'time': t,
            'throttle': throttle,
            'grade': 0
        })

    # Run simulation
    twin.run_simulation(drive_cycle, dt=10.0)

    # Predictions
    twin.predict_range()
    twin.predict_maintenance()

    # Export data
    twin.export_state_history('twin_history.json')


if __name__ == "__main__":
    main()
```

### 2. Azure Digital Twins Integration

```yaml
# Azure Digital Twins model definition (DTDL)
# File: vehicle-model.json

{
  "@context": "dtmi:dtdl:context;2",
  "@id": "dtmi:com:example:Vehicle;1",
  "@type": "Interface",
  "displayName": "Electric Vehicle",
  "contents": [
    {
      "@type": "Property",
      "name": "vin",
      "schema": "string",
      "description": "Vehicle Identification Number"
    },
    {
      "@type": "Telemetry",
      "name": "battery",
      "schema": {
        "@type": "Object",
        "fields": [
          {
            "name": "soc",
            "schema": "double"
          },
          {
            "name": "voltage",
            "schema": "double"
          },
          {
            "name": "current",
            "schema": "double"
          },
          {
            "name": "temperature",
            "schema": "double"
          }
        ]
      }
    },
    {
      "@type": "Telemetry",
      "name": "location",
      "schema": "geopoint"
    },
    {
      "@type": "Telemetry",
      "name": "speed",
      "schema": "double"
    },
    {
      "@type": "Command",
      "name": "predictRange",
      "response": {
        "name": "rangeResult",
        "schema": "double"
      }
    },
    {
      "@type": "Command",
      "name": "simulateDriveCycle",
      "request": {
        "name": "driveCycleData",
        "schema": "string"
      }
    }
  ]
}
```

### 3. CI/CD Pipeline for Digital Twin

```yaml
# File: .github/workflows/digital-twin-ci.yml

name: Digital Twin CI/CD

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.9'

      - name: Install dependencies
        run: |
          pip install -r requirements.txt
          pip install pytest pytest-cov

      - name: Run unit tests
        run: |
          pytest tests/ --cov=digital_twin --cov-report=xml

      - name: Run physics model validation
        run: |
          python tests/validate_physics.py

      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          file: ./coverage.xml

  simulate:
    runs-on: ubuntu-latest
    needs: test

    steps:
      - uses: actions/checkout@v3

      - name: Run simulation tests
        run: |
          python digital_twin.py --mode simulation \
            --drive-cycle tests/wltp_cycle.json \
            --output results/

      - name: Validate results
        run: |
          python tests/validate_simulation.py results/

      - name: Upload artifacts
        uses: actions/upload-artifact@v3
        with:
          name: simulation-results
          path: results/

  deploy:
    runs-on: ubuntu-latest
    needs: [test, simulate]
    if: github.ref == 'refs/heads/main'

    steps:
      - uses: actions/checkout@v3

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-west-2

      - name: Deploy to AWS IoT
        run: |
          aws iot create-thing --thing-name digital-twin-${{ github.sha }}
          aws lambda update-function-code \
            --function-name vehicle-digital-twin \
            --zip-file fileb://digital_twin.zip
```

## Real-World Examples

### Tesla Digital Twin
- **Fleet learning**: Aggregate shadow mode data for Autopilot
- **Battery degradation modeling**: Predict range loss over time
- **Virtual testing**: Test new software on digital fleet before OTA
- **Predictive maintenance**: Schedule service based on digital twin analysis

### BMW Digital Twin
- **Production line**: Digital twin during manufacturing
- **Lifetime tracking**: Track vehicle from production to end-of-life
- **Service optimization**: Predict maintenance needs
- **Retrofit planning**: Test compatibility of new features

### Rivian Adventure Network
- **Route optimization**: Simulate range on planned routes
- **Charging strategy**: Optimize charging stops
- **Off-road capability**: Simulate vehicle performance on trails
- **Load planning**: Test vehicle with different cargo/trailer loads

## Best Practices

1. **High-fidelity physics**: Use validated physics models
2. **Real-time sync**: Keep twin synchronized with physical vehicle
3. **Historical data**: Store state history for analytics
4. **Predictive models**: Use ML for maintenance predictions
5. **Virtual testing**: Test software on twins before deployment
6. **CI/CD integration**: Automate testing with digital twins
7. **Fleet-wide insights**: Aggregate data across all twins
8. **Privacy protection**: Anonymize sensitive data
9. **Model validation**: Continuously validate against real-world data
10. **Scalability**: Design for millions of twins

## Security Considerations

- **Authentication**: Secure twin-to-cloud communication
- **Data encryption**: Encrypt state data and telemetry
- **Access control**: Limit who can command twins
- **Audit logging**: Track all twin operations
- **Simulation isolation**: Sandbox simulation environments
- **Model protection**: Protect proprietary physics models

## References

- **Azure Digital Twins**: https://azure.microsoft.com/en-us/products/digital-twins/
- **AWS IoT TwinMaker**: https://aws.amazon.com/iot-twinmaker/
- **Eclipse Ditto**: https://www.eclipse.org/ditto/
- **Digital Twin Consortium**: https://www.digitaltwinconsortium.org/
