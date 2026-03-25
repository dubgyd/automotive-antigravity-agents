# Vehicle Middleware Platforms — SDV Middleware Stacks

Expert knowledge of SDV middleware stacks (COVESA VSS, Eclipse SDV, AUTOSAR Adaptive), data models (VSS/VISS), pub-sub brokers, and service mesh for vehicles.

## Core Concepts

### Middleware Components

1. **Data Abstraction**: VSS (Vehicle Signal Specification)
2. **Service Communication**: SOME/IP, DDS, MQTT
3. **Service Discovery**: mDNS, service registries
4. **Security**: TLS, authentication, authorization
5. **Orchestration**: Lifecycle management

### Key Standards

- **COVESA VSS**: Standardized vehicle data model
- **COVESA VISS**: Vehicle Information Service Specification (API)
- **Eclipse SDV**: Open-source SDV components
- **AUTOSAR Adaptive**: Service-oriented automotive architecture

## Production-Ready Implementation

### 1. VSS Data Model Implementation

```yaml
# Vehicle Signal Specification (VSS) tree
# File: vehicle-signals.vspec

Vehicle:
  description: Top-level vehicle
  type: branch

Vehicle.Speed:
  datatype: float
  type: sensor
  unit: km/h
  description: Vehicle speed
  min: 0
  max: 300

Vehicle.Powertrain:
  type: branch
  description: Powertrain signals

Vehicle.Powertrain.Battery:
  type: branch
  description: Battery system

Vehicle.Powertrain.Battery.StateOfCharge:
  datatype: float
  type: sensor
  unit: percent
  description: Battery state of charge
  min: 0
  max: 100

Vehicle.Powertrain.Battery.Voltage:
  datatype: float
  type: sensor
  unit: V
  description: Battery voltage
  min: 0
  max: 800

Vehicle.Powertrain.Battery.Current:
  datatype: float
  type: sensor
  unit: A
  description: Battery current (positive = charging)
  min: -400
  max: 400

Vehicle.Powertrain.Battery.Temperature:
  datatype: float
  type: sensor
  unit: celsius
  description: Battery temperature
  min: -40
  max: 80

Vehicle.Cabin:
  type: branch
  description: Cabin signals

Vehicle.Cabin.HVAC:
  type: branch
  description: HVAC system

Vehicle.Cabin.HVAC.IsAirConditioningActive:
  datatype: boolean
  type: actuator
  description: Air conditioning status

Vehicle.Cabin.HVAC.AmbientAirTemperature:
  datatype: float
  type: sensor
  unit: celsius
  description: Ambient temperature

Vehicle.Body:
  type: branch
  description: Body signals

Vehicle.Body.Doors:
  type: branch
  instances:
    - Row1Left
    - Row1Right
    - Row2Left
    - Row2Right

Vehicle.Body.Doors.IsLocked:
  datatype: boolean
  type: actuator
  description: Door lock status

Vehicle.Body.Doors.IsOpen:
  datatype: boolean
  type: sensor
  description: Door open status

Vehicle.ADAS:
  type: branch
  description: ADAS signals

Vehicle.ADAS.CruiseControl:
  type: branch
  description: Cruise control

Vehicle.ADAS.CruiseControl.IsActive:
  datatype: boolean
  type: actuator
  description: Cruise control active

Vehicle.ADAS.CruiseControl.SpeedSet:
  datatype: float
  type: actuator
  unit: km/h
  description: Set cruise control speed
```

### 2. VSS Data Broker (Rust)

```rust
// VSS data broker implementation
// File: vss-broker/src/main.rs

use tokio;
use std::collections::HashMap;
use std::sync::{Arc, RwLock};
use serde::{Deserialize, Serialize};
use warp::Filter;

#[derive(Debug, Clone, Serialize, Deserialize)]
struct VehicleSignal {
    path: String,
    value: SignalValue,
    timestamp: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(untagged)]
enum SignalValue {
    Float(f64),
    Int(i64),
    Bool(bool),
    String(String),
}

#[derive(Clone)]
struct DataBroker {
    signals: Arc<RwLock<HashMap<String, VehicleSignal>>>,
    subscribers: Arc<RwLock<HashMap<String, Vec<tokio::sync::mpsc::UnboundedSender<VehicleSignal>>>>>,
}

impl DataBroker {
    fn new() -> Self {
        DataBroker {
            signals: Arc::new(RwLock::new(HashMap::new())),
            subscribers: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    /// Get signal value
    fn get(&self, path: &str) -> Option<VehicleSignal> {
        let signals = self.signals.read().unwrap();
        signals.get(path).cloned()
    }

    /// Set signal value
    fn set(&self, signal: VehicleSignal) {
        let path = signal.path.clone();

        // Store signal
        {
            let mut signals = self.signals.write().unwrap();
            signals.insert(path.clone(), signal.clone());
        }

        // Notify subscribers
        self.notify_subscribers(&path, signal);
    }

    /// Subscribe to signal updates
    fn subscribe(&self, path: String) -> tokio::sync::mpsc::UnboundedReceiver<VehicleSignal> {
        let (tx, rx) = tokio::sync::mpsc::unbounded_channel();

        let mut subscribers = self.subscribers.write().unwrap();
        subscribers.entry(path).or_insert_with(Vec::new).push(tx);

        rx
    }

    /// Notify subscribers of signal update
    fn notify_subscribers(&self, path: &str, signal: VehicleSignal) {
        let subscribers = self.subscribers.read().unwrap();

        if let Some(subs) = subscribers.get(path) {
            for tx in subs {
                let _ = tx.send(signal.clone());
            }
        }

        // Also notify wildcard subscribers (path.*)
        let parts: Vec<&str> = path.split('.').collect();
        for i in 0..parts.len() {
            let wildcard_path = format!("{}.*", parts[..i].join("."));
            if let Some(subs) = subscribers.get(&wildcard_path) {
                for tx in subs {
                    let _ = tx.send(signal.clone());
                }
            }
        }
    }

    /// Batch get signals
    fn get_batch(&self, paths: Vec<String>) -> HashMap<String, VehicleSignal> {
        let signals = self.signals.read().unwrap();
        let mut result = HashMap::new();

        for path in paths {
            if let Some(signal) = signals.get(&path) {
                result.insert(path, signal.clone());
            }
        }

        result
    }
}

#[tokio::main]
async fn main() {
    let broker = DataBroker::new();
    let broker = Arc::new(broker);

    // REST API routes
    let broker_filter = warp::any().map(move || broker.clone());

    // GET /api/signals/{path}
    let get_signal = warp::path!("api" / "signals" / String)
        .and(warp::get())
        .and(broker_filter.clone())
        .map(|path: String, broker: Arc<DataBroker>| {
            match broker.get(&path) {
                Some(signal) => warp::reply::json(&signal),
                None => warp::reply::json(&serde_json::json!({
                    "error": "Signal not found"
                })),
            }
        });

    // POST /api/signals
    let set_signal = warp::path!("api" / "signals")
        .and(warp::post())
        .and(warp::body::json())
        .and(broker_filter.clone())
        .map(|signal: VehicleSignal, broker: Arc<DataBroker>| {
            broker.set(signal.clone());
            warp::reply::json(&serde_json::json!({
                "status": "ok",
                "path": signal.path
            }))
        });

    // WebSocket /api/subscribe
    let subscribe = warp::path!("api" / "subscribe")
        .and(warp::ws())
        .and(broker_filter.clone())
        .map(|ws: warp::ws::Ws, broker: Arc<DataBroker>| {
            ws.on_upgrade(move |socket| handle_websocket(socket, broker))
        });

    let routes = get_signal
        .or(set_signal)
        .or(subscribe);

    println!("[VSS Broker] Starting on 0.0.0.0:8080");
    warp::serve(routes)
        .run(([0, 0, 0, 0], 8080))
        .await;
}

async fn handle_websocket(
    websocket: warp::ws::WebSocket,
    broker: Arc<DataBroker>
) {
    use futures::{StreamExt, SinkExt};

    let (mut tx, mut rx) = websocket.split();

    // Handle incoming subscription requests
    while let Some(result) = rx.next().await {
        let msg = match result {
            Ok(msg) => msg,
            Err(e) => {
                eprintln!("WebSocket error: {}", e);
                break;
            }
        };

        if let Ok(text) = msg.to_str() {
            // Parse subscription request
            if let Ok(req) = serde_json::from_str::<serde_json::Value>(text) {
                if let Some(path) = req["path"].as_str() {
                    let path = path.to_string();
                    let mut signal_rx = broker.subscribe(path.clone());

                    // Send updates
                    tokio::spawn(async move {
                        while let Some(signal) = signal_rx.recv().await {
                            let json = serde_json::to_string(&signal).unwrap();
                            if tx.send(warp::ws::Message::text(json)).await.is_err() {
                                break;
                            }
                        }
                    });
                }
            }
        }
    }
}
```

### 3. VISS Server (Python/FastAPI)

```python
#!/usr/bin/env python3
"""
VISS (Vehicle Information Service Specification) server.
RESTful and WebSocket API for VSS data access.
"""

from fastapi import FastAPI, WebSocket, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from typing import Optional, List, Dict, Any
import asyncio
import json
from datetime import datetime


app = FastAPI(title="VISS Server", version="2.0.0")


class VehicleSignal(BaseModel):
    """Vehicle signal data model."""
    path: str
    value: Any
    timestamp: Optional[int] = None


class GetRequest(BaseModel):
    """VISS GET request."""
    action: str = "get"
    path: str
    requestId: str


class SetRequest(BaseModel):
    """VISS SET request."""
    action: str = "set"
    path: str
    value: Any
    requestId: str


class SubscribeRequest(BaseModel):
    """VISS SUBSCRIBE request."""
    action: str = "subscribe"
    path: str
    subscriptionId: str


# In-memory signal storage (replace with Redis in production)
signals_db: Dict[str, VehicleSignal] = {}

# WebSocket subscriptions
subscriptions: Dict[str, List[WebSocket]] = {}


@app.get("/vss/api/v2/{path:path}")
async def get_signal_rest(path: str):
    """
    Get signal value via REST API.

    Example: GET /vss/api/v2/Vehicle/Speed
    """
    if path not in signals_db:
        raise HTTPException(status_code=404, detail="Signal not found")

    signal = signals_db[path]

    return JSONResponse({
        "action": "get",
        "path": path,
        "value": signal.value,
        "timestamp": signal.timestamp or int(datetime.utcnow().timestamp() * 1000),
        "requestId": "rest-" + str(int(datetime.utcnow().timestamp()))
    })


@app.put("/vss/api/v2/{path:path}")
async def set_signal_rest(path: str, value: Any):
    """
    Set signal value via REST API.

    Example: PUT /vss/api/v2/Vehicle/Cabin/HVAC/IsAirConditioningActive
    Body: {"value": true}
    """
    signal = VehicleSignal(
        path=path,
        value=value,
        timestamp=int(datetime.utcnow().timestamp() * 1000)
    )

    signals_db[path] = signal

    # Notify subscribers
    await notify_subscribers(path, signal)

    return JSONResponse({
        "action": "set",
        "path": path,
        "timestamp": signal.timestamp,
        "requestId": "rest-" + str(int(datetime.utcnow().timestamp()))
    })


@app.websocket("/vss/api/v2")
async def websocket_endpoint(websocket: WebSocket):
    """
    VISS WebSocket endpoint for real-time communication.

    Supports:
    - GET: Get signal value
    - SET: Set signal value
    - SUBSCRIBE: Subscribe to signal updates
    - UNSUBSCRIBE: Unsubscribe from signal
    """
    await websocket.accept()

    try:
        while True:
            # Receive request
            data = await websocket.receive_text()
            request = json.loads(data)

            action = request.get("action")

            if action == "get":
                await handle_get(websocket, request)
            elif action == "set":
                await handle_set(websocket, request)
            elif action == "subscribe":
                await handle_subscribe(websocket, request)
            elif action == "unsubscribe":
                await handle_unsubscribe(websocket, request)
            else:
                await websocket.send_json({
                    "error": {"number": 400, "message": "Invalid action"},
                    "requestId": request.get("requestId", "unknown")
                })

    except Exception as e:
        print(f"[VISS] WebSocket error: {e}")
    finally:
        # Clean up subscriptions
        for path, subs in subscriptions.items():
            if websocket in subs:
                subs.remove(websocket)


async def handle_get(websocket: WebSocket, request: dict):
    """Handle GET request."""
    path = request["path"]

    if path not in signals_db:
        await websocket.send_json({
            "action": "get",
            "error": {"number": 404, "message": "Signal not found"},
            "requestId": request["requestId"]
        })
        return

    signal = signals_db[path]

    await websocket.send_json({
        "action": "get",
        "path": path,
        "value": signal.value,
        "timestamp": signal.timestamp,
        "requestId": request["requestId"]
    })


async def handle_set(websocket: WebSocket, request: dict):
    """Handle SET request."""
    path = request["path"]
    value = request["value"]

    signal = VehicleSignal(
        path=path,
        value=value,
        timestamp=int(datetime.utcnow().timestamp() * 1000)
    )

    signals_db[path] = signal

    # Notify subscribers
    await notify_subscribers(path, signal)

    await websocket.send_json({
        "action": "set",
        "path": path,
        "timestamp": signal.timestamp,
        "requestId": request["requestId"]
    })


async def handle_subscribe(websocket: WebSocket, request: dict):
    """Handle SUBSCRIBE request."""
    path = request["path"]
    subscription_id = request["subscriptionId"]

    # Add to subscriptions
    if path not in subscriptions:
        subscriptions[path] = []

    subscriptions[path].append(websocket)

    # Send confirmation
    await websocket.send_json({
        "action": "subscribe",
        "subscriptionId": subscription_id,
        "timestamp": int(datetime.utcnow().timestamp() * 1000)
    })


async def handle_unsubscribe(websocket: WebSocket, request: dict):
    """Handle UNSUBSCRIBE request."""
    subscription_id = request["subscriptionId"]

    # Remove from subscriptions
    for path, subs in subscriptions.items():
        if websocket in subs:
            subs.remove(websocket)

    await websocket.send_json({
        "action": "unsubscribe",
        "subscriptionId": subscription_id,
        "timestamp": int(datetime.utcnow().timestamp() * 1000)
    })


async def notify_subscribers(path: str, signal: VehicleSignal):
    """Notify all subscribers of signal update."""
    if path in subscriptions:
        notification = {
            "action": "subscription",
            "path": path,
            "value": signal.value,
            "timestamp": signal.timestamp
        }

        # Send to all subscribers
        dead_sockets = []
        for websocket in subscriptions[path]:
            try:
                await websocket.send_json(notification)
            except Exception:
                dead_sockets.append(websocket)

        # Remove dead sockets
        for ws in dead_sockets:
            subscriptions[path].remove(ws)


# Populate some initial data
@app.on_event("startup")
async def populate_initial_data():
    """Populate initial vehicle signals."""
    initial_signals = [
        VehicleSignal(path="Vehicle.Speed", value=0.0),
        VehicleSignal(path="Vehicle.Powertrain.Battery.StateOfCharge", value=80.0),
        VehicleSignal(path="Vehicle.Powertrain.Battery.Voltage", value=400.0),
        VehicleSignal(path="Vehicle.Powertrain.Battery.Current", value=0.0),
        VehicleSignal(path="Vehicle.Cabin.HVAC.IsAirConditioningActive", value=False),
        VehicleSignal(path="Vehicle.Body.Doors.Row1Left.IsLocked", value=True),
        VehicleSignal(path="Vehicle.ADAS.CruiseControl.IsActive", value=False),
    ]

    for signal in initial_signals:
        signal.timestamp = int(datetime.utcnow().timestamp() * 1000)
        signals_db[signal.path] = signal

    print("[VISS] Initial signals populated")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)
```

### 4. Service Mesh Configuration (Istio-like for Automotive)

```yaml
# Service mesh configuration for vehicle platform
# File: vehicle-service-mesh.yaml

apiVersion: v1
kind: ConfigMap
metadata:
  name: service-mesh-config
  namespace: vehicle-platform
data:
  mesh-config.yaml: |
    # Global mesh configuration
    defaultConfig:
      discoveryAddress: mesh-pilot.vehicle-platform.svc:15010
      tracing:
        zipkin:
          address: zipkin.vehicle-platform.svc:9411
      proxyMetadata:
        ISTIO_META_DNS_CAPTURE: "true"
        ISTIO_META_DNS_AUTO_ALLOCATE: "true"

    # Access logging
    accessLogFile: /dev/stdout
    accessLogEncoding: JSON

    # mTLS configuration
    enableAutoMtls: true

    # Trust domain
    trustDomain: vehicle.local

    # Service discovery
    defaultServiceExportTo:
      - "*"

---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: vss-broker
spec:
  hosts:
    - vss-broker.vehicle-platform.svc
  http:
    - match:
        - uri:
            prefix: /api/signals
      route:
        - destination:
            host: vss-broker.vehicle-platform.svc
            port:
              number: 8080
      timeout: 5s
      retries:
        attempts: 3
        perTryTimeout: 2s

---
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: vss-broker
spec:
  host: vss-broker.vehicle-platform.svc
  trafficPolicy:
    loadBalancer:
      simple: ROUND_ROBIN
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 50
        http2MaxRequests: 100
    outlierDetection:
      consecutiveErrors: 5
      interval: 30s
      baseEjectionTime: 60s
      maxEjectionPercent: 50

---
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: vehicle-platform
spec:
  mtls:
    mode: STRICT

---
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: vss-access-control
  namespace: vehicle-platform
spec:
  selector:
    matchLabels:
      app: vss-broker
  action: ALLOW
  rules:
    - from:
        - source:
            principals: ["cluster.local/ns/infotainment/sa/spotify"]
      to:
        - operation:
            methods: ["GET"]
            paths: ["/api/signals/Vehicle/Speed"]
```

### 5. Eclipse Kuksa Integration

```python
#!/usr/bin/env python3
"""
Eclipse Kuksa.VAL integration for VSS data access.
"""

import asyncio
from kuksa_client.grpc import VSSClient
from kuksa_client.grpc.aio import VSSClientAsync


async def main():
    """Example Kuksa.VAL client."""

    # Connect to Kuksa databroker
    async with VSSClientAsync('127.0.0.1', 55555) as client:
        print("[Kuksa] Connected to data broker")

        # Set signal value
        await client.set_current_values({
            'Vehicle.Speed': 65.5,
            'Vehicle.Powertrain.Battery.StateOfCharge': 75.0
        })

        print("[Kuksa] Signals set")

        # Get signal value
        response = await client.get_current_values([
            'Vehicle.Speed',
            'Vehicle.Powertrain.Battery.StateOfCharge'
        ])

        for entry in response.entries:
            print(f"[Kuksa] {entry.path} = {entry.value.double}")

        # Subscribe to signal
        async for updates in client.subscribe_current_values([
            'Vehicle.Speed'
        ]):
            for update in updates.updates:
                print(f"[Kuksa] Update: {update.entry.path} = {update.entry.value.double}")


if __name__ == "__main__":
    asyncio.run(main())
```

## Real-World Examples

### COVESA (Connected Vehicle Systems Alliance)
- **VSS Standard**: De facto vehicle data model
- **VISS API**: RESTful and WebSocket access to VSS
- **Industry adoption**: BMW, Ford, Tesla, VW all exploring VSS

### Eclipse SDV Working Group
- **Kuksa.VAL**: Reference VSS data broker
- **Eclipse Leda**: SDV platform distribution
- **Eclipse Ankaios**: Workload orchestrator
- **Eclipse Zenoh**: Unified communication middleware

### AUTOSAR Adaptive
- **Service-oriented**: Pub/sub and RPC services
- **SOME/IP**: Scalable service-oriented middleware
- **Ara::Com**: Communication management API
- **Service discovery**: Dynamic service registration

### Apex.AI
- **ROS 2 for automotive**: Safe, real-time ROS 2
- **DDS middleware**: OMG Data Distribution Service
- **Apex.OS**: Automotive-grade Linux + ROS 2

## Best Practices

1. **Use VSS**: Standardize on VSS data model
2. **Service mesh**: Use service mesh for inter-service communication
3. **mTLS everywhere**: Mutual TLS for all service communication
4. **API gateway**: Centralized API management
5. **Rate limiting**: Protect services from overload
6. **Circuit breakers**: Handle service failures gracefully
7. **Observability**: Distributed tracing (Zipkin, Jaeger)
8. **Service discovery**: Dynamic service registration
9. **Version management**: API versioning strategy
10. **Documentation**: OpenAPI specs for all services

## Security Considerations

- **mTLS**: Mutual authentication between services
- **RBAC**: Role-based access control for VSS signals
- **API keys**: Authenticate app access to services
- **Rate limiting**: Prevent abuse
- **Audit logging**: Log all signal access
- **Encryption**: Encrypt sensitive signals at rest
- **Network policies**: Restrict service-to-service communication

## References

- **COVESA VSS**: https://covesa.global/
- **Eclipse Kuksa**: https://www.eclipse.org/kuksa/
- **Eclipse SDV**: https://sdv.eclipse.org/
- **AUTOSAR Adaptive**: https://www.autosar.org/standards/adaptive-platform/
- **SOME/IP**: https://some-ip.com/
- **Zenoh**: https://zenoh.io/
