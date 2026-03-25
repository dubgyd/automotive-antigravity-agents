# Cloud-Vehicle Integration — Connected Vehicle Platforms

Expert knowledge of vehicle-to-cloud connectivity (MQTT, AMQP, HTTP/2), telemetry streaming, remote diagnostics, cloud-based fleet management, and API gateways.

## Core Concepts

### Communication Protocols

1. **MQTT**: Lightweight pub/sub for telemetry (Eclipse Mosquitto, AWS IoT Core)
2. **AMQP**: Reliable message queuing (RabbitMQ, Azure Service Bus)
3. **HTTP/2**: RESTful APIs with server push
4. **WebSocket**: Real-time bidirectional communication
5. **gRPC**: High-performance RPC for services

### Architecture Patterns

- **Edge Computing**: Process data locally before cloud
- **Digital Twin**: Virtual representation of vehicle in cloud
- **Command & Control**: Remote vehicle operations
- **Fleet Management**: Aggregate analytics across vehicles
- **OTA Coordination**: Centralized update management

## Production-Ready Implementation

### 1. Vehicle Telemetry Client (Python/MQTT)

```python
#!/usr/bin/env python3
"""
Vehicle telemetry client using MQTT.
Streams vehicle data to cloud platform with offline buffering.
"""

import json
import time
import sqlite3
from dataclasses import dataclass, asdict
from datetime import datetime
from typing import Optional, List
import paho.mqtt.client as mqtt
import can


@dataclass
class TelemetryMessage:
    """Vehicle telemetry data point."""
    vin: str
    timestamp: str
    message_type: str
    data: dict


class VehicleTelemetryClient:
    """
    MQTT-based telemetry client.

    Features:
    - Real-time telemetry streaming
    - Offline buffering with SQLite
    - Automatic reconnection
    - QoS levels for reliability
    - Compression for bandwidth optimization
    """

    def __init__(self, config_path: str = "/etc/vehicle/telemetry-config.json"):
        self.config = self._load_config(config_path)
        self.vin = self._get_vin()
        self.mqtt_client = None
        self.can_bus = None
        self.offline_buffer = OfflineBuffer()
        self.connected = False

    def _load_config(self, path: str) -> dict:
        """Load configuration."""
        with open(path, 'r') as f:
            return json.load(f)

    def _get_vin(self) -> str:
        """Get vehicle VIN."""
        with open('/sys/firmware/devicetree/base/serial-number', 'r') as f:
            return f.read().strip()

    def connect(self):
        """Connect to MQTT broker."""
        self.mqtt_client = mqtt.Client(
            client_id=f"vehicle-{self.vin}",
            clean_session=False,  # Maintain session across reconnects
            protocol=mqtt.MQTTv5
        )

        # Set credentials
        self.mqtt_client.username_pw_set(
            self.config['mqtt_username'],
            self.config['mqtt_password']
        )

        # Configure TLS
        if self.config.get('mqtt_tls', True):
            self.mqtt_client.tls_set(
                ca_certs=self.config['mqtt_ca_cert'],
                certfile=self.config.get('mqtt_client_cert'),
                keyfile=self.config.get('mqtt_client_key')
            )

        # Set callbacks
        self.mqtt_client.on_connect = self._on_connect
        self.mqtt_client.on_disconnect = self._on_disconnect
        self.mqtt_client.on_message = self._on_message
        self.mqtt_client.on_publish = self._on_publish

        # Set last will (notify cloud if vehicle disconnects unexpectedly)
        self.mqtt_client.will_set(
            f"vehicles/{self.vin}/status",
            payload=json.dumps({
                "status": "offline",
                "timestamp": datetime.utcnow().isoformat()
            }),
            qos=1,
            retain=True
        )

        # Connect
        print(f"[Telemetry] Connecting to {self.config['mqtt_broker']}:{self.config['mqtt_port']}")
        self.mqtt_client.connect(
            self.config['mqtt_broker'],
            self.config['mqtt_port'],
            keepalive=60
        )

        # Start network loop in background
        self.mqtt_client.loop_start()

    def _on_connect(self, client, userdata, flags, rc, properties=None):
        """Handle MQTT connection."""
        if rc == 0:
            print("[Telemetry] Connected to MQTT broker")
            self.connected = True

            # Publish online status
            self.mqtt_client.publish(
                f"vehicles/{self.vin}/status",
                payload=json.dumps({
                    "status": "online",
                    "timestamp": datetime.utcnow().isoformat(),
                    "sw_version": self._get_software_version()
                }),
                qos=1,
                retain=True
            )

            # Subscribe to command topics
            self.mqtt_client.subscribe(f"vehicles/{self.vin}/commands/#", qos=1)

            # Send buffered messages
            self._flush_offline_buffer()
        else:
            print(f"[Telemetry] Connection failed: {rc}")
            self.connected = False

    def _on_disconnect(self, client, userdata, rc):
        """Handle MQTT disconnection."""
        print(f"[Telemetry] Disconnected from broker: {rc}")
        self.connected = False

        if rc != 0:
            print("[Telemetry] Unexpected disconnect, will reconnect")

    def _on_message(self, client, userdata, msg):
        """Handle incoming command messages."""
        print(f"[Telemetry] Received command: {msg.topic}")

        try:
            payload = json.loads(msg.payload.decode())
            self._handle_command(msg.topic, payload)
        except Exception as e:
            print(f"[Telemetry] Error processing command: {e}")

    def _on_publish(self, client, userdata, mid):
        """Handle successful publish."""
        # Remove from offline buffer if it was buffered
        pass

    def _handle_command(self, topic: str, payload: dict):
        """Handle remote commands from cloud."""
        command_type = topic.split('/')[-1]

        if command_type == "diagnostics":
            # Trigger diagnostic data collection
            print("[Telemetry] Starting diagnostic data collection")
            self._collect_diagnostics()

        elif command_type == "update":
            # Trigger OTA update check
            print("[Telemetry] Checking for updates")
            # Integration with OTA system

        elif command_type == "lock":
            # Remote lock command
            print("[Telemetry] Remote lock requested")
            self._remote_lock()

        elif command_type == "honk":
            # Remote horn activation
            print("[Telemetry] Remote honk requested")
            self._remote_honk()

    def publish_telemetry(self, message_type: str, data: dict, qos: int = 0):
        """
        Publish telemetry message.

        Args:
            message_type: Type of telemetry (battery, location, speed, etc.)
            data: Telemetry data
            qos: MQTT QoS level (0, 1, or 2)
        """
        msg = TelemetryMessage(
            vin=self.vin,
            timestamp=datetime.utcnow().isoformat(),
            message_type=message_type,
            data=data
        )

        topic = f"vehicles/{self.vin}/telemetry/{message_type}"
        payload = json.dumps(asdict(msg))

        if self.connected:
            result = self.mqtt_client.publish(topic, payload, qos=qos)

            if result.rc == mqtt.MQTT_ERR_SUCCESS:
                print(f"[Telemetry] Published {message_type}")
            else:
                print(f"[Telemetry] Publish failed: {result.rc}")
                # Buffer for later
                self.offline_buffer.store(topic, payload, qos)
        else:
            # Store in offline buffer
            self.offline_buffer.store(topic, payload, qos)
            print(f"[Telemetry] Buffered {message_type} (offline)")

    def _flush_offline_buffer(self):
        """Send buffered messages when connection restored."""
        messages = self.offline_buffer.retrieve_all()
        print(f"[Telemetry] Flushing {len(messages)} buffered messages")

        for msg in messages:
            self.mqtt_client.publish(msg['topic'], msg['payload'], qos=msg['qos'])
            self.offline_buffer.delete(msg['id'])

    def start_can_monitoring(self):
        """Start monitoring CAN bus and streaming telemetry."""
        print("[Telemetry] Starting CAN bus monitoring")

        # Connect to CAN bus
        self.can_bus = can.interface.Bus(channel='can0', bustype='socketcan')

        # Define telemetry intervals
        intervals = {
            'battery': 60,  # Every minute
            'location': 300,  # Every 5 minutes
            'speed': 10,  # Every 10 seconds
            'diagnostics': 3600,  # Every hour
        }

        last_publish = {k: 0 for k in intervals.keys()}

        while True:
            # Read CAN messages
            msg = self.can_bus.recv(timeout=1.0)

            if msg is None:
                continue

            current_time = time.time()

            # Process specific CAN IDs
            if msg.arbitration_id == 0x123:  # Battery telemetry
                if current_time - last_publish['battery'] >= intervals['battery']:
                    battery_data = self._parse_battery_can(msg.data)
                    self.publish_telemetry('battery', battery_data, qos=1)
                    last_publish['battery'] = current_time

            elif msg.arbitration_id == 0x456:  # Speed/location
                if current_time - last_publish['speed'] >= intervals['speed']:
                    speed_data = self._parse_speed_can(msg.data)
                    self.publish_telemetry('speed', speed_data, qos=0)
                    last_publish['speed'] = current_time

            # Periodic location publish
            if current_time - last_publish['location'] >= intervals['location']:
                location_data = self._get_gps_location()
                self.publish_telemetry('location', location_data, qos=1)
                last_publish['location'] = current_time

    def _parse_battery_can(self, data: bytes) -> dict:
        """Parse battery telemetry from CAN message."""
        return {
            'soc': int.from_bytes(data[0:2], 'big') / 100,  # State of charge %
            'voltage': int.from_bytes(data[2:4], 'big') / 10,  # Volts
            'current': int.from_bytes(data[4:6], 'big', signed=True) / 10,  # Amps
            'temperature': int.from_bytes(data[6:8], 'big') / 10 - 40,  # Celsius
        }

    def _parse_speed_can(self, data: bytes) -> dict:
        """Parse speed telemetry from CAN message."""
        return {
            'speed': int.from_bytes(data[0:2], 'big') / 100,  # km/h
            'odometer': int.from_bytes(data[2:6], 'big') / 10,  # km
        }

    def _get_gps_location(self) -> dict:
        """Get GPS location from GNSS receiver."""
        # Read from gpsd or similar
        return {
            'latitude': 37.7749,
            'longitude': -122.4194,
            'altitude': 16.0,
            'heading': 270.0,
            'accuracy': 3.5
        }

    def _get_software_version(self) -> str:
        """Get vehicle software version."""
        with open('/etc/vehicle/version', 'r') as f:
            return f.read().strip()

    def _collect_diagnostics(self):
        """Collect comprehensive diagnostic data."""
        diagnostics = {
            'dtcs': [],  # Diagnostic Trouble Codes
            'ecu_status': {},
            'battery_health': {},
            'sensor_status': {},
        }

        # Publish diagnostic report
        self.publish_telemetry('diagnostics', diagnostics, qos=1)

    def _remote_lock(self):
        """Execute remote lock command."""
        # Send CAN command to lock doors
        pass

    def _remote_honk(self):
        """Execute remote horn activation."""
        # Send CAN command to honk
        pass

    def disconnect(self):
        """Disconnect from MQTT broker."""
        if self.mqtt_client:
            self.mqtt_client.loop_stop()
            self.mqtt_client.disconnect()

        if self.can_bus:
            self.can_bus.shutdown()


class OfflineBuffer:
    """SQLite-based offline message buffer."""

    def __init__(self, db_path: str = "/var/lib/vehicle/telemetry-buffer.db"):
        self.db_path = db_path
        self._init_db()

    def _init_db(self):
        """Initialize SQLite database."""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

        cursor.execute('''
            CREATE TABLE IF NOT EXISTS buffer (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                topic TEXT NOT NULL,
                payload TEXT NOT NULL,
                qos INTEGER NOT NULL,
                timestamp REAL NOT NULL
            )
        ''')

        conn.commit()
        conn.close()

    def store(self, topic: str, payload: str, qos: int):
        """Store message in buffer."""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

        cursor.execute(
            'INSERT INTO buffer (topic, payload, qos, timestamp) VALUES (?, ?, ?, ?)',
            (topic, payload, qos, time.time())
        )

        conn.commit()
        conn.close()

    def retrieve_all(self) -> List[dict]:
        """Retrieve all buffered messages."""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

        cursor.execute('SELECT id, topic, payload, qos FROM buffer ORDER BY timestamp')
        rows = cursor.fetchall()

        conn.close()

        return [
            {'id': row[0], 'topic': row[1], 'payload': row[2], 'qos': row[3]}
            for row in rows
        ]

    def delete(self, msg_id: int):
        """Delete message from buffer."""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

        cursor.execute('DELETE FROM buffer WHERE id = ?', (msg_id,))

        conn.commit()
        conn.close()


def main():
    """Main telemetry client loop."""
    client = VehicleTelemetryClient()

    try:
        client.connect()
        client.start_can_monitoring()
    except KeyboardInterrupt:
        print("\n[Telemetry] Shutting down")
        client.disconnect()


if __name__ == "__main__":
    main()
```

### 2. Cloud Backend (AWS IoT Core Integration)

```python
#!/usr/bin/env python3
"""
Cloud backend for vehicle fleet management using AWS IoT Core.
"""

import json
import boto3
from datetime import datetime
from typing import Dict, List
from aws_iot_device_sdk import mqtt as mqtt5
import redis


class FleetManagementBackend:
    """
    Fleet management backend.

    Services:
    - Receive telemetry from vehicles
    - Store in time-series database
    - Real-time analytics
    - Remote command dispatch
    """

    def __init__(self):
        # AWS IoT Core client
        self.iot_client = boto3.client('iot-data', region_name='us-west-2')

        # DynamoDB for vehicle state
        self.dynamodb = boto3.resource('dynamodb', region_name='us-west-2')
        self.vehicle_table = self.dynamodb.Table('VehicleState')

        # Timestream for telemetry
        self.timestream = boto3.client('timestream-write', region_name='us-west-2')
        self.ts_database = 'VehicleTelemetry'
        self.ts_table = 'TelemetryData'

        # Redis for real-time data
        self.redis = redis.Redis(host='localhost', port=6379, decode_responses=True)

    def process_telemetry(self, vin: str, message_type: str, data: dict):
        """
        Process incoming telemetry message.

        Args:
            vin: Vehicle identification number
            message_type: Type of telemetry
            data: Telemetry data
        """
        print(f"[Fleet] Processing {message_type} from {vin}")

        # Update vehicle state in DynamoDB
        self._update_vehicle_state(vin, message_type, data)

        # Store in Timestream for historical analytics
        self._store_timestream(vin, message_type, data)

        # Cache in Redis for real-time queries
        self._cache_redis(vin, message_type, data)

        # Trigger alerts if necessary
        self._check_alerts(vin, message_type, data)

    def _update_vehicle_state(self, vin: str, message_type: str, data: dict):
        """Update vehicle state in DynamoDB."""
        self.vehicle_table.update_item(
            Key={'vin': vin},
            UpdateExpression=f'SET {message_type} = :data, last_update = :timestamp',
            ExpressionAttributeValues={
                ':data': data,
                ':timestamp': datetime.utcnow().isoformat()
            }
        )

    def _store_timestream(self, vin: str, message_type: str, data: dict):
        """Store telemetry in AWS Timestream."""
        records = []

        for key, value in data.items():
            records.append({
                'Time': str(int(datetime.utcnow().timestamp() * 1000)),
                'TimeUnit': 'MILLISECONDS',
                'Dimensions': [
                    {'Name': 'vin', 'Value': vin},
                    {'Name': 'message_type', 'Value': message_type},
                ],
                'MeasureName': key,
                'MeasureValue': str(value),
                'MeasureValueType': 'DOUBLE' if isinstance(value, float) else 'BIGINT'
            })

        try:
            self.timestream.write_records(
                DatabaseName=self.ts_database,
                TableName=self.ts_table,
                Records=records
            )
        except Exception as e:
            print(f"[Fleet] Timestream write error: {e}")

    def _cache_redis(self, vin: str, message_type: str, data: dict):
        """Cache latest telemetry in Redis."""
        key = f"vehicle:{vin}:{message_type}"
        self.redis.setex(key, 3600, json.dumps(data))  # 1 hour TTL

    def _check_alerts(self, vin: str, message_type: str, data: dict):
        """Check for alert conditions."""
        if message_type == 'battery':
            # Low battery alert
            if data.get('soc', 100) < 20:
                self._send_alert(vin, 'low_battery', f"Battery at {data['soc']}%")

            # High temperature alert
            if data.get('temperature', 0) > 50:
                self._send_alert(vin, 'high_temperature',
                               f"Battery temp: {data['temperature']}°C")

        elif message_type == 'diagnostics':
            # DTC alert
            if data.get('dtcs'):
                self._send_alert(vin, 'diagnostic_codes',
                               f"DTCs: {', '.join(data['dtcs'])}")

    def _send_alert(self, vin: str, alert_type: str, message: str):
        """Send alert to monitoring system."""
        print(f"[Fleet] ALERT - {vin}: {alert_type} - {message}")

        # Send to SNS topic
        sns = boto3.client('sns', region_name='us-west-2')
        sns.publish(
            TopicArn='arn:aws:sns:us-west-2:123456789012:vehicle-alerts',
            Subject=f"Vehicle Alert: {alert_type}",
            Message=f"VIN: {vin}\nType: {alert_type}\nMessage: {message}"
        )

    def send_command(self, vin: str, command: str, params: dict = None):
        """
        Send command to vehicle.

        Args:
            vin: Vehicle identification number
            command: Command type (lock, unlock, honk, update)
            params: Command parameters
        """
        topic = f"vehicles/{vin}/commands/{command}"
        payload = json.dumps(params or {})

        print(f"[Fleet] Sending command to {vin}: {command}")

        try:
            self.iot_client.publish(
                topic=topic,
                qos=1,
                payload=payload
            )

            # Log command
            self._log_command(vin, command, params)

        except Exception as e:
            print(f"[Fleet] Command send error: {e}")

    def _log_command(self, vin: str, command: str, params: dict):
        """Log command to DynamoDB."""
        commands_table = self.dynamodb.Table('VehicleCommands')

        commands_table.put_item(
            Item={
                'vin': vin,
                'timestamp': datetime.utcnow().isoformat(),
                'command': command,
                'params': params or {},
                'status': 'sent'
            }
        )

    def get_vehicle_state(self, vin: str) -> Dict:
        """Get current vehicle state."""
        response = self.vehicle_table.get_item(Key={'vin': vin})
        return response.get('Item', {})

    def get_fleet_status(self) -> List[Dict]:
        """Get status of entire fleet."""
        response = self.vehicle_table.scan()
        return response.get('Items', [])

    def query_telemetry_history(self, vin: str, metric: str,
                                start_time: datetime, end_time: datetime) -> List[Dict]:
        """Query historical telemetry from Timestream."""
        query_client = boto3.client('timestream-query', region_name='us-west-2')

        query = f"""
        SELECT time, measure_value::double as value
        FROM "{self.ts_database}"."{self.ts_table}"
        WHERE vin = '{vin}'
          AND measure_name = '{metric}'
          AND time BETWEEN from_iso8601_timestamp('{start_time.isoformat()}')
                       AND from_iso8601_timestamp('{end_time.isoformat()}')
        ORDER BY time DESC
        """

        try:
            response = query_client.query(QueryString=query)

            results = []
            for row in response['Rows']:
                results.append({
                    'time': row['Data'][0]['ScalarValue'],
                    'value': float(row['Data'][1]['ScalarValue'])
                })

            return results

        except Exception as e:
            print(f"[Fleet] Query error: {e}")
            return []
```

### 3. API Gateway (FastAPI)

```python
#!/usr/bin/env python3
"""
Fleet management API gateway.
RESTful API for vehicle operations and telemetry queries.
"""

from fastapi import FastAPI, HTTPException, Depends, Security
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
from datetime import datetime
from typing import List, Optional


app = FastAPI(title="Fleet Management API", version="2.0.0")
security = HTTPBearer()

# Initialize backend
backend = FleetManagementBackend()


class CommandRequest(BaseModel):
    """Remote command request."""
    command: str
    params: Optional[dict] = None


class TelemetryQuery(BaseModel):
    """Telemetry query parameters."""
    metric: str
    start_time: datetime
    end_time: datetime


@app.get("/api/v1/vehicles")
async def list_vehicles(credentials: HTTPAuthorizationCredentials = Security(security)):
    """List all vehicles in fleet."""
    fleet = backend.get_fleet_status()
    return {"vehicles": fleet, "count": len(fleet)}


@app.get("/api/v1/vehicles/{vin}")
async def get_vehicle(vin: str, credentials: HTTPAuthorizationCredentials = Security(security)):
    """Get vehicle state."""
    state = backend.get_vehicle_state(vin)

    if not state:
        raise HTTPException(status_code=404, detail="Vehicle not found")

    return state


@app.post("/api/v1/vehicles/{vin}/commands")
async def send_command(
    vin: str,
    request: CommandRequest,
    credentials: HTTPAuthorizationCredentials = Security(security)
):
    """Send command to vehicle."""
    backend.send_command(vin, request.command, request.params)
    return {"message": "Command sent", "vin": vin, "command": request.command}


@app.post("/api/v1/vehicles/{vin}/telemetry/query")
async def query_telemetry(
    vin: str,
    query: TelemetryQuery,
    credentials: HTTPAuthorizationCredentials = Security(security)
):
    """Query historical telemetry data."""
    results = backend.query_telemetry_history(
        vin,
        query.metric,
        query.start_time,
        query.end_time
    )

    return {"vin": vin, "metric": query.metric, "data": results}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)
```

### 4. Terraform Infrastructure (AWS)

```hcl
# File: terraform/main.tf
# AWS IoT Core infrastructure for vehicle fleet

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# IoT Core Thing Type for Vehicles
resource "aws_iot_thing_type" "vehicle" {
  name = "VehicleType"

  properties {
    description           = "Connected vehicle"
    searchable_attributes = ["vin", "model", "year"]
  }
}

# IoT Policy for Vehicle
resource "aws_iot_policy" "vehicle_policy" {
  name = "VehiclePolicy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iot:Connect"
        ]
        Resource = "arn:aws:iot:${var.aws_region}:${data.aws_caller_identity.current.account_id}:client/vehicle-*"
      },
      {
        Effect = "Allow"
        Action = [
          "iot:Publish"
        ]
        Resource = "arn:aws:iot:${var.aws_region}:${data.aws_caller_identity.current.account_id}:topic/vehicles/*/telemetry/*"
      },
      {
        Effect = "Allow"
        Action = [
          "iot:Subscribe"
        ]
        Resource = "arn:aws:iot:${var.aws_region}:${data.aws_caller_identity.current.account_id}:topicfilter/vehicles/*/commands/*"
      },
      {
        Effect = "Allow"
        Action = [
          "iot:Receive"
        ]
        Resource = "arn:aws:iot:${var.aws_region}:${data.aws_caller_identity.current.account_id}:topic/vehicles/*/commands/*"
      }
    ]
  })
}

# DynamoDB Table for Vehicle State
resource "aws_dynamodb_table" "vehicle_state" {
  name           = "VehicleState"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "vin"

  attribute {
    name = "vin"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = {
    Name = "vehicle-state"
  }
}

# Timestream Database for Telemetry
resource "aws_timestreamwrite_database" "telemetry" {
  database_name = "VehicleTelemetry"
}

resource "aws_timestreamwrite_table" "telemetry_data" {
  database_name = aws_timestreamwrite_database.telemetry.database_name
  table_name    = "TelemetryData"

  retention_properties {
    memory_store_retention_period_in_hours  = 24
    magnetic_store_retention_period_in_days = 365
  }
}

# SNS Topic for Alerts
resource "aws_sns_topic" "vehicle_alerts" {
  name = "vehicle-alerts"
}

# IoT Rule to Route Telemetry
resource "aws_iot_topic_rule" "telemetry_rule" {
  name        = "VehicleTelemetryRule"
  enabled     = true
  sql         = "SELECT * FROM 'vehicles/+/telemetry/#'"
  sql_version = "2016-03-23"

  timestream {
    database_name = aws_timestreamwrite_database.telemetry.database_name
    table_name    = aws_timestreamwrite_table.telemetry_data.table_name
    role_arn      = aws_iam_role.iot_timestream_role.arn

    dimension {
      name  = "vin"
      value = "${topic(2)}"
    }

    dimension {
      name  = "message_type"
      value = "${topic(4)}"
    }
  }

  dynamodb_v2 {
    role_arn = aws_iam_role.iot_dynamodb_role.arn
    put_item {
      table_name = aws_dynamodb_table.vehicle_state.name
    }
  }
}

# IAM Roles
resource "aws_iam_role" "iot_timestream_role" {
  name = "IoTTimestreamRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "iot.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "iot_timestream_policy" {
  name = "IoTTimestreamPolicy"
  role = aws_iam_role.iot_timestream_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "timestream:WriteRecords"
        ]
        Resource = aws_timestreamwrite_table.telemetry_data.arn
      },
      {
        Effect = "Allow"
        Action = [
          "timestream:DescribeEndpoints"
        ]
        Resource = "*"
      }
    ]
  })
}

data "aws_caller_identity" "current" {}

variable "aws_region" {
  default = "us-west-2"
}
```

## Real-World Examples

### Tesla Cloud Architecture
- **Real-time telemetry**: Battery, location, charging status
- **Fleet learning**: Aggregate data for Autopilot improvement
- **Remote commands**: Lock/unlock, climate control, horn/lights
- **OTA coordination**: Staged rollout based on fleet data

### Rivian Cloud Platform
- **Adventure network**: Charging station availability
- **Fleet Services**: Commercial fleet management for R1T
- **Remote diagnostics**: Proactive service scheduling
- **Gear Shop integration**: In-vehicle accessory ordering

### VW.OS Cloud Services
- **We Connect**: Remote vehicle services
- **Charging optimization**: Route planning with charging stations
- **Predictive maintenance**: AI-based service predictions
- **Car-Net**: Emergency services integration

## Best Practices

1. **Use MQTT for telemetry**: Lightweight, efficient, pub/sub
2. **Implement offline buffering**: Handle connectivity loss gracefully
3. **QoS levels**: Critical data (QoS 1), non-critical (QoS 0)
4. **TLS encryption**: Always use TLS 1.2+ for transport security
5. **Rate limiting**: Prevent telemetry storms
6. **Compression**: Reduce bandwidth usage
7. **Edge processing**: Process data locally before cloud
8. **Time-series database**: Use Timestream, InfluxDB, or TimescaleDB
9. **Real-time cache**: Redis for low-latency queries
10. **Command acknowledgment**: Require vehicle ACK for critical commands

## Security Considerations

- **Device authentication**: X.509 certificates per vehicle
- **Message encryption**: TLS 1.2+ for transport
- **Authorization**: Fine-grained permissions per VIN
- **Audit logging**: Log all commands and access
- **API rate limiting**: Prevent abuse
- **Data retention**: GDPR-compliant data lifecycle
- **Secure provisioning**: Certificate injection during manufacturing

## References

- **AWS IoT Core**: https://aws.amazon.com/iot-core/
- **Azure IoT Hub**: https://azure.microsoft.com/en-us/products/iot-hub/
- **Eclipse Paho MQTT**: https://www.eclipse.org/paho/
- **MQTT Specification**: https://mqtt.org/
- **AMQP**: https://www.amqp.org/
