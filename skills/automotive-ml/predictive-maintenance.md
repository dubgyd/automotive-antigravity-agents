# Predictive Maintenance for Automotive Components

Predict component failures before they occur using supervised ML and survival analysis. Focus on battery SOH, tire wear, brake pad life, and electric motor degradation.

## Use Cases

1. **Battery State of Health (SOH)**: Predict remaining useful life, capacity fade, impedance rise
2. **Tire Wear**: Estimate tread depth, predict replacement needs
3. **Brake System**: Brake pad thickness, rotor wear, fluid degradation
4. **Electric Motor**: Bearing wear, insulation degradation, magnet demagnetization
5. **Cooling System**: Pump failure, radiator clogging, coolant degradation

## Problem Formulation

### Regression (Remaining Useful Life)
Predict time-to-failure or remaining capacity as continuous value.

**Algorithms**:
- Gradient Boosting (XGBoost, LightGBM, CatBoost)
- Random Forest
- LSTM/GRU for sequential degradation

### Classification (Failure within Window)
Predict if failure will occur in next N days/cycles.

**Algorithms**:
- Gradient Boosting Classifiers
- Logistic Regression (baseline)
- Neural Networks

### Survival Analysis (Time-to-Event)
Model probability of survival beyond time t, handling censored data.

**Algorithms**:
- Cox Proportional Hazards
- Random Survival Forests
- Deep survival models (DeepSurv)

## Battery SOH Prediction

### Feature Engineering

```python
import numpy as np
import pandas as pd
from scipy.stats import skew, kurtosis
from typing import Dict

class BatterySOHFeatureEngineer:
    """
    Extract features from battery charge/discharge cycles for SOH prediction.

    Features capture:
    - Capacity fade
    - Impedance rise
    - Charge acceptance degradation
    - Thermal behavior changes
    """

    @staticmethod
    def extract_cycle_features(
        cycle_data: pd.DataFrame,
        metadata: Dict
    ) -> Dict[str, float]:
        """
        Extract features from a single charge/discharge cycle.

        Expected columns:
        - timestamp, voltage, current, temperature, soc
        """
        features = {}

        # Metadata
        features['cycle_number'] = metadata['cycle_number']
        features['total_kwh_throughput'] = metadata['total_kwh_throughput']
        features['age_days'] = metadata['age_days']
        features['ambient_temp_avg'] = metadata.get('ambient_temp_avg', 25.0)

        # Capacity features
        charge_data = cycle_data[cycle_data['current'] > 0]
        discharge_data = cycle_data[cycle_data['current'] < 0]

        if len(charge_data) > 0:
            features['charge_capacity_ah'] = (
                charge_data['current'].sum() *
                (charge_data['timestamp'].diff().dt.total_seconds().mean() / 3600)
            )
            features['charge_duration_min'] = (
                (charge_data['timestamp'].max() - charge_data['timestamp'].min())
                .total_seconds() / 60
            )
        else:
            features['charge_capacity_ah'] = 0
            features['charge_duration_min'] = 0

        if len(discharge_data) > 0:
            features['discharge_capacity_ah'] = abs(
                discharge_data['current'].sum() *
                (discharge_data['timestamp'].diff().dt.total_seconds().mean() / 3600)
            )
            features['discharge_duration_min'] = (
                (discharge_data['timestamp'].max() - discharge_data['timestamp'].min())
                .total_seconds() / 60
            )
        else:
            features['discharge_capacity_ah'] = 0
            features['discharge_duration_min'] = 0

        # Coulombic efficiency
        if features['charge_capacity_ah'] > 0:
            features['coulombic_efficiency'] = (
                features['discharge_capacity_ah'] / features['charge_capacity_ah']
            )
        else:
            features['coulombic_efficiency'] = 1.0

        # Voltage features
        features['voltage_mean'] = cycle_data['voltage'].mean()
        features['voltage_std'] = cycle_data['voltage'].std()
        features['voltage_min'] = cycle_data['voltage'].min()
        features['voltage_max'] = cycle_data['voltage'].max()

        # dV/dSOC (charge acceptance indicator)
        if len(charge_data) > 10:
            soc_bins = pd.cut(charge_data['soc'], bins=10)
            voltage_per_soc = charge_data.groupby(soc_bins)['voltage'].mean()
            features['dv_dsoc_slope'] = np.polyfit(
                range(len(voltage_per_soc)),
                voltage_per_soc.values,
                1
            )[0]
        else:
            features['dv_dsoc_slope'] = 0

        # Impedance proxy (voltage drop at constant current)
        if len(discharge_data) > 100:
            # Find steady-state discharge region (SOC 80% -> 20%)
            steady_discharge = discharge_data[
                (discharge_data['soc'] >= 20) & (discharge_data['soc'] <= 80)
            ]
            if len(steady_discharge) > 10:
                # Impedance ~ voltage_drop / current
                current_mean = steady_discharge['current'].mean()
                voltage_drop_per_amp = steady_discharge['voltage'].std() / abs(current_mean)
                features['impedance_proxy'] = voltage_drop_per_amp
            else:
                features['impedance_proxy'] = 0
        else:
            features['impedance_proxy'] = 0

        # Thermal features
        features['temp_mean'] = cycle_data['temperature'].mean()
        features['temp_max'] = cycle_data['temperature'].max()
        features['temp_std'] = cycle_data['temperature'].std()
        features['temp_rise'] = (
            cycle_data['temperature'].max() - cycle_data['temperature'].min()
        )

        # Temperature-power correlation (thermal management quality)
        if len(cycle_data) > 10:
            power = cycle_data['voltage'] * cycle_data['current']
            temp_power_corr = cycle_data['temperature'].corr(power)
            features['temp_power_correlation'] = temp_power_corr
        else:
            features['temp_power_correlation'] = 0

        # Resting voltage (open-circuit voltage after rest period)
        # Indicates equilibrium state
        rest_data = cycle_data[abs(cycle_data['current']) < 1.0]  # <1A = rest
        if len(rest_data) > 5:
            features['rest_voltage'] = rest_data['voltage'].mean()
        else:
            features['rest_voltage'] = cycle_data['voltage'].mean()

        # Statistical features
        features['voltage_skewness'] = skew(cycle_data['voltage'])
        features['voltage_kurtosis'] = kurtosis(cycle_data['voltage'])

        return features

    @staticmethod
    def create_degradation_trends(
        cycle_features_df: pd.DataFrame,
        window: int = 10
    ) -> pd.DataFrame:
        """
        Create trend features from cycle history.

        Args:
            cycle_features_df: Features per cycle (sorted by cycle_number)
            window: Rolling window size for trend calculation
        """
        trends = cycle_features_df.copy()

        # Capacity fade rate
        trends['capacity_fade_rate'] = (
            -trends['discharge_capacity_ah']
            .rolling(window=window, min_periods=3)
            .apply(lambda x: np.polyfit(range(len(x)), x, 1)[0])
        )

        # Impedance rise rate
        trends['impedance_rise_rate'] = (
            trends['impedance_proxy']
            .rolling(window=window, min_periods=3)
            .apply(lambda x: np.polyfit(range(len(x)), x, 1)[0])
        )

        # Efficiency degradation
        trends['efficiency_decline_rate'] = (
            -trends['coulombic_efficiency']
            .rolling(window=window, min_periods=3)
            .apply(lambda x: np.polyfit(range(len(x)), x, 1)[0])
        )

        # Temperature increase trend (thermal management degradation)
        trends['temp_increase_rate'] = (
            trends['temp_mean']
            .rolling(window=window, min_periods=3)
            .apply(lambda x: np.polyfit(range(len(x)), x, 1)[0])
        )

        # Volatility features (increased variance = instability)
        trends['capacity_volatility'] = (
            trends['discharge_capacity_ah'].rolling(window=window).std()
        )

        return trends.fillna(0)


# Example usage
if __name__ == "__main__":
    # Load cycle data
    cycle_df = pd.read_parquet('battery_cycle_001.parquet')
    metadata = {
        'cycle_number': 1,
        'total_kwh_throughput': 120.5,
        'age_days': 45
    }

    engineer = BatterySOHFeatureEngineer()
    features = engineer.extract_cycle_features(cycle_df, metadata)

    print("Extracted features:")
    for key, value in features.items():
        print(f"  {key}: {value:.4f}")
```

### Model Implementation: Gradient Boosting

```python
import lightgbm as lgb
import numpy as np
import pandas as pd
from sklearn.model_selection import TimeSeriesSplit
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
from typing import Tuple
import joblib
import logging

logger = logging.getLogger(__name__)

class BatterySOHPredictor:
    """
    LightGBM-based State of Health predictor.

    Predicts:
    - Current SOH (0-100%)
    - Remaining useful cycles (until 80% SOH)
    - Capacity at next cycle
    """

    def __init__(self, model_params: dict = None):
        """
        Args:
            model_params: LightGBM hyperparameters
        """
        default_params = {
            'objective': 'regression',
            'metric': 'rmse',
            'boosting_type': 'gbdt',
            'num_leaves': 31,
            'learning_rate': 0.05,
            'feature_fraction': 0.8,
            'bagging_fraction': 0.8,
            'bagging_freq': 5,
            'max_depth': 6,
            'min_child_samples': 20,
            'verbosity': -1,
            'n_jobs': -1
        }
        self.params = model_params or default_params
        self.model = None
        self.feature_names = None

    def train(
        self,
        X: pd.DataFrame,
        y: np.ndarray,
        n_splits: int = 5,
        n_estimators: int = 500,
        early_stopping_rounds: int = 50
    ) -> dict:
        """
        Train SOH predictor with time-series cross-validation.

        Args:
            X: Feature matrix (cycle features)
            y: Target (SOH percentage, 0-100)
            n_splits: Number of CV splits
            n_estimators: Number of boosting rounds
            early_stopping_rounds: Early stopping patience

        Returns:
            Training metrics
        """
        self.feature_names = X.columns.tolist()

        # Time-series cross-validation (preserve temporal order)
        tscv = TimeSeriesSplit(n_splits=n_splits)

        cv_scores = []
        for fold, (train_idx, val_idx) in enumerate(tscv.split(X)):
            X_train, X_val = X.iloc[train_idx], X.iloc[val_idx]
            y_train, y_val = y[train_idx], y[val_idx]

            train_data = lgb.Dataset(X_train, label=y_train)
            val_data = lgb.Dataset(X_val, label=y_val, reference=train_data)

            model = lgb.train(
                self.params,
                train_data,
                num_boost_round=n_estimators,
                valid_sets=[val_data],
                valid_names=['val'],
                callbacks=[
                    lgb.early_stopping(early_stopping_rounds),
                    lgb.log_evaluation(period=0)  # Silent
                ]
            )

            # Evaluate
            y_pred = model.predict(X_val)
            mae = mean_absolute_error(y_val, y_pred)
            rmse = np.sqrt(mean_squared_error(y_val, y_pred))
            r2 = r2_score(y_val, y_pred)

            cv_scores.append({'mae': mae, 'rmse': rmse, 'r2': r2})
            logger.info(f"Fold {fold+1}: MAE={mae:.3f}, RMSE={rmse:.3f}, R2={r2:.3f}")

        # Train final model on full data
        full_data = lgb.Dataset(X, label=y)
        self.model = lgb.train(
            self.params,
            full_data,
            num_boost_round=n_estimators
        )

        # Aggregate CV metrics
        avg_metrics = {
            'mae': np.mean([s['mae'] for s in cv_scores]),
            'rmse': np.mean([s['rmse'] for s in cv_scores]),
            'r2': np.mean([s['r2'] for s in cv_scores]),
            'cv_scores': cv_scores
        }

        logger.info(f"Average CV MAE: {avg_metrics['mae']:.3f}%")
        logger.info(f"Average CV RMSE: {avg_metrics['rmse']:.3f}%")
        logger.info(f"Average CV R2: {avg_metrics['r2']:.3f}")

        return avg_metrics

    def predict(self, X: pd.DataFrame) -> np.ndarray:
        """
        Predict SOH for new samples.

        Returns:
            Predicted SOH values (0-100%)
        """
        if self.model is None:
            raise ValueError("Model must be trained before prediction")

        return self.model.predict(X)

    def predict_with_uncertainty(
        self,
        X: pd.DataFrame,
        n_iterations: int = 100
    ) -> Tuple[np.ndarray, np.ndarray]:
        """
        Predict with uncertainty estimation using dropout simulation.

        Returns:
            mean_predictions: Mean predicted SOH
            std_predictions: Standard deviation (uncertainty)
        """
        # LightGBM doesn't have native dropout, so we use bootstrapping
        predictions = []

        for _ in range(n_iterations):
            # Random feature subsample
            feature_fraction = self.params.get('feature_fraction', 0.8)
            n_features = int(len(X.columns) * feature_fraction)
            random_features = np.random.choice(
                X.columns,
                size=n_features,
                replace=False
            )

            pred = self.model.predict(X[random_features])
            predictions.append(pred)

        predictions = np.array(predictions)
        mean_pred = predictions.mean(axis=0)
        std_pred = predictions.std(axis=0)

        return mean_pred, std_pred

    def predict_remaining_cycles(
        self,
        X: pd.DataFrame,
        current_soh: np.ndarray,
        eol_threshold: float = 80.0
    ) -> np.ndarray:
        """
        Predict remaining useful cycles until end-of-life.

        Args:
            X: Current feature matrix
            current_soh: Current SOH values
            eol_threshold: End-of-life SOH threshold (default 80%)

        Returns:
            Estimated remaining cycles
        """
        # Estimate degradation rate from recent trend
        if 'capacity_fade_rate' in X.columns:
            fade_rates = X['capacity_fade_rate'].values
            # Prevent division by zero
            fade_rates = np.where(np.abs(fade_rates) < 1e-6, -0.1, fade_rates)

            # RUL = (current_soh - eol_threshold) / abs(fade_rate)
            rul = (current_soh - eol_threshold) / np.abs(fade_rates)

            # Clip to reasonable range [0, 5000]
            rul = np.clip(rul, 0, 5000)
        else:
            # Fallback: assume constant 0.05% fade per cycle
            rul = (current_soh - eol_threshold) / 0.05

        return rul

    def feature_importance(self, plot: bool = False) -> pd.DataFrame:
        """
        Get feature importance scores.

        Args:
            plot: If True, display bar plot

        Returns:
            DataFrame with feature names and importance scores
        """
        if self.model is None:
            raise ValueError("Model must be trained before feature importance")

        importance = self.model.feature_importance(importance_type='gain')
        importance_df = pd.DataFrame({
            'feature': self.feature_names,
            'importance': importance
        }).sort_values('importance', ascending=False)

        if plot:
            import matplotlib.pyplot as plt
            plt.figure(figsize=(10, 6))
            plt.barh(importance_df['feature'][:15], importance_df['importance'][:15])
            plt.xlabel('Importance (Gain)')
            plt.title('Top 15 Features for SOH Prediction')
            plt.gca().invert_yaxis()
            plt.tight_layout()
            plt.show()

        return importance_df

    def save(self, path: str):
        """Save trained model."""
        if self.model is None:
            raise ValueError("Cannot save untrained model")

        joblib.dump({
            'model': self.model,
            'params': self.params,
            'feature_names': self.feature_names
        }, path)
        logger.info(f"Model saved to {path}")

    @classmethod
    def load(cls, path: str) -> 'BatterySOHPredictor':
        """Load trained model."""
        data = joblib.load(path)
        predictor = cls(model_params=data['params'])
        predictor.model = data['model']
        predictor.feature_names = data['feature_names']
        logger.info(f"Model loaded from {path}")
        return predictor


# Example usage
if __name__ == "__main__":
    # Load preprocessed cycle features
    df = pd.read_parquet('battery_cycle_features.parquet')

    # Features and target
    feature_cols = [col for col in df.columns if col not in ['soh', 'battery_id']]
    X = df[feature_cols]
    y = df['soh'].values

    # Train predictor
    predictor = BatterySOHPredictor()
    metrics = predictor.train(X, y, n_splits=5)

    # Feature importance
    importance_df = predictor.feature_importance()
    print("\nTop 10 Most Important Features:")
    print(importance_df.head(10))

    # Save model
    predictor.save('battery_soh_predictor.pkl')

    # Predict with uncertainty
    X_test = X.iloc[-100:]
    mean_pred, std_pred = predictor.predict_with_uncertainty(X_test)

    print("\nPredictions with uncertainty:")
    for i in range(5):
        print(f"  Sample {i}: {mean_pred[i]:.2f}% +/- {std_pred[i]:.2f}%")

    # Remaining useful life
    rul = predictor.predict_remaining_cycles(X_test, mean_pred)
    print(f"\nEstimated RUL: {rul[:5]} cycles")
```

## LSTM for Sequential Degradation

```python
import torch
import torch.nn as nn
from torch.utils.data import Dataset, DataLoader
import numpy as np
import pandas as pd

class BatterySequenceDataset(Dataset):
    """Dataset for multi-cycle battery sequences."""

    def __init__(
        self,
        sequences: np.ndarray,
        targets: np.ndarray,
        seq_len: int = 50
    ):
        """
        Args:
            sequences: (N, max_cycles, n_features) array
            targets: (N,) array of target SOH
            seq_len: Sequence length to use
        """
        self.sequences = torch.FloatTensor(sequences[:, -seq_len:, :])
        self.targets = torch.FloatTensor(targets)

    def __len__(self):
        return len(self.sequences)

    def __getitem__(self, idx):
        return self.sequences[idx], self.targets[idx]


class BatterySOHLSTM(nn.Module):
    """
    LSTM-based SOH predictor for sequential degradation modeling.

    Input: (batch, seq_len, n_features) - last N cycles
    Output: (batch,) - predicted SOH at next cycle
    """

    def __init__(
        self,
        n_features: int,
        hidden_dim: int = 64,
        n_layers: int = 2,
        dropout: float = 0.2
    ):
        super().__init__()

        self.lstm = nn.LSTM(
            input_size=n_features,
            hidden_size=hidden_dim,
            num_layers=n_layers,
            batch_first=True,
            dropout=dropout if n_layers > 1 else 0
        )

        self.fc = nn.Sequential(
            nn.Linear(hidden_dim, 32),
            nn.ReLU(),
            nn.Dropout(dropout),
            nn.Linear(32, 1)
        )

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        # x: (batch, seq_len, n_features)
        lstm_out, (hidden, _) = self.lstm(x)

        # Use last hidden state
        out = self.fc(hidden[-1])  # (batch, 1)
        return out.squeeze()  # (batch,)


def train_lstm_predictor(
    train_sequences: np.ndarray,
    train_targets: np.ndarray,
    val_sequences: np.ndarray,
    val_targets: np.ndarray,
    n_features: int,
    epochs: int = 100,
    batch_size: int = 32,
    lr: float = 0.001
) -> BatterySOHLSTM:
    """
    Train LSTM SOH predictor.

    Args:
        train_sequences: (N_train, seq_len, n_features)
        train_targets: (N_train,) - SOH values
        val_sequences: (N_val, seq_len, n_features)
        val_targets: (N_val,)
        n_features: Number of input features
        epochs: Training epochs
        batch_size: Batch size
        lr: Learning rate

    Returns:
        Trained model
    """
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')

    # Create datasets
    train_dataset = BatterySequenceDataset(train_sequences, train_targets)
    val_dataset = BatterySequenceDataset(val_sequences, val_targets)

    train_loader = DataLoader(train_dataset, batch_size=batch_size, shuffle=True)
    val_loader = DataLoader(val_dataset, batch_size=batch_size)

    # Model
    model = BatterySOHLSTM(n_features=n_features).to(device)
    optimizer = torch.optim.Adam(model.parameters(), lr=lr)
    criterion = nn.MSELoss()

    best_val_loss = float('inf')
    patience = 10
    patience_counter = 0

    for epoch in range(epochs):
        # Training
        model.train()
        train_loss = 0
        for sequences, targets in train_loader:
            sequences = sequences.to(device)
            targets = targets.to(device)

            optimizer.zero_grad()
            outputs = model(sequences)
            loss = criterion(outputs, targets)
            loss.backward()
            optimizer.step()

            train_loss += loss.item()

        train_loss /= len(train_loader)

        # Validation
        model.eval()
        val_loss = 0
        with torch.no_grad():
            for sequences, targets in val_loader:
                sequences = sequences.to(device)
                targets = targets.to(device)
                outputs = model(sequences)
                loss = criterion(outputs, targets)
                val_loss += loss.item()

        val_loss /= len(val_loader)

        if (epoch + 1) % 10 == 0:
            print(f"Epoch {epoch+1}/{epochs} - "
                  f"Train Loss: {train_loss:.4f}, Val Loss: {val_loss:.4f}")

        # Early stopping
        if val_loss < best_val_loss:
            best_val_loss = val_loss
            patience_counter = 0
            best_model_state = model.state_dict()
        else:
            patience_counter += 1
            if patience_counter >= patience:
                print(f"Early stopping at epoch {epoch+1}")
                break

    # Load best model
    model.load_state_dict(best_model_state)
    return model
```

## Tire Wear Prediction

```python
from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import train_test_split
import numpy as np
import pandas as pd

class TireWearPredictor:
    """
    Predict tire tread depth based on usage patterns.

    Features:
    - Mileage
    - Driving style (acceleration, braking intensity)
    - Road conditions (highway vs city, temperature)
    - Tire pressure history
    - Load distribution
    """

    def __init__(self):
        self.model = RandomForestRegressor(
            n_estimators=200,
            max_depth=15,
            min_samples_split=10,
            random_state=42,
            n_jobs=-1
        )
        self.initial_tread_depth_mm = 8.0  # New tire

    def extract_features(self, vehicle_data: pd.DataFrame) -> pd.DataFrame:
        """
        Extract tire wear features from vehicle telemetry.

        Expected columns:
        - mileage, speed, acceleration, brake_pressure,
        - tire_pressure_fl, tire_pressure_fr, tire_pressure_rl, tire_pressure_rr,
        - ambient_temp, road_surface
        """
        features = pd.DataFrame()

        # Usage features
        features['total_mileage_km'] = vehicle_data['mileage']
        features['avg_speed_kmh'] = vehicle_data.groupby('vehicle_id')['speed'].transform('mean')

        # Driving style
        features['harsh_accel_count'] = (
            (vehicle_data['acceleration'] > 2.5)
            .groupby(vehicle_data['vehicle_id']).transform('sum')
        )
        features['harsh_brake_count'] = (
            (vehicle_data['brake_pressure'] > 0.7)
            .groupby(vehicle_data['vehicle_id']).transform('sum')
        )

        # Tire pressure (underinflation accelerates wear)
        tire_cols = ['tire_pressure_fl', 'tire_pressure_fr',
                     'tire_pressure_rl', 'tire_pressure_rr']
        features['avg_tire_pressure_bar'] = vehicle_data[tire_cols].mean(axis=1)
        features['tire_pressure_variance'] = vehicle_data[tire_cols].var(axis=1)

        # Underinflation events
        optimal_pressure = 2.5  # bar
        features['underinflation_events'] = (
            (vehicle_data[tire_cols] < optimal_pressure * 0.9).sum(axis=1)
            .groupby(vehicle_data['vehicle_id']).transform('sum')
        )

        # Environmental
        features['avg_temp_c'] = vehicle_data.groupby('vehicle_id')['ambient_temp'].transform('mean')

        # Road surface distribution
        if 'road_surface' in vehicle_data.columns:
            road_dummies = pd.get_dummies(vehicle_data['road_surface'], prefix='road')
            for col in road_dummies.columns:
                features[col] = road_dummies[col].groupby(vehicle_data['vehicle_id']).transform('mean')

        return features

    def train(self, X: pd.DataFrame, y: np.ndarray):
        """
        Train tire wear predictor.

        Args:
            X: Feature matrix
            y: Measured tread depth [mm]
        """
        X_train, X_val, y_train, y_val = train_test_split(
            X, y, test_size=0.2, random_state=42
        )

        self.model.fit(X_train, y_train)

        # Evaluate
        train_score = self.model.score(X_train, y_train)
        val_score = self.model.score(X_val, y_val)
        print(f"Training R2: {train_score:.3f}")
        print(f"Validation R2: {val_score:.3f}")

    def predict_tread_depth(self, X: pd.DataFrame) -> np.ndarray:
        """Predict current tread depth [mm]."""
        return self.model.predict(X)

    def predict_replacement_mileage(
        self,
        X: pd.DataFrame,
        current_mileage: np.ndarray,
        min_tread_depth_mm: float = 1.6
    ) -> np.ndarray:
        """
        Predict mileage at which tire should be replaced.

        Args:
            X: Current feature matrix
            current_mileage: Current vehicle mileage [km]
            min_tread_depth_mm: Legal minimum tread depth

        Returns:
            Estimated mileage at replacement [km]
        """
        current_tread = self.predict_tread_depth(X)

        # Estimate wear rate (mm per 1000 km)
        wear_so_far = self.initial_tread_depth_mm - current_tread
        wear_rate = wear_so_far / (current_mileage / 1000)

        # Remaining mileage
        remaining_tread = current_tread - min_tread_depth_mm
        remaining_mileage = (remaining_tread / wear_rate) * 1000

        replacement_mileage = current_mileage + remaining_mileage

        return replacement_mileage
```

## Deployment Architecture

```yaml
# Predictive maintenance pipeline
pipeline:
  data_ingestion:
    source: Vehicle telemetry stream (Kafka)
    frequency: Real-time for critical, daily batch for non-critical

  feature_engineering:
    engine: Apache Spark / Pandas
    caching: Redis (recent features)

  inference:
    model_serving: TensorFlow Serving / FastAPI
    latency: <100ms for real-time, <1h for batch

  output:
    storage: PostgreSQL (predictions) + Grafana dashboards
    alerts: PagerDuty / Slack for critical predictions
    recommendations: Maintenance scheduling system

monitoring:
  metrics:
    - Prediction accuracy (MAE, RMSE)
    - Model drift (feature distribution shift)
    - Alert precision/recall
    - Business KPIs (maintenance cost reduction, downtime)

  retraining:
    trigger: Performance degradation OR new failure modes
    frequency: Monthly for battery SOH, quarterly for tires
    validation: Holdout test set + field validation
```

## Production Checklist

- [ ] Training data spans full degradation lifecycle (0 -> EOL)
- [ ] Model validated on multiple battery/component types
- [ ] Feature engineering handles missing sensors gracefully
- [ ] Prediction confidence intervals calibrated
- [ ] Alert thresholds set based on cost-benefit analysis
- [ ] Integration with maintenance scheduling system tested
- [ ] Model versioning and rollback procedure in place
- [ ] Monitoring dashboards for prediction accuracy
- [ ] Retraining pipeline automated with data quality checks
- [ ] A/B testing framework for model updates
