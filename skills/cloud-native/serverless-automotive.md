# Serverless for Automotive

Expert guidance for building serverless automotive applications using AWS Lambda, Azure Functions, and Google Cloud Functions for event-driven vehicle data processing.

## Architecture Patterns

### Event-Driven Processing

```
Vehicle Fleet -> IoT Core/Hub -> Lambda/Functions -> Data Lake/DB
                                      |
                                      v
                              Analytics/ML Services
```

**Key Patterns**:
- **Message Processing**: CAN messages, telemetry, diagnostics
- **Event Fanout**: Single vehicle event triggers multiple functions
- **Aggregation**: Batch processing for fleet-wide analytics
- **Stream Processing**: Real-time telemetry transformation

## AWS Lambda for Automotive

### CAN Message Processing

```python
# lambda_function.py
import json
import boto3
import struct
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('VehicleTelemetry')
s3 = boto3.client('s3')

def lambda_handler(event, context):
    """
    Process CAN messages from AWS IoT Core
    Event structure: IoT Core MQTT message
    """

    for record in event.get('Records', [event]):
        # Parse IoT Core message
        vin = record.get('vin')
        timestamp = record.get('timestamp')
        can_data = record.get('can_data', [])

        if not vin or not can_data:
            print(f"Invalid record: {record}")
            continue

        # Process CAN messages
        processed_signals = process_can_messages(can_data)

        # Store in DynamoDB for real-time access
        store_telemetry(vin, timestamp, processed_signals)

        # Archive raw data to S3 for long-term storage
        archive_raw_data(vin, timestamp, can_data)

        # Trigger analytics if battery anomaly detected
        if detect_battery_anomaly(processed_signals):
            trigger_anomaly_workflow(vin, processed_signals)

    return {
        'statusCode': 200,
        'body': json.dumps(f'Processed {len(event.get("Records", [event]))} messages')
    }

def process_can_messages(can_data):
    """
    Decode CAN messages using DBC definitions
    """
    signals = {}

    for msg in can_data:
        msg_id = msg.get('id')
        data = bytes.fromhex(msg.get('data', ''))

        # Battery voltage (0x1A1) - 16-bit, scale 0.01V
        if msg_id == 0x1A1:
            voltage_raw = struct.unpack('>H', data[0:2])[0]
            signals['battery_voltage_v'] = Decimal(str(voltage_raw * 0.01))

        # Battery current (0x1A2) - 16-bit signed, scale 0.1A
        elif msg_id == 0x1A2:
            current_raw = struct.unpack('>h', data[0:2])[0]
            signals['battery_current_a'] = Decimal(str(current_raw * 0.1))

        # Battery temperature (0x1A3) - 8-bit, offset -40°C
        elif msg_id == 0x1A3:
            temp_raw = struct.unpack('B', data[0:1])[0]
            signals['battery_temp_c'] = Decimal(str(temp_raw - 40))

        # SOC (0x1A4) - 8-bit, scale 0.5%
        elif msg_id == 0x1A4:
            soc_raw = struct.unpack('B', data[0:1])[0]
            signals['battery_soc_pct'] = Decimal(str(soc_raw * 0.5))

    return signals

def store_telemetry(vin, timestamp, signals):
    """
    Store processed telemetry in DynamoDB
    """
    table.put_item(
        Item={
            'VIN': vin,
            'Timestamp': timestamp,
            **signals,
            'TTL': int(timestamp) + 2592000  # 30 days retention
        }
    )

def archive_raw_data(vin, timestamp, can_data):
    """
    Archive raw CAN data to S3 for compliance and ML training
    """
    date_prefix = timestamp[:10]  # YYYY-MM-DD
    s3_key = f"raw-can/{vin}/{date_prefix}/{timestamp}.json"

    s3.put_object(
        Bucket='vehicle-data-archive',
        Key=s3_key,
        Body=json.dumps(can_data),
        ContentType='application/json',
        ServerSideEncryption='AES256'
    )

def detect_battery_anomaly(signals):
    """
    Simple rule-based anomaly detection
    """
    voltage = float(signals.get('battery_voltage_v', 0))
    current = float(signals.get('battery_current_a', 0))
    temp = float(signals.get('battery_temp_c', 0))

    # Critical thresholds
    if voltage < 320 or voltage > 420:
        return True
    if abs(current) > 300:
        return True
    if temp < -20 or temp > 60:
        return True

    return False

def trigger_anomaly_workflow(vin, signals):
    """
    Trigger Step Functions workflow for anomaly handling
    """
    stepfunctions = boto3.client('stepfunctions')

    stepfunctions.start_execution(
        stateMachineArn='arn:aws:states:us-east-1:123456789012:stateMachine:BatteryAnomalyWorkflow',
        input=json.dumps({
            'vin': vin,
            'signals': {k: float(v) for k, v in signals.items()},
            'severity': 'critical'
        })
    )
```

### Serverless Framework Configuration

```yaml
# serverless.yml
service: automotive-telemetry

provider:
  name: aws
  runtime: python3.11
  stage: ${opt:stage, 'dev'}
  region: us-east-1
  memorySize: 512
  timeout: 30

  environment:
    TELEMETRY_TABLE: ${self:custom.telemetryTable}
    ARCHIVE_BUCKET: ${self:custom.archiveBucket}
    STAGE: ${self:provider.stage}

  iam:
    role:
      statements:
        - Effect: Allow
          Action:
            - dynamodb:PutItem
            - dynamodb:GetItem
            - dynamodb:Query
          Resource:
            - !GetAtt TelemetryTable.Arn
        - Effect: Allow
          Action:
            - s3:PutObject
            - s3:GetObject
          Resource:
            - !Sub ${ArchiveBucket.Arn}/*
        - Effect: Allow
          Action:
            - states:StartExecution
          Resource:
            - !Ref BatteryAnomalyStateMachine
        - Effect: Allow
          Action:
            - iot:Publish
          Resource:
            - !Sub arn:aws:iot:${AWS::Region}:${AWS::AccountId}:topic/vehicle/alerts/*

custom:
  telemetryTable: ${self:service}-telemetry-${self:provider.stage}
  archiveBucket: ${self:service}-archive-${self:provider.stage}

functions:
  processCanMessages:
    handler: lambda_function.lambda_handler
    description: Process CAN messages from IoT Core
    events:
      - iot:
          sql: "SELECT * FROM 'vehicle/+/can'"
          sqlVersion: '2016-03-23'
    reservedConcurrency: 100

  processDiagnostics:
    handler: diagnostics_handler.lambda_handler
    description: Process UDS diagnostic messages
    events:
      - iot:
          sql: "SELECT * FROM 'vehicle/+/diagnostics'"

  aggregateTelemetry:
    handler: aggregation_handler.lambda_handler
    description: Aggregate telemetry for analytics
    events:
      - schedule:
          rate: rate(5 minutes)
          enabled: true

  handleBatteryAlert:
    handler: alert_handler.lambda_handler
    description: Handle battery anomaly alerts
    events:
      - eventBridge:
          pattern:
            source:
              - custom.automotive
            detail-type:
              - BatteryAnomaly

resources:
  Resources:
    TelemetryTable:
      Type: AWS::DynamoDB::Table
      Properties:
        TableName: ${self:custom.telemetryTable}
        BillingMode: PAY_PER_REQUEST
        TimeToLiveSpecification:
          Enabled: true
          AttributeName: TTL
        AttributeDefinitions:
          - AttributeName: VIN
            AttributeType: S
          - AttributeName: Timestamp
            AttributeType: S
        KeySchema:
          - AttributeName: VIN
            KeyType: HASH
          - AttributeName: Timestamp
            KeyType: RANGE
        StreamSpecification:
          StreamViewType: NEW_AND_OLD_IMAGES
        GlobalSecondaryIndexes:
          - IndexName: TimestampIndex
            KeySchema:
              - AttributeName: Timestamp
                KeyType: HASH
            Projection:
              ProjectionType: ALL

    ArchiveBucket:
      Type: AWS::S3::Bucket
      Properties:
        BucketName: ${self:custom.archiveBucket}
        BucketEncryption:
          ServerSideEncryptionConfiguration:
            - ServerSideEncryptionByDefault:
                SSEAlgorithm: AES256
        LifecycleConfiguration:
          Rules:
            - Id: ArchiveOldData
              Status: Enabled
              Transitions:
                - TransitionInDays: 90
                  StorageClass: GLACIER
                - TransitionInDays: 365
                  StorageClass: DEEP_ARCHIVE
        PublicAccessBlockConfiguration:
          BlockPublicAcls: true
          BlockPublicPolicy: true
          IgnorePublicAcls: true
          RestrictPublicBuckets: true

    BatteryAnomalyStateMachine:
      Type: AWS::StepFunctions::StateMachine
      Properties:
        StateMachineName: BatteryAnomalyWorkflow
        RoleArn: !GetAtt StepFunctionsRole.Arn
        DefinitionString: !Sub |
          {
            "Comment": "Battery anomaly handling workflow",
            "StartAt": "ValidateAnomaly",
            "States": {
              "ValidateAnomaly": {
                "Type": "Task",
                "Resource": "arn:aws:lambda:${AWS::Region}:${AWS::AccountId}:function:${self:service}-validateAnomaly-${self:provider.stage}",
                "Next": "IsCritical"
              },
              "IsCritical": {
                "Type": "Choice",
                "Choices": [
                  {
                    "Variable": "$.severity",
                    "StringEquals": "critical",
                    "Next": "NotifyFleetManager"
                  }
                ],
                "Default": "LogAnomaly"
              },
              "NotifyFleetManager": {
                "Type": "Task",
                "Resource": "arn:aws:states:::sns:publish",
                "Parameters": {
                  "TopicArn": "arn:aws:sns:${AWS::Region}:${AWS::AccountId}:battery-critical-alerts",
                  "Message.$": "$.message"
                },
                "Next": "LogAnomaly"
              },
              "LogAnomaly": {
                "Type": "Task",
                "Resource": "arn:aws:states:::dynamodb:putItem",
                "Parameters": {
                  "TableName": "${self:service}-anomalies-${self:provider.stage}",
                  "Item": {
                    "VIN": {"S.$": "$.vin"},
                    "Timestamp": {"S.$": "$$.State.EnteredTime"},
                    "Severity": {"S.$": "$.severity"}
                  }
                },
                "End": true
              }
            }
          }

plugins:
  - serverless-python-requirements
  - serverless-iam-roles-per-function
  - serverless-plugin-tracing

package:
  individually: true
  exclude:
    - .venv/**
    - .pytest_cache/**
    - tests/**
    - node_modules/**
```

## Azure Functions for Automotive

### Event Hub Triggered Function

```python
# function_app.py
import logging
import json
import azure.functions as func
from azure.cosmos import CosmosClient
from azure.storage.blob import BlobServiceClient
from datetime import datetime, timedelta

app = func.FunctionApp()

# Initialize clients
cosmos_client = CosmosClient.from_connection_string(
    os.environ['COSMOS_CONNECTION_STRING']
)
database = cosmos_client.get_database_client('VehicleData')
container = database.get_container_client('Telemetry')

blob_service = BlobServiceClient.from_connection_string(
    os.environ['STORAGE_CONNECTION_STRING']
)

@app.function_name(name="ProcessVehicleTelemetry")
@app.event_hub_message_trigger(
    arg_name="events",
    event_hub_name="vehicle-telemetry",
    connection="EVENT_HUB_CONNECTION"
)
@app.cosmos_db_output(
    arg_name="outputDocument",
    database_name="VehicleData",
    container_name="Telemetry",
    connection="COSMOS_CONNECTION_STRING"
)
def process_telemetry(events: func.EventHubEvent, outputDocument: func.Out[func.Document]):
    """
    Process vehicle telemetry from Event Hub
    """
    messages = []

    for event in events:
        try:
            message_body = json.loads(event.get_body().decode('utf-8'))

            vin = message_body.get('vin')
            timestamp = message_body.get('timestamp')
            telemetry = message_body.get('telemetry', {})

            # Enrich with processing metadata
            processed_message = {
                'id': f"{vin}_{timestamp}",
                'vin': vin,
                'timestamp': timestamp,
                'telemetry': telemetry,
                'processed_at': datetime.utcnow().isoformat(),
                'partition_key': vin,
                'ttl': int((datetime.utcnow() + timedelta(days=30)).timestamp())
            }

            messages.append(processed_message)

            # Check for critical conditions
            if is_critical_condition(telemetry):
                send_alert(vin, telemetry)

        except Exception as e:
            logging.error(f"Error processing event: {str(e)}")

    # Batch write to Cosmos DB
    if messages:
        outputDocument.set(messages)

    logging.info(f"Processed {len(messages)} telemetry messages")

def is_critical_condition(telemetry):
    """
    Check for critical vehicle conditions
    """
    battery_temp = telemetry.get('battery_temp_c', 0)
    battery_voltage = telemetry.get('battery_voltage_v', 0)

    return battery_temp > 60 or battery_voltage < 320

def send_alert(vin, telemetry):
    """
    Send alert via Event Grid
    """
    # Implementation would use Event Grid client
    pass

@app.function_name(name="AggregateFleetData")
@app.timer_trigger(
    arg_name="timer",
    schedule="0 */5 * * * *"  # Every 5 minutes
)
def aggregate_fleet_data(timer: func.TimerRequest):
    """
    Aggregate fleet-wide metrics
    """
    logging.info("Starting fleet aggregation")

    # Query recent telemetry
    query = "SELECT * FROM c WHERE c.timestamp > @cutoff"
    cutoff = (datetime.utcnow() - timedelta(minutes=5)).isoformat()

    items = container.query_items(
        query=query,
        parameters=[{"name": "@cutoff", "value": cutoff}],
        enable_cross_partition_query=True
    )

    # Calculate fleet metrics
    metrics = calculate_fleet_metrics(list(items))

    # Store aggregated metrics
    store_fleet_metrics(metrics)

def calculate_fleet_metrics(telemetry_items):
    """
    Calculate fleet-wide metrics
    """
    total_vehicles = len(set(item['vin'] for item in telemetry_items))
    avg_battery_temp = sum(item['telemetry'].get('battery_temp_c', 0)
                           for item in telemetry_items) / len(telemetry_items)
    avg_soc = sum(item['telemetry'].get('battery_soc_pct', 0)
                  for item in telemetry_items) / len(telemetry_items)

    return {
        'total_vehicles': total_vehicles,
        'avg_battery_temp_c': avg_battery_temp,
        'avg_soc_pct': avg_soc,
        'timestamp': datetime.utcnow().isoformat()
    }

def store_fleet_metrics(metrics):
    """
    Store fleet metrics in Cosmos DB
    """
    container = database.get_container_client('FleetMetrics')
    container.create_item(body=metrics)
```

### Function Configuration (host.json)

```json
{
  "version": "2.0",
  "logging": {
    "applicationInsights": {
      "samplingSettings": {
        "isEnabled": true,
        "maxTelemetryItemsPerSecond": 20
      }
    },
    "logLevel": {
      "default": "Information",
      "Function": "Information"
    }
  },
  "extensions": {
    "eventHubs": {
      "maxBatchSize": 100,
      "prefetchCount": 300,
      "batchCheckpointFrequency": 1
    },
    "cosmosDB": {
      "connectionMode": "Gateway"
    }
  },
  "concurrency": {
    "dynamicConcurrencyEnabled": true,
    "snapshotPersistenceEnabled": true
  }
}
```

## Google Cloud Functions

### Pub/Sub Triggered Function

```python
# main.py
import json
import base64
from google.cloud import firestore
from google.cloud import storage
from datetime import datetime, timedelta

db = firestore.Client()
storage_client = storage.Client()

def process_vehicle_event(event, context):
    """
    Cloud Function triggered by Pub/Sub
    Args:
        event: Pub/Sub event
        context: Event context
    """
    pubsub_message = base64.b64decode(event['data']).decode('utf-8')
    message_data = json.loads(pubsub_message)

    vin = message_data.get('vin')
    event_type = message_data.get('event_type')
    payload = message_data.get('payload', {})

    # Store in Firestore
    doc_ref = db.collection('vehicle_events').document()
    doc_ref.set({
        'vin': vin,
        'event_type': event_type,
        'payload': payload,
        'timestamp': firestore.SERVER_TIMESTAMP,
        'processed_at': datetime.utcnow().isoformat()
    })

    # Process based on event type
    if event_type == 'battery_warning':
        handle_battery_warning(vin, payload)
    elif event_type == 'diagnostics':
        handle_diagnostics(vin, payload)

    return 'OK'

def handle_battery_warning(vin, payload):
    """
    Handle battery warning events
    """
    # Trigger workflow or notification
    pass

def handle_diagnostics(vin, payload):
    """
    Handle diagnostic trouble codes
    """
    # Store DTCs for analysis
    pass
```

## Best Practices

### Performance Optimization

1. **Cold Start Mitigation**:
   - Use provisioned concurrency for critical functions
   - Minimize deployment package size
   - Lazy-load heavy dependencies
   - Keep functions warm with CloudWatch/Health Check pings

2. **Memory Configuration**:
   - Start with 512MB, profile actual usage
   - Higher memory = faster CPU allocation
   - Monitor Lambda insights for right-sizing

3. **Batch Processing**:
   - Process multiple records per invocation
   - Use batch APIs for DynamoDB/Cosmos
   - Configure appropriate batch sizes for event sources

### Security

1. **IAM/RBAC**:
   - Least privilege permissions
   - Separate roles per function
   - Use service principals, not user credentials

2. **Secret Management**:
   - AWS Secrets Manager / Azure Key Vault
   - Inject secrets via environment variables
   - Rotate credentials regularly

3. **VPC Configuration**:
   - Place functions in VPC for database access
   - Use VPC endpoints for AWS services
   - Configure security groups properly

### Cost Optimization

1. **Right-Size Resources**:
   - Monitor actual memory/CPU usage
   - Use ARM-based runtime (Graviton2)
   - Set appropriate timeouts

2. **Use Reserved Capacity**:
   - Provisioned concurrency for predictable loads
   - Savings plans for consistent usage

3. **Optimize Invocations**:
   - Batch processing where possible
   - Use DLQ for retry logic
   - Implement exponential backoff

## Scaling Strategies

### Horizontal Scaling

```yaml
# Auto-scaling configuration
provider:
  environment:
    AWS_NODEJS_CONNECTION_REUSE_ENABLED: 1

functions:
  processCanMessages:
    reservedConcurrency: 100  # Max concurrent executions
    provisionedConcurrency: 10  # Always warm
    events:
      - sqs:
          arn: !GetAtt VehicleQueue.Arn
          batchSize: 10
          maximumBatchingWindowInSeconds: 5
```

### Vertical Scaling

```python
# Memory/CPU scaling
functions:
  highThroughputProcessor:
    memorySize: 3008  # Maximum memory = maximum CPU
    timeout: 900  # 15 minutes max
```

## Monitoring and Observability

### CloudWatch/Application Insights

```python
import logging
from aws_lambda_powertools import Logger, Tracer, Metrics
from aws_lambda_powertools.metrics import MetricUnit

logger = Logger()
tracer = Tracer()
metrics = Metrics()

@tracer.capture_lambda_handler
@metrics.log_metrics(capture_cold_start_metric=True)
@logger.inject_lambda_context
def lambda_handler(event, context):
    logger.info("Processing vehicle telemetry", extra={"event": event})

    # Add custom metric
    metrics.add_metric(name="VehiclesProcessed", unit=MetricUnit.Count, value=1)

    # Trace external call
    with tracer.capture_method():
        result = process_data(event)

    return result
```

## Production Checklist

- [ ] Error handling with retries and DLQ
- [ ] Structured logging with correlation IDs
- [ ] Custom metrics for business KPIs
- [ ] Distributed tracing enabled
- [ ] Secrets externalized to secret managers
- [ ] VPC configuration for private resources
- [ ] Reserved/provisioned concurrency configured
- [ ] Cost monitoring and budgets set
- [ ] Automated deployment pipeline
- [ ] Integration tests for event flows

## Related Patterns

- Event-Driven Architecture: EventBridge/Event Grid patterns
- API Gateway Patterns: REST/GraphQL for vehicle data access
- WebSockets for Real-Time: Live telemetry streaming
- gRPC for Microservices: Inter-service communication

## References

- AWS Lambda Best Practices: https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html
- Azure Functions Performance: https://learn.microsoft.com/azure/azure-functions/functions-best-practices
- Google Cloud Functions Guide: https://cloud.google.com/functions/docs/bestpractices
