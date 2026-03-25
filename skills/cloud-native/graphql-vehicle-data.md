# GraphQL for Vehicle Data

Expert guidance for building flexible vehicle data APIs using GraphQL with AWS AppSync, Azure Data API Builder, and Apollo Server for efficient fleet management queries.

## Architecture Overview

```
Mobile/Web Clients
       |
       v
GraphQL API (Query, Mutation, Subscription)
       |
       v
Resolvers (Lambda, Functions, Microservices)
       |
       v
Data Sources (DynamoDB, Cosmos, SQL, REST APIs)
```

**GraphQL Benefits for Automotive**:
- Single endpoint for all vehicle data
- Client-specified response shape
- Real-time subscriptions for telemetry
- Efficient batching and caching
- Strong typing and introspection
- Reduced over/under-fetching

## Schema Design

### Core Types

```graphql
# schema.graphql

"""
Vehicle identification and core details
"""
type Vehicle {
  vin: String!
  model: String!
  year: Int!
  batteryCapacityKwh: Float!
  softwareVersion: String!
  lastConnected: AWSDateTime!

  # Nested queries
  telemetry(
    from: AWSDateTime
    to: AWSDateTime
    limit: Int = 100
  ): TelemetryConnection!

  diagnostics(
    severity: [DiagnosticSeverity!]
    resolved: Boolean
  ): [DiagnosticCode!]!

  trips(
    from: AWSDateTime
    to: AWSDateTime
  ): [Trip!]!

  currentState: VehicleState!
  config: VehicleConfig!
}

"""
Real-time telemetry data
"""
type TelemetryData {
  timestamp: AWSDateTime!
  batteryVoltageV: Float!
  batteryCurrentA: Float!
  batteryTempC: Float!
  batterySocPct: Float!
  speedKmh: Float
  location: Location
  odometerkm: Float
}

"""
Paginated telemetry response
"""
type TelemetryConnection {
  items: [TelemetryData!]!
  nextToken: String
  count: Int!
}

"""
Diagnostic trouble code
"""
type DiagnosticCode {
  id: ID!
  vin: String!
  dtcCode: String!
  severity: DiagnosticSeverity!
  description: String!
  system: VehicleSystem!
  timestamp: AWSDateTime!
  resolved: Boolean!
  resolvedAt: AWSDateTime
}

enum DiagnosticSeverity {
  CRITICAL
  HIGH
  MEDIUM
  LOW
}

enum VehicleSystem {
  POWERTRAIN
  CHASSIS
  BODY
  NETWORK
  BATTERY
}

"""
Vehicle state information
"""
type VehicleState {
  state: State!
  chargingState: ChargingState
  location: Location
  isMoving: Boolean!
  lastUpdated: AWSDateTime!
}

enum State {
  PARKED
  DRIVING
  CHARGING
  OFFLINE
}

enum ChargingState {
  IDLE
  CHARGING
  COMPLETE
  ERROR
}

"""
Geographic location
"""
type Location {
  latitude: Float!
  longitude: Float!
  accuracy: Float
  timestamp: AWSDateTime!
}

"""
Trip information
"""
type Trip {
  id: ID!
  vin: String!
  startTime: AWSDateTime!
  endTime: AWSDateTime
  startLocation: Location!
  endLocation: Location
  distanceKm: Float
  energyConsumedKwh: Float
  averageSpeedKmh: Float
  maxSpeedKmh: Float
}

"""
Vehicle configuration
"""
type VehicleConfig {
  chargeLimitPct: Float!
  maxChargeCurrentA: Float!
  preconditioningEnabled: Boolean!
  regenerativeBrakingLevel: Int!
}

"""
Fleet-wide statistics
"""
type FleetStats {
  totalVehicles: Int!
  onlineVehicles: Int!
  chargingVehicles: Int!
  averageSocPct: Float!
  totalEnergyConsumedKwh: Float!
  totalDistanceKm: Float!
}

# Query root
type Query {
  """
  Get vehicle by VIN
  """
  vehicle(vin: String!): Vehicle

  """
  List vehicles with filtering
  """
  vehicles(
    state: State
    minSoc: Float
    maxSoc: Float
    limit: Int = 20
    nextToken: String
  ): VehicleConnection!

  """
  Get fleet statistics
  """
  fleetStats: FleetStats!

  """
  Search vehicles by location
  """
  vehiclesByLocation(
    latitude: Float!
    longitude: Float!
    radiusKm: Float!
  ): [Vehicle!]!
}

type VehicleConnection {
  items: [Vehicle!]!
  nextToken: String
  count: Int!
}

# Mutation root
type Mutation {
  """
  Update vehicle configuration
  """
  updateVehicleConfig(
    vin: String!
    config: VehicleConfigInput!
  ): VehicleConfig!

  """
  Send remote command to vehicle
  """
  sendCommand(
    vin: String!
    command: VehicleCommand!
    parameters: AWSJSON
  ): CommandResponse!

  """
  Mark diagnostic code as resolved
  """
  resolveDiagnostic(
    vin: String!
    dtcCode: String!
  ): DiagnosticCode!
}

input VehicleConfigInput {
  chargeLimitPct: Float
  maxChargeCurrentA: Float
  preconditioningEnabled: Boolean
  regenerativeBrakingLevel: Int
}

enum VehicleCommand {
  START_CHARGING
  STOP_CHARGING
  PRECONDITION
  LOCK
  UNLOCK
  HONK
  FLASH_LIGHTS
}

type CommandResponse {
  success: Boolean!
  message: String
  requestId: String!
}

# Subscription root
type Subscription {
  """
  Subscribe to telemetry updates for a vehicle
  """
  onTelemetryUpdate(vin: String!): TelemetryData
    @aws_subscribe(mutations: ["publishTelemetry"])

  """
  Subscribe to vehicle state changes
  """
  onVehicleStateChange(vin: String!): VehicleState
    @aws_subscribe(mutations: ["updateVehicleState"])

  """
  Subscribe to new diagnostic codes
  """
  onDiagnosticDetected(vin: String!): DiagnosticCode
    @aws_subscribe(mutations: ["reportDiagnostic"])
}

# Internal mutation for publishing telemetry
type Mutation {
  publishTelemetry(
    vin: String!
    data: TelemetryInput!
  ): TelemetryData
}

input TelemetryInput {
  timestamp: AWSDateTime!
  batteryVoltageV: Float!
  batteryCurrentA: Float!
  batteryTempC: Float!
  batterySocPct: Float!
  speedKmh: Float
  location: LocationInput
}

input LocationInput {
  latitude: Float!
  longitude: Float!
  accuracy: Float
}
```

## AWS AppSync Implementation

### AppSync Configuration

```yaml
# serverless.yml with AppSync plugin
service: vehicle-graphql-api

provider:
  name: aws
  runtime: nodejs18.x
  region: us-east-1

plugins:
  - serverless-appsync-plugin

custom:
  appSync:
    name: vehicle-graphql-api
    authenticationType: AMAZON_COGNITO_USER_POOLS
    userPoolConfig:
      userPoolId: !Ref CognitoUserPool
      awsRegion: us-east-1
      defaultAction: ALLOW
    additionalAuthenticationProviders:
      - authenticationType: API_KEY
        apiKeyConfig:
          expirationDays: 365
    schema: schema.graphql
    logConfig:
      loggingRoleArn: !GetAtt AppSyncLoggingRole.Arn
      level: ERROR

    dataSources:
      - type: AMAZON_DYNAMODB
        name: VehiclesTable
        config:
          tableName: !Ref VehiclesTable
      - type: AMAZON_DYNAMODB
        name: TelemetryTable
        config:
          tableName: !Ref TelemetryTable
      - type: AWS_LAMBDA
        name: VehicleCommandFunction
        config:
          functionName: vehicleCommand

    mappingTemplates:
      # Query: vehicle
      - type: Query
        field: vehicle
        dataSource: VehiclesTable
        request: queries/getVehicle.request.vtl
        response: queries/getVehicle.response.vtl

      # Query: vehicles (list)
      - type: Query
        field: vehicles
        dataSource: VehiclesTable
        request: queries/listVehicles.request.vtl
        response: queries/listVehicles.response.vtl

      # Vehicle: telemetry (nested)
      - type: Vehicle
        field: telemetry
        dataSource: TelemetryTable
        request: resolvers/vehicleTelemetry.request.vtl
        response: resolvers/vehicleTelemetry.response.vtl

      # Mutation: updateVehicleConfig
      - type: Mutation
        field: updateVehicleConfig
        dataSource: VehiclesTable
        request: mutations/updateConfig.request.vtl
        response: mutations/updateConfig.response.vtl

      # Mutation: sendCommand
      - type: Mutation
        field: sendCommand
        dataSource: VehicleCommandFunction
        request: false  # Direct Lambda invocation
        response: false

resources:
  Resources:
    VehiclesTable:
      Type: AWS::DynamoDB::Table
      Properties:
        TableName: Vehicles
        BillingMode: PAY_PER_REQUEST
        AttributeDefinitions:
          - AttributeName: VIN
            AttributeType: S
          - AttributeName: State
            AttributeType: S
        KeySchema:
          - AttributeName: VIN
            KeyType: HASH
        GlobalSecondaryIndexes:
          - IndexName: StateIndex
            KeySchema:
              - AttributeName: State
                KeyType: HASH
            Projection:
              ProjectionType: ALL

    TelemetryTable:
      Type: AWS::DynamoDB::Table
      Properties:
        TableName: VehicleTelemetry
        BillingMode: PAY_PER_REQUEST
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
        TimeToLiveSpecification:
          Enabled: true
          AttributeName: TTL
```

### VTL Resolvers

```vtl
## queries/getVehicle.request.vtl
{
  "version": "2018-05-29",
  "operation": "GetItem",
  "key": {
    "VIN": $util.dynamodb.toDynamoDBJson($ctx.args.vin)
  }
}

## queries/getVehicle.response.vtl
#if($ctx.error)
  $util.error($ctx.error.message, $ctx.error.type)
#end

$util.toJson($ctx.result)

## resolvers/vehicleTelemetry.request.vtl
#set($from = $util.defaultIfNull($ctx.args.from, $util.time.nowISO8601()))
#set($to = $util.defaultIfNull($ctx.args.to, $util.time.nowISO8601()))
#set($limit = $util.defaultIfNull($ctx.args.limit, 100))

{
  "version": "2018-05-29",
  "operation": "Query",
  "query": {
    "expression": "VIN = :vin AND #timestamp BETWEEN :from AND :to",
    "expressionNames": {
      "#timestamp": "Timestamp"
    },
    "expressionValues": {
      ":vin": $util.dynamodb.toDynamoDBJson($ctx.source.vin),
      ":from": $util.dynamodb.toDynamoDBJson($from),
      ":to": $util.dynamodb.toDynamoDBJson($to)
    }
  },
  "limit": $limit,
  "scanIndexForward": false
}

## resolvers/vehicleTelemetry.response.vtl
{
  "items": $util.toJson($ctx.result.items),
  "nextToken": $util.toJson($ctx.result.nextToken),
  "count": $ctx.result.items.size()
}
```

### Lambda Resolvers

```javascript
// vehicleCommand.js
const AWS = require('aws-sdk');
const iot = AWS.IoTData({ endpoint: process.env.IOT_ENDPOINT });

exports.handler = async (event) => {
  const { vin, command, parameters } = event.arguments;

  console.log(`Sending command ${command} to vehicle ${vin}`);

  // Publish command to IoT Core
  const topic = `vehicle/${vin}/commands`;
  const payload = {
    command,
    parameters: parameters ? JSON.parse(parameters) : {},
    requestId: generateRequestId(),
    timestamp: new Date().toISOString()
  };

  try {
    await iot.publish({
      topic,
      payload: JSON.stringify(payload),
      qos: 1
    }).promise();

    return {
      success: true,
      message: `Command ${command} sent successfully`,
      requestId: payload.requestId
    };
  } catch (error) {
    console.error('Error sending command:', error);
    return {
      success: false,
      message: error.message,
      requestId: payload.requestId
    };
  }
};

function generateRequestId() {
  return `cmd-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
}
```

## Apollo Server Implementation

### Server Setup

```javascript
// server.js
const { ApolloServer } = require('@apollo/server');
const { startStandaloneServer } = require('@apollo/server/standalone');
const { makeExecutableSchema } = require('@graphql-tools/schema');
const { PubSub } = require('graphql-subscriptions');
const { createServer } = require('http');
const { WebSocketServer } = require('ws');
const { useServer } = require('graphql-ws/lib/use/ws');
const { ApolloServerPluginDrainHttpServer } = require('@apollo/server/plugin/drainHttpServer');

const typeDefs = require('./schema');
const resolvers = require('./resolvers');

const pubsub = new PubSub();

// Create schema
const schema = makeExecutableSchema({ typeDefs, resolvers });

// Create HTTP server
const httpServer = createServer();

// Create WebSocket server for subscriptions
const wsServer = new WebSocketServer({
  server: httpServer,
  path: '/graphql',
});

// Setup WebSocket handler
const serverCleanup = useServer({ schema }, wsServer);

// Create Apollo Server
const server = new ApolloServer({
  schema,
  plugins: [
    ApolloServerPluginDrainHttpServer({ httpServer }),
    {
      async serverWillStart() {
        return {
          async drainServer() {
            await serverCleanup.dispose();
          },
        };
      },
    },
  ],
  context: ({ req }) => ({
    pubsub,
    userId: req.headers['x-user-id'],
    vin: req.headers['x-vin']
  })
});

// Start server
async function startServer() {
  await server.start();

  httpServer.on('request', server.createHandler());

  httpServer.listen(4000, () => {
    console.log(`Server ready at http://localhost:4000/graphql`);
    console.log(`Subscriptions ready at ws://localhost:4000/graphql`);
  });
}

startServer();
```

### Resolvers

```javascript
// resolvers/index.js
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, GetCommand, QueryCommand, UpdateCommand } = require('@aws-sdk/lib-dynamodb');
const { GraphQLError } = require('graphql');

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

const resolvers = {
  Query: {
    vehicle: async (parent, { vin }, context) => {
      // Check authorization
      if (context.vin && context.vin !== vin) {
        throw new GraphQLError('Unauthorized', {
          extensions: { code: 'FORBIDDEN' }
        });
      }

      const command = new GetCommand({
        TableName: 'Vehicles',
        Key: { VIN: vin }
      });

      const response = await docClient.send(command);

      if (!response.Item) {
        throw new GraphQLError('Vehicle not found', {
          extensions: { code: 'NOT_FOUND' }
        });
      }

      return response.Item;
    },

    vehicles: async (parent, args, context) => {
      const { state, minSoc, maxSoc, limit = 20, nextToken } = args;

      let params = {
        TableName: 'Vehicles',
        Limit: limit
      };

      // Add filters
      let filterExpressions = [];
      let expressionAttributeValues = {};

      if (state) {
        filterExpressions.push('State = :state');
        expressionAttributeValues[':state'] = state;
      }

      if (minSoc !== undefined) {
        filterExpressions.push('BatterySocPct >= :minSoc');
        expressionAttributeValues[':minSoc'] = minSoc;
      }

      if (maxSoc !== undefined) {
        filterExpressions.push('BatterySocPct <= :maxSoc');
        expressionAttributeValues[':maxSoc'] = maxSoc;
      }

      if (filterExpressions.length > 0) {
        params.FilterExpression = filterExpressions.join(' AND ');
        params.ExpressionAttributeValues = expressionAttributeValues;
      }

      if (nextToken) {
        params.ExclusiveStartKey = JSON.parse(Buffer.from(nextToken, 'base64').toString());
      }

      const command = new QueryCommand(params);
      const response = await docClient.send(command);

      return {
        items: response.Items,
        nextToken: response.LastEvaluatedKey
          ? Buffer.from(JSON.stringify(response.LastEvaluatedKey)).toString('base64')
          : null,
        count: response.Items.length
      };
    },

    fleetStats: async (parent, args, context) => {
      // Implementation would aggregate from DynamoDB or use cached metrics
      return {
        totalVehicles: 150,
        onlineVehicles: 142,
        chargingVehicles: 23,
        averageSocPct: 68.5,
        totalEnergyConsumedKwh: 12450.8,
        totalDistanceKm: 45823.2
      };
    }
  },

  Vehicle: {
    telemetry: async (parent, args, context) => {
      const { vin } = parent;
      const { from, to, limit = 100 } = args;

      const command = new QueryCommand({
        TableName: 'VehicleTelemetry',
        KeyConditionExpression: 'VIN = :vin AND #timestamp BETWEEN :from AND :to',
        ExpressionAttributeNames: {
          '#timestamp': 'Timestamp'
        },
        ExpressionAttributeValues: {
          ':vin': vin,
          ':from': from || new Date(Date.now() - 3600000).toISOString(),
          ':to': to || new Date().toISOString()
        },
        Limit: limit,
        ScanIndexForward: false
      });

      const response = await docClient.send(command);

      return {
        items: response.Items,
        nextToken: response.LastEvaluatedKey
          ? Buffer.from(JSON.stringify(response.LastEvaluatedKey)).toString('base64')
          : null,
        count: response.Items.length
      };
    },

    diagnostics: async (parent, args, context) => {
      const { vin } = parent;
      const { severity, resolved } = args;

      // Query diagnostics table
      // Implementation similar to telemetry
      return [];
    },

    currentState: async (parent, args, context) => {
      // Return cached state or query from table
      return {
        state: parent.State || 'PARKED',
        chargingState: parent.ChargingState,
        location: parent.Location,
        isMoving: parent.State === 'DRIVING',
        lastUpdated: parent.LastUpdated
      };
    },

    config: async (parent, args, context) => {
      return {
        chargeLimitPct: parent.ChargeLimitPct || 80,
        maxChargeCurrentA: parent.MaxChargeCurrentA || 150,
        preconditioningEnabled: parent.PreconditioningEnabled || false,
        regenerativeBrakingLevel: parent.RegenerativeBrakingLevel || 2
      };
    }
  },

  Mutation: {
    updateVehicleConfig: async (parent, { vin, config }, context) => {
      // Build update expression
      let updateExpression = 'SET ';
      let expressionAttributeValues = {};
      let updates = [];

      if (config.chargeLimitPct !== undefined) {
        updates.push('ChargeLimitPct = :chargeLimitPct');
        expressionAttributeValues[':chargeLimitPct'] = config.chargeLimitPct;
      }

      if (config.maxChargeCurrentA !== undefined) {
        updates.push('MaxChargeCurrentA = :maxChargeCurrentA');
        expressionAttributeValues[':maxChargeCurrentA'] = config.maxChargeCurrentA;
      }

      if (config.preconditioningEnabled !== undefined) {
        updates.push('PreconditioningEnabled = :preconditioningEnabled');
        expressionAttributeValues[':preconditioningEnabled'] = config.preconditioningEnabled;
      }

      updateExpression += updates.join(', ');

      const command = new UpdateCommand({
        TableName: 'Vehicles',
        Key: { VIN: vin },
        UpdateExpression: updateExpression,
        ExpressionAttributeValues: expressionAttributeValues,
        ReturnValues: 'ALL_NEW'
      });

      const response = await docClient.send(command);

      return {
        chargeLimitPct: response.Attributes.ChargeLimitPct,
        maxChargeCurrentA: response.Attributes.MaxChargeCurrentA,
        preconditioningEnabled: response.Attributes.PreconditioningEnabled,
        regenerativeBrakingLevel: response.Attributes.RegenerativeBrakingLevel
      };
    },

    sendCommand: async (parent, { vin, command, parameters }, context) => {
      // Send command via IoT Core or queue
      // Implementation depends on vehicle communication layer
      return {
        success: true,
        message: `Command ${command} queued for vehicle ${vin}`,
        requestId: `cmd-${Date.now()}`
      };
    },

    publishTelemetry: async (parent, { vin, data }, context) => {
      // Publish to subscription
      const telemetryData = {
        ...data,
        vin
      };

      await context.pubsub.publish(`TELEMETRY_${vin}`, {
        onTelemetryUpdate: telemetryData
      });

      return telemetryData;
    }
  },

  Subscription: {
    onTelemetryUpdate: {
      subscribe: (parent, { vin }, context) => {
        return context.pubsub.asyncIterator(`TELEMETRY_${vin}`);
      }
    },

    onVehicleStateChange: {
      subscribe: (parent, { vin }, context) => {
        return context.pubsub.asyncIterator(`STATE_${vin}`);
      }
    },

    onDiagnosticDetected: {
      subscribe: (parent, { vin }, context) => {
        return context.pubsub.asyncIterator(`DIAGNOSTIC_${vin}`);
      }
    }
  }
};

module.exports = resolvers;
```

## Client Usage

### React Apollo Client

```javascript
// client/App.jsx
import { ApolloClient, InMemoryCache, ApolloProvider, useQuery, useSubscription, gql } from '@apollo/client';
import { GraphQLWsLink } from '@apollo/client/link/subscriptions';
import { createClient } from 'graphql-ws';

// GraphQL queries
const GET_VEHICLE = gql`
  query GetVehicle($vin: String!) {
    vehicle(vin: $vin) {
      vin
      model
      year
      batteryCapacityKwh
      currentState {
        state
        chargingState
        location {
          latitude
          longitude
        }
      }
      telemetry(limit: 10) {
        items {
          timestamp
          batteryVoltageV
          batteryCurrentA
          batteryTempC
          batterySocPct
        }
      }
    }
  }
`;

const TELEMETRY_SUBSCRIPTION = gql`
  subscription OnTelemetryUpdate($vin: String!) {
    onTelemetryUpdate(vin: $vin) {
      timestamp
      batteryVoltageV
      batteryCurrentA
      batteryTempC
      batterySocPct
    }
  }
`;

// WebSocket link for subscriptions
const wsLink = new GraphQLWsLink(createClient({
  url: 'ws://localhost:4000/graphql',
}));

// Apollo Client
const client = new ApolloClient({
  link: wsLink,
  cache: new InMemoryCache()
});

function VehicleDashboard({ vin }) {
  const { loading, error, data } = useQuery(GET_VEHICLE, {
    variables: { vin }
  });

  const { data: telemetryData } = useSubscription(TELEMETRY_SUBSCRIPTION, {
    variables: { vin }
  });

  if (loading) return <div>Loading...</div>;
  if (error) return <div>Error: {error.message}</div>;

  const vehicle = data.vehicle;

  return (
    <div>
      <h1>{vehicle.model} ({vehicle.year})</h1>
      <p>VIN: {vehicle.vin}</p>
      <p>State: {vehicle.currentState.state}</p>

      <h2>Latest Telemetry</h2>
      {telemetryData?.onTelemetryUpdate && (
        <div>
          <p>SOC: {telemetryData.onTelemetryUpdate.batterySocPct}%</p>
          <p>Voltage: {telemetryData.onTelemetryUpdate.batteryVoltageV}V</p>
          <p>Current: {telemetryData.onTelemetryUpdate.batteryCurrentA}A</p>
          <p>Temp: {telemetryData.onTelemetryUpdate.batteryTempC}°C</p>
        </div>
      )}

      <h2>Historical Data</h2>
      {vehicle.telemetry.items.map((item, idx) => (
        <div key={idx}>
          {item.timestamp}: {item.batterySocPct}% SOC
        </div>
      ))}
    </div>
  );
}

export default function App() {
  return (
    <ApolloProvider client={client}>
      <VehicleDashboard vin="WV1ZZZ7HZ12345678" />
    </ApolloProvider>
  );
}
```

## Best Practices

### Performance

1. **DataLoader for batching**: Prevent N+1 queries
2. **Query depth limiting**: Prevent abusive queries
3. **Query complexity analysis**: Assign costs to fields
4. **Response caching**: Cache frequently accessed data
5. **Persisted queries**: Reduce payload size

### Security

1. **Authentication**: Cognito, Auth0, custom JWT
2. **Authorization**: Field-level access control
3. **Input validation**: Validate arguments
4. **Rate limiting**: Per-user/per-IP limits
5. **Query allow-listing**: Production safety

### Monitoring

1. **Apollo Studio**: Query performance tracking
2. **Custom metrics**: Business KPIs
3. **Error tracking**: Sentry integration
4. **Distributed tracing**: OpenTelemetry

## Production Checklist

- [ ] Schema versioning strategy
- [ ] Authentication configured
- [ ] Authorization rules applied
- [ ] Query complexity limits set
- [ ] DataLoader implemented
- [ ] Caching strategy defined
- [ ] Subscription cleanup
- [ ] Error handling standardized
- [ ] Monitoring dashboards
- [ ] Documentation published

## Related Patterns

- API Gateway Patterns: REST alternative
- WebSockets for Real-Time: Subscription transport
- Serverless for Automotive: Resolver implementation
- Event-Driven Architecture: Real-time updates

## References

- GraphQL Specification: https://spec.graphql.org/
- AWS AppSync: https://docs.aws.amazon.com/appsync/
- Apollo Server: https://www.apollographql.com/docs/apollo-server/
- GraphQL Best Practices: https://graphql.org/learn/best-practices/
