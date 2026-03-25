# WebSockets for Real-Time Automotive Data

Expert guidance for building real-time vehicle telemetry streaming using WebSockets with AWS IoT Core, Azure SignalR, and Socket.IO for live dashboards and monitoring.

## Architecture Overview

```
Vehicle Fleet -> IoT Gateway -> WebSocket Server -> Dashboards/Apps
                                      |
                                      v
                            Connection Management
                            (Scaling, Auth, Rooms)
```

**Use Cases**:
- Live telemetry streaming to dashboards
- Real-time fleet monitoring
- Driver assistance notifications
- Battery health monitoring
- Trip tracking and updates
- Vehicle location tracking

## AWS IoT Core WebSocket Bridge

### IoT Core MQTT over WebSocket

```javascript
// iot-websocket-bridge.js
const AWS = require('aws-sdk');
const iot = new AWS.Iot();
const iotData = new AWS.IotData({ endpoint: process.env.IOT_ENDPOINT });

/**
 * Get temporary credentials for WebSocket connection
 */
async function getIoTCredentials(vin, userId) {
  // Create policy for this VIN
  const policyName = `vehicle-${vin}-policy`;
  const policyDocument = {
    Version: '2012-10-17',
    Statement: [
      {
        Effect: 'Allow',
        Action: ['iot:Connect'],
        Resource: [`arn:aws:iot:${process.env.AWS_REGION}:${process.env.ACCOUNT_ID}:client/${userId}`]
      },
      {
        Effect: 'Allow',
        Action: ['iot:Subscribe', 'iot:Receive'],
        Resource: [
          `arn:aws:iot:${process.env.AWS_REGION}:${process.env.ACCOUNT_ID}:topicfilter/vehicle/${vin}/*`,
          `arn:aws:iot:${process.env.AWS_REGION}:${process.env.ACCOUNT_ID}:topic/vehicle/${vin}/*`
        ]
      }
    ]
  };

  try {
    // Create or update policy
    await iot.createPolicy({
      policyName,
      policyDocument: JSON.stringify(policyDocument)
    }).promise();
  } catch (error) {
    if (error.code !== 'ResourceAlreadyExistsException') {
      throw error;
    }
  }

  // Attach policy to identity
  const sts = new AWS.STS();
  const identity = await sts.getCallerIdentity().promise();

  return {
    endpoint: process.env.IOT_ENDPOINT,
    region: process.env.AWS_REGION,
    accessKeyId: process.env.AWS_ACCESS_KEY_ID,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
    sessionToken: process.env.AWS_SESSION_TOKEN
  };
}

// Client-side WebSocket connection to IoT Core
// client.js
const AWSIoTData = require('aws-iot-device-sdk');

class VehicleWebSocketClient {
  constructor(credentials, vin) {
    this.vin = vin;
    this.device = AWSIoTData.device({
      region: credentials.region,
      host: credentials.endpoint,
      protocol: 'wss',
      accessKeyId: credentials.accessKeyId,
      secretKey: credentials.secretAccessKey,
      sessionToken: credentials.sessionToken,
      clientId: `dashboard-${Date.now()}`
    });

    this.setupHandlers();
  }

  setupHandlers() {
    this.device.on('connect', () => {
      console.log(`Connected to IoT Core for VIN ${this.vin}`);
      this.subscribe();
    });

    this.device.on('message', (topic, payload) => {
      const data = JSON.parse(payload.toString());
      this.handleMessage(topic, data);
    });

    this.device.on('error', (error) => {
      console.error('IoT WebSocket error:', error);
    });

    this.device.on('close', () => {
      console.log('Connection closed');
    });
  }

  subscribe() {
    // Subscribe to telemetry
    this.device.subscribe(`vehicle/${this.vin}/telemetry`);

    // Subscribe to state changes
    this.device.subscribe(`vehicle/${this.vin}/state`);

    // Subscribe to diagnostics
    this.device.subscribe(`vehicle/${this.vin}/diagnostics`);
  }

  handleMessage(topic, data) {
    const parts = topic.split('/');
    const messageType = parts[parts.length - 1];

    switch (messageType) {
      case 'telemetry':
        this.onTelemetry(data);
        break;
      case 'state':
        this.onStateChange(data);
        break;
      case 'diagnostics':
        this.onDiagnostic(data);
        break;
    }
  }

  onTelemetry(data) {
    // Override in implementation
    console.log('Telemetry:', data);
  }

  onStateChange(data) {
    console.log('State change:', data);
  }

  onDiagnostic(data) {
    console.log('Diagnostic:', data);
  }

  disconnect() {
    this.device.end();
  }
}

module.exports = VehicleWebSocketClient;
```

## Socket.IO Implementation

### Server Setup

```javascript
// socket-server.js
const express = require('express');
const { createServer } = require('http');
const { Server } = require('socket.io');
const Redis = require('ioredis');
const { createAdapter } = require('@socket.io/redis-adapter');
const jwt = require('jsonwebtoken');

const app = express();
const httpServer = createServer(app);

// Redis for pub/sub (scaling across instances)
const pubClient = new Redis({
  host: process.env.REDIS_HOST,
  port: process.env.REDIS_PORT
});
const subClient = pubClient.duplicate();

// Socket.IO server with Redis adapter
const io = new Server(httpServer, {
  cors: {
    origin: ['https://fleet.example.com', 'https://mobile.example.com'],
    credentials: true
  },
  adapter: createAdapter(pubClient, subClient)
});

// Authentication middleware
io.use(async (socket, next) => {
  const token = socket.handshake.auth.token;

  if (!token) {
    return next(new Error('Authentication required'));
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    socket.userId = decoded.sub;
    socket.authorizedVins = decoded.vins || [];
    next();
  } catch (error) {
    next(new Error('Invalid token'));
  }
});

// Connection handling
io.on('connection', (socket) => {
  console.log(`Client connected: ${socket.id} (User: ${socket.userId})`);

  // Subscribe to vehicle telemetry
  socket.on('subscribe:vehicle', (vin) => {
    // Check authorization
    if (!socket.authorizedVins.includes(vin)) {
      socket.emit('error', { message: 'Unauthorized VIN' });
      return;
    }

    // Join room for this VIN
    socket.join(`vehicle:${vin}`);
    console.log(`Client ${socket.id} subscribed to vehicle ${vin}`);

    // Send initial data
    sendInitialVehicleData(socket, vin);
  });

  // Unsubscribe from vehicle
  socket.on('unsubscribe:vehicle', (vin) => {
    socket.leave(`vehicle:${vin}`);
    console.log(`Client ${socket.id} unsubscribed from vehicle ${vin}`);
  });

  // Subscribe to fleet updates
  socket.on('subscribe:fleet', () => {
    socket.join('fleet:all');
    sendFleetStats(socket);
  });

  // Send command to vehicle
  socket.on('vehicle:command', async (data) => {
    const { vin, command, parameters } = data;

    if (!socket.authorizedVins.includes(vin)) {
      socket.emit('error', { message: 'Unauthorized' });
      return;
    }

    try {
      await sendVehicleCommand(vin, command, parameters);
      socket.emit('command:sent', { vin, command, success: true });
    } catch (error) {
      socket.emit('command:error', { vin, command, error: error.message });
    }
  });

  // Disconnection
  socket.on('disconnect', (reason) => {
    console.log(`Client disconnected: ${socket.id} (${reason})`);
  });
});

// Vehicle telemetry publisher (from IoT Core or message queue)
async function publishTelemetry(vin, telemetryData) {
  io.to(`vehicle:${vin}`).emit('telemetry:update', {
    vin,
    timestamp: new Date().toISOString(),
    ...telemetryData
  });
}

// Vehicle state change publisher
async function publishStateChange(vin, state) {
  io.to(`vehicle:${vin}`).emit('state:change', {
    vin,
    state,
    timestamp: new Date().toISOString()
  });
}

// Fleet statistics publisher
async function publishFleetStats(stats) {
  io.to('fleet:all').emit('fleet:stats', stats);
}

// Send initial vehicle data on subscription
async function sendInitialVehicleData(socket, vin) {
  // Fetch from database
  const vehicleData = await getVehicleData(vin);
  const latestTelemetry = await getLatestTelemetry(vin);

  socket.emit('vehicle:initial', {
    vin,
    vehicle: vehicleData,
    telemetry: latestTelemetry
  });
}

// Helpers
async function getVehicleData(vin) {
  // Query from DynamoDB or database
  return {
    vin,
    model: 'Model S',
    year: 2024,
    batteryCapacityKwh: 100
  };
}

async function getLatestTelemetry(vin) {
  // Query latest telemetry
  return {
    batteryVoltageV: 385.6,
    batteryCurrentA: -125.3,
    batteryTempC: 42.5,
    batterySocPct: 78.5
  };
}

async function sendVehicleCommand(vin, command, parameters) {
  // Publish to IoT Core or message queue
  console.log(`Sending command ${command} to ${vin}`);
}

async function sendFleetStats(socket) {
  const stats = {
    totalVehicles: 150,
    onlineVehicles: 142,
    chargingVehicles: 23,
    averageSocPct: 68.5
  };
  socket.emit('fleet:stats', stats);
}

// Start server
const PORT = process.env.PORT || 3000;
httpServer.listen(PORT, () => {
  console.log(`WebSocket server listening on port ${PORT}`);
});

module.exports = { io, publishTelemetry, publishStateChange, publishFleetStats };
```

### Client Implementation

```javascript
// client/websocket-client.js
import { io } from 'socket.io-client';

class VehicleWebSocketClient {
  constructor(token) {
    this.socket = io('wss://api.example.com', {
      auth: { token },
      transports: ['websocket'],
      reconnection: true,
      reconnectionDelay: 1000,
      reconnectionDelayMax: 5000,
      reconnectionAttempts: Infinity
    });

    this.setupHandlers();
  }

  setupHandlers() {
    this.socket.on('connect', () => {
      console.log('Connected to WebSocket server');
    });

    this.socket.on('disconnect', (reason) => {
      console.log('Disconnected:', reason);
      if (reason === 'io server disconnect') {
        // Server disconnected, reconnect manually
        this.socket.connect();
      }
    });

    this.socket.on('error', (error) => {
      console.error('WebSocket error:', error);
    });

    this.socket.on('telemetry:update', (data) => {
      this.handleTelemetry(data);
    });

    this.socket.on('state:change', (data) => {
      this.handleStateChange(data);
    });

    this.socket.on('vehicle:initial', (data) => {
      this.handleInitialData(data);
    });

    this.socket.on('fleet:stats', (data) => {
      this.handleFleetStats(data);
    });

    this.socket.on('command:sent', (data) => {
      console.log('Command sent:', data);
    });

    this.socket.on('command:error', (data) => {
      console.error('Command error:', data);
    });
  }

  subscribeToVehicle(vin) {
    this.socket.emit('subscribe:vehicle', vin);
  }

  unsubscribeFromVehicle(vin) {
    this.socket.emit('unsubscribe:vehicle', vin);
  }

  subscribeToFleet() {
    this.socket.emit('subscribe:fleet');
  }

  sendCommand(vin, command, parameters = {}) {
    this.socket.emit('vehicle:command', { vin, command, parameters });
  }

  handleTelemetry(data) {
    // Override in implementation
    console.log('Telemetry update:', data);
  }

  handleStateChange(data) {
    console.log('State change:', data);
  }

  handleInitialData(data) {
    console.log('Initial data:', data);
  }

  handleFleetStats(data) {
    console.log('Fleet stats:', data);
  }

  disconnect() {
    this.socket.disconnect();
  }
}

export default VehicleWebSocketClient;
```

### React Integration

```jsx
// components/VehicleDashboard.jsx
import React, { useEffect, useState } from 'react';
import VehicleWebSocketClient from '../websocket-client';

function VehicleDashboard({ vin, token }) {
  const [telemetry, setTelemetry] = useState(null);
  const [vehicleState, setVehicleState] = useState(null);
  const [wsClient, setWsClient] = useState(null);

  useEffect(() => {
    // Create WebSocket client
    const client = new VehicleWebSocketClient(token);

    // Override handlers
    client.handleTelemetry = (data) => {
      if (data.vin === vin) {
        setTelemetry(data);
      }
    };

    client.handleStateChange = (data) => {
      if (data.vin === vin) {
        setVehicleState(data.state);
      }
    };

    client.handleInitialData = (data) => {
      if (data.vin === vin) {
        setTelemetry(data.telemetry);
        setVehicleState(data.vehicle.state);
      }
    };

    // Subscribe to vehicle
    client.subscribeToVehicle(vin);

    setWsClient(client);

    // Cleanup
    return () => {
      client.unsubscribeFromVehicle(vin);
      client.disconnect();
    };
  }, [vin, token]);

  const handleCommand = (command) => {
    if (wsClient) {
      wsClient.sendCommand(vin, command);
    }
  };

  if (!telemetry) {
    return <div>Loading...</div>;
  }

  return (
    <div className="vehicle-dashboard">
      <h1>Vehicle {vin}</h1>

      <div className="state">
        <h2>State: {vehicleState}</h2>
      </div>

      <div className="telemetry">
        <h2>Live Telemetry</h2>
        <div className="metrics">
          <div className="metric">
            <label>Battery SOC</label>
            <span>{telemetry.batterySocPct?.toFixed(1)}%</span>
          </div>
          <div className="metric">
            <label>Voltage</label>
            <span>{telemetry.batteryVoltageV?.toFixed(1)} V</span>
          </div>
          <div className="metric">
            <label>Current</label>
            <span>{telemetry.batteryCurrentA?.toFixed(1)} A</span>
          </div>
          <div className="metric">
            <label>Temperature</label>
            <span>{telemetry.batteryTempC?.toFixed(1)} °C</span>
          </div>
        </div>
        <div className="timestamp">
          Last update: {new Date(telemetry.timestamp).toLocaleString()}
        </div>
      </div>

      <div className="controls">
        <button onClick={() => handleCommand('START_CHARGING')}>
          Start Charging
        </button>
        <button onClick={() => handleCommand('STOP_CHARGING')}>
          Stop Charging
        </button>
        <button onClick={() => handleCommand('PRECONDITION')}>
          Precondition Battery
        </button>
      </div>
    </div>
  );
}

export default VehicleDashboard;
```

## Azure SignalR Service

### SignalR Hub Setup

```csharp
// VehicleHub.cs
using Microsoft.AspNetCore.SignalR;
using Microsoft.AspNetCore.Authorization;
using System.Threading.Tasks;

[Authorize]
public class VehicleHub : Hub
{
    private readonly IVehicleService _vehicleService;

    public VehicleHub(IVehicleService vehicleService)
    {
        _vehicleService = vehicleService;
    }

    public override async Task OnConnectedAsync()
    {
        var userId = Context.User?.FindFirst("sub")?.Value;
        Console.WriteLine($"Client connected: {Context.ConnectionId} (User: {userId})");
        await base.OnConnectedAsync();
    }

    public async Task SubscribeToVehicle(string vin)
    {
        // Check authorization
        var authorizedVins = Context.User?.FindFirst("vins")?.Value.Split(',');
        if (!authorizedVins.Contains(vin))
        {
            await Clients.Caller.SendAsync("Error", "Unauthorized VIN");
            return;
        }

        // Join group for this VIN
        await Groups.AddToGroupAsync(Context.ConnectionId, $"vehicle:{vin}");

        // Send initial data
        var vehicleData = await _vehicleService.GetVehicleAsync(vin);
        var telemetry = await _vehicleService.GetLatestTelemetryAsync(vin);

        await Clients.Caller.SendAsync("VehicleInitial", new
        {
            Vin = vin,
            Vehicle = vehicleData,
            Telemetry = telemetry
        });
    }

    public async Task UnsubscribeFromVehicle(string vin)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"vehicle:{vin}");
    }

    public async Task SubscribeToFleet()
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, "fleet:all");
        var stats = await _vehicleService.GetFleetStatsAsync();
        await Clients.Caller.SendAsync("FleetStats", stats);
    }

    public async Task SendVehicleCommand(string vin, string command, object parameters)
    {
        // Check authorization
        var authorizedVins = Context.User?.FindFirst("vins")?.Value.Split(',');
        if (!authorizedVins.Contains(vin))
        {
            await Clients.Caller.SendAsync("CommandError", "Unauthorized");
            return;
        }

        try
        {
            await _vehicleService.SendCommandAsync(vin, command, parameters);
            await Clients.Caller.SendAsync("CommandSent", new { Vin = vin, Command = command, Success = true });
        }
        catch (Exception ex)
        {
            await Clients.Caller.SendAsync("CommandError", new { Vin = vin, Command = command, Error = ex.Message });
        }
    }

    public override async Task OnDisconnectedAsync(Exception exception)
    {
        Console.WriteLine($"Client disconnected: {Context.ConnectionId}");
        await base.OnDisconnectedAsync(exception);
    }
}

// Startup.cs
public void ConfigureServices(IServiceCollection services)
{
    services.AddSignalR()
        .AddAzureSignalR(options =>
        {
            options.ConnectionString = Configuration["Azure:SignalR:ConnectionString"];
        });

    services.AddSingleton<IVehicleService, VehicleService>();
}

public void Configure(IApplicationBuilder app)
{
    app.UseRouting();
    app.UseAuthentication();
    app.UseAuthorization();

    app.UseEndpoints(endpoints =>
    {
        endpoints.MapHub<VehicleHub>("/vehiclehub");
    });
}
```

### Publishing Messages

```csharp
// VehicleService.cs
using Microsoft.AspNetCore.SignalR;

public class VehicleService : IVehicleService
{
    private readonly IHubContext<VehicleHub> _hubContext;

    public VehicleService(IHubContext<VehicleHub> hubContext)
    {
        _hubContext = hubContext;
    }

    public async Task PublishTelemetryAsync(string vin, TelemetryData data)
    {
        await _hubContext.Clients.Group($"vehicle:{vin}").SendAsync("TelemetryUpdate", new
        {
            Vin = vin,
            Timestamp = DateTime.UtcNow,
            BatteryVoltageV = data.BatteryVoltageV,
            BatteryCurrentA = data.BatteryCurrentA,
            BatteryTempC = data.BatteryTempC,
            BatterySocPct = data.BatterySocPct
        });
    }

    public async Task PublishStateChangeAsync(string vin, string state)
    {
        await _hubContext.Clients.Group($"vehicle:{vin}").SendAsync("StateChange", new
        {
            Vin = vin,
            State = state,
            Timestamp = DateTime.UtcNow
        });
    }

    public async Task PublishFleetStatsAsync(FleetStats stats)
    {
        await _hubContext.Clients.Group("fleet:all").SendAsync("FleetStats", stats);
    }
}
```

## Connection Management

### Heartbeat and Reconnection

```javascript
// heartbeat.js
class WebSocketWithHeartbeat {
  constructor(url, token) {
    this.url = url;
    this.token = token;
    this.heartbeatInterval = 30000; // 30 seconds
    this.heartbeatTimer = null;
    this.reconnectDelay = 1000;
    this.maxReconnectDelay = 30000;
    this.connect();
  }

  connect() {
    this.socket = io(this.url, {
      auth: { token: this.token },
      transports: ['websocket']
    });

    this.socket.on('connect', () => {
      console.log('Connected');
      this.reconnectDelay = 1000;
      this.startHeartbeat();
    });

    this.socket.on('disconnect', () => {
      console.log('Disconnected');
      this.stopHeartbeat();
      this.scheduleReconnect();
    });

    this.socket.on('pong', () => {
      console.log('Heartbeat received');
    });
  }

  startHeartbeat() {
    this.stopHeartbeat();
    this.heartbeatTimer = setInterval(() => {
      this.socket.emit('ping');
    }, this.heartbeatInterval);
  }

  stopHeartbeat() {
    if (this.heartbeatTimer) {
      clearInterval(this.heartbeatTimer);
      this.heartbeatTimer = null;
    }
  }

  scheduleReconnect() {
    setTimeout(() => {
      console.log('Attempting reconnect...');
      this.connect();
      this.reconnectDelay = Math.min(this.reconnectDelay * 2, this.maxReconnectDelay);
    }, this.reconnectDelay);
  }

  disconnect() {
    this.stopHeartbeat();
    this.socket.disconnect();
  }
}
```

## Scaling Strategies

### Horizontal Scaling with Redis

```javascript
// Redis adapter for multi-instance deployment
const { createAdapter } = require('@socket.io/redis-adapter');
const Redis = require('ioredis');

const pubClient = new Redis({
  host: process.env.REDIS_HOST,
  port: 6379,
  password: process.env.REDIS_PASSWORD
});

const subClient = pubClient.duplicate();

io.adapter(createAdapter(pubClient, subClient));

// Sticky sessions with Nginx
/*
upstream websocket_backend {
    ip_hash;
    server backend1:3000;
    server backend2:3000;
    server backend3:3000;
}

server {
    location /socket.io/ {
        proxy_pass http://websocket_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
    }
}
*/
```

## Best Practices

### Performance

1. **Use binary protocols**: MessagePack for smaller payloads
2. **Throttle updates**: Send telemetry at reasonable intervals (1-5s)
3. **Batch messages**: Combine multiple updates when possible
4. **Compression**: Enable WebSocket compression
5. **Connection pooling**: Limit connections per client

### Security

1. **TLS/SSL**: Always use wss:// in production
2. **Authentication**: JWT tokens, API keys
3. **Authorization**: Check permissions for each subscription
4. **Rate limiting**: Prevent abuse
5. **Input validation**: Validate all client messages

### Reliability

1. **Automatic reconnection**: Exponential backoff
2. **Heartbeat/ping-pong**: Detect dead connections
3. **Message acknowledgment**: Ensure delivery
4. **State recovery**: Resume from last known state
5. **Error handling**: Graceful degradation

## Production Checklist

- [ ] TLS/SSL configured
- [ ] Authentication implemented
- [ ] Authorization checks in place
- [ ] Rate limiting enabled
- [ ] Heartbeat mechanism active
- [ ] Automatic reconnection
- [ ] Redis adapter for scaling
- [ ] Connection monitoring
- [ ] Error tracking
- [ ] Load testing completed

## Related Patterns

- GraphQL for Vehicle Data: GraphQL subscriptions alternative
- Event-Driven Architecture: Backend event processing
- API Gateway Patterns: REST API fallback
- Serverless for Automotive: WebSocket Lambda authorizers

## References

- Socket.IO Documentation: https://socket.io/docs/
- AWS IoT Core WebSockets: https://docs.aws.amazon.com/iot/latest/developerguide/protocols.html
- Azure SignalR Service: https://learn.microsoft.com/azure/azure-signalr/
- WebSocket RFC: https://datatracker.ietf.org/doc/html/rfc6455
