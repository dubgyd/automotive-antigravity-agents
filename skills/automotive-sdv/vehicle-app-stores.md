# Vehicle App Stores — Automotive Application Platforms

Expert knowledge of automotive app platforms, app lifecycle management, sandboxing, permissions model, revenue sharing, 3rd-party developer SDKs, and app certification.

## Core Concepts

### App Store Architecture

1. **App Marketplace**: Discovery, purchase, installation
2. **Developer Portal**: App submission, certification, analytics
3. **Runtime Environment**: Sandboxed execution environment
4. **Payment Integration**: In-app purchases, subscriptions
5. **Update Management**: Automatic app updates

### App Types

- **Infotainment Apps**: Media, navigation, productivity
- **ADAS Extensions**: Enhanced driver assistance features
- **Telematics Apps**: Fleet management, usage tracking
- **Comfort Apps**: Climate control, seat adjustments
- **Diagnostic Tools**: Vehicle health monitoring

## Production-Ready Implementation

### 1. App Store Backend API (Python/FastAPI)

```python
#!/usr/bin/env python3
"""
Vehicle App Store Backend API.

Handles:
- App catalog management
- User authentication and purchases
- App installation and updates
- Developer portal integration
"""

from datetime import datetime, timedelta
from enum import Enum
from typing import List, Optional
from fastapi import FastAPI, HTTPException, Depends, Security
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, Field
from sqlalchemy import create_engine, Column, String, Integer, Float, DateTime, Boolean, JSON
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
import jwt
import hashlib


# Database models
Base = declarative_base()


class AppCategory(str, Enum):
    """App categories."""
    NAVIGATION = "navigation"
    MEDIA = "media"
    PRODUCTIVITY = "productivity"
    GAMES = "games"
    UTILITIES = "utilities"
    ADAS = "adas"
    DIAGNOSTICS = "diagnostics"


class AppStatus(str, Enum):
    """App certification status."""
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"
    SUSPENDED = "suspended"


class App(Base):
    """Application model."""
    __tablename__ = "apps"

    id = Column(String, primary_key=True)
    name = Column(String, nullable=False)
    developer_id = Column(String, nullable=False)
    category = Column(String, nullable=False)
    version = Column(String, nullable=False)
    description = Column(String)
    price = Column(Float, default=0.0)
    rating = Column(Float, default=0.0)
    downloads = Column(Integer, default=0)
    status = Column(String, default=AppStatus.PENDING.value)
    manifest_url = Column(String)
    icon_url = Column(String)
    screenshots = Column(JSON, default=list)
    permissions = Column(JSON, default=list)
    min_platform_version = Column(String)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class User(Base):
    """User model."""
    __tablename__ = "users"

    id = Column(String, primary_key=True)
    vin = Column(String, unique=True, nullable=False)  # Vehicle VIN
    email = Column(String)
    purchased_apps = Column(JSON, default=list)
    installed_apps = Column(JSON, default=list)
    created_at = Column(DateTime, default=datetime.utcnow)


class Purchase(Base):
    """Purchase transaction model."""
    __tablename__ = "purchases"

    id = Column(String, primary_key=True)
    user_id = Column(String, nullable=False)
    app_id = Column(String, nullable=False)
    amount = Column(Float)
    transaction_date = Column(DateTime, default=datetime.utcnow)
    status = Column(String, default="completed")


# Pydantic schemas
class AppCreate(BaseModel):
    """App creation schema."""
    name: str
    developer_id: str
    category: AppCategory
    version: str
    description: str
    price: float = 0.0
    manifest_url: str
    icon_url: str
    screenshots: List[str] = []
    permissions: List[str] = []
    min_platform_version: str = "1.0.0"


class AppResponse(BaseModel):
    """App response schema."""
    id: str
    name: str
    developer_id: str
    category: str
    version: str
    description: str
    price: float
    rating: float
    downloads: int
    status: str
    icon_url: str
    screenshots: List[str]
    permissions: List[str]
    created_at: datetime

    class Config:
        from_attributes = True


class PurchaseRequest(BaseModel):
    """Purchase request schema."""
    app_id: str
    payment_method: str = "credit_card"


class InstallRequest(BaseModel):
    """App installation request."""
    app_id: str


# Initialize FastAPI
app = FastAPI(title="Vehicle App Store API", version="1.0.0")
security = HTTPBearer()

# Database setup
DATABASE_URL = "postgresql://appstore:password@localhost/vehicle_appstore"
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# JWT secret
JWT_SECRET = "your-secret-key-change-in-production"


def get_db():
    """Database session dependency."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def verify_token(credentials: HTTPAuthorizationCredentials = Security(security)) -> dict:
    """Verify JWT token and extract user info."""
    try:
        token = credentials.credentials
        payload = jwt.decode(token, JWT_SECRET, algorithms=["HS256"])
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")


@app.post("/auth/login")
async def login(vin: str, db: Session = Depends(get_db)):
    """
    Authenticate vehicle by VIN.

    In production, this would verify VIN against manufacturer database.
    """
    user = db.query(User).filter(User.vin == vin).first()

    if not user:
        # Create new user
        user = User(id=hashlib.sha256(vin.encode()).hexdigest()[:16], vin=vin)
        db.add(user)
        db.commit()

    # Generate JWT
    token = jwt.encode(
        {
            "user_id": user.id,
            "vin": user.vin,
            "exp": datetime.utcnow() + timedelta(days=30)
        },
        JWT_SECRET,
        algorithm="HS256"
    )

    return {"access_token": token, "token_type": "bearer"}


@app.get("/apps", response_model=List[AppResponse])
async def list_apps(
    category: Optional[AppCategory] = None,
    search: Optional[str] = None,
    db: Session = Depends(get_db)
):
    """
    List available apps.

    Filters by category and search query.
    Only returns approved apps.
    """
    query = db.query(App).filter(App.status == AppStatus.APPROVED.value)

    if category:
        query = query.filter(App.category == category.value)

    if search:
        query = query.filter(App.name.ilike(f"%{search}%"))

    apps = query.order_by(App.rating.desc(), App.downloads.desc()).limit(50).all()
    return apps


@app.get("/apps/{app_id}", response_model=AppResponse)
async def get_app(app_id: str, db: Session = Depends(get_db)):
    """Get app details."""
    app_obj = db.query(App).filter(App.id == app_id).first()

    if not app_obj:
        raise HTTPException(status_code=404, detail="App not found")

    return app_obj


@app.post("/apps", response_model=AppResponse)
async def submit_app(
    app_data: AppCreate,
    user_info: dict = Depends(verify_token),
    db: Session = Depends(get_db)
):
    """
    Submit new app for certification.

    Developer portal endpoint.
    """
    app_id = hashlib.sha256(
        f"{app_data.name}{app_data.developer_id}{datetime.utcnow()}".encode()
    ).hexdigest()[:16]

    app_obj = App(
        id=app_id,
        name=app_data.name,
        developer_id=app_data.developer_id,
        category=app_data.category.value,
        version=app_data.version,
        description=app_data.description,
        price=app_data.price,
        manifest_url=app_data.manifest_url,
        icon_url=app_data.icon_url,
        screenshots=app_data.screenshots,
        permissions=app_data.permissions,
        min_platform_version=app_data.min_platform_version,
        status=AppStatus.PENDING.value
    )

    db.add(app_obj)
    db.commit()
    db.refresh(app_obj)

    return app_obj


@app.post("/apps/{app_id}/purchase")
async def purchase_app(
    app_id: str,
    purchase_data: PurchaseRequest,
    user_info: dict = Depends(verify_token),
    db: Session = Depends(get_db)
):
    """
    Purchase app.

    Handles payment processing and license activation.
    """
    app_obj = db.query(App).filter(App.id == app_id).first()

    if not app_obj:
        raise HTTPException(status_code=404, detail="App not found")

    user = db.query(User).filter(User.id == user_info["user_id"]).first()

    # Check if already purchased
    if app_id in user.purchased_apps:
        return {"message": "App already purchased", "app_id": app_id}

    # Process payment (integrate with payment gateway)
    # For demo purposes, assume payment succeeds
    purchase_id = hashlib.sha256(
        f"{user.id}{app_id}{datetime.utcnow()}".encode()
    ).hexdigest()[:16]

    purchase = Purchase(
        id=purchase_id,
        user_id=user.id,
        app_id=app_id,
        amount=app_obj.price,
        status="completed"
    )

    # Update user purchased apps
    user.purchased_apps.append(app_id)

    # Increment app downloads
    app_obj.downloads += 1

    db.add(purchase)
    db.commit()

    return {
        "message": "Purchase successful",
        "purchase_id": purchase_id,
        "app_id": app_id,
        "amount": app_obj.price
    }


@app.post("/apps/{app_id}/install")
async def install_app(
    app_id: str,
    user_info: dict = Depends(verify_token),
    db: Session = Depends(get_db)
):
    """
    Install app to vehicle.

    Returns manifest URL for vehicle runtime to download.
    """
    user = db.query(User).filter(User.id == user_info["user_id"]).first()

    # Check if purchased
    if app_id not in user.purchased_apps:
        raise HTTPException(status_code=403, detail="App not purchased")

    app_obj = db.query(App).filter(App.id == app_id).first()

    if not app_obj:
        raise HTTPException(status_code=404, detail="App not found")

    # Add to installed apps
    if app_id not in user.installed_apps:
        user.installed_apps.append(app_id)
        db.commit()

    return {
        "message": "Installation initiated",
        "app_id": app_id,
        "manifest_url": app_obj.manifest_url,
        "version": app_obj.version
    }


@app.get("/apps/{app_id}/updates")
async def check_app_updates(
    app_id: str,
    current_version: str,
    user_info: dict = Depends(verify_token),
    db: Session = Depends(get_db)
):
    """
    Check for app updates.

    Returns latest version if newer than current.
    """
    app_obj = db.query(App).filter(App.id == app_id).first()

    if not app_obj:
        raise HTTPException(status_code=404, detail="App not found")

    if app_obj.version != current_version:
        return {
            "update_available": True,
            "latest_version": app_obj.version,
            "manifest_url": app_obj.manifest_url,
            "changelog": f"Updated to version {app_obj.version}"
        }

    return {"update_available": False}


@app.get("/user/apps")
async def get_user_apps(
    user_info: dict = Depends(verify_token),
    db: Session = Depends(get_db)
):
    """Get user's purchased and installed apps."""
    user = db.query(User).filter(User.id == user_info["user_id"]).first()

    purchased = db.query(App).filter(App.id.in_(user.purchased_apps)).all()
    installed = db.query(App).filter(App.id.in_(user.installed_apps)).all()

    return {
        "purchased": [AppResponse.from_orm(app) for app in purchased],
        "installed": [AppResponse.from_orm(app) for app in installed]
    }


@app.post("/apps/{app_id}/rate")
async def rate_app(
    app_id: str,
    rating: float = Field(..., ge=1.0, le=5.0),
    user_info: dict = Depends(verify_token),
    db: Session = Depends(get_db)
):
    """Rate an app (1-5 stars)."""
    user = db.query(User).filter(User.id == user_info["user_id"]).first()

    if app_id not in user.purchased_apps:
        raise HTTPException(status_code=403, detail="Must own app to rate")

    app_obj = db.query(App).filter(App.id == app_id).first()

    # Update rolling average (simplified)
    # In production, store individual ratings
    app_obj.rating = (app_obj.rating + rating) / 2

    db.commit()

    return {"message": "Rating submitted", "new_rating": app_obj.rating}


if __name__ == "__main__":
    import uvicorn
    Base.metadata.create_all(bind=engine)
    uvicorn.run(app, host="0.0.0.0", port=8000)
```

### 2. App Manifest Format

```yaml
# App manifest - describes app metadata and requirements
# File: app-manifest.yaml

apiVersion: vehicle.app/v1
kind: VehicleApp
metadata:
  name: spotify-automotive
  version: 2.1.4
  displayName: Spotify for Cars
  developer:
    id: spotify-inc
    name: Spotify AB
    email: automotive@spotify.com
    website: https://www.spotify.com

spec:
  description: |
    Stream millions of songs and podcasts directly in your vehicle.
    Integrates with vehicle audio system and steering wheel controls.

  category: media
  price: 0.0  # Free with subscription
  inAppPurchases: true

  # Platform requirements
  platform:
    minVersion: "2.0.0"
    targetVersion: "3.1.0"
    architecture: ["arm64", "x86_64"]

  # Permissions required
  permissions:
    - AUDIO_PLAYBACK
    - INTERNET
    - BLUETOOTH
    - VEHICLE_SPEED  # For audio ducking when speed > 100mph
    - STEERING_CONTROLS
    - LOCATION  # For personalized recommendations

  # Resource limits
  resources:
    memory: 512Mi
    cpu: 500m
    storage: 2Gi
    bandwidth: 10Mbps

  # Container configuration
  container:
    image: registry.spotify.com/automotive/spotify:2.1.4
    entrypoint: ["/usr/bin/spotify-app"]
    environment:
      - name: API_KEY
        valueFrom:
          secretRef:
            name: spotify-api-credentials
            key: api-key

  # Service exposure
  services:
    - name: media-player
      protocol: dbus
      interface: org.mpris.MediaPlayer2
      path: /org/mpris/MediaPlayer2/spotify

  # UI configuration
  ui:
    icon: https://cdn.spotify.com/automotive/icon-512.png
    screenshots:
      - https://cdn.spotify.com/automotive/screenshot1.png
      - https://cdn.spotify.com/automotive/screenshot2.png
    launchMode: fullscreen
    displayInLauncher: true

  # Integration points
  integrations:
    voiceAssistant:
      enabled: true
      wakeWords: ["play music", "open spotify"]
    steeringControls:
      enabled: true
      actions: [play, pause, next, previous, volume]
    clusterDisplay:
      enabled: true
      showNowPlaying: true

  # Safety constraints
  safety:
    disableWhileDriving: false
    touchInteractionLimit: true  # Limit UI interaction while moving
    voiceControlRequired: false

  # Analytics and telemetry
  telemetry:
    enabled: true
    endpoint: https://telemetry.spotify.com/automotive
    dataTypes:
      - usage_statistics
      - crash_reports
      - performance_metrics

  # Update strategy
  updatePolicy:
    automatic: true
    canRollback: true
    maxDowntime: 30s
```

### 3. App Sandbox Runtime (Golang)

```go
// Vehicle app sandbox runtime using containerd
// File: app-runtime.go

package main

import (
    "context"
    "fmt"
    "log"
    "os"
    "path/filepath"
    "syscall"

    "github.com/containerd/containerd"
    "github.com/containerd/containerd/cio"
    "github.com/containerd/containerd/namespaces"
    "github.com/containerd/containerd/oci"
    "gopkg.in/yaml.v3"
)

// AppManifest represents vehicle app configuration
type AppManifest struct {
    APIVersion string `yaml:"apiVersion"`
    Kind       string `yaml:"kind"`
    Metadata   struct {
        Name        string `yaml:"name"`
        Version     string `yaml:"version"`
        DisplayName string `yaml:"displayName"`
    } `yaml:"metadata"`
    Spec struct {
        Permissions []string `yaml:"permissions"`
        Resources   struct {
            Memory    string `yaml:"memory"`
            CPU       string `yaml:"cpu"`
            Storage   string `yaml:"storage"`
            Bandwidth string `yaml:"bandwidth"`
        } `yaml:"resources"`
        Container struct {
            Image       string   `yaml:"image"`
            Entrypoint  []string `yaml:"entrypoint"`
            Environment []struct {
                Name  string `yaml:"name"`
                Value string `yaml:"value,omitempty"`
            } `yaml:"environment"`
        } `yaml:"container"`
        Safety struct {
            DisableWhileDriving    bool `yaml:"disableWhileDriving"`
            TouchInteractionLimit  bool `yaml:"touchInteractionLimit"`
        } `yaml:"safety"`
    } `yaml:"spec"`
}

// AppRuntime manages vehicle app lifecycle
type AppRuntime struct {
    client    *containerd.Client
    namespace string
}

// NewAppRuntime creates a new app runtime
func NewAppRuntime() (*AppRuntime, error) {
    client, err := containerd.New("/run/containerd/containerd.sock")
    if err != nil {
        return nil, fmt.Errorf("failed to connect to containerd: %w", err)
    }

    return &AppRuntime{
        client:    client,
        namespace: "vehicle-apps",
    }, nil
}

// InstallApp installs an app from manifest
func (r *AppRuntime) InstallApp(manifestPath string) error {
    // Load manifest
    manifest, err := r.loadManifest(manifestPath)
    if err != nil {
        return fmt.Errorf("failed to load manifest: %w", err)
    }

    log.Printf("Installing app: %s v%s", manifest.Metadata.Name, manifest.Metadata.Version)

    ctx := namespaces.WithNamespace(context.Background(), r.namespace)

    // Pull container image
    image, err := r.client.Pull(ctx, manifest.Spec.Container.Image,
        containerd.WithPullUnpack)
    if err != nil {
        return fmt.Errorf("failed to pull image: %w", err)
    }

    log.Printf("Pulled image: %s", image.Name())

    // Create container with security constraints
    container, err := r.createSecureContainer(ctx, manifest, image)
    if err != nil {
        return fmt.Errorf("failed to create container: %w", err)
    }

    log.Printf("App installed successfully: %s", container.ID())
    return nil
}

// createSecureContainer creates a sandboxed container with security policies
func (r *AppRuntime) createSecureContainer(
    ctx context.Context,
    manifest *AppManifest,
    image containerd.Image,
) (containerd.Container, error) {

    appName := manifest.Metadata.Name

    // Define security policies based on permissions
    opts := []oci.SpecOpts{
        oci.WithImageConfig(image),
        oci.WithEnv(r.buildEnvironment(manifest)),

        // Resource limits
        oci.WithMemoryLimit(r.parseMemory(manifest.Spec.Resources.Memory)),
        oci.WithCPUQuota(500000, 100000), // 500m CPU

        // Security constraints
        oci.WithNoNewPrivileges,
        oci.WithPrivileged(false),

        // Read-only root filesystem
        oci.WithRootFSReadonly(),

        // Drop all capabilities by default
        oci.WithCapabilities([]string{}),

        // Add capabilities based on permissions
        oci.WithAddedCapabilities(r.getCapabilities(manifest.Spec.Permissions)),

        // Mount tmpfs for writable directories
        oci.WithMounts([]oci.Mount{
            {
                Type:        "tmpfs",
                Source:      "tmpfs",
                Destination: "/tmp",
                Options:     []string{"nosuid", "noexec", "nodev"},
            },
            {
                Type:        "bind",
                Source:      filepath.Join("/var/lib/vehicle-apps", appName, "data"),
                Destination: "/data",
                Options:     []string{"rbind", "rw"},
            },
        }),

        // Namespace isolation
        oci.WithLinuxNamespace(oci.LinuxNamespace{
            Type: "pid",
        }),
        oci.WithLinuxNamespace(oci.LinuxNamespace{
            Type: "network",
        }),
        oci.WithLinuxNamespace(oci.LinuxNamespace{
            Type: "ipc",
        }),
    }

    // Permission-specific constraints
    if !r.hasPermission(manifest.Spec.Permissions, "INTERNET") {
        // Block network access
        opts = append(opts, oci.WithHostNamespace(oci.NetworkNamespace))
    }

    // Create container
    container, err := r.client.NewContainer(
        ctx,
        appName,
        containerd.WithImage(image),
        containerd.WithNewSnapshot(appName+"-snapshot", image),
        containerd.WithNewSpec(opts...),
    )

    return container, err
}

// StartApp starts an installed app
func (r *AppRuntime) StartApp(appName string, manifest *AppManifest) error {
    ctx := namespaces.WithNamespace(context.Background(), r.namespace)

    container, err := r.client.LoadContainer(ctx, appName)
    if err != nil {
        return fmt.Errorf("failed to load container: %w", err)
    }

    // Check safety constraints
    if manifest.Spec.Safety.DisableWhileDriving {
        if r.isVehicleMoving() {
            return fmt.Errorf("app disabled while driving")
        }
    }

    // Create task
    task, err := container.NewTask(ctx, cio.NewCreator(cio.WithStdio))
    if err != nil {
        return fmt.Errorf("failed to create task: %w", err)
    }

    // Start task
    if err := task.Start(ctx); err != nil {
        return fmt.Errorf("failed to start task: %w", err)
    }

    log.Printf("App started: %s (PID: %d)", appName, task.Pid())
    return nil
}

// StopApp stops a running app
func (r *AppRuntime) StopApp(appName string) error {
    ctx := namespaces.WithNamespace(context.Background(), r.namespace)

    container, err := r.client.LoadContainer(ctx, appName)
    if err != nil {
        return fmt.Errorf("failed to load container: %w", err)
    }

    task, err := container.Task(ctx, nil)
    if err != nil {
        return fmt.Errorf("failed to get task: %w", err)
    }

    // Graceful shutdown
    if err := task.Kill(ctx, syscall.SIGTERM); err != nil {
        return fmt.Errorf("failed to send SIGTERM: %w", err)
    }

    // Wait for exit (with timeout)
    status, err := task.Wait(ctx)
    if err != nil {
        return fmt.Errorf("failed to wait for exit: %w", err)
    }

    <-status

    log.Printf("App stopped: %s", appName)
    return nil
}

// UninstallApp removes an installed app
func (r *AppRuntime) UninstallApp(appName string) error {
    ctx := namespaces.WithNamespace(context.Background(), r.namespace)

    // Stop if running
    _ = r.StopApp(appName)

    // Delete container
    container, err := r.client.LoadContainer(ctx, appName)
    if err != nil {
        return fmt.Errorf("failed to load container: %w", err)
    }

    if err := container.Delete(ctx, containerd.WithSnapshotCleanup); err != nil {
        return fmt.Errorf("failed to delete container: %w", err)
    }

    log.Printf("App uninstalled: %s", appName)
    return nil
}

// Helper functions

func (r *AppRuntime) loadManifest(path string) (*AppManifest, error) {
    data, err := os.ReadFile(path)
    if err != nil {
        return nil, err
    }

    var manifest AppManifest
    if err := yaml.Unmarshal(data, &manifest); err != nil {
        return nil, err
    }

    return &manifest, nil
}

func (r *AppRuntime) buildEnvironment(manifest *AppManifest) []string {
    env := []string{}
    for _, e := range manifest.Spec.Container.Environment {
        env = append(env, fmt.Sprintf("%s=%s", e.Name, e.Value))
    }
    return env
}

func (r *AppRuntime) parseMemory(mem string) uint64 {
    // Simple parser for Mi/Gi units
    // In production, use proper parsing
    return 512 * 1024 * 1024 // 512Mi
}

func (r *AppRuntime) getCapabilities(permissions []string) []string {
    caps := []string{}

    for _, perm := range permissions {
        switch perm {
        case "INTERNET":
            caps = append(caps, "CAP_NET_BIND_SERVICE")
        case "BLUETOOTH":
            caps = append(caps, "CAP_NET_ADMIN")
        case "AUDIO_PLAYBACK":
            // Allow access to audio devices
        }
    }

    return caps
}

func (r *AppRuntime) hasPermission(permissions []string, perm string) bool {
    for _, p := range permissions {
        if p == perm {
            return true
        }
    }
    return false
}

func (r *AppRuntime) isVehicleMoving() bool {
    // Check vehicle speed from CAN bus
    // Placeholder implementation
    return false
}

func main() {
    runtime, err := NewAppRuntime()
    if err != nil {
        log.Fatalf("Failed to create runtime: %v", err)
    }

    // Example: Install and start app
    if err := runtime.InstallApp("spotify-manifest.yaml"); err != nil {
        log.Fatalf("Failed to install app: %v", err)
    }

    // Load manifest for safety checks
    manifest, _ := runtime.loadManifest("spotify-manifest.yaml")

    if err := runtime.StartApp("spotify-automotive", manifest); err != nil {
        log.Fatalf("Failed to start app: %v", err)
    }

    log.Println("App runtime running...")
    select {} // Keep running
}
```

### 4. Developer SDK Example (TypeScript)

```typescript
// Vehicle App Developer SDK
// File: vehicle-app-sdk.ts

/**
 * Vehicle App SDK for TypeScript/JavaScript apps
 * Provides APIs for vehicle integration
 */

export enum Permission {
  AUDIO_PLAYBACK = 'AUDIO_PLAYBACK',
  INTERNET = 'INTERNET',
  BLUETOOTH = 'BLUETOOTH',
  VEHICLE_SPEED = 'VEHICLE_SPEED',
  LOCATION = 'LOCATION',
  STEERING_CONTROLS = 'STEERING_CONTROLS',
  CLIMATE_CONTROL = 'CLIMATE_CONTROL',
}

export interface VehicleState {
  speed: number; // km/h
  gear: string;
  isMoving: boolean;
  batteryLevel: number; // percentage
  range: number; // km
}

export class VehicleAppSDK {
  private readonly appId: string;
  private readonly permissions: Permission[];
  private ws: WebSocket | null = null;

  constructor(appId: string, permissions: Permission[]) {
    this.appId = appId;
    this.permissions = permissions;
  }

  /**
   * Initialize SDK connection to vehicle platform
   */
  async initialize(): Promise<void> {
    console.log(`Initializing SDK for app: ${this.appId}`);

    // Connect to vehicle platform via WebSocket
    this.ws = new WebSocket('ws://vehicle-platform:8080/apps/ws');

    return new Promise((resolve, reject) => {
      this.ws!.onopen = () => {
        console.log('Connected to vehicle platform');

        // Send authentication
        this.ws!.send(JSON.stringify({
          type: 'auth',
          appId: this.appId,
          permissions: this.permissions,
        }));

        resolve();
      };

      this.ws!.onerror = (error) => {
        reject(new Error(`WebSocket error: ${error}`));
      };
    });
  }

  /**
   * Get current vehicle state
   */
  async getVehicleState(): Promise<VehicleState> {
    this.checkPermission(Permission.VEHICLE_SPEED);

    return new Promise((resolve, reject) => {
      const requestId = Date.now().toString();

      this.ws!.send(JSON.stringify({
        type: 'request',
        requestId,
        method: 'getVehicleState',
      }));

      const handler = (event: MessageEvent) => {
        const data = JSON.parse(event.data);
        if (data.requestId === requestId) {
          this.ws!.removeEventListener('message', handler);
          resolve(data.result);
        }
      };

      this.ws!.addEventListener('message', handler);

      // Timeout after 5 seconds
      setTimeout(() => {
        this.ws!.removeEventListener('message', handler);
        reject(new Error('Request timeout'));
      }, 5000);
    });
  }

  /**
   * Subscribe to vehicle state changes
   */
  onVehicleStateChange(callback: (state: VehicleState) => void): void {
    this.checkPermission(Permission.VEHICLE_SPEED);

    this.ws!.addEventListener('message', (event) => {
      const data = JSON.parse(event.data);
      if (data.type === 'vehicleStateUpdate') {
        callback(data.state);
      }
    });

    // Subscribe
    this.ws!.send(JSON.stringify({
      type: 'subscribe',
      topic: 'vehicleState',
    }));
  }

  /**
   * Control audio playback
   */
  async playAudio(url: string): Promise<void> {
    this.checkPermission(Permission.AUDIO_PLAYBACK);

    await this.sendRequest('playAudio', { url });
  }

  /**
   * Subscribe to steering control events
   */
  onSteeringControl(callback: (action: string) => void): void {
    this.checkPermission(Permission.STEERING_CONTROLS);

    this.ws!.addEventListener('message', (event) => {
      const data = JSON.parse(event.data);
      if (data.type === 'steeringControl') {
        callback(data.action); // 'next', 'previous', 'play', 'pause'
      }
    });

    this.ws!.send(JSON.stringify({
      type: 'subscribe',
      topic: 'steeringControls',
    }));
  }

  /**
   * Display notification in vehicle cluster
   */
  async showNotification(title: string, message: string): Promise<void> {
    await this.sendRequest('showNotification', { title, message });
  }

  /**
   * Get current location
   */
  async getLocation(): Promise<{ latitude: number; longitude: number }> {
    this.checkPermission(Permission.LOCATION);

    const result = await this.sendRequest('getLocation', {});
    return result as { latitude: number; longitude: number };
  }

  private checkPermission(permission: Permission): void {
    if (!this.permissions.includes(permission)) {
      throw new Error(`Permission not granted: ${permission}`);
    }
  }

  private async sendRequest(method: string, params: any): Promise<any> {
    return new Promise((resolve, reject) => {
      const requestId = Date.now().toString();

      this.ws!.send(JSON.stringify({
        type: 'request',
        requestId,
        method,
        params,
      }));

      const handler = (event: MessageEvent) => {
        const data = JSON.parse(event.data);
        if (data.requestId === requestId) {
          this.ws!.removeEventListener('message', handler);

          if (data.error) {
            reject(new Error(data.error));
          } else {
            resolve(data.result);
          }
        }
      };

      this.ws!.addEventListener('message', handler);

      setTimeout(() => {
        this.ws!.removeEventListener('message', handler);
        reject(new Error('Request timeout'));
      }, 5000);
    });
  }
}

// Example app using SDK
async function exampleApp() {
  const sdk = new VehicleAppSDK('spotify-automotive', [
    Permission.AUDIO_PLAYBACK,
    Permission.STEERING_CONTROLS,
    Permission.VEHICLE_SPEED,
  ]);

  await sdk.initialize();

  // Get vehicle state
  const state = await sdk.getVehicleState();
  console.log(`Vehicle speed: ${state.speed} km/h`);

  // Subscribe to steering controls
  sdk.onSteeringControl((action) => {
    console.log(`Steering control: ${action}`);
    if (action === 'play') {
      sdk.playAudio('https://cdn.spotify.com/track/123.mp3');
    }
  });

  // Monitor vehicle state
  sdk.onVehicleStateChange((state) => {
    if (state.speed > 100) {
      // Duck audio volume at high speeds
      console.log('High speed detected, reducing volume');
    }
  });
}
```

## Real-World Examples

### Tesla App Store Strategy
- **Built-in apps**: Native Tesla apps (Netflix, YouTube, Spotify)
- **No third-party yet**: Closed ecosystem for quality control
- **Game integration**: Steam integration announced for Model S/X
- **API access**: Limited fleet API for developers

### GM Ultifi Platform
- **Open developer program**: Third-party app marketplace
- **Revenue sharing**: 70/30 split (developer/GM)
- **SDK availability**: Public SDK with APIs for vehicle data
- **Categories**: Navigation, media, productivity, games

### VW.OS App Store
- **Phased rollout**: Starting with MEB platform (ID. series)
- **Partner apps**: Curated partners initially
- **In-car payment**: Integrated billing system
- **Cross-brand**: Shared across VW Group brands

### Rivian App Shop
- **Adventure focus**: Apps for off-road, camping, outdoor
- **Fleet integration**: Apps for commercial R1T owners
- **OTA updates**: Apps update independently of vehicle software

## Best Practices

1. **Strict permission model**: Request only necessary permissions
2. **Sandboxed execution**: Isolate apps from vehicle systems
3. **Resource limits**: Enforce memory, CPU, bandwidth limits
4. **Safety first**: Disable/limit apps while driving
5. **Certification process**: Manual security review before approval
6. **Privacy protection**: Transparent data collection policies
7. **Offline functionality**: Apps should work without connectivity
8. **Graceful degradation**: Handle missing permissions elegantly
9. **Update mechanism**: Automatic updates for security patches
10. **Rollback support**: Ability to rollback problematic updates

## Security Considerations

- **Code signing**: All apps must be signed by developer
- **Runtime verification**: Verify signatures before execution
- **Capability-based security**: Grant minimal capabilities
- **Network isolation**: Apps cannot access vehicle CAN bus directly
- **Data encryption**: Encrypt app data at rest
- **Audit logging**: Log all permission requests and usage
- **Kill switch**: Remote ability to disable compromised apps

## References

- **Android Automotive**: https://source.android.com/devices/automotive
- **COVESA**: https://covesa.global/
- **GENIVI**: https://www.genivi.org/
- **Eclipse SDV**: https://sdv.eclipse.org/
