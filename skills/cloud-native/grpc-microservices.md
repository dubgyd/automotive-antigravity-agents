# gRPC for Automotive Microservices

Expert guidance for building high-performance automotive microservices using gRPC with Protocol Buffers for inter-service communication in cloud-native vehicle platforms.

## Architecture Overview

```
API Gateway -> gRPC Services (Internal) -> Data Layer
     |              |
     v              v
   REST          Service Mesh
 GraphQL      (Istio, Linkerd)
```

**gRPC Benefits for Automotive**:
- High-performance binary protocol (Protocol Buffers)
- Strong typing with schema validation
- Bidirectional streaming for telemetry
- Built-in load balancing and retries
- Code generation for multiple languages
- HTTP/2 multiplexing

## Protocol Buffer Definitions

### Vehicle Service Proto

```protobuf
// vehicle.proto
syntax = "proto3";

package automotive.vehicle.v1;

option go_package = "github.com/automotive/services/vehicle/v1";
option java_package = "com.automotive.vehicle.v1";
option csharp_namespace = "Automotive.Vehicle.V1";

import "google/protobuf/timestamp.proto";
import "google/protobuf/empty.proto";

// Vehicle service for fleet management
service VehicleService {
  // Get vehicle details
  rpc GetVehicle(GetVehicleRequest) returns (Vehicle);

  // List vehicles with filtering
  rpc ListVehicles(ListVehiclesRequest) returns (ListVehiclesResponse);

  // Update vehicle configuration
  rpc UpdateVehicleConfig(UpdateVehicleConfigRequest) returns (VehicleConfig);

  // Stream telemetry data
  rpc StreamTelemetry(StreamTelemetryRequest) returns (stream TelemetryData);

  // Bidirectional command stream
  rpc CommandStream(stream VehicleCommand) returns (stream CommandResponse);

  // Get vehicle state
  rpc GetVehicleState(GetVehicleStateRequest) returns (VehicleState);
}

// Request/Response messages
message GetVehicleRequest {
  string vin = 1;
}

message ListVehiclesRequest {
  // Filtering
  optional VehicleState.State state = 1;
  optional float min_soc = 2;
  optional float max_soc = 3;

  // Pagination
  int32 page_size = 4;
  string page_token = 5;
}

message ListVehiclesResponse {
  repeated Vehicle vehicles = 1;
  string next_page_token = 2;
  int32 total_count = 3;
}

message UpdateVehicleConfigRequest {
  string vin = 1;
  VehicleConfig config = 2;
}

message StreamTelemetryRequest {
  string vin = 1;
  google.protobuf.Timestamp from = 2;
  google.protobuf.Timestamp to = 3;
}

message GetVehicleStateRequest {
  string vin = 1;
}

// Domain models
message Vehicle {
  string vin = 1;
  string model = 2;
  int32 year = 3;
  float battery_capacity_kwh = 4;
  string software_version = 5;
  google.protobuf.Timestamp last_connected = 6;
  VehicleState state = 7;
  VehicleConfig config = 8;
}

message VehicleState {
  enum State {
    STATE_UNSPECIFIED = 0;
    STATE_PARKED = 1;
    STATE_DRIVING = 2;
    STATE_CHARGING = 3;
    STATE_OFFLINE = 4;
  }

  enum ChargingState {
    CHARGING_STATE_UNSPECIFIED = 0;
    CHARGING_STATE_IDLE = 1;
    CHARGING_STATE_CHARGING = 2;
    CHARGING_STATE_COMPLETE = 3;
    CHARGING_STATE_ERROR = 4;
  }

  State state = 1;
  ChargingState charging_state = 2;
  Location location = 3;
  bool is_moving = 4;
  google.protobuf.Timestamp last_updated = 5;
}

message Location {
  double latitude = 1;
  double longitude = 2;
  float accuracy = 3;
  google.protobuf.Timestamp timestamp = 4;
}

message VehicleConfig {
  float charge_limit_pct = 1;
  float max_charge_current_a = 2;
  bool preconditioning_enabled = 3;
  int32 regenerative_braking_level = 4;
}

message TelemetryData {
  string vin = 1;
  google.protobuf.Timestamp timestamp = 2;
  float battery_voltage_v = 3;
  float battery_current_a = 4;
  float battery_temp_c = 5;
  float battery_soc_pct = 6;
  float speed_kmh = 7;
  Location location = 8;
  float odometer_km = 9;
}

message VehicleCommand {
  enum Command {
    COMMAND_UNSPECIFIED = 0;
    COMMAND_START_CHARGING = 1;
    COMMAND_STOP_CHARGING = 2;
    COMMAND_PRECONDITION = 3;
    COMMAND_LOCK = 4;
    COMMAND_UNLOCK = 5;
    COMMAND_HONK = 6;
    COMMAND_FLASH_LIGHTS = 7;
  }

  string request_id = 1;
  string vin = 2;
  Command command = 3;
  map<string, string> parameters = 4;
}

message CommandResponse {
  string request_id = 1;
  bool success = 2;
  string message = 3;
  google.protobuf.Timestamp timestamp = 4;
}
```

### Diagnostic Service Proto

```protobuf
// diagnostic.proto
syntax = "proto3";

package automotive.diagnostic.v1;

import "google/protobuf/timestamp.proto";

service DiagnosticService {
  // Get diagnostic codes for vehicle
  rpc GetDiagnostics(GetDiagnosticsRequest) returns (GetDiagnosticsResponse);

  // Report new diagnostic code
  rpc ReportDiagnostic(ReportDiagnosticRequest) returns (DiagnosticCode);

  // Resolve diagnostic code
  rpc ResolveDiagnostic(ResolveDiagnosticRequest) returns (DiagnosticCode);

  // Stream diagnostic events
  rpc StreamDiagnostics(StreamDiagnosticsRequest) returns (stream DiagnosticCode);
}

message GetDiagnosticsRequest {
  string vin = 1;
  repeated Severity severities = 2;
  optional bool resolved = 3;
}

message GetDiagnosticsResponse {
  repeated DiagnosticCode diagnostics = 1;
}

message ReportDiagnosticRequest {
  string vin = 1;
  string dtc_code = 2;
  Severity severity = 3;
  string description = 4;
  VehicleSystem system = 5;
}

message ResolveDiagnosticRequest {
  string vin = 1;
  string dtc_code = 2;
}

message StreamDiagnosticsRequest {
  string vin = 1;
}

message DiagnosticCode {
  string id = 1;
  string vin = 2;
  string dtc_code = 3;
  Severity severity = 4;
  string description = 5;
  VehicleSystem system = 6;
  google.protobuf.Timestamp timestamp = 7;
  bool resolved = 8;
  google.protobuf.Timestamp resolved_at = 9;
}

enum Severity {
  SEVERITY_UNSPECIFIED = 0;
  SEVERITY_CRITICAL = 1;
  SEVERITY_HIGH = 2;
  SEVERITY_MEDIUM = 3;
  SEVERITY_LOW = 4;
}

enum VehicleSystem {
  VEHICLE_SYSTEM_UNSPECIFIED = 0;
  VEHICLE_SYSTEM_POWERTRAIN = 1;
  VEHICLE_SYSTEM_CHASSIS = 2;
  VEHICLE_SYSTEM_BODY = 3;
  VEHICLE_SYSTEM_NETWORK = 4;
  VEHICLE_SYSTEM_BATTERY = 5;
}
```

## Go gRPC Server Implementation

### Vehicle Service Server

```go
// server/vehicle_service.go
package server

import (
    "context"
    "fmt"
    "time"

    "google.golang.org/grpc/codes"
    "google.golang.org/grpc/status"
    "google.golang.org/protobuf/types/known/timestamppb"

    pb "github.com/automotive/services/vehicle/v1"
)

type VehicleServer struct {
    pb.UnimplementedVehicleServiceServer
    db VehicleRepository
}

func NewVehicleServer(db VehicleRepository) *VehicleServer {
    return &VehicleServer{db: db}
}

func (s *VehicleServer) GetVehicle(ctx context.Context, req *pb.GetVehicleRequest) (*pb.Vehicle, error) {
    if req.Vin == "" {
        return nil, status.Error(codes.InvalidArgument, "VIN is required")
    }

    vehicle, err := s.db.GetVehicle(ctx, req.Vin)
    if err != nil {
        if err == ErrNotFound {
            return nil, status.Error(codes.NotFound, "vehicle not found")
        }
        return nil, status.Error(codes.Internal, err.Error())
    }

    return vehicle, nil
}

func (s *VehicleServer) ListVehicles(ctx context.Context, req *pb.ListVehiclesRequest) (*pb.ListVehiclesResponse, error) {
    pageSize := req.PageSize
    if pageSize == 0 {
        pageSize = 20
    }
    if pageSize > 100 {
        pageSize = 100
    }

    vehicles, nextToken, total, err := s.db.ListVehicles(ctx, &ListVehiclesFilter{
        State:     req.State,
        MinSoc:    req.MinSoc,
        MaxSoc:    req.MaxSoc,
        PageSize:  pageSize,
        PageToken: req.PageToken,
    })

    if err != nil {
        return nil, status.Error(codes.Internal, err.Error())
    }

    return &pb.ListVehiclesResponse{
        Vehicles:      vehicles,
        NextPageToken: nextToken,
        TotalCount:    total,
    }, nil
}

func (s *VehicleServer) UpdateVehicleConfig(ctx context.Context, req *pb.UpdateVehicleConfigRequest) (*pb.VehicleConfig, error) {
    if req.Vin == "" {
        return nil, status.Error(codes.InvalidArgument, "VIN is required")
    }

    // Validate config
    if err := validateVehicleConfig(req.Config); err != nil {
        return nil, status.Error(codes.InvalidArgument, err.Error())
    }

    config, err := s.db.UpdateVehicleConfig(ctx, req.Vin, req.Config)
    if err != nil {
        return nil, status.Error(codes.Internal, err.Error())
    }

    return config, nil
}

func (s *VehicleServer) StreamTelemetry(req *pb.StreamTelemetryRequest, stream pb.VehicleService_StreamTelemetryServer) error {
    if req.Vin == "" {
        return status.Error(codes.InvalidArgument, "VIN is required")
    }

    ctx := stream.Context()

    // Query historical telemetry
    telemetryData, err := s.db.GetTelemetryRange(ctx, req.Vin, req.From.AsTime(), req.To.AsTime())
    if err != nil {
        return status.Error(codes.Internal, err.Error())
    }

    // Stream telemetry data
    for _, data := range telemetryData {
        if err := stream.Send(data); err != nil {
            return status.Error(codes.Internal, err.Error())
        }

        // Check if client disconnected
        select {
        case <-ctx.Done():
            return ctx.Err()
        default:
        }
    }

    return nil
}

func (s *VehicleServer) CommandStream(stream pb.VehicleService_CommandStreamServer) error {
    ctx := stream.Context()

    for {
        select {
        case <-ctx.Done():
            return ctx.Err()
        default:
        }

        // Receive command from client
        cmd, err := stream.Recv()
        if err != nil {
            return status.Error(codes.Internal, err.Error())
        }

        // Process command
        response := s.processCommand(ctx, cmd)

        // Send response
        if err := stream.Send(response); err != nil {
            return status.Error(codes.Internal, err.Error())
        }
    }
}

func (s *VehicleServer) GetVehicleState(ctx context.Context, req *pb.GetVehicleStateRequest) (*pb.VehicleState, error) {
    if req.Vin == "" {
        return nil, status.Error(codes.InvalidArgument, "VIN is required")
    }

    state, err := s.db.GetVehicleState(ctx, req.Vin)
    if err != nil {
        return nil, status.Error(codes.Internal, err.Error())
    }

    return state, nil
}

func (s *VehicleServer) processCommand(ctx context.Context, cmd *pb.VehicleCommand) *pb.CommandResponse {
    // Publish command to IoT or message queue
    err := s.publishCommand(ctx, cmd)

    if err != nil {
        return &pb.CommandResponse{
            RequestId: cmd.RequestId,
            Success:   false,
            Message:   err.Error(),
            Timestamp: timestamppb.Now(),
        }
    }

    return &pb.CommandResponse{
        RequestId: cmd.RequestId,
        Success:   true,
        Message:   fmt.Sprintf("Command %s sent successfully", cmd.Command),
        Timestamp: timestamppb.Now(),
    }
}

func (s *VehicleServer) publishCommand(ctx context.Context, cmd *pb.VehicleCommand) error {
    // Implementation: Publish to AWS IoT Core, Azure IoT Hub, etc.
    return nil
}

func validateVehicleConfig(config *pb.VehicleConfig) error {
    if config.ChargeLimitPct < 50 || config.ChargeLimitPct > 100 {
        return fmt.Errorf("charge limit must be between 50 and 100")
    }
    if config.MaxChargeCurrentA < 10 || config.MaxChargeCurrentA > 500 {
        return fmt.Errorf("max charge current must be between 10 and 500 A")
    }
    return nil
}
```

### gRPC Server Setup

```go
// cmd/server/main.go
package main

import (
    "context"
    "log"
    "net"

    "google.golang.org/grpc"
    "google.golang.org/grpc/credentials"
    "google.golang.org/grpc/reflection"

    pb "github.com/automotive/services/vehicle/v1"
    "github.com/automotive/services/vehicle/server"
)

func main() {
    // Load TLS credentials
    creds, err := credentials.NewServerTLSFromFile("server.crt", "server.key")
    if err != nil {
        log.Fatalf("Failed to load TLS credentials: %v", err)
    }

    // Create gRPC server with interceptors
    grpcServer := grpc.NewServer(
        grpc.Creds(creds),
        grpc.UnaryInterceptor(unaryInterceptor),
        grpc.StreamInterceptor(streamInterceptor),
        grpc.MaxRecvMsgSize(10*1024*1024), // 10MB
        grpc.MaxSendMsgSize(10*1024*1024),
    )

    // Register services
    db := NewDynamoDBRepository()
    vehicleServer := server.NewVehicleServer(db)
    pb.RegisterVehicleServiceServer(grpcServer, vehicleServer)

    // Enable reflection for grpcurl
    reflection.Register(grpcServer)

    // Start server
    listener, err := net.Listen("tcp", ":50051")
    if err != nil {
        log.Fatalf("Failed to listen: %v", err)
    }

    log.Println("gRPC server listening on :50051")
    if err := grpcServer.Serve(listener); err != nil {
        log.Fatalf("Failed to serve: %v", err)
    }
}

func unaryInterceptor(ctx context.Context, req interface{}, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (interface{}, error) {
    log.Printf("Unary call: %s", info.FullMethod)

    // Add authentication, logging, metrics, etc.

    resp, err := handler(ctx, req)
    return resp, err
}

func streamInterceptor(srv interface{}, ss grpc.ServerStream, info *grpc.StreamServerInfo, handler grpc.StreamHandler) error {
    log.Printf("Stream call: %s", info.FullMethod)

    // Add authentication, logging, metrics, etc.

    err := handler(srv, ss)
    return err
}
```

## Node.js gRPC Client

### Client Implementation

```javascript
// client/vehicle-client.js
const grpc = require('@grpc/grpc-js');
const protoLoader = require('@grpc/proto-loader');
const path = require('path');

const PROTO_PATH = path.join(__dirname, '../proto/vehicle.proto');

const packageDefinition = protoLoader.loadSync(PROTO_PATH, {
  keepCase: true,
  longs: String,
  enums: String,
  defaults: true,
  oneofs: true
});

const vehicleProto = grpc.loadPackageDefinition(packageDefinition).automotive.vehicle.v1;

class VehicleClient {
  constructor(serverAddress) {
    // Load TLS credentials
    const credentials = grpc.credentials.createSsl(
      fs.readFileSync('ca.crt'),
      fs.readFileSync('client.key'),
      fs.readFileSync('client.crt')
    );

    this.client = new vehicleProto.VehicleService(
      serverAddress,
      credentials
    );
  }

  async getVehicle(vin) {
    return new Promise((resolve, reject) => {
      this.client.GetVehicle({ vin }, (error, response) => {
        if (error) {
          reject(error);
        } else {
          resolve(response);
        }
      });
    });
  }

  async listVehicles(filters = {}) {
    return new Promise((resolve, reject) => {
      this.client.ListVehicles(filters, (error, response) => {
        if (error) {
          reject(error);
        } else {
          resolve(response);
        }
      });
    });
  }

  async updateVehicleConfig(vin, config) {
    return new Promise((resolve, reject) => {
      this.client.UpdateVehicleConfig({ vin, config }, (error, response) => {
        if (error) {
          reject(error);
        } else {
          resolve(response);
        }
      });
    });
  }

  streamTelemetry(vin, from, to, onData, onEnd, onError) {
    const call = this.client.StreamTelemetry({
      vin,
      from: { seconds: Math.floor(from.getTime() / 1000) },
      to: { seconds: Math.floor(to.getTime() / 1000) }
    });

    call.on('data', onData);
    call.on('end', onEnd);
    call.on('error', onError);

    return call;
  }

  commandStream() {
    const call = this.client.CommandStream();

    const api = {
      sendCommand: (command) => {
        call.write(command);
      },
      onResponse: (callback) => {
        call.on('data', callback);
      },
      onEnd: (callback) => {
        call.on('end', callback);
      },
      onError: (callback) => {
        call.on('error', callback);
      },
      close: () => {
        call.end();
      }
    };

    return api;
  }

  async getVehicleState(vin) {
    return new Promise((resolve, reject) => {
      this.client.GetVehicleState({ vin }, (error, response) => {
        if (error) {
          reject(error);
        } else {
          resolve(response);
        }
      });
    });
  }
}

module.exports = VehicleClient;

// Example usage
async function main() {
  const client = new VehicleClient('vehicle-service:50051');

  try {
    // Get vehicle
    const vehicle = await client.getVehicle('WV1ZZZ7HZ12345678');
    console.log('Vehicle:', vehicle);

    // List vehicles
    const vehicles = await client.listVehicles({
      state: 'STATE_CHARGING',
      page_size: 10
    });
    console.log('Vehicles:', vehicles);

    // Stream telemetry
    client.streamTelemetry(
      'WV1ZZZ7HZ12345678',
      new Date(Date.now() - 3600000),
      new Date(),
      (data) => console.log('Telemetry:', data),
      () => console.log('Stream ended'),
      (error) => console.error('Stream error:', error)
    );

    // Command stream
    const cmdStream = client.commandStream();

    cmdStream.onResponse((response) => {
      console.log('Command response:', response);
    });

    cmdStream.sendCommand({
      request_id: 'cmd-123',
      vin: 'WV1ZZZ7HZ12345678',
      command: 'COMMAND_START_CHARGING',
      parameters: {}
    });

  } catch (error) {
    console.error('Error:', error);
  }
}

if (require.main === module) {
  main();
}
```

## Python gRPC Client

```python
# client/vehicle_client.py
import grpc
from datetime import datetime, timedelta
from google.protobuf.timestamp_pb2 import Timestamp

import vehicle_pb2
import vehicle_pb2_grpc

class VehicleClient:
    def __init__(self, server_address):
        # Load TLS credentials
        with open('ca.crt', 'rb') as f:
            ca_cert = f.read()
        with open('client.key', 'rb') as f:
            client_key = f.read()
        with open('client.crt', 'rb') as f:
            client_cert = f.read()

        credentials = grpc.ssl_channel_credentials(
            root_certificates=ca_cert,
            private_key=client_key,
            certificate_chain=client_cert
        )

        self.channel = grpc.secure_channel(server_address, credentials)
        self.stub = vehicle_pb2_grpc.VehicleServiceStub(self.channel)

    def get_vehicle(self, vin):
        request = vehicle_pb2.GetVehicleRequest(vin=vin)
        return self.stub.GetVehicle(request)

    def list_vehicles(self, state=None, min_soc=None, max_soc=None, page_size=20):
        request = vehicle_pb2.ListVehiclesRequest(
            state=state,
            min_soc=min_soc,
            max_soc=max_soc,
            page_size=page_size
        )
        return self.stub.ListVehicles(request)

    def update_vehicle_config(self, vin, config):
        request = vehicle_pb2.UpdateVehicleConfigRequest(
            vin=vin,
            config=config
        )
        return self.stub.UpdateVehicleConfig(request)

    def stream_telemetry(self, vin, from_time, to_time):
        from_ts = Timestamp()
        from_ts.FromDatetime(from_time)

        to_ts = Timestamp()
        to_ts.FromDatetime(to_time)

        request = vehicle_pb2.StreamTelemetryRequest(
            vin=vin,
            from_time=from_ts,
            to_time=to_ts
        )

        for telemetry in self.stub.StreamTelemetry(request):
            yield telemetry

    def command_stream(self):
        return self.stub.CommandStream(self._generate_commands())

    def _generate_commands(self):
        # Generator for bidirectional streaming
        pass

    def close(self):
        self.channel.close()

# Usage
if __name__ == '__main__':
    client = VehicleClient('vehicle-service:50051')

    # Get vehicle
    vehicle = client.get_vehicle('WV1ZZZ7HZ12345678')
    print(f'Vehicle: {vehicle}')

    # Stream telemetry
    from_time = datetime.now() - timedelta(hours=1)
    to_time = datetime.now()

    for telemetry in client.stream_telemetry('WV1ZZZ7HZ12345678', from_time, to_time):
        print(f'Telemetry: SOC={telemetry.battery_soc_pct}%')

    client.close()
```

## Service Mesh Integration

### Istio Configuration

```yaml
# istio-config.yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: vehicle-service
spec:
  hosts:
    - vehicle-service
  http:
    - match:
        - uri:
            prefix: /automotive.vehicle.v1.VehicleService
      route:
        - destination:
            host: vehicle-service
            subset: v1
          weight: 90
        - destination:
            host: vehicle-service
            subset: v2
          weight: 10
      retries:
        attempts: 3
        perTryTimeout: 2s
      timeout: 10s

---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: vehicle-service
spec:
  host: vehicle-service
  trafficPolicy:
    loadBalancer:
      simple: ROUND_ROBIN
    connectionPool:
      grpc:
        maxRequests: 100
  subsets:
    - name: v1
      labels:
        version: v1
    - name: v2
      labels:
        version: v2
```

## Best Practices

### Performance

1. **Use HTTP/2 multiplexing**: Single connection for multiple RPCs
2. **Streaming for large datasets**: Server/client/bidirectional streaming
3. **Connection pooling**: Reuse connections
4. **Message compression**: gzip for large payloads
5. **Deadlines/timeouts**: Set reasonable timeouts

### Security

1. **TLS mutual authentication**: mTLS for service-to-service
2. **Token-based auth**: JWT in metadata
3. **Authorization**: Per-method access control
4. **Input validation**: Validate all proto fields
5. **Rate limiting**: Per-client limits

### Reliability

1. **Retries with backoff**: Exponential backoff
2. **Circuit breakers**: Prevent cascade failures
3. **Health checks**: Implement health service
4. **Graceful shutdown**: Drain connections
5. **Error handling**: Use gRPC status codes

## Production Checklist

- [ ] TLS/mTLS configured
- [ ] Authentication implemented
- [ ] Authorization per method
- [ ] Logging and tracing
- [ ] Metrics collection
- [ ] Health checks
- [ ] Retry logic
- [ ] Circuit breakers
- [ ] Load balancing
- [ ] Service mesh integration

## Related Patterns

- API Gateway Patterns: gRPC-Web for browsers
- WebSockets for Real-Time: Alternative for streaming
- Event-Driven Architecture: Async communication
- Serverless for Automotive: gRPC in containers

## References

- gRPC Documentation: https://grpc.io/docs/
- Protocol Buffers: https://protobuf.dev/
- gRPC Best Practices: https://grpc.io/docs/guides/performance/
- Service Mesh Patterns: https://istio.io/latest/docs/
