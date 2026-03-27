# Anomaly Detection for Automotive Systems

Detect unusual vehicle behavior across battery systems, sensors, and drivetrain components using unsupervised ML techniques.

## Use Cases

1. **Battery Anomalies**: Cell voltage drift, thermal runaway precursors, SOC inconsistencies
2. **Sensor Failures**: LiDAR/radar malfunction, camera degradation, IMU drift
3. **Drivetrain Issues**: Motor vibration anomalies, inverter faults, cooling system failures
4. **Charging Anomalies**: Abnormal charging curves, connector issues, grid irregularities

## Algorithm Selection

### Isolation Forest
**Best for**: High-dimensional sensor data with mixed feature types

**Pros**:
- Handles non-Gaussian distributions
- Efficient for large datasets
- No assumptions about normal behavior shape
- Low memory footprint

**Cons**:
- Sensitive to feature scaling
- May struggle with local anomalies

**Use cases**: Real-time battery monitoring, sensor fault detection

### Autoencoder (Deep Learning)
**Best for**: Complex time-series patterns, image-based anomalies

**Pros**:
- Learns compressed representation
- Excellent for time-series sequences
- Handles multi-modal data
- Can detect subtle pattern deviations

**Cons**:
- Requires significant training data
- Computationally expensive
- Black-box interpretation

**Use cases**: Camera degradation, LiDAR point cloud anomalies, battery degradation patterns

### Local Outlier Factor (LOF)
**Best for**: Local density-based anomalies

**Pros**:
- Detects local outliers in varying density regions
- No global threshold needed
- Good for spatial data

**Cons**:
- Computationally intensive for large datasets
- Requires careful k-neighbor selection

**Use cases**: Geographic anomalies (GPS data), fleet-wide comparison

### One-Class SVM
**Best for**: Small, well-defined normal behavior regions

**Pros**:
- Kernel trick for non-linear boundaries
- Robust to outliers in training set
- Theoretical foundation

**Cons**:
- Difficult hyperparameter tuning
- Slow on large datasets
- Memory intensive

**Use cases**: Safety-critical systems with narrow normal operating ranges

## Feature Engineering

### Battery Systems
```python
features = [
    # Static features
    'cell_voltage_mean', 'cell_voltage_std', 'cell_voltage_range',
    'temperature_mean', 'temperature_std', 'temperature_max',
    'soc_value', 'soh_estimate', 'current_value',

    # Derived features
    'voltage_imbalance_ratio',  # max_voltage / min_voltage
    'thermal_gradient',          # max_temp - min_temp
    'charge_acceptance',         # dSOC / dTime at constant current

    # Time-series features (sliding window)
    'voltage_trend_5min',        # Linear regression slope
    'temperature_volatility',    # Rolling std deviation
    'current_spike_count',       # Threshold crossings

    # Cross-domain features
    'power_efficiency',          # Output power / Input power
    'thermal_power_ratio'        # Temperature rise / Power delivered
]
```

### Sensor Systems
```python
features = [
    # LiDAR
    'point_cloud_density', 'max_range', 'noise_level',
    'ground_plane_fit_error', 'object_count',

    # Camera
    'brightness_mean', 'contrast_std', 'edge_density',
    'motion_blur_score', 'lens_distortion_coefficient',

    # IMU
    'accel_magnitude_mean', 'gyro_drift_rate',
    'vibration_frequency_peak', 'calibration_offset',

    # GPS
    'hdop', 'satellite_count', 'position_jump_distance',
    'velocity_consistency_score'
]
```

## Implementation Example: Isolation Forest for Battery

```python
import numpy as np
import pandas as pd
from sklearn.ensemble import IsolationForest
from sklearn.preprocessing import StandardScaler
from sklearn.pipeline import Pipeline
import joblib
from typing import Dict, List, Tuple
import logging

logger = logging.getLogger(__name__)

class BatteryAnomalyDetector:
    """
    Isolation Forest-based anomaly detection for battery systems.

    Detects:
    - Cell voltage imbalances
    - Thermal anomalies
    - Charge/discharge irregularities
    - SOH degradation patterns
    """

    def __init__(
        self,
        contamination: float = 0.01,
        n_estimators: int = 100,
        max_samples: int = 256,
        random_state: int = 42
    ):
        """
        Args:
            contamination: Expected proportion of outliers (0.01 = 1%)
            n_estimators: Number of isolation trees
            max_samples: Samples per tree (higher = more global detection)
            random_state: Reproducibility seed
        """
        self.pipeline = Pipeline([
            ('scaler', StandardScaler()),
            ('detector', IsolationForest(
                contamination=contamination,
                n_estimators=n_estimators,
                max_samples=max_samples,
                random_state=random_state,
                n_jobs=-1
            ))
        ])
        self.feature_names = None
        self.trained = False

    def engineer_features(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        Create derived features from raw battery telemetry.

        Expected columns:
        - cell_voltages: list of voltages [V]
        - cell_temperatures: list of temps [C]
        - soc: State of charge [0-100]
        - soh: State of health [0-100]
        - current: Pack current [A]
        - timestamp: datetime
        """
        features = pd.DataFrame()

        # Voltage statistics
        voltages = np.array(df['cell_voltages'].tolist())
        features['voltage_mean'] = voltages.mean(axis=1)
        features['voltage_std'] = voltages.std(axis=1)
        features['voltage_min'] = voltages.min(axis=1)
        features['voltage_max'] = voltages.max(axis=1)
        features['voltage_range'] = features['voltage_max'] - features['voltage_min']
        features['voltage_imbalance'] = features['voltage_max'] / (features['voltage_min'] + 1e-6)

        # Temperature statistics
        temps = np.array(df['cell_temperatures'].tolist())
        features['temp_mean'] = temps.mean(axis=1)
        features['temp_std'] = temps.std(axis=1)
        features['temp_max'] = temps.max(axis=1)
        features['thermal_gradient'] = temps.max(axis=1) - temps.min(axis=1)

        # State features
        features['soc'] = df['soc']
        features['soh'] = df['soh']
        features['current'] = df['current']
        features['power'] = df['current'] * features['voltage_mean']

        # Time-series features (requires sorted by timestamp)
        df_sorted = df.sort_values('timestamp')
        features['voltage_trend_5min'] = (
            features['voltage_mean']
            .rolling(window=30, min_periods=5)  # 30 samples @ 10s = 5min
            .apply(lambda x: np.polyfit(range(len(x)), x, 1)[0])
        )

        features['temp_volatility'] = (
            features['temp_mean']
            .rolling(window=12, min_periods=3)
            .std()
        )

        # Efficiency metrics
        features['thermal_power_ratio'] = (
            features['thermal_gradient'] / (abs(features['power']) + 1.0)
        )

        # Handle NaN from rolling windows
        features = features.fillna(method='bfill').fillna(0)

        self.feature_names = features.columns.tolist()
        return features

    def fit(self, df: pd.DataFrame) -> 'BatteryAnomalyDetector':
        """
        Train detector on normal operating data.

        Args:
            df: DataFrame with battery telemetry (normal conditions only)

        Returns:
            self for chaining
        """
        features = self.engineer_features(df)

        logger.info(f"Training on {len(features)} samples with {len(self.feature_names)} features")
        self.pipeline.fit(features)
        self.trained = True

        # Compute baseline statistics
        predictions = self.pipeline.predict(features)
        scores = self.pipeline.decision_function(features)

        logger.info(f"Training complete. Anomaly rate: {(predictions == -1).mean():.2%}")
        logger.info(f"Score range: [{scores.min():.3f}, {scores.max():.3f}]")

        return self

    def predict(
        self,
        df: pd.DataFrame,
        return_scores: bool = False
    ) -> np.ndarray | Tuple[np.ndarray, np.ndarray]:
        """
        Detect anomalies in new data.

        Args:
            df: DataFrame with battery telemetry
            return_scores: If True, return (labels, scores) tuple

        Returns:
            labels: 1 for normal, -1 for anomaly
            scores: (optional) Anomaly scores (lower = more anomalous)
        """
        if not self.trained:
            raise ValueError("Detector must be trained before prediction")

        features = self.engineer_features(df)
        labels = self.pipeline.predict(features)

        if return_scores:
            scores = self.pipeline.decision_function(features)
            return labels, scores

        return labels

    def explain_anomaly(self, df: pd.DataFrame, index: int) -> Dict[str, float]:
        """
        Explain why a specific sample was flagged as anomalous.

        Returns feature contributions sorted by absolute deviation from mean.
        """
        if not self.trained:
            raise ValueError("Detector must be trained before explanation")

        features = self.engineer_features(df)
        sample = features.iloc[index]

        # Get feature means from training (after scaling)
        scaler = self.pipeline.named_steps['scaler']
        feature_means = scaler.mean_
        feature_stds = scaler.scale_

        # Compute z-scores
        z_scores = {}
        for i, feature_name in enumerate(self.feature_names):
            z_score = abs((sample[feature_name] - feature_means[i]) / feature_stds[i])
            z_scores[feature_name] = z_score

        # Sort by deviation magnitude
        sorted_features = sorted(z_scores.items(), key=lambda x: x[1], reverse=True)

        return dict(sorted_features)

    def save(self, path: str):
        """Save trained model to disk."""
        if not self.trained:
            raise ValueError("Cannot save untrained model")

        joblib.dump({
            'pipeline': self.pipeline,
            'feature_names': self.feature_names
        }, path)
        logger.info(f"Model saved to {path}")

    @classmethod
    def load(cls, path: str) -> 'BatteryAnomalyDetector':
        """Load trained model from disk."""
        data = joblib.load(path)
        detector = cls()
        detector.pipeline = data['pipeline']
        detector.feature_names = data['feature_names']
        detector.trained = True
        logger.info(f"Model loaded from {path}")
        return detector


# Example usage
if __name__ == "__main__":
    # Load training data (normal operation only)
    train_df = pd.read_parquet('battery_telemetry_normal.parquet')

    # Train detector
    detector = BatteryAnomalyDetector(contamination=0.01)
    detector.fit(train_df)

    # Save model
    detector.save('battery_anomaly_detector.pkl')

    # Detect anomalies in new data
    test_df = pd.read_parquet('battery_telemetry_recent.parquet')
    labels, scores = detector.predict(test_df, return_scores=True)

    # Analyze anomalies
    anomaly_indices = np.where(labels == -1)[0]
    print(f"Detected {len(anomaly_indices)} anomalies ({len(anomaly_indices)/len(test_df):.2%})")

    for idx in anomaly_indices[:5]:  # Show first 5
        print(f"\nAnomaly at index {idx} (score: {scores[idx]:.3f})")
        explanation = detector.explain_anomaly(test_df, idx)
        print("Top contributing features:")
        for feature, z_score in list(explanation.items())[:5]:
            print(f"  {feature}: z-score = {z_score:.2f}")
```

## Autoencoder for Time-Series Anomalies

```python
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import Dataset, DataLoader
import numpy as np
import pandas as pd
from typing import Tuple

class BatterySequenceDataset(Dataset):
    """Dataset for time-series battery data."""

    def __init__(self, sequences: np.ndarray):
        """
        Args:
            sequences: (N, seq_len, n_features) array
        """
        self.sequences = torch.FloatTensor(sequences)

    def __len__(self):
        return len(self.sequences)

    def __getitem__(self, idx):
        return self.sequences[idx]


class LSTMAutoencoder(nn.Module):
    """
    LSTM-based autoencoder for battery time-series anomaly detection.

    Architecture:
    - Encoder: LSTM -> reduces sequence to latent vector
    - Decoder: LSTM -> reconstructs sequence from latent
    - Loss: MSE between input and reconstruction
    """

    def __init__(
        self,
        n_features: int,
        seq_len: int,
        latent_dim: int = 16,
        hidden_dim: int = 64,
        n_layers: int = 2,
        dropout: float = 0.2
    ):
        super().__init__()

        self.n_features = n_features
        self.seq_len = seq_len
        self.latent_dim = latent_dim

        # Encoder: (batch, seq_len, n_features) -> (batch, latent_dim)
        self.encoder_lstm = nn.LSTM(
            input_size=n_features,
            hidden_size=hidden_dim,
            num_layers=n_layers,
            batch_first=True,
            dropout=dropout if n_layers > 1 else 0
        )
        self.encoder_fc = nn.Linear(hidden_dim, latent_dim)

        # Decoder: (batch, latent_dim) -> (batch, seq_len, n_features)
        self.decoder_fc = nn.Linear(latent_dim, hidden_dim)
        self.decoder_lstm = nn.LSTM(
            input_size=hidden_dim,
            hidden_size=hidden_dim,
            num_layers=n_layers,
            batch_first=True,
            dropout=dropout if n_layers > 1 else 0
        )
        self.output_fc = nn.Linear(hidden_dim, n_features)

    def encode(self, x: torch.Tensor) -> torch.Tensor:
        """Encode sequence to latent vector."""
        # x: (batch, seq_len, n_features)
        _, (hidden, _) = self.encoder_lstm(x)
        # hidden: (n_layers, batch, hidden_dim) -> take last layer
        latent = self.encoder_fc(hidden[-1])  # (batch, latent_dim)
        return latent

    def decode(self, latent: torch.Tensor) -> torch.Tensor:
        """Decode latent vector to sequence."""
        # latent: (batch, latent_dim)
        hidden = self.decoder_fc(latent)  # (batch, hidden_dim)

        # Repeat hidden for each time step
        hidden_seq = hidden.unsqueeze(1).repeat(1, self.seq_len, 1)
        # hidden_seq: (batch, seq_len, hidden_dim)

        decoder_out, _ = self.decoder_lstm(hidden_seq)
        reconstruction = self.output_fc(decoder_out)
        # reconstruction: (batch, seq_len, n_features)

        return reconstruction

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        """Forward pass: encode then decode."""
        latent = self.encode(x)
        reconstruction = self.decode(latent)
        return reconstruction


class AutoencoderAnomalyDetector:
    """Autoencoder-based anomaly detection for time-series data."""

    def __init__(
        self,
        n_features: int,
        seq_len: int,
        latent_dim: int = 16,
        device: str = 'cpu'
    ):
        self.model = LSTMAutoencoder(
            n_features=n_features,
            seq_len=seq_len,
            latent_dim=latent_dim
        ).to(device)

        self.device = device
        self.threshold = None
        self.scaler_mean = None
        self.scaler_std = None

    def train(
        self,
        sequences: np.ndarray,
        epochs: int = 50,
        batch_size: int = 64,
        lr: float = 0.001
    ):
        """
        Train autoencoder on normal sequences.

        Args:
            sequences: (N, seq_len, n_features) array of normal data
            epochs: Training epochs
            batch_size: Batch size
            lr: Learning rate
        """
        # Normalize
        self.scaler_mean = sequences.mean(axis=(0, 1))
        self.scaler_std = sequences.std(axis=(0, 1)) + 1e-6
        sequences_norm = (sequences - self.scaler_mean) / self.scaler_std

        # Create data loader
        dataset = BatterySequenceDataset(sequences_norm)
        loader = DataLoader(dataset, batch_size=batch_size, shuffle=True)

        # Training
        optimizer = optim.Adam(self.model.parameters(), lr=lr)
        criterion = nn.MSELoss()

        self.model.train()
        for epoch in range(epochs):
            total_loss = 0
            for batch in loader:
                batch = batch.to(self.device)

                optimizer.zero_grad()
                reconstruction = self.model(batch)
                loss = criterion(reconstruction, batch)
                loss.backward()
                optimizer.step()

                total_loss += loss.item()

            avg_loss = total_loss / len(loader)
            if (epoch + 1) % 10 == 0:
                print(f"Epoch {epoch+1}/{epochs}, Loss: {avg_loss:.6f}")

        # Compute threshold (95th percentile of training reconstruction errors)
        self.model.eval()
        with torch.no_grad():
            all_errors = []
            for batch in DataLoader(dataset, batch_size=batch_size):
                batch = batch.to(self.device)
                reconstruction = self.model(batch)
                errors = torch.mean((batch - reconstruction) ** 2, dim=(1, 2))
                all_errors.extend(errors.cpu().numpy())

            self.threshold = np.percentile(all_errors, 95)
            print(f"Anomaly threshold set to: {self.threshold:.6f}")

    def predict(self, sequences: np.ndarray) -> Tuple[np.ndarray, np.ndarray]:
        """
        Detect anomalies in sequences.

        Returns:
            labels: 0 for normal, 1 for anomaly
            errors: Reconstruction error per sequence
        """
        # Normalize
        sequences_norm = (sequences - self.scaler_mean) / self.scaler_std

        dataset = BatterySequenceDataset(sequences_norm)
        loader = DataLoader(dataset, batch_size=64)

        self.model.eval()
        all_errors = []
        with torch.no_grad():
            for batch in loader:
                batch = batch.to(self.device)
                reconstruction = self.model(batch)
                errors = torch.mean((batch - reconstruction) ** 2, dim=(1, 2))
                all_errors.extend(errors.cpu().numpy())

        errors = np.array(all_errors)
        labels = (errors > self.threshold).astype(int)

        return labels, errors
```

## Deployment Strategy

### Edge Deployment (Vehicle ECU)
```yaml
# Model optimization for embedded systems
optimization:
  quantization: INT8  # Reduce model size by 4x
  pruning: 0.3        # Remove 30% least important weights
  inference_engine: ONNX Runtime
  target_latency: <50ms

hardware:
  platform: NVIDIA Jetson Xavier NX / Intel Myriad X
  memory: <100MB per model
  power_budget: <5W

monitoring:
  - Track inference latency
  - Log anomaly rate (should be <1%)
  - Alert on detector failures
```

### Cloud Deployment (Fleet-wide)
```yaml
architecture:
  ingestion: Apache Kafka
  preprocessing: Apache Spark Structured Streaming
  inference: TensorFlow Serving / Ray Serve
  storage: TimescaleDB (anomalies) + S3 (raw data)

scalability:
  - Horizontal scaling based on vehicle count
  - Batch processing for non-real-time analysis
  - A/B testing for model updates

mlops:
  - Model versioning with MLflow
  - Automated retraining on new anomaly patterns
  - Canary deployments (5% -> 25% -> 100%)
  - Rollback on performance degradation
```

## Evaluation Metrics

### For Labeled Test Sets
```python
from sklearn.metrics import (
    precision_score, recall_score, f1_score,
    roc_auc_score, confusion_matrix, classification_report
)

def evaluate_detector(y_true: np.ndarray, y_pred: np.ndarray, scores: np.ndarray):
    """
    Comprehensive evaluation of anomaly detector.

    Args:
        y_true: Ground truth labels (1=anomaly, 0=normal)
        y_pred: Predicted labels (1=anomaly, 0=normal)
        scores: Anomaly scores (continuous)
    """
    # Convert Isolation Forest labels (-1, 1) to (1, 0)
    y_pred_binary = (y_pred == -1).astype(int)

    # Metrics
    precision = precision_score(y_true, y_pred_binary)
    recall = recall_score(y_true, y_pred_binary)
    f1 = f1_score(y_true, y_pred_binary)

    # AUC-ROC (requires scores)
    # Negate scores since Isolation Forest: lower = more anomalous
    auc = roc_auc_score(y_true, -scores)

    print(f"Precision: {precision:.3f}")
    print(f"Recall: {recall:.3f}")
    print(f"F1-Score: {f1:.3f}")
    print(f"AUC-ROC: {auc:.3f}")
    print("\nConfusion Matrix:")
    print(confusion_matrix(y_true, y_pred_binary))
    print("\nClassification Report:")
    print(classification_report(y_true, y_pred_binary,
                                target_names=['Normal', 'Anomaly']))
```

### For Unlabeled Production Data
```python
def monitor_detector_health(predictions: np.ndarray, scores: np.ndarray):
    """
    Monitor detector behavior in production (no ground truth).

    Alerts:
    - Anomaly rate too high (>5%) -> possible drift
    - Anomaly rate too low (<0.1%) -> detector not sensitive
    - Score distribution shift -> model degradation
    """
    anomaly_rate = (predictions == -1).mean()
    score_mean = scores.mean()
    score_std = scores.std()

    print(f"Anomaly Rate: {anomaly_rate:.2%}")
    print(f"Score Mean: {score_mean:.3f} +/- {score_std:.3f}")

    # Alerts
    if anomaly_rate > 0.05:
        print("WARNING: High anomaly rate detected. Possible data drift.")
    elif anomaly_rate < 0.001:
        print("WARNING: Low anomaly rate. Detector may not be sensitive enough.")
```

## Production Checklist

- [ ] Model trained on representative normal data (>10k samples)
- [ ] Threshold calibrated on validation set (target: 1-2% false positive rate)
- [ ] Feature engineering validated for edge cases (missing sensors, extreme temps)
- [ ] Model compressed for edge deployment (ONNX + quantization)
- [ ] Inference latency tested (<100ms p99)
- [ ] Monitoring dashboards configured (Grafana + Prometheus)
- [ ] Alert thresholds set (anomaly rate, detector health)
- [ ] Retraining pipeline automated (weekly batch on new normal data)
- [ ] A/B testing framework ready
- [ ] Rollback procedure documented
