# Event-Driven Architecture for Automotive

Expert guidance for building event-driven automotive systems using AWS EventBridge, Azure Event Grid, and Google Cloud Pub/Sub for scalable vehicle event processing.

## Architecture Patterns

### Event Flow

```
Vehicle ECUs -> Gateway -> Event Bus -> Event Handlers -> Data Stores
                                  |
                                  v
                           Event Processing Rules
                                  |
                                  v
                          Downstream Services
                         (Analytics, Alerts, ML)
```

**Core Components**:
- **Event Producers**: Vehicles, gateways, services
- **Event Bus**: Central routing mechanism
- **Event Consumers**: Lambdas, microservices, queues
- **Event Archive**: Long-term storage for replay

## AWS EventBridge

### Event Bus Architecture

```yaml
# CloudFormation template
Resources:
  VehicleEventBus:
    Type: AWS::Events::EventBus
    Properties:
      Name: vehicle-events

  # Archive for event replay
  VehicleEventArchive:
    Type: AWS::Events::Archive
    Properties:
      ArchiveName: vehicle-events-archive
      SourceArn: !GetAtt VehicleEventBus.Arn
      RetentionDays: 365

  # Rule: Battery anomaly detection
  BatteryAnomalyRule:
    Type: AWS::Events::Rule
    Properties:
      Name: battery-anomaly-detection
      EventBusName: !Ref VehicleEventBus
      EventPattern:
        source:
          - vehicle.telemetry
        detail-type:
          - BatteryMetrics
        detail:
          battery_temp_c:
            - numeric:
                - ">"
                - 60
      State: ENABLED
      Targets:
        - Arn: !GetAtt BatteryAnomalyFunction.Arn
          Id: BatteryAnomalyLambda
          RetryPolicy:
            MaximumRetryAttempts: 2
            MaximumEventAge: 3600
          DeadLetterConfig:
            Arn: !GetAtt BatteryAnomalyDLQ.Arn

  # Rule: Diagnostic trouble codes
  DiagnosticCodeRule:
    Type: AWS::Events::Rule
    Properties:
      Name: diagnostic-code-processing
      EventBusName: !Ref VehicleEventBus
      EventPattern:
        source:
          - vehicle.diagnostics
        detail-type:
          - DTCDetected
        detail:
          severity:
            - critical
            - high
      Targets:
        - Arn: !Ref DiagnosticQueue.Arn
          Id: DiagnosticSQS
        - Arn: !Ref DiagnosticTopic.Arn
          Id: DiagnosticSNS

  # Rule: Vehicle state changes
  VehicleStateRule:
    Type: AWS::Events::Rule
    Properties:
      Name: vehicle-state-change
      EventBusName: !Ref VehicleEventBus
      EventPattern:
        source:
          - vehicle.state
        detail-type:
          - StateChange
        detail:
          previous_state:
            - parked
          current_state:
            - driving
      Targets:
        - Arn: !GetAtt StateChangeFunction.Arn
          Id: StateChangeLambda

  BatteryAnomalyDLQ:
    Type: AWS::SQS::Queue
    Properties:
      QueueName: battery-anomaly-dlq
      MessageRetentionPeriod: 1209600  # 14 days

  DiagnosticQueue:
    Type: AWS::SQS::Queue
    Properties:
      QueueName: diagnostic-processing-queue
      VisibilityTimeout: 300
      RedrivePolicy:
        deadLetterTargetArn: !GetAtt DiagnosticDLQ.Arn
        maxReceiveCount: 3

  DiagnosticDLQ:
    Type: AWS::SQS::Queue
    Properties:
      QueueName: diagnostic-dlq

  DiagnosticTopic:
    Type: AWS::SNS::Topic
    Properties:
      TopicName: diagnostic-alerts
```

### Event Producer

```python
# event_producer.py
import boto3
import json
from datetime import datetime
from typing import Dict, Any

eventbridge = boto3.client('events')

def publish_battery_event(vin: str, metrics: Dict[str, Any]):
    """
    Publish battery metrics event to EventBridge
    """
    event = {
        'Source': 'vehicle.telemetry',
        'DetailType': 'BatteryMetrics',
        'Detail': json.dumps({
            'vin': vin,
            'timestamp': datetime.utcnow().isoformat(),
            'battery_voltage_v': metrics['voltage'],
            'battery_current_a': metrics['current'],
            'battery_temp_c': metrics['temperature'],
            'battery_soc_pct': metrics['soc'],
            'cell_voltages': metrics.get('cell_voltages', []),
            'health_status': metrics.get('health_status', 'normal')
        }),
        'EventBusName': 'vehicle-events'
    }

    response = eventbridge.put_events(Entries=[event])

    if response['FailedEntryCount'] > 0:
        raise Exception(f"Failed to publish event: {response['Entries'][0]}")

    return response

def publish_diagnostic_event(vin: str, dtc_code: str, severity: str, description: str):
    """
    Publish diagnostic trouble code event
    """
    event = {
        'Source': 'vehicle.diagnostics',
        'DetailType': 'DTCDetected',
        'Detail': json.dumps({
            'vin': vin,
            'timestamp': datetime.utcnow().isoformat(),
            'dtc_code': dtc_code,
            'severity': severity,
            'description': description,
            'system': extract_system_from_dtc(dtc_code)
        }),
        'EventBusName': 'vehicle-events'
    }

    return eventbridge.put_events(Entries=[event])

def publish_state_change_event(vin: str, previous_state: str, current_state: str):
    """
    Publish vehicle state change event
    """
    event = {
        'Source': 'vehicle.state',
        'DetailType': 'StateChange',
        'Detail': json.dumps({
            'vin': vin,
            'timestamp': datetime.utcnow().isoformat(),
            'previous_state': previous_state,
            'current_state': current_state,
            'location': get_vehicle_location(vin)
        }),
        'EventBusName': 'vehicle-events'
    }

    return eventbridge.put_events(Entries=[event])

def publish_batch_events(events: list):
    """
    Publish multiple events in a single call (max 10)
    """
    entries = []

    for event in events[:10]:  # EventBridge limit
        entries.append({
            'Source': event['source'],
            'DetailType': event['detail_type'],
            'Detail': json.dumps(event['detail']),
            'EventBusName': 'vehicle-events'
        })

    response = eventbridge.put_events(Entries=entries)

    return {
        'total': len(entries),
        'failed': response['FailedEntryCount'],
        'successful': len(entries) - response['FailedEntryCount']
    }

def extract_system_from_dtc(dtc_code: str) -> str:
    """
    Extract vehicle system from DTC code
    """
    if dtc_code.startswith('P'):
        return 'powertrain'
    elif dtc_code.startswith('C'):
        return 'chassis'
    elif dtc_code.startswith('B'):
        return 'body'
    elif dtc_code.startswith('U'):
        return 'network'
    return 'unknown'

def get_vehicle_location(vin: str) -> Dict[str, float]:
    """
    Get current vehicle location (placeholder)
    """
    # Would query from telemetry database
    return {'latitude': 0.0, 'longitude': 0.0}
```

### Event Consumer

```python
# event_consumer.py
import json
import boto3
from typing import Dict, Any

dynamodb = boto3.resource('dynamodb')
sns = boto3.client('sns')
sqs = boto3.client('sqs')

def handle_battery_anomaly(event: Dict[str, Any], context):
    """
    Handle battery anomaly events from EventBridge
    """
    detail = event['detail']
    vin = detail['vin']
    temp = detail['battery_temp_c']
    voltage = detail['battery_voltage_v']

    # Store anomaly
    table = dynamodb.Table('BatteryAnomalies')
    table.put_item(
        Item={
            'VIN': vin,
            'Timestamp': detail['timestamp'],
            'Temperature': temp,
            'Voltage': voltage,
            'Severity': determine_severity(temp, voltage),
            'Status': 'open'
        }
    )

    # Send alert if critical
    if temp > 65 or voltage < 300:
        send_critical_alert(vin, detail)

    # Schedule maintenance check
    schedule_maintenance(vin, 'battery_check')

    return {'statusCode': 200}

def handle_diagnostic_code(event: Dict[str, Any], context):
    """
    Handle diagnostic trouble code events
    """
    detail = event['detail']
    vin = detail['vin']
    dtc_code = detail['dtc_code']
    severity = detail['severity']

    # Store DTC
    table = dynamodb.Table('DiagnosticCodes')
    table.put_item(
        Item={
            'VIN': vin,
            'DTCCode': dtc_code,
            'Timestamp': detail['timestamp'],
            'Severity': severity,
            'Description': detail['description'],
            'System': detail['system'],
            'Resolved': False
        }
    )

    # Trigger automated diagnostics
    if severity in ['critical', 'high']:
        trigger_remote_diagnostics(vin, dtc_code)

    return {'statusCode': 200}

def handle_state_change(event: Dict[str, Any], context):
    """
    Handle vehicle state change events
    """
    detail = event['detail']
    vin = detail['vin']
    current_state = detail['current_state']

    # Update vehicle state cache
    update_vehicle_state_cache(vin, current_state)

    # Start trip tracking if driving
    if current_state == 'driving':
        start_trip_tracking(vin, detail['timestamp'])

    # End trip tracking if parked
    elif current_state == 'parked':
        end_trip_tracking(vin, detail['timestamp'])

    return {'statusCode': 200}

def determine_severity(temp: float, voltage: float) -> str:
    """
    Determine anomaly severity
    """
    if temp > 70 or voltage < 280:
        return 'critical'
    elif temp > 60 or voltage < 300:
        return 'high'
    elif temp > 50 or voltage < 320:
        return 'medium'
    return 'low'

def send_critical_alert(vin: str, detail: Dict[str, Any]):
    """
    Send critical alert via SNS
    """
    sns.publish(
        TopicArn='arn:aws:sns:us-east-1:123456789012:battery-critical-alerts',
        Subject=f'Critical Battery Alert - {vin}',
        Message=json.dumps(detail, indent=2)
    )

def schedule_maintenance(vin: str, maintenance_type: str):
    """
    Schedule maintenance check
    """
    # Would integrate with maintenance scheduling system
    pass

def trigger_remote_diagnostics(vin: str, dtc_code: str):
    """
    Trigger remote diagnostic session
    """
    # Would send UDS commands via IoT Core
    pass

def update_vehicle_state_cache(vin: str, state: str):
    """
    Update Redis cache with current state
    """
    # Would use ElastiCache
    pass

def start_trip_tracking(vin: str, timestamp: str):
    """
    Initialize trip tracking record
    """
    table = dynamodb.Table('Trips')
    table.put_item(
        Item={
            'VIN': vin,
            'TripID': f"{vin}_{timestamp}",
            'StartTime': timestamp,
            'Status': 'active'
        }
    )

def end_trip_tracking(vin: str, timestamp: str):
    """
    Finalize trip tracking record
    """
    # Query active trip and update with end time
    pass
```

## Azure Event Grid

### Event Grid Configuration

```bicep
// event-grid.bicep
param location string = resourceGroup().location

resource vehicleEventTopic 'Microsoft.EventGrid/topics@2022-06-15' = {
  name: 'vehicle-events'
  location: location
  properties: {
    inputSchema: 'CloudEventSchemaV1_0'
    publicNetworkAccess: 'Enabled'
  }
}

// Subscription for battery events
resource batteryEventSubscription 'Microsoft.EventGrid/eventSubscriptions@2022-06-15' = {
  name: 'battery-anomaly-subscription'
  scope: vehicleEventTopic
  properties: {
    destination: {
      endpointType: 'AzureFunction'
      properties: {
        resourceId: batteryAnomalyFunction.id
        maxEventsPerBatch: 10
        preferredBatchSizeInKilobytes: 64
      }
    }
    filter: {
      includedEventTypes: [
        'VehicleTelemetry.BatteryMetrics'
      ]
      advancedFilters: [
        {
          operatorType: 'NumberGreaterThan'
          key: 'data.battery_temp_c'
          value: 60
        }
      ]
    }
    retryPolicy: {
      maxDeliveryAttempts: 30
      eventTimeToLiveInMinutes: 1440
    }
    deadLetterDestination: {
      endpointType: 'StorageBlob'
      properties: {
        resourceId: deadLetterStorage.id
        blobContainerName: 'event-deadletter'
      }
    }
  }
}

// Subscription for diagnostics
resource diagnosticEventSubscription 'Microsoft.EventGrid/eventSubscriptions@2022-06-15' = {
  name: 'diagnostic-subscription'
  scope: vehicleEventTopic
  properties: {
    destination: {
      endpointType: 'StorageQueue'
      properties: {
        resourceId: diagnosticStorage.id
        queueName: 'diagnostic-events'
      }
    }
    filter: {
      includedEventTypes: [
        'VehicleDiagnostics.DTCDetected'
      ]
      advancedFilters: [
        {
          operatorType: 'StringIn'
          key: 'data.severity'
          values: [
            'critical'
            'high'
          ]
        }
      ]
    }
  }
}
```

### Event Publishing (Azure)

```python
# azure_event_publisher.py
from azure.eventgrid import EventGridPublisherClient
from azure.core.credentials import AzureKeyCredential
from azure.eventgrid import EventGridEvent
from datetime import datetime
import os

topic_endpoint = os.environ['EVENT_GRID_TOPIC_ENDPOINT']
topic_key = os.environ['EVENT_GRID_TOPIC_KEY']

client = EventGridPublisherClient(
    endpoint=topic_endpoint,
    credential=AzureKeyCredential(topic_key)
)

def publish_battery_event(vin: str, metrics: dict):
    """
    Publish battery metrics to Event Grid
    """
    event = EventGridEvent(
        event_type='VehicleTelemetry.BatteryMetrics',
        data={
            'vin': vin,
            'timestamp': datetime.utcnow().isoformat(),
            'battery_voltage_v': metrics['voltage'],
            'battery_current_a': metrics['current'],
            'battery_temp_c': metrics['temperature'],
            'battery_soc_pct': metrics['soc']
        },
        subject=f'vehicles/{vin}/battery',
        data_version='1.0'
    )

    client.send([event])

def publish_diagnostic_event(vin: str, dtc_code: str, severity: str):
    """
    Publish diagnostic event
    """
    event = EventGridEvent(
        event_type='VehicleDiagnostics.DTCDetected',
        data={
            'vin': vin,
            'timestamp': datetime.utcnow().isoformat(),
            'dtc_code': dtc_code,
            'severity': severity,
            'system': extract_system_from_dtc(dtc_code)
        },
        subject=f'vehicles/{vin}/diagnostics',
        data_version='1.0'
    )

    client.send([event])

def publish_batch_events(events: list):
    """
    Publish multiple events (max 100)
    """
    event_grid_events = []

    for event in events[:100]:
        event_grid_events.append(EventGridEvent(
            event_type=event['event_type'],
            data=event['data'],
            subject=event['subject'],
            data_version='1.0'
        ))

    client.send(event_grid_events)
```

## Google Cloud Pub/Sub

### Topic and Subscription Setup

```python
# pubsub_setup.py
from google.cloud import pubsub_v1
import json

project_id = "automotive-project"

publisher = pubsub_v1.PublisherClient()
subscriber = pubsub_v1.SubscriberClient()

# Create topics
def create_topics():
    topics = [
        'vehicle-telemetry',
        'vehicle-diagnostics',
        'vehicle-state-changes'
    ]

    for topic_name in topics:
        topic_path = publisher.topic_path(project_id, topic_name)
        try:
            publisher.create_topic(request={"name": topic_path})
            print(f"Created topic: {topic_path}")
        except Exception as e:
            print(f"Topic already exists: {topic_name}")

# Create subscriptions
def create_subscriptions():
    subscriptions = [
        {
            'name': 'battery-anomaly-sub',
            'topic': 'vehicle-telemetry',
            'filter': 'attributes.event_type="battery_metrics" AND attributes.battery_temp>60'
        },
        {
            'name': 'diagnostic-sub',
            'topic': 'vehicle-diagnostics',
            'filter': 'attributes.severity="critical" OR attributes.severity="high"'
        },
        {
            'name': 'state-change-sub',
            'topic': 'vehicle-state-changes',
            'filter': None
        }
    ]

    for sub_config in subscriptions:
        topic_path = publisher.topic_path(project_id, sub_config['topic'])
        subscription_path = subscriber.subscription_path(project_id, sub_config['name'])

        try:
            subscription = subscriber.create_subscription(
                request={
                    "name": subscription_path,
                    "topic": topic_path,
                    "ack_deadline_seconds": 60,
                    "retry_policy": {
                        "minimum_backoff": {"seconds": 10},
                        "maximum_backoff": {"seconds": 600}
                    },
                    "dead_letter_policy": {
                        "dead_letter_topic": publisher.topic_path(project_id, "dead-letter"),
                        "max_delivery_attempts": 5
                    },
                    "filter": sub_config['filter']
                }
            )
            print(f"Created subscription: {subscription_path}")
        except Exception as e:
            print(f"Subscription already exists: {sub_config['name']}")

# Publish event
def publish_event(topic_name: str, data: dict, attributes: dict):
    """
    Publish event to Pub/Sub topic
    """
    topic_path = publisher.topic_path(project_id, topic_name)

    data_bytes = json.dumps(data).encode('utf-8')

    future = publisher.publish(
        topic_path,
        data_bytes,
        **attributes
    )

    message_id = future.result()
    print(f"Published message ID: {message_id}")
    return message_id

# Subscribe to events
def subscribe_callback(message):
    """
    Callback for processing messages
    """
    print(f"Received message: {message.data}")
    print(f"Attributes: {message.attributes}")

    # Process message
    data = json.loads(message.data.decode('utf-8'))
    process_vehicle_event(data)

    # Acknowledge
    message.ack()

def subscribe_to_events(subscription_name: str):
    """
    Start subscribing to events
    """
    subscription_path = subscriber.subscription_path(project_id, subscription_name)

    streaming_pull_future = subscriber.subscribe(
        subscription_path,
        callback=subscribe_callback
    )

    print(f"Listening for messages on {subscription_path}")

    try:
        streaming_pull_future.result()
    except Exception as e:
        streaming_pull_future.cancel()
        print(f"Subscription canceled: {e}")

def process_vehicle_event(data: dict):
    """
    Process vehicle event
    """
    # Implementation
    pass
```

## Event Schemas

### CloudEvents Standard

```json
{
  "specversion": "1.0",
  "type": "com.automotive.vehicle.telemetry.battery",
  "source": "vehicle/WV1ZZZ7HZ12345678",
  "id": "A234-1234-1234",
  "time": "2024-03-19T12:00:00Z",
  "datacontenttype": "application/json",
  "data": {
    "vin": "WV1ZZZ7HZ12345678",
    "battery_voltage_v": 385.6,
    "battery_current_a": -125.3,
    "battery_temp_c": 42.5,
    "battery_soc_pct": 78.5,
    "cell_voltages": [3.85, 3.86, 3.84, 3.87],
    "health_status": "normal"
  }
}
```

### Custom Schema Registry

```python
# schema_registry.py
import json
from typing import Dict, Any

SCHEMAS = {
    'vehicle.telemetry.battery': {
        'version': '1.0',
        'schema': {
            'type': 'object',
            'properties': {
                'vin': {'type': 'string', 'pattern': '^[A-HJ-NPR-Z0-9]{17}$'},
                'timestamp': {'type': 'string', 'format': 'date-time'},
                'battery_voltage_v': {'type': 'number', 'minimum': 0, 'maximum': 1000},
                'battery_current_a': {'type': 'number'},
                'battery_temp_c': {'type': 'number', 'minimum': -40, 'maximum': 100},
                'battery_soc_pct': {'type': 'number', 'minimum': 0, 'maximum': 100}
            },
            'required': ['vin', 'timestamp', 'battery_voltage_v', 'battery_soc_pct']
        }
    },
    'vehicle.diagnostics.dtc': {
        'version': '1.0',
        'schema': {
            'type': 'object',
            'properties': {
                'vin': {'type': 'string', 'pattern': '^[A-HJ-NPR-Z0-9]{17}$'},
                'timestamp': {'type': 'string', 'format': 'date-time'},
                'dtc_code': {'type': 'string', 'pattern': '^[PCBU][0-9A-F]{4}$'},
                'severity': {'type': 'string', 'enum': ['critical', 'high', 'medium', 'low']},
                'description': {'type': 'string'},
                'system': {'type': 'string'}
            },
            'required': ['vin', 'timestamp', 'dtc_code', 'severity']
        }
    }
}

def validate_event(event_type: str, data: Dict[str, Any]) -> bool:
    """
    Validate event against schema
    """
    from jsonschema import validate, ValidationError

    if event_type not in SCHEMAS:
        raise ValueError(f"Unknown event type: {event_type}")

    try:
        validate(instance=data, schema=SCHEMAS[event_type]['schema'])
        return True
    except ValidationError as e:
        print(f"Validation error: {e.message}")
        return False
```

## Best Practices

### Event Design

1. **Use CloudEvents standard**: Consistent structure across platforms
2. **Include correlation IDs**: Track event flows through system
3. **Version your events**: Support schema evolution
4. **Keep events small**: < 256KB for better performance
5. **Make events immutable**: Never modify published events

### Routing Patterns

1. **Content-based routing**: Filter on event payload
2. **Topic-based routing**: Separate topics per event type
3. **Dead letter queues**: Handle failed events gracefully
4. **Event replay**: Archive events for reprocessing

### Reliability

1. **At-least-once delivery**: Design idempotent consumers
2. **Retry with exponential backoff**: Handle transient failures
3. **Circuit breakers**: Protect downstream services
4. **Monitoring and alerting**: Track event processing metrics

## Production Checklist

- [ ] Event schemas defined and versioned
- [ ] Dead letter queues configured
- [ ] Retry policies implemented
- [ ] Event archiving enabled
- [ ] Monitoring dashboards created
- [ ] Alerting rules configured
- [ ] Cost monitoring enabled
- [ ] Security policies applied
- [ ] Disaster recovery tested
- [ ] Documentation complete

## Related Patterns

- Serverless for Automotive: Lambda/Functions for event processing
- API Gateway Patterns: Synchronous request/response
- WebSockets for Real-Time: Bidirectional communication
- gRPC for Microservices: Point-to-point RPC

## References

- AWS EventBridge: https://docs.aws.amazon.com/eventbridge/
- Azure Event Grid: https://learn.microsoft.com/azure/event-grid/
- Google Cloud Pub/Sub: https://cloud.google.com/pubsub/docs
- CloudEvents Spec: https://cloudevents.io/
