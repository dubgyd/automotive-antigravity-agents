# Driver Behavior Analysis and Safety Scoring

Analyze driving patterns, compute safety scores, and provide personalized feedback for driver improvement. Focus on risk assessment, insurance optimization, and training recommendations.

## Use Cases

1. **Safety Scoring**: Quantitative assessment of driver risk (0-100 scale)
2. **Insurance Optimization**: Usage-based insurance (UBI) premiums
3. **Driver Training**: Personalized improvement recommendations
4. **Fleet Management**: Identify high-risk drivers for intervention
5. **Accident Prevention**: Predict and prevent risky behaviors

## Feature Engineering

```python
import pandas as pd
import numpy as np
from typing import Dict, Tuple
from scipy.stats import zscore

class DriverBehaviorFeatureEngineer:
    """
    Extract driver behavior features from vehicle telemetry.

    Feature categories:
    - Acceleration patterns (smooth vs aggressive)
    - Braking behavior (harsh braking frequency)
    - Speed management (speeding, speed variance)
    - Cornering (lateral acceleration)
    - Anticipation (time-to-collision events)
    - Distraction indicators (steering wheel anomalies)
    """

    @staticmethod
    def extract_trip_features(trip_data: pd.DataFrame) -> Dict[str, float]:
        """
        Extract behavior features from a single trip.

        Expected columns:
        - timestamp, speed_kmh, acceleration_ms2, lateral_accel_ms2,
        - brake_pressure, steering_angle, distance_to_vehicle_m,
        - speed_limit_kmh (if available)
        """
        features = {}

        # Trip metadata
        features['duration_min'] = (
            (trip_data['timestamp'].max() - trip_data['timestamp'].min())
            .total_seconds() / 60
        )
        features['distance_km'] = trip_data['speed_kmh'].sum() / 3600  # Simplified

        # Acceleration analysis
        accel = trip_data['acceleration_ms2']
        features['accel_mean'] = accel.mean()
        features['accel_std'] = accel.std()
        features['accel_max'] = accel.max()

        # Harsh acceleration events (> 2.5 m/s²)
        harsh_accel = accel > 2.5
        features['harsh_accel_count'] = harsh_accel.sum()
        features['harsh_accel_rate_per_100km'] = (
            features['harsh_accel_count'] / (features['distance_km'] + 1e-3) * 100
        )

        # Braking analysis
        # Assume deceleration is negative acceleration
        decel = accel[accel < 0]
        features['decel_mean'] = decel.mean() if len(decel) > 0 else 0
        features['decel_std'] = decel.std() if len(decel) > 0 else 0

        # Harsh braking events (< -3.0 m/s²)
        harsh_brake = accel < -3.0
        features['harsh_brake_count'] = harsh_brake.sum()
        features['harsh_brake_rate_per_100km'] = (
            features['harsh_brake_count'] / (features['distance_km'] + 1e-3) * 100
        )

        # Brake pressure statistics
        if 'brake_pressure' in trip_data.columns:
            brake = trip_data['brake_pressure']
            features['brake_pressure_mean'] = brake.mean()
            features['brake_pressure_max'] = brake.max()

            # Emergency braking (brake pressure > 0.8)
            emergency_brake = brake > 0.8
            features['emergency_brake_count'] = emergency_brake.sum()

        # Speed management
        speed = trip_data['speed_kmh']
        features['speed_mean'] = speed.mean()
        features['speed_std'] = speed.std()
        features['speed_max'] = speed.max()

        # Speed variance (indication of smooth vs erratic driving)
        features['speed_variance'] = speed.var()

        # Speeding analysis
        if 'speed_limit_kmh' in trip_data.columns:
            speeding = speed > trip_data['speed_limit_kmh']
            features['speeding_pct'] = (speeding.sum() / len(trip_data)) * 100

            # Excessive speeding (>20 km/h over limit)
            excessive_speeding = (speed - trip_data['speed_limit_kmh']) > 20
            features['excessive_speeding_pct'] = (
                excessive_speeding.sum() / len(trip_data)
            ) * 100
        else:
            features['speeding_pct'] = 0
            features['excessive_speeding_pct'] = 0

        # Cornering analysis
        if 'lateral_accel_ms2' in trip_data.columns:
            lateral_accel = trip_data['lateral_accel_ms2']
            features['lateral_accel_mean'] = abs(lateral_accel).mean()
            features['lateral_accel_max'] = abs(lateral_accel).max()

            # Harsh cornering (lateral accel > 4 m/s²)
            harsh_corner = abs(lateral_accel) > 4.0
            features['harsh_corner_count'] = harsh_corner.sum()
            features['harsh_corner_rate_per_100km'] = (
                features['harsh_corner_count'] / (features['distance_km'] + 1e-3) * 100
            )

        # Anticipation and safety margins
        if 'distance_to_vehicle_m' in trip_data.columns:
            # Time-to-collision (TTC) at current speed
            # TTC = distance / speed
            ttc = trip_data['distance_to_vehicle_m'] / (
                trip_data['speed_kmh'] / 3.6 + 1e-3
            )  # Convert to m/s

            # Critical TTC events (<2 seconds)
            critical_ttc = ttc < 2.0
            features['critical_ttc_count'] = critical_ttc.sum()
            features['critical_ttc_rate_per_100km'] = (
                features['critical_ttc_count'] / (features['distance_km'] + 1e-3) * 100
            )

            features['avg_following_distance_m'] = trip_data['distance_to_vehicle_m'].mean()

        # Steering behavior (distraction indicator)
        if 'steering_angle' in trip_data.columns:
            steering = trip_data['steering_angle']
            features['steering_variance'] = steering.diff().abs().var()

            # Erratic steering (high frequency oscillations)
            steering_changes = abs(steering.diff())
            features['erratic_steering_events'] = (steering_changes > 10).sum()

        # Idle time (inefficient driving)
        idle = (speed < 1) & (accel.abs() < 0.1)
        features['idle_time_min'] = idle.sum() / 60  # Assuming 1 Hz data

        return features

    @staticmethod
    def aggregate_driver_features(
        trip_features_list: list
    ) -> pd.DataFrame:
        """
        Aggregate features across multiple trips for driver profiling.

        Args:
            trip_features_list: List of feature dictionaries (one per trip)

        Returns:
            DataFrame with aggregated driver statistics
        """
        df = pd.DataFrame(trip_features_list)

        # Aggregate statistics
        agg_features = {}

        # Mean metrics
        mean_cols = [
            'harsh_accel_rate_per_100km',
            'harsh_brake_rate_per_100km',
            'harsh_corner_rate_per_100km',
            'speeding_pct',
            'excessive_speeding_pct',
            'speed_variance',
            'critical_ttc_rate_per_100km'
        ]

        for col in mean_cols:
            if col in df.columns:
                agg_features[f'{col}_mean'] = df[col].mean()
                agg_features[f'{col}_std'] = df[col].std()

        # Count metrics
        count_cols = [
            'harsh_accel_count',
            'harsh_brake_count',
            'emergency_brake_count',
            'critical_ttc_count'
        ]

        for col in count_cols:
            if col in df.columns:
                agg_features[f'{col}_total'] = df[col].sum()

        # Totals
        agg_features['total_trips'] = len(df)
        agg_features['total_distance_km'] = df['distance_km'].sum()
        agg_features['total_duration_min'] = df['duration_min'].sum()

        return pd.DataFrame([agg_features])


# Example usage
if __name__ == "__main__":
    # Load trip data
    trip_df = pd.read_parquet('trip_001.parquet')

    # Extract features
    engineer = DriverBehaviorFeatureEngineer()
    features = engineer.extract_trip_features(trip_df)

    print("Trip Features:")
    for key, value in features.items():
        print(f"  {key}: {value:.3f}")
```

## Safety Scoring Model

```python
import numpy as np
import pandas as pd
from sklearn.preprocessing import MinMaxScaler
from typing import Dict, Tuple
import joblib

class DriverSafetyScoringModel:
    """
    Compute comprehensive driver safety score (0-100).

    Methodology:
    - Weighted composite of sub-scores
    - Penalize risky behaviors
    - Reward safe driving patterns
    - Calibrated against industry benchmarks
    """

    def __init__(self):
        """
        Initialize scoring model with component weights.
        """
        # Component weights (must sum to 1.0)
        self.weights = {
            'acceleration': 0.20,
            'braking': 0.25,
            'speed': 0.25,
            'cornering': 0.15,
            'anticipation': 0.15
        }

        # Benchmark values (50th percentile of safe drivers)
        self.benchmarks = {
            'harsh_accel_rate_per_100km': 5.0,
            'harsh_brake_rate_per_100km': 3.0,
            'harsh_corner_rate_per_100km': 2.0,
            'speeding_pct': 10.0,
            'excessive_speeding_pct': 1.0,
            'speed_variance': 150.0,
            'critical_ttc_rate_per_100km': 2.0
        }

        # Penalty factors (multiplier for scores below threshold)
        self.penalties = {
            'emergency_brake_count': 5.0,  # -5 points per event
            'critical_ttc_count': 3.0       # -3 points per event
        }

    def compute_acceleration_score(self, features: Dict) -> float:
        """
        Score acceleration behavior (0-100).

        Lower harsh acceleration rate = higher score.
        """
        rate = features.get('harsh_accel_rate_per_100km_mean', 0)
        benchmark = self.benchmarks['harsh_accel_rate_per_100km']

        # Exponential decay: score = 100 * exp(-rate / benchmark)
        score = 100 * np.exp(-rate / benchmark)

        return np.clip(score, 0, 100)

    def compute_braking_score(self, features: Dict) -> float:
        """
        Score braking behavior (0-100).

        Penalize harsh braking and emergency stops.
        """
        rate = features.get('harsh_brake_rate_per_100km_mean', 0)
        benchmark = self.benchmarks['harsh_brake_rate_per_100km']

        base_score = 100 * np.exp(-rate / benchmark)

        # Apply penalty for emergency braking
        emergency_count = features.get('emergency_brake_count_total', 0)
        penalty = emergency_count * self.penalties['emergency_brake_count']

        score = base_score - penalty

        return np.clip(score, 0, 100)

    def compute_speed_score(self, features: Dict) -> float:
        """
        Score speed management (0-100).

        Penalize speeding and erratic speed changes.
        """
        speeding_pct = features.get('speeding_pct_mean', 0)
        excessive_pct = features.get('excessive_speeding_pct_mean', 0)
        speed_var = features.get('speed_variance_mean', 0)

        # Speed limit compliance
        speeding_benchmark = self.benchmarks['speeding_pct']
        speeding_score = 100 * np.exp(-speeding_pct / speeding_benchmark)

        # Excessive speeding (heavy penalty)
        excessive_benchmark = self.benchmarks['excessive_speeding_pct']
        excessive_penalty = 50 * (excessive_pct / (excessive_benchmark + 1))

        # Speed smoothness
        variance_benchmark = self.benchmarks['speed_variance']
        smoothness_score = 100 * np.exp(-speed_var / variance_benchmark)

        # Weighted average
        score = (
            0.5 * speeding_score +
            0.3 * smoothness_score -
            0.2 * excessive_penalty
        )

        return np.clip(score, 0, 100)

    def compute_cornering_score(self, features: Dict) -> float:
        """
        Score cornering behavior (0-100).

        Reward smooth cornering, penalize harsh turns.
        """
        rate = features.get('harsh_corner_rate_per_100km_mean', 0)
        benchmark = self.benchmarks['harsh_corner_rate_per_100km']

        score = 100 * np.exp(-rate / benchmark)

        return np.clip(score, 0, 100)

    def compute_anticipation_score(self, features: Dict) -> float:
        """
        Score anticipation and safety margins (0-100).

        Penalize tailgating and critical TTC events.
        """
        ttc_rate = features.get('critical_ttc_rate_per_100km_mean', 0)
        benchmark = self.benchmarks['critical_ttc_rate_per_100km']

        base_score = 100 * np.exp(-ttc_rate / benchmark)

        # Apply penalty for critical TTC events
        ttc_count = features.get('critical_ttc_count_total', 0)
        penalty = ttc_count * self.penalties['critical_ttc_count']

        score = base_score - penalty

        return np.clip(score, 0, 100)

    def compute_overall_score(self, features: Dict) -> Tuple[float, Dict[str, float]]:
        """
        Compute weighted overall safety score.

        Returns:
            overall_score: Composite score (0-100)
            component_scores: Dictionary of sub-scores
        """
        # Compute component scores
        components = {
            'acceleration': self.compute_acceleration_score(features),
            'braking': self.compute_braking_score(features),
            'speed': self.compute_speed_score(features),
            'cornering': self.compute_cornering_score(features),
            'anticipation': self.compute_anticipation_score(features)
        }

        # Weighted average
        overall = sum(
            components[key] * self.weights[key]
            for key in components
        )

        return overall, components

    def classify_risk_level(self, score: float) -> str:
        """
        Classify driver into risk category.

        Args:
            score: Safety score (0-100)

        Returns:
            Risk category string
        """
        if score >= 85:
            return 'Low Risk'
        elif score >= 70:
            return 'Medium Risk'
        elif score >= 50:
            return 'High Risk'
        else:
            return 'Critical Risk'

    def generate_feedback(
        self,
        components: Dict[str, float]
    ) -> list:
        """
        Generate personalized feedback for driver improvement.

        Args:
            components: Component scores dictionary

        Returns:
            List of improvement recommendations
        """
        feedback = []

        # Identify weakest areas
        sorted_components = sorted(components.items(), key=lambda x: x[1])

        for component, score in sorted_components[:2]:  # Focus on 2 worst
            if score < 70:
                if component == 'acceleration':
                    feedback.append(
                        "⚠️ Reduce harsh acceleration. Gradually increase speed to "
                        "improve fuel efficiency and safety."
                    )
                elif component == 'braking':
                    feedback.append(
                        "⚠️ Anticipate stops earlier to avoid harsh braking. "
                        "Maintain safe following distance."
                    )
                elif component == 'speed':
                    feedback.append(
                        "⚠️ Adhere to speed limits and maintain consistent speed. "
                        "Reduce speeding incidents."
                    )
                elif component == 'cornering':
                    feedback.append(
                        "⚠️ Slow down before corners. Smooth steering reduces tire wear "
                        "and improves stability."
                    )
                elif component == 'anticipation':
                    feedback.append(
                        "⚠️ Increase following distance. Avoid tailgating to reduce "
                        "collision risk."
                    )

        # Positive reinforcement for strong areas
        best_component = max(components.items(), key=lambda x: x[1])
        if best_component[1] >= 90:
            feedback.append(
                f"✅ Excellent {best_component[0]} behavior! Keep it up."
            )

        return feedback


# Example usage
if __name__ == "__main__":
    # Sample driver features (aggregated from multiple trips)
    driver_features = {
        'harsh_accel_rate_per_100km_mean': 7.2,
        'harsh_brake_rate_per_100km_mean': 4.5,
        'harsh_corner_rate_per_100km_mean': 1.8,
        'speeding_pct_mean': 15.0,
        'excessive_speeding_pct_mean': 2.5,
        'speed_variance_mean': 180.0,
        'critical_ttc_rate_per_100km_mean': 3.0,
        'emergency_brake_count_total': 2,
        'critical_ttc_count_total': 5
    }

    # Compute safety score
    scorer = DriverSafetyScoringModel()
    overall_score, components = scorer.compute_overall_score(driver_features)
    risk_level = scorer.classify_risk_level(overall_score)

    print(f"\nOverall Safety Score: {overall_score:.1f} / 100")
    print(f"Risk Level: {risk_level}\n")

    print("Component Scores:")
    for component, score in components.items():
        print(f"  {component.capitalize()}: {score:.1f}")

    print("\nPersonalized Feedback:")
    feedback = scorer.generate_feedback(components)
    for item in feedback:
        print(f"  {item}")
```

## Driver Clustering

```python
from sklearn.cluster import KMeans
from sklearn.preprocessing import StandardScaler
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns

class DriverClustering:
    """
    Cluster drivers into behavioral profiles.

    Profiles:
    - Conservative: Low speeds, smooth acceleration/braking
    - Aggressive: High speeds, harsh maneuvers
    - Efficient: Optimized for fuel/energy efficiency
    - Distracted: Erratic patterns, low anticipation
    """

    def __init__(self, n_clusters: int = 4):
        self.n_clusters = n_clusters
        self.scaler = StandardScaler()
        self.kmeans = KMeans(n_clusters=n_clusters, random_state=42)

    def prepare_features(self, driver_data: pd.DataFrame) -> pd.DataFrame:
        """
        Select and normalize features for clustering.

        Expected columns: driver_id, harsh_accel_rate, harsh_brake_rate,
        speeding_pct, speed_variance, critical_ttc_rate
        """
        feature_cols = [
            'harsh_accel_rate_per_100km_mean',
            'harsh_brake_rate_per_100km_mean',
            'speeding_pct_mean',
            'speed_variance_mean',
            'critical_ttc_rate_per_100km_mean'
        ]

        X = driver_data[feature_cols]
        X_scaled = self.scaler.fit_transform(X)

        return X_scaled, feature_cols

    def fit_predict(self, driver_data: pd.DataFrame) -> np.ndarray:
        """
        Cluster drivers and return labels.

        Returns:
            Cluster labels (0 to n_clusters-1)
        """
        X_scaled, _ = self.prepare_features(driver_data)
        labels = self.kmeans.fit_predict(X_scaled)

        return labels

    def visualize_clusters(
        self,
        driver_data: pd.DataFrame,
        labels: np.ndarray
    ):
        """
        Visualize driver clusters using pair plot.
        """
        # Add cluster labels
        driver_data_labeled = driver_data.copy()
        driver_data_labeled['cluster'] = labels

        # Select key features for visualization
        viz_features = [
            'harsh_accel_rate_per_100km_mean',
            'harsh_brake_rate_per_100km_mean',
            'speeding_pct_mean',
            'cluster'
        ]

        sns.pairplot(
            driver_data_labeled[viz_features],
            hue='cluster',
            palette='viridis',
            diag_kind='kde'
        )
        plt.suptitle('Driver Behavior Clusters', y=1.02)
        plt.show()

    def describe_clusters(
        self,
        driver_data: pd.DataFrame,
        labels: np.ndarray
    ) -> pd.DataFrame:
        """
        Describe cluster characteristics.

        Returns:
            DataFrame with cluster profiles
        """
        driver_data_labeled = driver_data.copy()
        driver_data_labeled['cluster'] = labels

        profiles = driver_data_labeled.groupby('cluster').agg({
            'harsh_accel_rate_per_100km_mean': 'mean',
            'harsh_brake_rate_per_100km_mean': 'mean',
            'speeding_pct_mean': 'mean',
            'speed_variance_mean': 'mean',
            'critical_ttc_rate_per_100km_mean': 'mean'
        }).round(2)

        return profiles

    def assign_profile_names(
        self,
        profiles: pd.DataFrame
    ) -> Dict[int, str]:
        """
        Assign interpretable names to clusters.
        """
        names = {}

        for cluster_id in profiles.index:
            accel = profiles.loc[cluster_id, 'harsh_accel_rate_per_100km_mean']
            brake = profiles.loc[cluster_id, 'harsh_brake_rate_per_100km_mean']
            speeding = profiles.loc[cluster_id, 'speeding_pct_mean']

            # Rule-based naming
            if accel < 3 and brake < 2 and speeding < 5:
                names[cluster_id] = "Conservative"
            elif accel > 8 and brake > 5:
                names[cluster_id] = "Aggressive"
            elif speeding > 20:
                names[cluster_id] = "Speeder"
            else:
                names[cluster_id] = "Average"

        return names
```

## Deployment Architecture

```yaml
# Driver behavior analytics pipeline
pipeline:
  data_collection:
    source: Vehicle telemetry (CAN bus) + GPS
    frequency: 10 Hz (acceleration, speed), 1 Hz (location)
    storage: TimescaleDB (raw) + Parquet (trips)

  trip_segmentation:
    algorithm: Speed-based (ignition on/off or idle detection)
    min_duration: 2 minutes
    min_distance: 1 km

  feature_extraction:
    engine: Apache Spark (batch) or Python (streaming)
    frequency: Per-trip (real-time) + weekly aggregation
    storage: PostgreSQL (features table)

  scoring:
    model: Rule-based composite score
    update_frequency: Daily (driver profile)
    storage: PostgreSQL (scores table)

  dashboard:
    framework: Streamlit / React
    update_frequency: Real-time (trip-level), daily (aggregates)
    features: Score trends, feedback, leaderboard

monitoring:
  metrics:
    - Score distribution (fleet-wide)
    - Score volatility (per driver)
    - Feature extraction success rate
    - Dashboard latency

alerts:
  - Critical risk driver detected (score < 50)
  - Repeated risky behaviors (3+ harsh events per trip)
  - Score degradation (>10 point drop in 7 days)
```

## Production Checklist

- [ ] Trip segmentation validated (accuracy > 95%)
- [ ] Feature extraction handles edge cases (short trips, missing sensors)
- [ ] Score calibration validated against insurance claims data
- [ ] Feedback messages reviewed for clarity and positivity
- [ ] Dashboard responsive (<2s load time)
- [ ] Privacy compliance (GDPR, CCPA) - anonymization
- [ ] Driver consent workflow implemented
- [ ] Alert thresholds configured (avoid alert fatigue)
- [ ] A/B testing for scoring algorithm changes
- [ ] Driver appeal process documented
