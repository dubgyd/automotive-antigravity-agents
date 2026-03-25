# API Gateway Patterns for Automotive

Expert guidance for building scalable vehicle data APIs using AWS API Gateway, Azure API Management, and Google Cloud API Gateway with REST and GraphQL patterns.

## Architecture Overview

```
Mobile Apps / Web Dashboards
           |
           v
    API Gateway (Auth, Rate Limit, Cache)
           |
           v
    Backend Services (Lambda, Containers)
           |
           v
    Data Layer (DynamoDB, Cosmos, Firestore)
```

**Key Capabilities**:
- Authentication and authorization
- Rate limiting and throttling
- Request/response transformation
- Caching for performance
- API versioning
- CORS configuration
- Request validation
- Usage analytics

## AWS API Gateway

### REST API Configuration

```yaml
# CloudFormation template
Resources:
  VehicleAPI:
    Type: AWS::ApiGatewayV2::Api
    Properties:
      Name: vehicle-data-api
      ProtocolType: HTTP
      CorsConfiguration:
        AllowOrigins:
          - https://fleet.example.com
          - https://mobile.example.com
        AllowMethods:
          - GET
          - POST
          - PUT
          - DELETE
        AllowHeaders:
          - Content-Type
          - Authorization
          - X-VIN
        MaxAge: 3600

  # Lambda authorizer for VIN-based auth
  VINAuthorizer:
    Type: AWS::ApiGatewayV2::Authorizer
    Properties:
      ApiId: !Ref VehicleAPI
      Name: vin-authorizer
      AuthorizerType: REQUEST
      AuthorizerUri: !Sub arn:aws:apigateway:${AWS::Region}:lambda:path/2015-03-31/functions/${AuthorizerFunction.Arn}/invocations
      AuthorizerPayloadFormatVersion: 2.0
      EnableSimpleResponses: true
      IdentitySource:
        - $request.header.Authorization
        - $request.header.X-VIN

  # Stage configuration
  ProductionStage:
    Type: AWS::ApiGatewayV2::Stage
    Properties:
      ApiId: !Ref VehicleAPI
      StageName: prod
      AutoDeploy: true
      DefaultRouteSettings:
        ThrottlingBurstLimit: 1000
        ThrottlingRateLimit: 500
      AccessLogSettings:
        DestinationArn: !GetAtt APILogGroup.Arn
        Format: '$context.requestId $context.error.message $context.error.messageString'

  # Routes
  GetVehicleRoute:
    Type: AWS::ApiGatewayV2::Route
    Properties:
      ApiId: !Ref VehicleAPI
      RouteKey: GET /vehicles/{vin}
      AuthorizerId: !Ref VINAuthorizer
      Target: !Sub integrations/${GetVehicleIntegration}

  GetVehicleIntegration:
    Type: AWS::ApiGatewayV2::Integration
    Properties:
      ApiId: !Ref VehicleAPI
      IntegrationType: AWS_PROXY
      IntegrationUri: !GetAtt GetVehicleFunction.Arn
      PayloadFormatVersion: 2.0

  GetTelemetryRoute:
    Type: AWS::ApiGatewayV2::Route
    Properties:
      ApiId: !Ref VehicleAPI
      RouteKey: GET /vehicles/{vin}/telemetry
      AuthorizerId: !Ref VINAuthorizer
      Target: !Sub integrations/${GetTelemetryIntegration}

  GetTelemetryIntegration:
    Type: AWS::ApiGatewayV2::Integration
    Properties:
      ApiId: !Ref VehicleAPI
      IntegrationType: AWS_PROXY
      IntegrationUri: !GetAtt GetTelemetryFunction.Arn
      PayloadFormatVersion: 2.0

  # Usage plan and API keys
  VehicleUsagePlan:
    Type: AWS::ApiGateway::UsagePlan
    Properties:
      UsagePlanName: vehicle-api-plan
      ApiStages:
        - ApiId: !Ref VehicleAPI
          Stage: !Ref ProductionStage
      Throttle:
        BurstLimit: 200
        RateLimit: 100
      Quota:
        Limit: 10000
        Period: DAY

  FleetAPIKey:
    Type: AWS::ApiGateway::ApiKey
    Properties:
      Name: fleet-management-key
      Enabled: true

  UsagePlanKey:
    Type: AWS::ApiGateway::UsagePlanKey
    Properties:
      KeyId: !Ref FleetAPIKey
      KeyType: API_KEY
      UsagePlanId: !Ref VehicleUsagePlan

  APILogGroup:
    Type: AWS::Logs::LogGroup
    Properties:
      LogGroupName: /aws/apigateway/vehicle-api
      RetentionInDays: 30
```

### VIN-Based Authorizer

```python
# authorizer.py
import jwt
import os
from typing import Dict, Any

SECRET_KEY = os.environ['JWT_SECRET_KEY']

def lambda_handler(event: Dict[str, Any], context):
    """
    Custom authorizer for VIN-based authentication
    """
    # Extract token and VIN from headers
    token = event['headers'].get('authorization', '').replace('Bearer ', '')
    requested_vin = event['headers'].get('x-vin', '')

    if not token or not requested_vin:
        return generate_policy('user', 'Deny', event['routeArn'])

    try:
        # Verify JWT token
        payload = jwt.decode(token, SECRET_KEY, algorithms=['HS256'])

        # Check if user has access to this VIN
        user_id = payload.get('sub')
        authorized_vins = payload.get('vins', [])

        if requested_vin not in authorized_vins:
            return generate_policy(user_id, 'Deny', event['routeArn'])

        # Generate allow policy
        return generate_policy(user_id, 'Allow', event['routeArn'], {
            'userId': user_id,
            'vin': requested_vin,
            'role': payload.get('role', 'user')
        })

    except jwt.ExpiredSignatureError:
        print("Token expired")
        return generate_policy('user', 'Deny', event['routeArn'])
    except jwt.InvalidTokenError:
        print("Invalid token")
        return generate_policy('user', 'Deny', event['routeArn'])

def generate_policy(principal_id: str, effect: str, resource: str, context: Dict = None):
    """
    Generate IAM policy for API Gateway
    """
    policy = {
        'principalId': principal_id,
        'policyDocument': {
            'Version': '2012-10-17',
            'Statement': [
                {
                    'Action': 'execute-api:Invoke',
                    'Effect': effect,
                    'Resource': resource
                }
            ]
        }
    }

    if context:
        policy['context'] = context

    return policy
```

### API Handler Functions

```python
# vehicle_handler.py
import json
import boto3
from typing import Dict, Any
from datetime import datetime, timedelta

dynamodb = boto3.resource('dynamodb')
vehicles_table = dynamodb.Table('Vehicles')
telemetry_table = dynamodb.Table('VehicleTelemetry')

def get_vehicle(event: Dict[str, Any], context):
    """
    GET /vehicles/{vin}
    Returns vehicle details
    """
    vin = event['pathParameters']['vin']

    # Verify authorization
    authorized_vin = event['requestContext']['authorizer']['lambda']['vin']
    if vin != authorized_vin:
        return {
            'statusCode': 403,
            'body': json.dumps({'error': 'Forbidden'})
        }

    # Fetch vehicle data
    response = vehicles_table.get_item(Key={'VIN': vin})

    if 'Item' not in response:
        return {
            'statusCode': 404,
            'body': json.dumps({'error': 'Vehicle not found'})
        }

    vehicle = response['Item']

    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'application/json',
            'Cache-Control': 'max-age=300'  # Cache for 5 minutes
        },
        'body': json.dumps({
            'vin': vehicle['VIN'],
            'model': vehicle['Model'],
            'year': vehicle['Year'],
            'battery_capacity_kwh': float(vehicle['BatteryCapacityKwh']),
            'odometer_km': float(vehicle['OdometerKm']),
            'last_updated': vehicle['LastUpdated']
        })
    }

def get_telemetry(event: Dict[str, Any], context):
    """
    GET /vehicles/{vin}/telemetry?from=TIMESTAMP&to=TIMESTAMP
    Returns vehicle telemetry data
    """
    vin = event['pathParameters']['vin']
    query_params = event.get('queryStringParameters', {}) or {}

    # Parse time range
    from_time = query_params.get('from', (datetime.utcnow() - timedelta(hours=1)).isoformat())
    to_time = query_params.get('to', datetime.utcnow().isoformat())

    # Query telemetry data
    response = telemetry_table.query(
        KeyConditionExpression='VIN = :vin AND Timestamp BETWEEN :from AND :to',
        ExpressionAttributeValues={
            ':vin': vin,
            ':from': from_time,
            ':to': to_time
        },
        Limit=100  # Pagination limit
    )

    telemetry_data = []
    for item in response['Items']:
        telemetry_data.append({
            'timestamp': item['Timestamp'],
            'battery_voltage_v': float(item.get('battery_voltage_v', 0)),
            'battery_current_a': float(item.get('battery_current_a', 0)),
            'battery_temp_c': float(item.get('battery_temp_c', 0)),
            'battery_soc_pct': float(item.get('battery_soc_pct', 0)),
            'speed_kmh': float(item.get('speed_kmh', 0)),
            'location': item.get('location', {})
        })

    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'application/json',
            'Cache-Control': 'max-age=60'  # Cache for 1 minute
        },
        'body': json.dumps({
            'vin': vin,
            'from': from_time,
            'to': to_time,
            'count': len(telemetry_data),
            'data': telemetry_data,
            'next_token': response.get('LastEvaluatedKey')
        })
    }

def update_vehicle_config(event: Dict[str, Any], context):
    """
    PUT /vehicles/{vin}/config
    Update vehicle configuration
    """
    vin = event['pathParameters']['vin']

    try:
        config = json.loads(event['body'])
    except json.JSONDecodeError:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'Invalid JSON'})
        }

    # Validate configuration
    if not validate_vehicle_config(config):
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'Invalid configuration'})
        }

    # Update in database
    vehicles_table.update_item(
        Key={'VIN': vin},
        UpdateExpression='SET #config = :config, LastUpdated = :timestamp',
        ExpressionAttributeNames={'#config': 'Config'},
        ExpressionAttributeValues={
            ':config': config,
            ':timestamp': datetime.utcnow().isoformat()
        }
    )

    return {
        'statusCode': 200,
        'body': json.dumps({'message': 'Configuration updated'})
    }

def validate_vehicle_config(config: Dict) -> bool:
    """
    Validate vehicle configuration
    """
    required_fields = ['charge_limit_pct', 'max_charge_current_a']
    return all(field in config for field in required_fields)
```

## Azure API Management

### APIM Configuration

```bicep
// apim.bicep
param location string = resourceGroup().location
param apimName string = 'vehicle-api-mgmt'

resource apim 'Microsoft.ApiManagement/service@2022-08-01' = {
  name: apimName
  location: location
  sku: {
    name: 'Developer'
    capacity: 1
  }
  properties: {
    publisherEmail: 'admin@example.com'
    publisherName: 'Fleet Management'
  }
}

// Vehicle API
resource vehicleAPI 'Microsoft.ApiManagement/service/apis@2022-08-01' = {
  parent: apim
  name: 'vehicle-data-api'
  properties: {
    displayName: 'Vehicle Data API'
    apiRevision: '1'
    subscriptionRequired: true
    path: 'vehicles'
    protocols: ['https']
    serviceUrl: 'https://vehicle-backend.azurewebsites.net'
  }
}

// Operations
resource getVehicleOp 'Microsoft.ApiManagement/service/apis/operations@2022-08-01' = {
  parent: vehicleAPI
  name: 'get-vehicle'
  properties: {
    displayName: 'Get Vehicle'
    method: 'GET'
    urlTemplate: '/{vin}'
    templateParameters: [
      {
        name: 'vin'
        required: true
        type: 'string'
        description: 'Vehicle Identification Number'
      }
    ]
    responses: [
      {
        statusCode: 200
        description: 'Success'
        representations: [
          {
            contentType: 'application/json'
          }
        ]
      }
    ]
  }
}

// Policies
resource vehicleAPIPolicy 'Microsoft.ApiManagement/service/apis/policies@2022-08-01' = {
  parent: vehicleAPI
  name: 'policy'
  properties: {
    value: '''
    <policies>
      <inbound>
        <base />
        <validate-jwt header-name="Authorization" failed-validation-httpcode="401">
          <openid-config url="https://login.microsoftonline.com/{tenant-id}/v2.0/.well-known/openid-configuration" />
          <audiences>
            <audience>api://vehicle-api</audience>
          </audiences>
        </validate-jwt>
        <rate-limit-by-key calls="100" renewal-period="60" counter-key="@(context.Request.Headers.GetValueOrDefault("X-VIN",""))" />
        <cache-lookup vary-by-developer="false" vary-by-developer-groups="false">
          <vary-by-header>X-VIN</vary-by-header>
        </cache-lookup>
      </inbound>
      <backend>
        <base />
      </backend>
      <outbound>
        <base />
        <cache-store duration="300" />
      </outbound>
      <on-error>
        <base />
      </on-error>
    </policies>
    '''
  }
}

// Product for subscription management
resource fleetProduct 'Microsoft.ApiManagement/service/products@2022-08-01' = {
  parent: apim
  name: 'fleet-management'
  properties: {
    displayName: 'Fleet Management'
    description: 'Access to vehicle data APIs'
    subscriptionRequired: true
    approvalRequired: true
    state: 'published'
  }
}

resource productAPI 'Microsoft.ApiManagement/service/products/apis@2022-08-01' = {
  parent: fleetProduct
  name: vehicleAPI.name
}
```

## Google Cloud API Gateway

### OpenAPI Specification

```yaml
# openapi.yaml
swagger: '2.0'
info:
  title: Vehicle Data API
  version: 1.0.0
  description: API for accessing vehicle telemetry and diagnostics

host: vehicle-api-gateway-xxxxxxx.uc.gateway.dev
schemes:
  - https

securityDefinitions:
  api_key:
    type: apiKey
    name: x-api-key
    in: header
  firebase:
    authorizationUrl: ''
    flow: implicit
    type: oauth2
    x-google-issuer: 'https://securetoken.google.com/PROJECT_ID'
    x-google-jwks_uri: 'https://www.googleapis.com/service_accounts/v1/metadata/x509/securetoken@system.gserviceaccount.com'
    x-google-audiences: 'PROJECT_ID'

paths:
  /vehicles/{vin}:
    get:
      summary: Get vehicle details
      operationId: getVehicle
      security:
        - firebase: []
      parameters:
        - name: vin
          in: path
          required: true
          type: string
          pattern: '^[A-HJ-NPR-Z0-9]{17}$'
      responses:
        '200':
          description: Vehicle details
          schema:
            $ref: '#/definitions/Vehicle'
        '404':
          description: Vehicle not found
      x-google-backend:
        address: https://us-central1-PROJECT_ID.cloudfunctions.net/getVehicle
        deadline: 10.0

  /vehicles/{vin}/telemetry:
    get:
      summary: Get vehicle telemetry
      operationId: getTelemetry
      security:
        - firebase: []
      parameters:
        - name: vin
          in: path
          required: true
          type: string
        - name: from
          in: query
          type: string
          format: date-time
        - name: to
          in: query
          type: string
          format: date-time
      responses:
        '200':
          description: Telemetry data
          schema:
            $ref: '#/definitions/TelemetryResponse'
      x-google-backend:
        address: https://us-central1-PROJECT_ID.cloudfunctions.net/getTelemetry
        deadline: 30.0
      x-google-quota:
        metricCosts:
          read-requests: 1

definitions:
  Vehicle:
    type: object
    properties:
      vin:
        type: string
      model:
        type: string
      year:
        type: integer
      battery_capacity_kwh:
        type: number

  TelemetryResponse:
    type: object
    properties:
      vin:
        type: string
      from:
        type: string
        format: date-time
      to:
        type: string
        format: date-time
      data:
        type: array
        items:
          $ref: '#/definitions/TelemetryData'

  TelemetryData:
    type: object
    properties:
      timestamp:
        type: string
        format: date-time
      battery_voltage_v:
        type: number
      battery_current_a:
        type: number
      battery_temp_c:
        type: number
      battery_soc_pct:
        type: number
```

## Request Validation

### JSON Schema Validation

```python
# validation.py
from jsonschema import validate, ValidationError

TELEMETRY_REQUEST_SCHEMA = {
    "type": "object",
    "properties": {
        "from": {"type": "string", "format": "date-time"},
        "to": {"type": "string", "format": "date-time"},
        "limit": {"type": "integer", "minimum": 1, "maximum": 1000}
    }
}

CONFIG_UPDATE_SCHEMA = {
    "type": "object",
    "properties": {
        "charge_limit_pct": {"type": "number", "minimum": 50, "maximum": 100},
        "max_charge_current_a": {"type": "number", "minimum": 10, "maximum": 500},
        "preconditioning_enabled": {"type": "boolean"}
    },
    "required": ["charge_limit_pct"]
}

def validate_request(data: dict, schema: dict) -> tuple:
    """
    Validate request against JSON schema
    Returns: (is_valid, error_message)
    """
    try:
        validate(instance=data, schema=schema)
        return True, None
    except ValidationError as e:
        return False, e.message
```

## Rate Limiting Strategies

### Token Bucket Algorithm

```python
# rate_limiter.py
import time
from typing import Dict
from threading import Lock

class RateLimiter:
    """
    Token bucket rate limiter for API requests
    """
    def __init__(self, rate: int, per: int):
        """
        Args:
            rate: Number of tokens
            per: Time period in seconds
        """
        self.rate = rate
        self.per = per
        self.allowance = rate
        self.last_check = time.time()
        self.lock = Lock()

    def is_allowed(self, tokens: int = 1) -> bool:
        """
        Check if request is allowed under rate limit
        """
        with self.lock:
            current = time.time()
            time_passed = current - self.last_check
            self.last_check = current

            # Add tokens based on time passed
            self.allowance += time_passed * (self.rate / self.per)

            # Cap at maximum rate
            if self.allowance > self.rate:
                self.allowance = self.rate

            # Check if enough tokens available
            if self.allowance < tokens:
                return False

            # Consume tokens
            self.allowance -= tokens
            return True

# Per-VIN rate limiting
vin_limiters: Dict[str, RateLimiter] = {}

def check_rate_limit(vin: str) -> bool:
    """
    Check rate limit for VIN (100 requests per minute)
    """
    if vin not in vin_limiters:
        vin_limiters[vin] = RateLimiter(rate=100, per=60)

    return vin_limiters[vin].is_allowed()
```

## Caching Strategies

### Response Caching

```python
# cache.py
import json
import hashlib
from typing import Optional
import redis

redis_client = redis.Redis(host='localhost', port=6379, db=0)

def cache_key(vin: str, endpoint: str, params: dict) -> str:
    """
    Generate cache key
    """
    param_str = json.dumps(params, sort_keys=True)
    hash_str = hashlib.md5(param_str.encode()).hexdigest()
    return f"api:{vin}:{endpoint}:{hash_str}"

def get_cached_response(vin: str, endpoint: str, params: dict) -> Optional[dict]:
    """
    Get cached API response
    """
    key = cache_key(vin, endpoint, params)
    cached = redis_client.get(key)

    if cached:
        return json.loads(cached)

    return None

def cache_response(vin: str, endpoint: str, params: dict, response: dict, ttl: int = 300):
    """
    Cache API response with TTL
    """
    key = cache_key(vin, endpoint, params)
    redis_client.setex(key, ttl, json.dumps(response))

def invalidate_cache(vin: str, pattern: str = '*'):
    """
    Invalidate cache for VIN
    """
    keys = redis_client.keys(f"api:{vin}:{pattern}")
    if keys:
        redis_client.delete(*keys)
```

## API Versioning

### URI Versioning

```python
# versioning.py

# Version 1 endpoint
@app.route('/v1/vehicles/<vin>', methods=['GET'])
def get_vehicle_v1(vin):
    """
    Legacy vehicle endpoint
    """
    vehicle = fetch_vehicle(vin)
    return jsonify({
        'vin': vehicle.vin,
        'model': vehicle.model,
        'year': vehicle.year
    })

# Version 2 endpoint with additional fields
@app.route('/v2/vehicles/<vin>', methods=['GET'])
def get_vehicle_v2(vin):
    """
    Enhanced vehicle endpoint
    """
    vehicle = fetch_vehicle(vin)
    return jsonify({
        'vin': vehicle.vin,
        'model': vehicle.model,
        'year': vehicle.year,
        'battery_capacity_kwh': vehicle.battery_capacity,
        'software_version': vehicle.software_version,
        'last_service_date': vehicle.last_service_date
    })
```

## Best Practices

### Security

1. **Always use HTTPS**: Enforce TLS 1.2+
2. **Implement authentication**: OAuth 2.0, JWT, API keys
3. **Validate inputs**: JSON schema, path parameters, query strings
4. **Rate limiting**: Prevent abuse and ensure fair usage
5. **CORS configuration**: Restrict allowed origins

### Performance

1. **Response caching**: Cache frequently accessed data
2. **Compression**: Enable gzip for responses
3. **Pagination**: Limit result sets, provide next tokens
4. **Async processing**: Use webhooks for long operations
5. **CDN integration**: Cache static responses at edge

### Monitoring

1. **Request logging**: CloudWatch, App Insights, Cloud Logging
2. **Custom metrics**: Track business KPIs
3. **Distributed tracing**: X-Ray, Application Insights, Cloud Trace
4. **Alerting**: Set thresholds for errors, latency, throttling

## Production Checklist

- [ ] Authentication configured
- [ ] Rate limiting enabled
- [ ] Input validation implemented
- [ ] Response caching configured
- [ ] CORS settings applied
- [ ] API versioning strategy defined
- [ ] Error handling standardized
- [ ] Monitoring dashboards created
- [ ] API documentation published
- [ ] Load testing completed

## Related Patterns

- GraphQL for Vehicle Data: Advanced query capabilities
- WebSockets for Real-Time: Bidirectional communication
- Serverless for Automotive: Backend function implementation
- gRPC for Microservices: Internal service communication

## References

- AWS API Gateway: https://docs.aws.amazon.com/apigateway/
- Azure API Management: https://learn.microsoft.com/azure/api-management/
- Google Cloud API Gateway: https://cloud.google.com/api-gateway/docs
- OpenAPI Specification: https://swagger.io/specification/
