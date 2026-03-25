# Energy Optimization and Route Planning

Optimize energy consumption through intelligent route planning, charging strategies, and predictive algorithms. Focus on electric vehicles with battery-electric and plug-in hybrid powertrains.

## Use Cases

1. **Route Optimization**: Minimize energy consumption for given destination
2. **Charging Strategy**: Optimize charging times and locations for cost/time
3. **Range Prediction**: Accurate remaining range estimation
4. **Eco-Routing**: Balance time vs energy trade-offs
5. **Fleet Electrification**: Optimal EV deployment planning

## Route Optimization with Reinforcement Learning

```python
import numpy as np
import pandas as pd
import gym
from gym import spaces
from typing import Tuple, Dict, List
import torch
import torch.nn as nn
import torch.optim as optim
from collections import deque
import random

class EVRoutingEnvironment(gym.Env):
    """
    OpenAI Gym environment for EV route optimization.

    State: Current location, SOC, traffic conditions, weather
    Action: Next waypoint selection
    Reward: -(energy_consumed + time_penalty + charging_cost)
    """

    def __init__(
        self,
        road_network: pd.DataFrame,
        charging_stations: pd.DataFrame,
        battery_capacity_kwh: float = 75.0
    ):
        """
        Args:
            road_network: Graph with edges (src, dst, distance, elevation, speed_limit)
            charging_stations: Locations with (lat, lon, power_kw, cost_per_kwh)
            battery_capacity_kwh: Vehicle battery capacity
        """
        super().__init__()

        self.road_network = road_network
        self.charging_stations = charging_stations
        self.battery_capacity = battery_capacity_kwh

        # State space: [current_node_id, soc, time_of_day, traffic_level]
        self.observation_space = spaces.Box(
            low=np.array([0, 0, 0, 0]),
            high=np.array([len(road_network), 100, 24, 10]),
            dtype=np.float32
        )

        # Action space: [next_node_id, charge_decision (0=no, 1=yes)]
        self.action_space = spaces.MultiDiscrete([len(road_network), 2])

        self.reset()

    def reset(self) -> np.ndarray:
        """
        Reset environment to initial state.

        Returns:
            Initial observation
        """
        self.current_node = 0  # Start node
        self.destination_node = len(self.road_network) - 1
        self.soc = 80.0  # Start with 80% SOC
        self.time = 8.0  # Start at 8 AM
        self.total_energy = 0
        self.total_cost = 0
        self.trajectory = [self.current_node]

        return self._get_observation()

    def _get_observation(self) -> np.ndarray:
        """Get current state observation."""
        traffic_level = self._get_traffic_level(self.time)
        return np.array([
            self.current_node,
            self.soc,
            self.time,
            traffic_level
        ], dtype=np.float32)

    def _get_traffic_level(self, time: float) -> float:
        """
        Model traffic congestion by time of day.

        Peak hours: 7-9 AM, 5-7 PM -> High traffic
        """
        if (7 <= time <= 9) or (17 <= time <= 19):
            return 8.0  # High traffic
        elif (6 <= time <= 10) or (16 <= time <= 20):
            return 5.0  # Medium traffic
        else:
            return 2.0  # Low traffic

    def _compute_energy_consumption(
        self,
        distance_km: float,
        elevation_gain_m: float,
        speed_kmh: float,
        traffic_level: float
    ) -> float:
        """
        Estimate energy consumption for segment.

        Model: Base consumption + elevation + traffic penalty
        """
        # Base consumption (kWh per 100 km)
        base_consumption = 18.0

        # Elevation impact (100m climb ≈ 1 kWh)
        elevation_energy = max(0, elevation_gain_m / 100)

        # Speed efficiency (optimal around 60 km/h)
        speed_factor = 1 + 0.01 * abs(speed_kmh - 60)

        # Traffic penalty (stop-and-go increases consumption)
        traffic_factor = 1 + 0.05 * traffic_level

        total_energy = (
            base_consumption * distance_km / 100 * speed_factor * traffic_factor +
            elevation_energy
        )

        return total_energy

    def step(self, action: Tuple[int, int]) -> Tuple[np.ndarray, float, bool, Dict]:
        """
        Execute action and return next state.

        Args:
            action: (next_node_id, charge_decision)

        Returns:
            observation, reward, done, info
        """
        next_node, charge_decision = action

        # Get edge info
        edge = self.road_network[
            (self.road_network['src'] == self.current_node) &
            (self.road_network['dst'] == next_node)
        ]

        if edge.empty:
            # Invalid action (no edge)
            return self._get_observation(), -1000, True, {'error': 'invalid_edge'}

        edge = edge.iloc[0]
        distance = edge['distance_km']
        elevation = edge['elevation_gain_m']
        speed_limit = edge['speed_limit_kmh']

        # Traffic-adjusted speed
        traffic_level = self._get_traffic_level(self.time)
        avg_speed = speed_limit * (1 - 0.05 * traffic_level)  # Slower in traffic

        # Energy consumption
        energy_consumed = self._compute_energy_consumption(
            distance, elevation, avg_speed, traffic_level
        )

        # Update SOC
        self.soc -= (energy_consumed / self.battery_capacity) * 100

        # Time elapsed
        time_elapsed = distance / avg_speed  # hours
        self.time += time_elapsed

        # Charging decision
        charging_cost = 0
        charging_time = 0

        if charge_decision == 1:
            # Find nearest charging station
            station = self.charging_stations.iloc[0]  # Simplified
            charge_amount_kwh = (80 - self.soc) / 100 * self.battery_capacity
            charging_time = charge_amount_kwh / station['power_kw']
            charging_cost = charge_amount_kwh * station['cost_per_kwh']

            self.soc = 80.0  # Charge to 80%
            self.time += charging_time
            self.total_cost += charging_cost

        # Update trajectory
        self.current_node = next_node
        self.trajectory.append(next_node)
        self.total_energy += energy_consumed

        # Check if done
        done = False
        if self.current_node == self.destination_node:
            done = True
        elif self.soc < 10:
            # Ran out of battery
            done = True
            reward = -1000
            return self._get_observation(), reward, done, {'error': 'battery_depleted'}

        # Compute reward
        # Minimize: energy + time + charging cost
        reward = -(
            energy_consumed +
            10 * time_elapsed +  # Time penalty
            charging_cost
        )

        # Bonus for reaching destination
        if done and self.current_node == self.destination_node:
            reward += 100

        info = {
            'energy_consumed': energy_consumed,
            'time_elapsed': time_elapsed,
            'charging_cost': charging_cost,
            'soc': self.soc
        }

        return self._get_observation(), reward, done, info


class DQN(nn.Module):
    """
    Deep Q-Network for route optimization.

    Architecture: Fully connected layers with ReLU activations.
    """

    def __init__(self, state_dim: int, action_dim: int):
        super().__init__()

        self.fc = nn.Sequential(
            nn.Linear(state_dim, 128),
            nn.ReLU(),
            nn.Linear(128, 128),
            nn.ReLU(),
            nn.Linear(128, action_dim)
        )

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.fc(x)


class DQNAgent:
    """
    DQN agent for EV route optimization.

    Uses experience replay and target network for stable learning.
    """

    def __init__(
        self,
        state_dim: int,
        action_dim: int,
        lr: float = 0.001,
        gamma: float = 0.99,
        epsilon: float = 1.0,
        epsilon_decay: float = 0.995,
        epsilon_min: float = 0.01
    ):
        self.state_dim = state_dim
        self.action_dim = action_dim
        self.gamma = gamma
        self.epsilon = epsilon
        self.epsilon_decay = epsilon_decay
        self.epsilon_min = epsilon_min

        # Q-network and target network
        self.q_network = DQN(state_dim, action_dim)
        self.target_network = DQN(state_dim, action_dim)
        self.target_network.load_state_dict(self.q_network.state_dict())

        self.optimizer = optim.Adam(self.q_network.parameters(), lr=lr)
        self.criterion = nn.MSELoss()

        # Experience replay
        self.memory = deque(maxlen=10000)
        self.batch_size = 64

    def select_action(self, state: np.ndarray) -> int:
        """
        Epsilon-greedy action selection.
        """
        if random.random() < self.epsilon:
            return random.randint(0, self.action_dim - 1)
        else:
            state_tensor = torch.FloatTensor(state).unsqueeze(0)
            with torch.no_grad():
                q_values = self.q_network(state_tensor)
            return q_values.argmax().item()

    def store_transition(
        self,
        state: np.ndarray,
        action: int,
        reward: float,
        next_state: np.ndarray,
        done: bool
    ):
        """Store experience in replay buffer."""
        self.memory.append((state, action, reward, next_state, done))

    def train(self):
        """Train Q-network on batch from replay buffer."""
        if len(self.memory) < self.batch_size:
            return

        # Sample batch
        batch = random.sample(self.memory, self.batch_size)
        states, actions, rewards, next_states, dones = zip(*batch)

        states = torch.FloatTensor(np.array(states))
        actions = torch.LongTensor(actions)
        rewards = torch.FloatTensor(rewards)
        next_states = torch.FloatTensor(np.array(next_states))
        dones = torch.FloatTensor(dones)

        # Current Q-values
        q_values = self.q_network(states).gather(1, actions.unsqueeze(1)).squeeze()

        # Target Q-values
        with torch.no_grad():
            next_q_values = self.target_network(next_states).max(1)[0]
            target_q_values = rewards + self.gamma * next_q_values * (1 - dones)

        # Loss and optimization
        loss = self.criterion(q_values, target_q_values)

        self.optimizer.zero_grad()
        loss.backward()
        self.optimizer.step()

        # Decay epsilon
        self.epsilon = max(self.epsilon_min, self.epsilon * self.epsilon_decay)

    def update_target_network(self):
        """Copy weights from Q-network to target network."""
        self.target_network.load_state_dict(self.q_network.state_dict())


# Example training loop
if __name__ == "__main__":
    # Create environment (with dummy data)
    road_network = pd.DataFrame({
        'src': [0, 1, 2],
        'dst': [1, 2, 3],
        'distance_km': [10, 15, 20],
        'elevation_gain_m': [50, 100, 150],
        'speed_limit_kmh': [60, 80, 100]
    })

    charging_stations = pd.DataFrame({
        'lat': [37.7749],
        'lon': [-122.4194],
        'power_kw': [150],
        'cost_per_kwh': [0.25]
    })

    env = EVRoutingEnvironment(road_network, charging_stations)

    # Initialize agent
    agent = DQNAgent(
        state_dim=env.observation_space.shape[0],
        action_dim=len(road_network)  # Simplified
    )

    # Training
    episodes = 500
    for episode in range(episodes):
        state = env.reset()
        total_reward = 0

        for step in range(100):
            action = agent.select_action(state)
            # Simplified action (no charging decision for now)
            next_state, reward, done, info = env.step((action, 0))

            agent.store_transition(state, action, reward, next_state, done)
            agent.train()

            state = next_state
            total_reward += reward

            if done:
                break

        # Update target network every 10 episodes
        if episode % 10 == 0:
            agent.update_target_network()

        if episode % 50 == 0:
            print(f"Episode {episode}, Total Reward: {total_reward:.2f}, "
                  f"Epsilon: {agent.epsilon:.3f}")
```

## Charging Strategy Optimization

```python
import pulp
import numpy as np
import pandas as pd
from typing import List, Dict, Tuple

class ChargingStrategyOptimizer:
    """
    Optimize charging schedule for fleet to minimize cost and maximize availability.

    Objective: Minimize electricity cost while ensuring all vehicles charged for next day.

    Constraints:
    - Each vehicle must reach target SOC before departure
    - Charger capacity limits (power, number of chargers)
    - Time-of-use electricity pricing
    """

    def __init__(
        self,
        n_vehicles: int,
        n_chargers: int,
        charger_power_kw: float,
        time_slots: int = 24,
        battery_capacity_kwh: float = 75.0
    ):
        """
        Args:
            n_vehicles: Number of vehicles in fleet
            n_chargers: Number of available chargers
            charger_power_kw: Charging power per charger [kW]
            time_slots: Planning horizon (hours)
            battery_capacity_kwh: Vehicle battery capacity
        """
        self.n_vehicles = n_vehicles
        self.n_chargers = n_chargers
        self.charger_power = charger_power_kw
        self.time_slots = time_slots
        self.battery_capacity = battery_capacity_kwh

    def optimize_schedule(
        self,
        arrival_soc: np.ndarray,
        target_soc: np.ndarray,
        arrival_times: np.ndarray,
        departure_times: np.ndarray,
        electricity_prices: np.ndarray
    ) -> Dict:
        """
        Optimize charging schedule using linear programming.

        Args:
            arrival_soc: Current SOC for each vehicle [%] (n_vehicles,)
            target_soc: Desired SOC for each vehicle [%] (n_vehicles,)
            arrival_times: Arrival time slot for each vehicle (n_vehicles,)
            departure_times: Departure time slot for each vehicle (n_vehicles,)
            electricity_prices: Price per kWh for each time slot [$/kWh] (time_slots,)

        Returns:
            Dictionary with optimal charging schedule
        """
        # Create optimization problem
        prob = pulp.LpProblem("Fleet_Charging_Optimization", pulp.LpMinimize)

        # Decision variables: charging[vehicle, time] = kWh charged in time slot
        charging = {}
        for v in range(self.n_vehicles):
            for t in range(self.time_slots):
                charging[v, t] = pulp.LpVariable(
                    f"charge_v{v}_t{t}",
                    lowBound=0,
                    upBound=self.charger_power  # Max charge rate
                )

        # Binary variable: is_charging[vehicle, time] = 1 if vehicle is charging
        is_charging = {}
        for v in range(self.n_vehicles):
            for t in range(self.time_slots):
                is_charging[v, t] = pulp.LpVariable(
                    f"is_charging_v{v}_t{t}",
                    cat='Binary'
                )

        # Objective: Minimize total electricity cost
        total_cost = pulp.lpSum([
            charging[v, t] * electricity_prices[t]
            for v in range(self.n_vehicles)
            for t in range(self.time_slots)
        ])
        prob += total_cost

        # Constraint 1: Each vehicle reaches target SOC
        for v in range(self.n_vehicles):
            energy_needed = (
                (target_soc[v] - arrival_soc[v]) / 100 * self.battery_capacity
            )

            total_charged = pulp.lpSum([
                charging[v, t]
                for t in range(int(arrival_times[v]), int(departure_times[v]))
            ])

            prob += total_charged >= energy_needed, f"target_soc_v{v}"

        # Constraint 2: Charger capacity (max n_chargers in use at once)
        for t in range(self.time_slots):
            prob += (
                pulp.lpSum([is_charging[v, t] for v in range(self.n_vehicles)]) <=
                self.n_chargers
            ), f"charger_capacity_t{t}"

        # Constraint 3: Link charging amount to is_charging binary
        for v in range(self.n_vehicles):
            for t in range(self.time_slots):
                prob += charging[v, t] <= self.charger_power * is_charging[v, t]

        # Constraint 4: Only charge when vehicle is available
        for v in range(self.n_vehicles):
            for t in range(self.time_slots):
                if t < arrival_times[v] or t >= departure_times[v]:
                    prob += charging[v, t] == 0

        # Solve
        prob.solve(pulp.PULP_CBC_CMD(msg=0))

        # Extract solution
        schedule = np.zeros((self.n_vehicles, self.time_slots))
        for v in range(self.n_vehicles):
            for t in range(self.time_slots):
                schedule[v, t] = pulp.value(charging[v, t])

        total_cost_value = pulp.value(prob.objective)
        total_energy = schedule.sum()

        return {
            'schedule': schedule,
            'total_cost_usd': total_cost_value,
            'total_energy_kwh': total_energy,
            'status': pulp.LpStatus[prob.status]
        }

    def visualize_schedule(self, schedule: np.ndarray, electricity_prices: np.ndarray):
        """
        Visualize charging schedule.

        Args:
            schedule: Charging schedule matrix (n_vehicles, time_slots)
            electricity_prices: Price per time slot
        """
        import matplotlib.pyplot as plt

        fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(12, 8), sharex=True)

        # Heatmap of charging schedule
        im = ax1.imshow(schedule, aspect='auto', cmap='YlOrRd')
        ax1.set_ylabel('Vehicle ID')
        ax1.set_title('Charging Schedule (kWh per hour)')
        plt.colorbar(im, ax=ax1, label='Energy (kWh)')

        # Electricity prices
        ax2.bar(range(self.time_slots), electricity_prices, color='steelblue')
        ax2.set_xlabel('Hour of Day')
        ax2.set_ylabel('Price ($/kWh)')
        ax2.set_title('Time-of-Use Electricity Pricing')

        plt.tight_layout()
        plt.show()


# Example usage
if __name__ == "__main__":
    # Fleet parameters
    n_vehicles = 10
    n_chargers = 5

    # Vehicle data
    np.random.seed(42)
    arrival_soc = np.random.uniform(20, 50, n_vehicles)  # Return with 20-50% SOC
    target_soc = np.full(n_vehicles, 90.0)  # Charge to 90%
    arrival_times = np.random.randint(18, 20, n_vehicles)  # Return 6-8 PM
    departure_times = np.random.randint(6, 8, n_vehicles)  # Depart 6-8 AM next day

    # Time-of-use pricing (higher during peak hours)
    electricity_prices = np.array([
        0.08, 0.08, 0.08, 0.08, 0.08, 0.08,  # 12AM-6AM: Off-peak
        0.15, 0.15, 0.20, 0.20, 0.15, 0.15,  # 6AM-12PM: Morning peak
        0.12, 0.12, 0.12, 0.12, 0.20, 0.20,  # 12PM-6PM: Afternoon peak
        0.18, 0.18, 0.12, 0.12, 0.08, 0.08   # 6PM-12AM: Evening/off-peak
    ])

    # Optimize
    optimizer = ChargingStrategyOptimizer(
        n_vehicles=n_vehicles,
        n_chargers=n_chargers,
        charger_power_kw=50.0
    )

    result = optimizer.optimize_schedule(
        arrival_soc=arrival_soc,
        target_soc=target_soc,
        arrival_times=arrival_times,
        departure_times=departure_times,
        electricity_prices=electricity_prices
    )

    print(f"Optimization Status: {result['status']}")
    print(f"Total Cost: ${result['total_cost_usd']:.2f}")
    print(f"Total Energy: {result['total_energy_kwh']:.2f} kWh")

    # Visualize
    optimizer.visualize_schedule(result['schedule'], electricity_prices)
```

## Eco-Routing with Multi-Objective Optimization

```python
import numpy as np
import pandas as pd
from typing import List, Tuple
from scipy.optimize import minimize

class EcoRouter:
    """
    Multi-objective route optimization: minimize energy AND time.

    Uses Pareto optimization to explore trade-off frontier.
    """

    def __init__(
        self,
        road_network: pd.DataFrame,
        battery_capacity_kwh: float = 75.0
    ):
        """
        Args:
            road_network: Graph edges with distance, elevation, speed_limit
            battery_capacity_kwh: Vehicle battery capacity
        """
        self.road_network = road_network
        self.battery_capacity = battery_capacity_kwh

    def compute_route_metrics(
        self,
        route: List[int],
        preference_weight: float = 0.5
    ) -> Tuple[float, float, float]:
        """
        Compute energy, time, and weighted score for route.

        Args:
            route: List of node IDs
            preference_weight: Weight for energy vs time (0=all time, 1=all energy)

        Returns:
            energy_kwh, time_hours, weighted_score
        """
        total_energy = 0
        total_time = 0

        for i in range(len(route) - 1):
            src, dst = route[i], route[i + 1]

            # Find edge
            edge = self.road_network[
                (self.road_network['src'] == src) &
                (self.road_network['dst'] == dst)
            ]

            if edge.empty:
                return float('inf'), float('inf'), float('inf')

            edge = edge.iloc[0]

            # Energy (simplified model)
            base_consumption = 18.0  # kWh per 100 km
            elevation_energy = max(0, edge['elevation_gain_m'] / 100)
            segment_energy = (
                base_consumption * edge['distance_km'] / 100 + elevation_energy
            )

            # Time
            segment_time = edge['distance_km'] / edge['speed_limit_kmh']

            total_energy += segment_energy
            total_time += segment_time

        # Weighted score (normalized)
        # Assuming typical trip: 50 km, 0.5 hours, 10 kWh
        energy_normalized = total_energy / 10
        time_normalized = total_time / 0.5

        weighted_score = (
            preference_weight * energy_normalized +
            (1 - preference_weight) * time_normalized
        )

        return total_energy, total_time, weighted_score

    def find_pareto_routes(
        self,
        start: int,
        end: int,
        candidate_routes: List[List[int]],
        n_pareto: int = 5
    ) -> pd.DataFrame:
        """
        Find Pareto-optimal routes (non-dominated solutions).

        Args:
            start: Start node
            end: End node
            candidate_routes: List of possible routes
            n_pareto: Number of Pareto solutions to return

        Returns:
            DataFrame with Pareto-optimal routes
        """
        results = []

        for route in candidate_routes:
            if route[0] != start or route[-1] != end:
                continue

            energy, time, _ = self.compute_route_metrics(route, preference_weight=0.5)

            if energy < float('inf'):
                results.append({
                    'route': route,
                    'energy_kwh': energy,
                    'time_hours': time
                })

        df = pd.DataFrame(results)

        # Find Pareto frontier (non-dominated solutions)
        is_pareto = np.ones(len(df), dtype=bool)

        for i in range(len(df)):
            for j in range(len(df)):
                if i == j:
                    continue

                # j dominates i if j is better in both objectives
                if (df.loc[j, 'energy_kwh'] <= df.loc[i, 'energy_kwh'] and
                    df.loc[j, 'time_hours'] <= df.loc[i, 'time_hours'] and
                    (df.loc[j, 'energy_kwh'] < df.loc[i, 'energy_kwh'] or
                     df.loc[j, 'time_hours'] < df.loc[i, 'time_hours'])):
                    is_pareto[i] = False
                    break

        pareto_df = df[is_pareto].sort_values('energy_kwh').head(n_pareto)

        return pareto_df


# Example usage
if __name__ == "__main__":
    # Sample road network
    road_network = pd.DataFrame({
        'src': [0, 0, 1, 1, 2],
        'dst': [1, 2, 3, 2, 3],
        'distance_km': [30, 40, 20, 15, 25],
        'elevation_gain_m': [100, 50, 200, 300, 100],
        'speed_limit_kmh': [80, 100, 60, 50, 80]
    })

    # Candidate routes (could be generated by routing algorithm)
    candidate_routes = [
        [0, 1, 3],  # Route A
        [0, 2, 3],  # Route B
        [0, 1, 2, 3]  # Route C
    ]

    router = EcoRouter(road_network)

    # Find Pareto-optimal routes
    pareto_routes = router.find_pareto_routes(
        start=0,
        end=3,
        candidate_routes=candidate_routes
    )

    print("Pareto-Optimal Routes:")
    print(pareto_routes[['energy_kwh', 'time_hours']])
```

## Production Deployment

```yaml
# Energy optimization pipeline
architecture:
  route_service:
    framework: FastAPI
    endpoints:
      - POST /api/v1/optimize-route (request: origin, destination, preferences)
      - GET /api/v1/charging-stations (params: location, radius)
    latency: <500ms p95

  optimization_engine:
    algorithm: DQN (pre-trained) + heuristic fallback
    model_storage: S3 / Azure Blob
    inference: CPU (sufficient for routing)

  charging_optimizer:
    algorithm: Linear programming (PuLP)
    trigger: Nightly batch (10 PM)
    runtime: <5 minutes for 100 vehicles

  data_sources:
    - Road network: OpenStreetMap + HERE Maps
    - Traffic: Real-time API (Google, TomTom)
    - Weather: OpenWeatherMap API
    - Charging stations: PlugShare, ChargePoint API
    - Electricity prices: Utility API

monitoring:
  metrics:
    - Route quality (energy savings vs baseline)
    - Prediction accuracy (estimated vs actual energy)
    - API latency
    - Model drift (consumption patterns change)

  alerts:
    - Prediction error > 20%
    - API latency > 1s
    - Charging optimizer failure
```

## Production Checklist

- [ ] Road network data updated (quarterly refresh)
- [ ] Traffic API integrated with fallback to historical averages
- [ ] Energy model calibrated on real vehicle data (R² > 0.85)
- [ ] Pareto routes validated by drivers (user study)
- [ ] Charging optimizer tested for feasibility (always finds solution)
- [ ] API rate limits configured (avoid external API overages)
- [ ] Model versioning in place (A/B test new algorithms)
- [ ] User preference storage (remember eco vs fast preference)
- [ ] Privacy compliance (location data anonymization)
- [ ] Offline mode (cache recent routes, fallback to heuristics)
