# Fleet Analytics for Connected Vehicles

Build comprehensive analytics dashboards and KPI tracking for vehicle fleets. Focus on operational efficiency, cost optimization, and performance monitoring.

## Key Performance Indicators (KPIs)

### Vehicle Health
- **Average SOH**: Fleet-wide battery health
- **Maintenance Compliance**: % vehicles on schedule
- **Fault Rate**: Faults per 1000 km
- **Downtime**: Hours unavailable per vehicle per month

### Energy & Efficiency
- **Energy Efficiency**: kWh per 100 km (fleet average, by vehicle type)
- **Charging Efficiency**: % of energy delivered vs drawn from grid
- **Idle Time**: % time parked with systems active
- **Regenerative Braking**: % energy recovered

### Utilization
- **Fleet Utilization**: % time vehicles in use
- **Distance per Day**: Average km per vehicle per day
- **Trip Count**: Number of trips per vehicle per week
- **Occupancy Rate**: % trips with passengers (if applicable)

### Cost Metrics
- **Total Cost of Ownership (TCO)**: Per vehicle per year
- **Energy Cost**: $ per kWh charged
- **Maintenance Cost**: $ per km
- **Insurance Cost**: $ per vehicle per year

### Safety & Compliance
- **Incident Rate**: Incidents per million km
- **Driver Safety Score**: 0-100 composite score
- **Compliance Violations**: Speeding, harsh braking events
- **Recall Compliance**: % vehicles with open recalls addressed

## Dashboard Architecture

```python
import pandas as pd
import numpy as np
import plotly.graph_objects as go
import plotly.express as px
from plotly.subplots import make_subplots
from typing import Dict, List
import streamlit as st
from datetime import datetime, timedelta

class FleetAnalyticsDashboard:
    """
    Comprehensive fleet analytics dashboard with real-time KPIs.

    Data sources:
    - Vehicle telemetry (PostgreSQL/TimescaleDB)
    - Maintenance records (ERP system)
    - Charging sessions (Charging management platform)
    - Driver profiles (Driver management system)
    """

    def __init__(self, db_connection):
        """
        Args:
            db_connection: Database connection object
        """
        self.db = db_connection

    def compute_fleet_kpis(
        self,
        start_date: datetime,
        end_date: datetime,
        vehicle_filter: List[str] = None
    ) -> Dict:
        """
        Compute all fleet-level KPIs for specified time range.

        Args:
            start_date: Start of analysis period
            end_date: End of analysis period
            vehicle_filter: Optional list of vehicle IDs to analyze

        Returns:
            Dictionary of KPIs
        """
        # Query vehicle data
        query = f"""
        SELECT
            vehicle_id,
            timestamp,
            odometer_km,
            soc,
            soh,
            energy_consumed_kwh,
            fault_codes,
            is_driving,
            driver_id
        FROM vehicle_telemetry
        WHERE timestamp BETWEEN '{start_date}' AND '{end_date}'
        """

        if vehicle_filter:
            query += f" AND vehicle_id IN ({','.join(map(repr, vehicle_filter))})"

        df = pd.read_sql(query, self.db)

        kpis = {}

        # Vehicle Health KPIs
        kpis['avg_soh'] = df.groupby('vehicle_id')['soh'].last().mean()
        kpis['soh_std'] = df.groupby('vehicle_id')['soh'].last().std()

        # Fault rate
        total_km = (
            df.groupby('vehicle_id')['odometer_km'].max() -
            df.groupby('vehicle_id')['odometer_km'].min()
        ).sum()

        fault_count = df['fault_codes'].notna().sum()
        kpis['fault_rate_per_1000km'] = (fault_count / total_km) * 1000 if total_km > 0 else 0

        # Energy efficiency
        total_energy = df['energy_consumed_kwh'].sum()
        kpis['fleet_efficiency_kwh_per_100km'] = (total_energy / total_km) * 100 if total_km > 0 else 0

        # Utilization
        total_hours = (end_date - start_date).total_seconds() / 3600
        driving_hours = df[df['is_driving']]['timestamp'].count() * (1/3600)  # Assuming 1 Hz data
        kpis['fleet_utilization_pct'] = (driving_hours / (total_hours * df['vehicle_id'].nunique())) * 100

        # Distance metrics
        n_vehicles = df['vehicle_id'].nunique()
        n_days = (end_date - start_date).days
        kpis['avg_km_per_vehicle_per_day'] = total_km / (n_vehicles * n_days) if n_days > 0 else 0

        # Cost metrics (assuming cost models)
        kpis['total_energy_cost_usd'] = total_energy * 0.12  # $0.12 per kWh
        kpis['energy_cost_per_km_usd'] = kpis['total_energy_cost_usd'] / total_km if total_km > 0 else 0

        return kpis

    def plot_soh_distribution(self, vehicle_data: pd.DataFrame) -> go.Figure:
        """
        Plot SOH distribution across fleet.

        Args:
            vehicle_data: DataFrame with columns: vehicle_id, soh
        """
        fig = go.Figure()

        # Histogram
        fig.add_trace(go.Histogram(
            x=vehicle_data['soh'],
            nbinsx=30,
            name='SOH Distribution',
            marker_color='steelblue'
        ))

        # Add threshold lines
        fig.add_vline(x=80, line_dash="dash", line_color="red",
                      annotation_text="EOL Threshold (80%)")
        fig.add_vline(x=90, line_dash="dash", line_color="orange",
                      annotation_text="Maintenance Alert (90%)")

        fig.update_layout(
            title='Fleet Battery SOH Distribution',
            xaxis_title='State of Health (%)',
            yaxis_title='Number of Vehicles',
            showlegend=False
        )

        return fig

    def plot_energy_efficiency_by_vehicle_type(
        self,
        vehicle_data: pd.DataFrame
    ) -> go.Figure:
        """
        Box plot of energy efficiency by vehicle type.

        Args:
            vehicle_data: Columns: vehicle_type, efficiency_kwh_per_100km
        """
        fig = px.box(
            vehicle_data,
            x='vehicle_type',
            y='efficiency_kwh_per_100km',
            color='vehicle_type',
            title='Energy Efficiency by Vehicle Type',
            labels={
                'efficiency_kwh_per_100km': 'Energy Efficiency (kWh/100km)',
                'vehicle_type': 'Vehicle Type'
            }
        )

        fig.update_layout(showlegend=False)
        return fig

    def plot_utilization_heatmap(
        self,
        usage_data: pd.DataFrame
    ) -> go.Figure:
        """
        Heatmap of fleet utilization by day and hour.

        Args:
            usage_data: Columns: timestamp, vehicle_id, is_driving
        """
        # Aggregate to hourly utilization
        usage_data['hour'] = usage_data['timestamp'].dt.hour
        usage_data['day_of_week'] = usage_data['timestamp'].dt.day_name()

        utilization = (
            usage_data.groupby(['day_of_week', 'hour'])['is_driving']
            .mean() * 100
        ).reset_index()

        # Pivot for heatmap
        pivot = utilization.pivot(index='day_of_week', columns='hour', values='is_driving')

        # Reorder days
        day_order = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
        pivot = pivot.reindex(day_order)

        fig = go.Figure(data=go.Heatmap(
            z=pivot.values,
            x=pivot.columns,
            y=pivot.index,
            colorscale='YlOrRd',
            colorbar=dict(title='Utilization %')
        ))

        fig.update_layout(
            title='Fleet Utilization by Day and Hour',
            xaxis_title='Hour of Day',
            yaxis_title='Day of Week'
        )

        return fig

    def plot_maintenance_cost_trend(
        self,
        maintenance_data: pd.DataFrame
    ) -> go.Figure:
        """
        Line plot of monthly maintenance costs.

        Args:
            maintenance_data: Columns: date, cost_usd, vehicle_id
        """
        # Aggregate to monthly
        monthly = (
            maintenance_data
            .groupby(pd.Grouper(key='date', freq='M'))['cost_usd']
            .agg(['sum', 'mean', 'count'])
            .reset_index()
        )

        fig = make_subplots(specs=[[{"secondary_y": True}]])

        # Total cost
        fig.add_trace(
            go.Bar(
                x=monthly['date'],
                y=monthly['sum'],
                name='Total Cost',
                marker_color='steelblue'
            ),
            secondary_y=False
        )

        # Average cost per vehicle
        fig.add_trace(
            go.Scatter(
                x=monthly['date'],
                y=monthly['mean'],
                name='Avg Cost per Vehicle',
                mode='lines+markers',
                marker_color='darkorange',
                line=dict(width=3)
            ),
            secondary_y=True
        )

        fig.update_layout(
            title='Monthly Maintenance Costs',
            xaxis_title='Month'
        )

        fig.update_yaxes(title_text='Total Cost ($)', secondary_y=False)
        fig.update_yaxes(title_text='Avg Cost per Vehicle ($)', secondary_y=True)

        return fig

    def plot_driver_safety_scores(
        self,
        driver_data: pd.DataFrame
    ) -> go.Figure:
        """
        Bar chart of driver safety scores with risk categories.

        Args:
            driver_data: Columns: driver_id, safety_score, risk_category
        """
        # Sort by safety score
        driver_data = driver_data.sort_values('safety_score', ascending=False)

        # Color mapping
        color_map = {
            'Low Risk': 'green',
            'Medium Risk': 'orange',
            'High Risk': 'red'
        }

        colors = driver_data['risk_category'].map(color_map)

        fig = go.Figure()

        fig.add_trace(go.Bar(
            x=driver_data['driver_id'],
            y=driver_data['safety_score'],
            marker_color=colors,
            text=driver_data['safety_score'].round(1),
            textposition='outside'
        ))

        fig.add_hline(y=70, line_dash="dash", line_color="red",
                      annotation_text="Retraining Threshold")

        fig.update_layout(
            title='Driver Safety Scores',
            xaxis_title='Driver ID',
            yaxis_title='Safety Score (0-100)',
            showlegend=False
        )

        return fig

    def generate_executive_summary(self, kpis: Dict) -> str:
        """
        Generate text summary of key findings.

        Args:
            kpis: Dictionary of computed KPIs

        Returns:
            Markdown-formatted summary
        """
        summary = f"""
## Fleet Executive Summary

### Vehicle Health
- **Average SOH**: {kpis['avg_soh']:.1f}% ± {kpis['soh_std']:.1f}%
- **Fault Rate**: {kpis['fault_rate_per_1000km']:.2f} faults per 1000 km

### Energy & Efficiency
- **Fleet Efficiency**: {kpis['fleet_efficiency_kwh_per_100km']:.2f} kWh per 100 km
- **Total Energy Cost**: ${kpis['total_energy_cost_usd']:.2f}
- **Cost per km**: ${kpis['energy_cost_per_km_usd']:.4f}

### Utilization
- **Fleet Utilization**: {kpis['fleet_utilization_pct']:.1f}%
- **Avg Distance**: {kpis['avg_km_per_vehicle_per_day']:.1f} km per vehicle per day

### Recommendations
"""

        # Add recommendations based on KPIs
        if kpis['avg_soh'] < 85:
            summary += "- **ACTION REQUIRED**: Fleet average SOH below 85%. Schedule battery assessments.\n"

        if kpis['fleet_utilization_pct'] < 50:
            summary += "- **OPTIMIZATION**: Fleet utilization below 50%. Consider fleet size optimization.\n"

        if kpis['fleet_efficiency_kwh_per_100km'] > 25:
            summary += "- **EFFICIENCY**: Energy efficiency above industry average. Investigate driver training needs.\n"

        return summary


# Streamlit Dashboard Application
def main():
    st.set_page_config(page_title="Fleet Analytics Dashboard", layout="wide")

    st.title("🚗 Fleet Analytics Dashboard")

    # Sidebar filters
    st.sidebar.header("Filters")
    date_range = st.sidebar.date_input(
        "Date Range",
        value=(datetime.now() - timedelta(days=30), datetime.now())
    )

    vehicle_types = st.sidebar.multiselect(
        "Vehicle Types",
        options=['Sedan', 'SUV', 'Van', 'Truck'],
        default=['Sedan', 'SUV']
    )

    # Initialize dashboard
    # db_connection = create_database_connection()  # Implement as needed
    # dashboard = FleetAnalyticsDashboard(db_connection)

    # Placeholder data for demo
    st.header("Key Performance Indicators")

    col1, col2, col3, col4 = st.columns(4)
    with col1:
        st.metric("Avg SOH", "92.3%", delta="-1.2%")
    with col2:
        st.metric("Fleet Efficiency", "18.5 kWh/100km", delta="+0.3")
    with col3:
        st.metric("Utilization", "68%", delta="+5%")
    with col4:
        st.metric("Fault Rate", "2.1/1000km", delta="-0.5")

    # Charts
    st.header("Detailed Analytics")

    tab1, tab2, tab3, tab4 = st.tabs(
        ["Vehicle Health", "Energy & Efficiency", "Utilization", "Costs"]
    )

    with tab1:
        st.subheader("Battery SOH Distribution")
        # Sample data
        soh_data = pd.DataFrame({
            'vehicle_id': [f'V{i:03d}' for i in range(100)],
            'soh': np.random.normal(92, 5, 100).clip(70, 100)
        })
        # fig = dashboard.plot_soh_distribution(soh_data)
        # st.plotly_chart(fig, use_container_width=True)

    with tab2:
        st.subheader("Energy Efficiency by Vehicle Type")
        # Charts would go here

    with tab3:
        st.subheader("Fleet Utilization Heatmap")
        # Charts would go here

    with tab4:
        st.subheader("Maintenance Cost Trends")
        # Charts would go here


if __name__ == "__main__":
    main()
```

## Advanced Analytics: Clustering & Segmentation

```python
from sklearn.cluster import KMeans, DBSCAN
from sklearn.preprocessing import StandardScaler
from sklearn.decomposition import PCA
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns

class FleetSegmentation:
    """
    Segment fleet vehicles into clusters based on usage patterns.

    Use cases:
    - Identify maintenance risk groups
    - Optimize charging schedules by usage pattern
    - Personalize driver training
    """

    def __init__(self, n_clusters: int = 5):
        """
        Args:
            n_clusters: Number of vehicle segments
        """
        self.n_clusters = n_clusters
        self.scaler = StandardScaler()
        self.kmeans = KMeans(n_clusters=n_clusters, random_state=42)
        self.pca = PCA(n_components=2)

    def engineer_clustering_features(
        self,
        vehicle_data: pd.DataFrame
    ) -> pd.DataFrame:
        """
        Create features for clustering.

        Expected columns:
        - vehicle_id, total_km, avg_trip_distance_km, max_speed_kmh,
        - harsh_accel_rate, harsh_brake_rate, idle_time_pct,
        - energy_efficiency_kwh_per_100km, soh, age_days
        """
        features = pd.DataFrame()

        # Usage intensity
        features['total_km'] = vehicle_data['total_km']
        features['avg_trip_distance_km'] = vehicle_data['avg_trip_distance_km']

        # Driving style
        features['max_speed_kmh'] = vehicle_data['max_speed_kmh']
        features['harsh_accel_rate'] = vehicle_data['harsh_accel_rate']
        features['harsh_brake_rate'] = vehicle_data['harsh_brake_rate']
        features['idle_time_pct'] = vehicle_data['idle_time_pct']

        # Efficiency & health
        features['energy_efficiency'] = vehicle_data['energy_efficiency_kwh_per_100km']
        features['soh'] = vehicle_data['soh']

        # Age
        features['age_days'] = vehicle_data['age_days']

        return features

    def fit_predict(self, X: pd.DataFrame) -> np.ndarray:
        """
        Cluster vehicles and return cluster labels.

        Args:
            X: Feature matrix

        Returns:
            Cluster labels (0 to n_clusters-1)
        """
        # Normalize features
        X_scaled = self.scaler.fit_transform(X)

        # Cluster
        labels = self.kmeans.fit_predict(X_scaled)

        return labels

    def visualize_clusters(self, X: pd.DataFrame, labels: np.ndarray):
        """
        Visualize clusters in 2D using PCA.

        Args:
            X: Feature matrix
            labels: Cluster labels
        """
        # PCA for visualization
        X_scaled = self.scaler.transform(X)
        X_pca = self.pca.fit_transform(X_scaled)

        plt.figure(figsize=(10, 6))
        scatter = plt.scatter(
            X_pca[:, 0],
            X_pca[:, 1],
            c=labels,
            cmap='viridis',
            alpha=0.6,
            edgecolors='k'
        )
        plt.colorbar(scatter, label='Cluster')
        plt.xlabel(f'PC1 ({self.pca.explained_variance_ratio_[0]:.1%} variance)')
        plt.ylabel(f'PC2 ({self.pca.explained_variance_ratio_[1]:.1%} variance)')
        plt.title('Vehicle Fleet Segmentation (PCA Projection)')
        plt.tight_layout()
        plt.show()

    def describe_clusters(
        self,
        X: pd.DataFrame,
        labels: np.ndarray
    ) -> pd.DataFrame:
        """
        Describe each cluster with summary statistics.

        Returns:
            DataFrame with cluster profiles
        """
        X_with_labels = X.copy()
        X_with_labels['cluster'] = labels

        cluster_profiles = X_with_labels.groupby('cluster').agg([
            'mean', 'std', 'min', 'max', 'count'
        ])

        return cluster_profiles

    def assign_cluster_names(
        self,
        cluster_profiles: pd.DataFrame
    ) -> Dict[int, str]:
        """
        Assign interpretable names to clusters based on characteristics.

        Example logic:
        - High km + low SOH = "High Usage, Aging"
        - Low km + high SOH = "Light Usage, Healthy"
        - High harsh_accel + low efficiency = "Aggressive Drivers"
        """
        names = {}

        for cluster_id in cluster_profiles.index.get_level_values(0).unique():
            profile = cluster_profiles.loc[cluster_id]

            # Extract key metrics (using 'mean' aggregation)
            total_km = profile[('total_km', 'mean')]
            soh = profile[('soh', 'mean')]
            harsh_rate = profile[('harsh_accel_rate', 'mean')]
            efficiency = profile[('energy_efficiency', 'mean')]

            # Rule-based naming
            if total_km > 50000 and soh < 85:
                names[cluster_id] = "High Usage, Aging"
            elif total_km < 20000 and soh > 95:
                names[cluster_id] = "Light Usage, Healthy"
            elif harsh_rate > 5 and efficiency > 20:
                names[cluster_id] = "Aggressive Drivers"
            elif efficiency < 15 and soh > 90:
                names[cluster_id] = "Efficient, Well-Maintained"
            else:
                names[cluster_id] = f"Cluster {cluster_id}"

        return names


# Example usage
if __name__ == "__main__":
    # Load vehicle data
    vehicle_df = pd.read_csv('fleet_vehicle_profiles.csv')

    # Initialize segmentation
    segmenter = FleetSegmentation(n_clusters=5)

    # Engineer features
    X = segmenter.engineer_clustering_features(vehicle_df)

    # Cluster
    labels = segmenter.fit_predict(X)

    # Visualize
    segmenter.visualize_clusters(X, labels)

    # Describe clusters
    profiles = segmenter.describe_clusters(X, labels)
    print("\nCluster Profiles:")
    print(profiles)

    # Assign names
    names = segmenter.assign_cluster_names(profiles)
    print("\nCluster Names:")
    for cluster_id, name in names.items():
        print(f"  Cluster {cluster_id}: {name}")
```

## Real-Time Streaming Analytics

```python
from kafka import KafkaConsumer
from influxdb_client import InfluxDBClient, Point
from influxdb_client.client.write_api import SYNCHRONOUS
import json
from typing import Dict
import logging

logger = logging.getLogger(__name__)

class RealTimeFleetAnalytics:
    """
    Stream processing for real-time fleet analytics.

    Architecture:
    - Kafka: Ingest vehicle telemetry
    - Processing: Compute rolling KPIs
    - InfluxDB: Store time-series metrics
    - Grafana: Visualization
    """

    def __init__(
        self,
        kafka_brokers: list,
        kafka_topic: str,
        influx_url: str,
        influx_token: str,
        influx_org: str,
        influx_bucket: str
    ):
        """
        Args:
            kafka_brokers: List of Kafka broker addresses
            kafka_topic: Topic name for vehicle telemetry
            influx_url: InfluxDB server URL
            influx_token: InfluxDB authentication token
            influx_org: InfluxDB organization
            influx_bucket: InfluxDB bucket name
        """
        # Kafka consumer
        self.consumer = KafkaConsumer(
            kafka_topic,
            bootstrap_servers=kafka_brokers,
            value_deserializer=lambda m: json.loads(m.decode('utf-8')),
            auto_offset_reset='latest',
            enable_auto_commit=True
        )

        # InfluxDB client
        self.influx_client = InfluxDBClient(
            url=influx_url,
            token=influx_token,
            org=influx_org
        )
        self.write_api = self.influx_client.write_api(write_options=SYNCHRONOUS)
        self.bucket = influx_bucket
        self.org = influx_org

        # State management (for rolling metrics)
        self.vehicle_states = {}

    def process_telemetry_message(self, message: Dict):
        """
        Process single telemetry message and compute metrics.

        Expected message format:
        {
            "vehicle_id": "V001",
            "timestamp": "2024-03-19T10:00:00Z",
            "odometer_km": 12345.6,
            "soc": 75,
            "soh": 92,
            "voltage": 400.5,
            "current": 150.2,
            "temperature": 35.0,
            "speed_kmh": 80,
            "is_driving": true
        }
        """
        vehicle_id = message['vehicle_id']
        timestamp = message['timestamp']

        # Update vehicle state
        if vehicle_id not in self.vehicle_states:
            self.vehicle_states[vehicle_id] = {
                'last_odometer': message['odometer_km'],
                'energy_consumed_kwh': 0,
                'trip_count': 0
            }

        state = self.vehicle_states[vehicle_id]

        # Compute derived metrics
        distance_delta = message['odometer_km'] - state['last_odometer']

        # Power consumption (simplified)
        power_kw = (message['voltage'] * message['current']) / 1000
        energy_delta_kwh = power_kw * (1 / 3600)  # Assuming 1 second interval

        state['energy_consumed_kwh'] += energy_delta_kwh
        state['last_odometer'] = message['odometer_km']

        # Trip detection
        if message['is_driving'] and not state.get('was_driving', False):
            state['trip_count'] += 1

        state['was_driving'] = message['is_driving']

        # Write metrics to InfluxDB
        self.write_vehicle_metrics(message, distance_delta, energy_delta_kwh)

    def write_vehicle_metrics(
        self,
        message: Dict,
        distance_delta: float,
        energy_delta: float
    ):
        """
        Write processed metrics to InfluxDB.
        """
        vehicle_id = message['vehicle_id']
        timestamp = message['timestamp']

        # Core telemetry
        point = Point("vehicle_telemetry") \
            .tag("vehicle_id", vehicle_id) \
            .field("soc", message['soc']) \
            .field("soh", message['soh']) \
            .field("voltage", message['voltage']) \
            .field("current", message['current']) \
            .field("temperature", message['temperature']) \
            .field("speed_kmh", message['speed_kmh']) \
            .time(timestamp)

        self.write_api.write(bucket=self.bucket, org=self.org, record=point)

        # Derived metrics
        if distance_delta > 0:
            efficiency_kwh_per_100km = (energy_delta / distance_delta) * 100

            point_derived = Point("vehicle_metrics") \
                .tag("vehicle_id", vehicle_id) \
                .field("energy_consumed_kwh", energy_delta) \
                .field("distance_km", distance_delta) \
                .field("efficiency_kwh_per_100km", efficiency_kwh_per_100km) \
                .time(timestamp)

            self.write_api.write(bucket=self.bucket, org=self.org, record=point_derived)

    def run(self):
        """
        Start consuming messages from Kafka and process in real-time.
        """
        logger.info("Starting real-time fleet analytics processor...")

        try:
            for message in self.consumer:
                try:
                    self.process_telemetry_message(message.value)
                except Exception as e:
                    logger.error(f"Error processing message: {e}")

        except KeyboardInterrupt:
            logger.info("Shutting down...")
        finally:
            self.consumer.close()
            self.influx_client.close()


# Example usage
if __name__ == "__main__":
    processor = RealTimeFleetAnalytics(
        kafka_brokers=['localhost:9092'],
        kafka_topic='vehicle-telemetry',
        influx_url='http://localhost:8086',
        influx_token='your-influx-token',
        influx_org='your-org',
        influx_bucket='fleet-analytics'
    )

    processor.run()
```

## Deployment Checklist

- [ ] Data pipeline validated (Kafka -> Processing -> Storage)
- [ ] Dashboard responsive (<2s load time)
- [ ] Real-time metrics update frequency configured (1-10s)
- [ ] Historical data retention policy defined
- [ ] Alert thresholds configured for critical KPIs
- [ ] User access controls implemented (RBAC)
- [ ] Dashboard mobile-responsive
- [ ] Export functionality (CSV, PDF reports)
- [ ] Scheduled reports automated (daily, weekly, monthly)
- [ ] Data quality monitoring (missing data, outliers)
