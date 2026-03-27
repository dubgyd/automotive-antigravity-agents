# Time-Series Forecasting for Automotive Systems

Forecast battery degradation, energy consumption, and charging demand using specialized time-series models.

## Use Cases

1. **Battery Degradation Forecasting**: Predict SOH trajectory over 5-10 years
2. **Energy Consumption Prediction**: Forecast energy usage for route planning
3. **Charging Demand Forecasting**: Predict station load for grid management
4. **Range Estimation**: Predict remaining range under varying conditions
5. **Thermal Management**: Forecast cooling/heating needs

## Algorithm Selection

### Prophet (Meta)
**Best for**: Business forecasting with seasonality and holidays

**Pros**:
- Handles missing data and outliers
- Automatic seasonality detection
- Interpretable components (trend, weekly, yearly)
- Fast training

**Cons**:
- Assumes additive model structure
- Limited for multivariate forecasting

**Use cases**: Charging station demand, fleet energy consumption

### LSTM/GRU
**Best for**: Complex non-linear temporal dependencies

**Pros**:
- Captures long-term dependencies
- Handles multivariate inputs
- Flexible architecture

**Cons**:
- Requires large training data
- Slow to train
- Hyperparameter sensitive

**Use cases**: Battery SOH trajectory, multi-sensor degradation

### ARIMA/SARIMAX
**Best for**: Stationary time-series with clear seasonality

**Pros**:
- Statistical rigor
- Confidence intervals
- Interpretable parameters

**Cons**:
- Requires stationarity
- Struggles with non-linear patterns
- Manual order selection

**Use cases**: Short-term energy consumption, charging demand

### Temporal Fusion Transformer (TFT)
**Best for**: Multi-horizon forecasting with multiple covariates

**Pros**:
- State-of-the-art performance
- Attention mechanism for interpretability
- Handles static and dynamic features

**Cons**:
- Computationally expensive
- Requires significant data
- Complex implementation

**Use cases**: Long-term battery degradation, fleet-wide energy optimization

## Battery SOH Forecasting with Prophet

```python
from prophet import Prophet
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from typing import Tuple, Dict

class BatterySOHForecaster:
    """
    Forecast battery State of Health using Facebook Prophet.

    Models degradation as:
    - Trend: Long-term capacity fade
    - Seasonal: Usage patterns (daily, weekly)
    - Regressor: Temperature, charge cycles
    """

    def __init__(
        self,
        growth: str = 'linear',
        seasonality_mode: str = 'additive'
    ):
        """
        Args:
            growth: 'linear' or 'logistic' (for bounded degradation)
            seasonality_mode: 'additive' or 'multiplicative'
        """
        self.model = Prophet(
            growth=growth,
            seasonality_mode=seasonality_mode,
            yearly_seasonality=False,  # Not relevant for batteries
            weekly_seasonality=True,   # Usage patterns
            daily_seasonality=True,    # Charge cycles
            changepoint_prior_scale=0.05  # Flexibility of trend changes
        )
        self.trained = False

    def prepare_data(
        self,
        soh_history: pd.DataFrame,
        temperature_history: pd.DataFrame = None
    ) -> pd.DataFrame:
        """
        Prepare data for Prophet.

        Args:
            soh_history: Columns: timestamp, soh
            temperature_history: Columns: timestamp, avg_temp_c

        Returns:
            DataFrame with columns: ds (timestamp), y (SOH), temp (optional)
        """
        df = soh_history.rename(columns={'timestamp': 'ds', 'soh': 'y'})

        # Cap for logistic growth (max 100%, min 0%)
        df['cap'] = 100.0
        df['floor'] = 0.0

        # Add temperature as regressor
        if temperature_history is not None:
            temp_df = temperature_history.rename(columns={'timestamp': 'ds'})
            df = df.merge(temp_df, on='ds', how='left')
            df['avg_temp_c'] = df['avg_temp_c'].fillna(method='ffill')

        return df

    def fit(self, df: pd.DataFrame):
        """
        Train Prophet model.

        Args:
            df: Prepared DataFrame (ds, y, optional regressors)
        """
        # Add regressors if present
        if 'avg_temp_c' in df.columns:
            self.model.add_regressor('avg_temp_c', prior_scale=0.5)

        self.model.fit(df)
        self.trained = True
        print("Model trained successfully")

    def forecast(
        self,
        periods: int,
        freq: str = 'D',
        include_history: bool = True,
        temperature_forecast: pd.DataFrame = None
    ) -> pd.DataFrame:
        """
        Generate SOH forecast.

        Args:
            periods: Number of periods to forecast
            freq: Frequency ('D' for daily, 'H' for hourly)
            include_history: Include historical fit
            temperature_forecast: Future temperature values

        Returns:
            DataFrame with columns: ds, yhat (predicted SOH), yhat_lower, yhat_upper
        """
        if not self.trained:
            raise ValueError("Model must be trained before forecasting")

        # Create future dataframe
        future = self.model.make_future_dataframe(
            periods=periods,
            freq=freq,
            include_history=include_history
        )

        # Add cap/floor for logistic growth
        future['cap'] = 100.0
        future['floor'] = 0.0

        # Add temperature regressor
        if temperature_forecast is not None and 'avg_temp_c' in self.model.extra_regressors:
            temp_df = temperature_forecast.rename(columns={'timestamp': 'ds'})
            future = future.merge(temp_df, on='ds', how='left')
            # Forward fill missing values
            future['avg_temp_c'] = future['avg_temp_c'].fillna(method='ffill')

        # Forecast
        forecast = self.model.predict(future)

        return forecast[['ds', 'yhat', 'yhat_lower', 'yhat_upper']]

    def plot_forecast(self, forecast: pd.DataFrame):
        """Plot forecast with components."""
        fig1 = self.model.plot(forecast)
        plt.title('Battery SOH Forecast')
        plt.ylabel('SOH (%)')
        plt.xlabel('Date')

        fig2 = self.model.plot_components(forecast)
        plt.show()

    def cross_validate(
        self,
        df: pd.DataFrame,
        initial: str = '365 days',
        period: str = '90 days',
        horizon: str = '180 days'
    ) -> pd.DataFrame:
        """
        Perform time-series cross-validation.

        Args:
            df: Training data
            initial: Initial training period
            period: Spacing between cutoff dates
            horizon: Forecast horizon

        Returns:
            DataFrame with CV results
        """
        from prophet.diagnostics import cross_validation, performance_metrics

        self.fit(df)

        df_cv = cross_validation(
            self.model,
            initial=initial,
            period=period,
            horizon=horizon
        )

        df_metrics = performance_metrics(df_cv)
        print("Cross-Validation Metrics:")
        print(df_metrics[['horizon', 'mse', 'rmse', 'mae', 'mape']].head())

        return df_cv


# Example usage
if __name__ == "__main__":
    # Load historical SOH data
    soh_df = pd.read_csv('battery_soh_history.csv', parse_dates=['timestamp'])

    # Optional: Load temperature data
    temp_df = pd.read_csv('temperature_history.csv', parse_dates=['timestamp'])

    # Initialize forecaster
    forecaster = BatterySOHForecaster(growth='logistic')

    # Prepare data
    train_df = forecaster.prepare_data(soh_df, temp_df)

    # Train
    forecaster.fit(train_df)

    # Forecast 365 days ahead
    forecast = forecaster.forecast(periods=365, freq='D')

    # Plot
    forecaster.plot_forecast(forecast)

    # Print key predictions
    future_forecast = forecast[forecast['ds'] > soh_df['timestamp'].max()]
    print("\nSOH Predictions (next 12 months):")
    print(future_forecast[['ds', 'yhat', 'yhat_lower', 'yhat_upper']].head(12))

    # Estimate EOL (80% SOH)
    eol_date = future_forecast[future_forecast['yhat'] <= 80.0]['ds'].iloc[0]
    print(f"\nEstimated End-of-Life Date (80% SOH): {eol_date}")
```

## LSTM for Multi-Variate Forecasting

```python
import torch
import torch.nn as nn
from torch.utils.data import Dataset, DataLoader
import numpy as np
import pandas as pd
from typing import Tuple

class BatteryMultivariateDataset(Dataset):
    """
    Dataset for multivariate battery forecasting.

    Features: voltage, current, temperature, SOC
    Target: Future SOH
    """

    def __init__(
        self,
        data: np.ndarray,
        target: np.ndarray,
        seq_len: int = 100,
        pred_len: int = 10
    ):
        """
        Args:
            data: (N_samples, N_features) array
            target: (N_samples,) array (SOH)
            seq_len: Input sequence length
            pred_len: Prediction horizon
        """
        self.seq_len = seq_len
        self.pred_len = pred_len

        # Create sequences
        self.sequences = []
        self.targets = []

        for i in range(len(data) - seq_len - pred_len + 1):
            self.sequences.append(data[i:i+seq_len])
            self.targets.append(target[i+seq_len+pred_len-1])

        self.sequences = torch.FloatTensor(np.array(self.sequences))
        self.targets = torch.FloatTensor(np.array(self.targets))

    def __len__(self):
        return len(self.sequences)

    def __getitem__(self, idx):
        return self.sequences[idx], self.targets[idx]


class BatteryLSTMForecaster(nn.Module):
    """
    Multi-layer LSTM for battery SOH forecasting.

    Architecture:
    - Encoder LSTM: Process input sequence
    - Attention: Weight important time steps
    - Decoder: Generate future predictions
    """

    def __init__(
        self,
        n_features: int,
        hidden_dim: int = 128,
        n_layers: int = 3,
        dropout: float = 0.3
    ):
        super().__init__()

        self.n_features = n_features
        self.hidden_dim = hidden_dim

        # LSTM layers
        self.lstm = nn.LSTM(
            input_size=n_features,
            hidden_size=hidden_dim,
            num_layers=n_layers,
            batch_first=True,
            dropout=dropout
        )

        # Attention mechanism
        self.attention = nn.Sequential(
            nn.Linear(hidden_dim, hidden_dim),
            nn.Tanh(),
            nn.Linear(hidden_dim, 1)
        )

        # Output layer
        self.fc = nn.Sequential(
            nn.Linear(hidden_dim, 64),
            nn.ReLU(),
            nn.Dropout(dropout),
            nn.Linear(64, 1)
        )

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        # x: (batch, seq_len, n_features)

        # LSTM encoding
        lstm_out, _ = self.lstm(x)
        # lstm_out: (batch, seq_len, hidden_dim)

        # Attention weights
        attention_weights = self.attention(lstm_out)
        # attention_weights: (batch, seq_len, 1)
        attention_weights = torch.softmax(attention_weights, dim=1)

        # Weighted sum
        context = torch.sum(lstm_out * attention_weights, dim=1)
        # context: (batch, hidden_dim)

        # Prediction
        out = self.fc(context)
        return out.squeeze()


def train_lstm_forecaster(
    train_data: np.ndarray,
    train_target: np.ndarray,
    val_data: np.ndarray,
    val_target: np.ndarray,
    n_features: int,
    seq_len: int = 100,
    pred_len: int = 10,
    epochs: int = 100,
    batch_size: int = 64,
    lr: float = 0.001
) -> BatteryLSTMForecaster:
    """
    Train LSTM forecaster.

    Args:
        train_data: Training features (N, n_features)
        train_target: Training SOH values (N,)
        val_data: Validation features
        val_target: Validation SOH values
        n_features: Number of input features
        seq_len: Input sequence length
        pred_len: Prediction horizon (time steps ahead)
        epochs: Training epochs
        batch_size: Batch size
        lr: Learning rate

    Returns:
        Trained model
    """
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')

    # Create datasets
    train_dataset = BatteryMultivariateDataset(
        train_data, train_target, seq_len, pred_len
    )
    val_dataset = BatteryMultivariateDataset(
        val_data, val_target, seq_len, pred_len
    )

    train_loader = DataLoader(train_dataset, batch_size=batch_size, shuffle=True)
    val_loader = DataLoader(val_dataset, batch_size=batch_size)

    # Model
    model = BatteryLSTMForecaster(n_features=n_features).to(device)
    optimizer = torch.optim.Adam(model.parameters(), lr=lr)
    criterion = nn.MSELoss()

    best_val_loss = float('inf')
    patience = 15
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

            # Gradient clipping
            torch.nn.utils.clip_grad_norm_(model.parameters(), max_norm=1.0)

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
    print(f"Best validation loss: {best_val_loss:.4f}")

    return model


def forecast_multi_step(
    model: BatteryLSTMForecaster,
    initial_sequence: np.ndarray,
    n_steps: int,
    device: str = 'cpu'
) -> np.ndarray:
    """
    Multi-step ahead forecasting with recursive prediction.

    Args:
        model: Trained LSTM model
        initial_sequence: (seq_len, n_features) - starting sequence
        n_steps: Number of steps to forecast ahead
        device: 'cpu' or 'cuda'

    Returns:
        Forecasted SOH values (n_steps,)
    """
    model.eval()
    model.to(device)

    predictions = []
    current_seq = torch.FloatTensor(initial_sequence).unsqueeze(0).to(device)
    # current_seq: (1, seq_len, n_features)

    with torch.no_grad():
        for _ in range(n_steps):
            # Predict next value
            pred = model(current_seq)
            predictions.append(pred.item())

            # Update sequence (shift left, add prediction)
            # Note: This assumes last feature is SOH. Adjust as needed.
            new_step = current_seq[0, -1, :].clone()
            new_step[-1] = pred  # Update SOH feature

            # Shift sequence
            current_seq = torch.cat([
                current_seq[:, 1:, :],
                new_step.unsqueeze(0).unsqueeze(0)
            ], dim=1)

    return np.array(predictions)
```

## Energy Consumption Forecasting

```python
from sklearn.ensemble import GradientBoostingRegressor
import numpy as np
import pandas as pd
from typing import Dict

class EnergyConsumptionForecaster:
    """
    Forecast vehicle energy consumption based on route and conditions.

    Features:
    - Route profile (distance, elevation change, road type)
    - Weather (temperature, wind, precipitation)
    - Traffic (congestion level, stop frequency)
    - Vehicle state (SOC, weight, tire pressure)
    - Driver behavior (historical consumption)
    """

    def __init__(self):
        self.model = GradientBoostingRegressor(
            n_estimators=200,
            learning_rate=0.05,
            max_depth=6,
            min_samples_split=20,
            random_state=42
        )

    def engineer_route_features(self, route_data: pd.DataFrame) -> pd.DataFrame:
        """
        Extract features from route data.

        Expected columns:
        - distance_km, elevation_gain_m, avg_speed_kmh,
        - road_type, ambient_temp_c, wind_speed_kmh,
        - traffic_level, stop_count
        """
        features = pd.DataFrame()

        # Route characteristics
        features['distance_km'] = route_data['distance_km']
        features['elevation_gain_m'] = route_data['elevation_gain_m']
        features['avg_speed_kmh'] = route_data['avg_speed_kmh']

        # Energy-relevant derived features
        features['elevation_per_km'] = (
            route_data['elevation_gain_m'] / (route_data['distance_km'] + 1e-3)
        )

        # Speed efficiency (most efficient around 60 km/h)
        features['speed_efficiency'] = np.exp(-((route_data['avg_speed_kmh'] - 60) / 30) ** 2)

        # Road type encoding
        if 'road_type' in route_data.columns:
            road_dummies = pd.get_dummies(route_data['road_type'], prefix='road')
            features = pd.concat([features, road_dummies], axis=1)

        # Weather impact
        features['ambient_temp_c'] = route_data['ambient_temp_c']
        features['temp_deviation_from_20'] = abs(route_data['ambient_temp_c'] - 20)
        features['wind_speed_kmh'] = route_data.get('wind_speed_kmh', 0)

        # Traffic impact
        features['traffic_level'] = route_data.get('traffic_level', 0)
        features['stops_per_km'] = (
            route_data.get('stop_count', 0) / (route_data['distance_km'] + 1e-3)
        )

        return features

    def train(self, X: pd.DataFrame, y: np.ndarray):
        """
        Train energy consumption model.

        Args:
            X: Feature matrix
            y: Energy consumed [kWh]
        """
        self.model.fit(X, y)
        score = self.model.score(X, y)
        print(f"Training R2: {score:.3f}")

    def predict_consumption(self, X: pd.DataFrame) -> np.ndarray:
        """
        Predict energy consumption for routes.

        Returns:
            Energy consumption [kWh]
        """
        return self.model.predict(X)

    def predict_range(
        self,
        route_features: pd.DataFrame,
        current_soc: float,
        battery_capacity_kwh: float
    ) -> Dict[str, float]:
        """
        Predict remaining range based on route profile.

        Args:
            route_features: Features for candidate routes
            current_soc: Current state of charge (0-100%)
            battery_capacity_kwh: Total battery capacity

        Returns:
            Dictionary with range estimates
        """
        # Available energy
        available_energy_kwh = (current_soc / 100) * battery_capacity_kwh

        # Predict consumption per route
        consumption_per_km = self.predict_consumption(route_features)

        # Range estimates
        estimated_range_km = available_energy_kwh / (consumption_per_km + 1e-6)

        return {
            'available_energy_kwh': available_energy_kwh,
            'estimated_consumption_kwh_per_km': consumption_per_km.mean(),
            'estimated_range_km': estimated_range_km.mean(),
            'range_uncertainty_km': estimated_range_km.std()
        }


# Example usage
if __name__ == "__main__":
    # Load historical trip data
    trips_df = pd.read_csv('historical_trips.csv')

    # Feature engineering
    forecaster = EnergyConsumptionForecaster()
    X = forecaster.engineer_route_features(trips_df)
    y = trips_df['energy_consumed_kwh'].values

    # Train
    forecaster.train(X, y)

    # Predict for new route
    new_route = pd.DataFrame([{
        'distance_km': 150,
        'elevation_gain_m': 500,
        'avg_speed_kmh': 80,
        'road_type': 'highway',
        'ambient_temp_c': 15,
        'wind_speed_kmh': 20,
        'traffic_level': 2,
        'stop_count': 5
    }])

    route_features = forecaster.engineer_route_features(new_route)
    range_estimate = forecaster.predict_range(
        route_features,
        current_soc=70,
        battery_capacity_kwh=75
    )

    print("\nRange Estimate:")
    for key, value in range_estimate.items():
        print(f"  {key}: {value:.2f}")
```

## Charging Demand Forecasting (SARIMAX)

```python
from statsmodels.tsa.statespace.sarimax import SARIMAX
import pandas as pd
import numpy as np
from typing import Tuple

class ChargingDemandForecaster:
    """
    Forecast charging station demand using SARIMAX.

    Captures:
    - Hourly seasonality (peak hours)
    - Weekly seasonality (weekday vs weekend)
    - Exogenous factors (weather, events)
    """

    def __init__(
        self,
        order: Tuple[int, int, int] = (1, 1, 1),
        seasonal_order: Tuple[int, int, int, int] = (1, 1, 1, 24)
    ):
        """
        Args:
            order: (p, d, q) for ARIMA
            seasonal_order: (P, D, Q, s) for seasonal component
                s=24 for hourly data with daily seasonality
        """
        self.order = order
        self.seasonal_order = seasonal_order
        self.model = None

    def fit(
        self,
        y: pd.Series,
        exog: pd.DataFrame = None
    ):
        """
        Fit SARIMAX model.

        Args:
            y: Time-series of charging demand (indexed by datetime)
            exog: Exogenous variables (temperature, events, etc.)
        """
        self.model = SARIMAX(
            y,
            exog=exog,
            order=self.order,
            seasonal_order=self.seasonal_order,
            enforce_stationarity=False,
            enforce_invertibility=False
        )

        self.results = self.model.fit(disp=False)
        print("Model fitted successfully")
        print(self.results.summary())

    def forecast(
        self,
        steps: int,
        exog: pd.DataFrame = None
    ) -> pd.DataFrame:
        """
        Forecast future demand.

        Args:
            steps: Number of steps ahead
            exog: Future exogenous variables

        Returns:
            DataFrame with forecast and confidence intervals
        """
        if self.model is None:
            raise ValueError("Model must be fitted before forecasting")

        forecast = self.results.get_forecast(steps=steps, exog=exog)
        forecast_df = forecast.summary_frame()

        return forecast_df.rename(columns={
            'mean': 'demand_forecast',
            'mean_ci_lower': 'lower_bound',
            'mean_ci_upper': 'upper_bound'
        })


# Example usage
if __name__ == "__main__":
    # Load hourly charging demand data
    demand_df = pd.read_csv('charging_demand.csv', parse_dates=['timestamp'])
    demand_df = demand_df.set_index('timestamp')

    # Exogenous variables
    exog_df = demand_df[['temperature_c', 'is_weekend', 'is_holiday']]
    y = demand_df['num_active_chargers']

    # Fit model
    forecaster = ChargingDemandForecaster(
        order=(1, 1, 1),
        seasonal_order=(1, 1, 1, 24)  # Daily seasonality
    )
    forecaster.fit(y, exog=exog_df)

    # Forecast next 48 hours
    future_exog = pd.DataFrame({
        'temperature_c': np.random.normal(20, 5, 48),
        'is_weekend': [0] * 24 + [1] * 24,
        'is_holiday': [0] * 48
    })

    forecast = forecaster.forecast(steps=48, exog=future_exog)
    print("\nDemand Forecast (next 48 hours):")
    print(forecast.head(12))
```

## Deployment Strategy

```yaml
# Time-series forecasting pipeline
pipeline:
  data_preparation:
    resampling: Hourly / Daily aggregation
    missing_data: Forward fill + interpolation
    outlier_handling: Median filter + IQR clipping

  feature_engineering:
    lag_features: [1, 7, 30] days
    rolling_statistics: Mean, std over [7, 30] day windows
    calendar_features: Hour, day_of_week, month, is_holiday

  model_training:
    framework: Prophet (quick) / LSTM (complex)
    validation: Time-series cross-validation
    hyperparameter_tuning: Bayesian optimization

  inference:
    frequency: Daily batch for long-term, real-time for short-term
    latency: <1s for API requests

  monitoring:
    metrics:
      - MAPE (Mean Absolute Percentage Error)
      - Coverage (% actual within confidence interval)
      - Forecast bias (systematic over/under prediction)

  retraining:
    trigger: MAPE > 10% OR weekly schedule
    validation: Backtest on last 90 days
```

## Production Checklist

- [ ] Historical data spans multiple seasons/years (if seasonal)
- [ ] Missing data strategy validated (forward fill, interpolation)
- [ ] Outliers identified and handled (capping, removal)
- [ ] Stationarity tested (ADF test) and differencing applied if needed
- [ ] Cross-validation on time-series splits (not random)
- [ ] Confidence intervals calibrated (90% coverage target)
- [ ] Model performance monitored (MAPE, coverage)
- [ ] Forecast horizon validated against business needs
- [ ] Retraining pipeline automated with data quality checks
- [ ] A/B testing for model updates (gradual rollout)
