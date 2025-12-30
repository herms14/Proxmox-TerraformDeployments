# Kubernetes Learning Tutorial: Deploying Glance Dashboard

> **Goal**: Learn Kubernetes concepts by deploying a real application (Glance Dashboard + APIs) to your on-premises cluster, then migrate it to Azure Kubernetes Service (AKS).

> **Important**: This is a learning exercise. Your production Glance on LXC 200 (192.168.40.12) will continue running unchanged.

---

## Table of Contents

1. [Introduction & Architecture](#1-introduction--architecture)
2. [Kubernetes Concepts Overview](#2-kubernetes-concepts-overview)
3. [Prerequisites](#3-prerequisites)
4. [Part 1: Preparing Your Application](#4-part-1-preparing-your-application)
5. [Part 2: Creating Kubernetes Manifests](#5-part-2-creating-kubernetes-manifests)
6. [Part 3: Deploying to On-Premises Kubernetes](#6-part-3-deploying-to-on-premises-kubernetes)
7. [Part 4: Exposing Services with Ingress](#7-part-4-exposing-services-with-ingress)
8. [Part 5: Configuration Management](#8-part-5-configuration-management)
9. [Part 6: Persistent Storage](#9-part-6-persistent-storage)
10. [Part 7: Monitoring & Health Checks](#10-part-7-monitoring--health-checks)
11. [Part 8: Migrating to Azure Kubernetes Service](#11-part-8-migrating-to-azure-kubernetes-service)
12. [Part 9: Best Practices Summary](#12-part-9-best-practices-summary)
13. [Troubleshooting](#13-troubleshooting)
14. [Cleanup](#14-cleanup)

---

## 1. Introduction & Architecture

### What We're Deploying

We'll deploy the complete Glance Dashboard stack consisting of 4 microservices:

| Service | Port | Purpose | Dependencies |
|---------|------|---------|--------------|
| **Glance** | 8080 | Main dashboard | Config files, APIs |
| **Media Stats API** | 5054 | Radarr/Sonarr statistics | External Radarr/Sonarr |
| **Reddit Manager** | 5053 | Reddit feed aggregation | Persistent storage |
| **NBA Stats API** | 5060 | Sports scores & fantasy | Yahoo OAuth tokens |

### Architecture Comparison

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        CURRENT (Docker on LXC)                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   LXC 200 (192.168.40.12)                                                   │
│   ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐          │
│   │   Glance    │ │ Media Stats │ │   Reddit    │ │  NBA Stats  │          │
│   │   :8080     │ │    :5054    │ │   :5053     │ │    :5060    │          │
│   └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘          │
│         │               │               │               │                   │
│         └───────────────┴───────────────┴───────────────┘                   │
│                                 │                                            │
│                          Docker Network                                      │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                      TARGET (Kubernetes Cluster)                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                        Ingress Controller                            │   │
│   │              (Routes: glance-k8s.hrmsmrflrii.xyz)                    │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                         │
│   ┌────────────────────────────────┼────────────────────────────────────┐   │
│   │                         glance-system namespace                      │   │
│   │                                │                                     │   │
│   │   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌───────────┐  │   │
│   │   │  Glance     │  │ Media Stats │  │   Reddit    │  │ NBA Stats │  │   │
│   │   │  Deployment │  │ Deployment  │  │ Deployment  │  │Deployment │  │   │
│   │   │  (2 pods)   │  │  (2 pods)   │  │  (1 pod)    │  │ (1 pod)   │  │   │
│   │   └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └─────┬─────┘  │   │
│   │          │                │                │                │        │   │
│   │   ┌──────┴──────┐  ┌──────┴──────┐  ┌──────┴──────┐  ┌─────┴─────┐  │   │
│   │   │   Service   │  │   Service   │  │   Service   │  │  Service  │  │   │
│   │   │ ClusterIP   │  │ ClusterIP   │  │ ClusterIP   │  │ ClusterIP │  │   │
│   │   └─────────────┘  └─────────────┘  └─────────────┘  └───────────┘  │   │
│   │                                                                      │   │
│   │   ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────────┐ │   │
│   │   │ ConfigMap   │  │   Secret    │  │  PersistentVolumeClaim      │ │   │
│   │   │ (glance.yml)│  │ (API keys)  │  │  (reddit-data, nba-data)    │ │   │
│   │   └─────────────┘  └─────────────┘  └─────────────────────────────┘ │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│   Worker Node 1          Worker Node 2          Worker Node 3               │
│   (192.168.20.43)       (192.168.20.44)       (192.168.20.45)              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Why Kubernetes?

| Docker Compose | Kubernetes |
|----------------|------------|
| Single host | Multi-node cluster |
| Manual scaling | Auto-scaling |
| Restart on failure | Self-healing + rolling updates |
| Manual load balancing | Built-in service discovery |
| File-based config | ConfigMaps & Secrets |
| Limited health checks | Liveness & Readiness probes |

---

## 2. Kubernetes Concepts Overview

Before we start, let's understand the key Kubernetes objects we'll use:

### Core Objects

| Object | Purpose | Analogy |
|--------|---------|---------|
| **Pod** | Smallest deployable unit; one or more containers | A single running instance of your app |
| **Deployment** | Manages Pod replicas and updates | docker-compose service with `replicas` |
| **Service** | Stable network endpoint for Pods | docker-compose network + port mapping |
| **ConfigMap** | Non-sensitive configuration data | .env file or config files |
| **Secret** | Sensitive data (passwords, API keys) | Encrypted .env file |
| **Namespace** | Virtual cluster isolation | Separate folder for your project |
| **Ingress** | HTTP routing from outside cluster | Reverse proxy (like Traefik) |
| **PersistentVolumeClaim** | Storage request | Docker volume |

### Object Relationship Diagram

```
                    ┌─────────────────┐
                    │    Ingress      │  ← External traffic enters here
                    │  (HTTP Router)  │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │    Service      │  ← Stable IP/DNS for pods
                    │  (Load Balancer)│
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
        ┌─────▼─────┐  ┌─────▼─────┐  ┌─────▼─────┐
        │   Pod 1   │  │   Pod 2   │  │   Pod 3   │  ← Actual containers
        │ (replica) │  │ (replica) │  │ (replica) │
        └─────┬─────┘  └─────┬─────┘  └─────┬─────┘
              │              │              │
              └──────────────┼──────────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
  ┌─────▼─────┐       ┌──────▼──────┐      ┌─────▼─────┐
  │ ConfigMap │       │   Secret    │      │    PVC    │
  │  (config) │       │ (API keys)  │      │ (storage) │
  └───────────┘       └─────────────┘      └───────────┘
```

### Kubernetes vs Docker Compose Terminology

| Docker Compose | Kubernetes Equivalent |
|----------------|----------------------|
| `docker-compose.yml` | Multiple YAML manifests |
| `services:` | `Deployment` + `Service` |
| `image:` | `spec.containers[].image` |
| `ports:` | `Service` with `ports` |
| `volumes:` | `PersistentVolumeClaim` + `volumeMounts` |
| `environment:` | `ConfigMap` or `Secret` |
| `env_file:` | `envFrom` with `ConfigMap`/`Secret` |
| `restart: always` | Default behavior (always restart) |
| `networks:` | Services auto-discover via DNS |
| `build:` | Separate image build + push to registry |

---

## 3. Prerequisites

### On-Premises Cluster Requirements

| Requirement | Your Setup | Verification Command |
|-------------|------------|---------------------|
| Kubernetes cluster | 9 nodes (v1.28.15) | `kubectl get nodes` |
| kubectl configured | ~/.kube/config | `kubectl cluster-info` |
| Storage provisioner | Local-path or NFS | `kubectl get storageclass` |
| Ingress controller | Traefik or Nginx | `kubectl get pods -n ingress` |

### Azure Requirements (for Part 8)

| Requirement | Purpose |
|-------------|---------|
| Azure account | Cloud subscription |
| Azure CLI (`az`) | Command-line management |
| Azure Container Registry (ACR) | Store Docker images |

### Verify Your On-Prem Cluster

```bash
# Connect to your cluster (from local machine or ansible controller)
ssh hermes-admin@192.168.20.30

# Check cluster status
kubectl get nodes
```

**Expected Output:**
```
NAME               STATUS   ROLES           AGE    VERSION
k8s-controller01   Ready    control-plane   30d    v1.28.15
k8s-controller02   Ready    control-plane   30d    v1.28.15
k8s-controller03   Ready    control-plane   30d    v1.28.15
k8s-worker01       Ready    <none>          30d    v1.28.15
k8s-worker02       Ready    <none>          30d    v1.28.15
...
```

### Install Required Tools

```bash
# On your local machine (macOS)
brew install kubectl azure-cli

# Verify installations
kubectl version --client
az version
```

---

## 4. Part 1: Preparing Your Application

### Step 1.1: Create Project Directory Structure

```bash
# Create a directory for your Kubernetes manifests
mkdir -p ~/k8s-glance/{base,overlays/dev,overlays/prod,overlays/azure}
cd ~/k8s-glance

# Create subdirectories for organization
mkdir -p base/{deployments,services,configmaps,secrets,storage}
```

**Directory Structure Explained:**
```
k8s-glance/
├── base/                    # Base manifests (shared across environments)
│   ├── deployments/         # Deployment manifests for each service
│   ├── services/            # Service manifests (networking)
│   ├── configmaps/          # Configuration files
│   ├── secrets/             # Sensitive data (API keys)
│   └── storage/             # PersistentVolumeClaims
├── overlays/
│   ├── dev/                 # Development-specific overrides
│   ├── prod/                # Production-specific overrides
│   └── azure/               # Azure AKS-specific overrides
```

> **Best Practice**: Use Kustomize overlays to manage different environments. This follows the DRY (Don't Repeat Yourself) principle.

### Step 1.2: Build and Push Container Images

Your custom APIs need to be built and pushed to a container registry. For on-prem, you can use:
- Docker Hub (public)
- Self-hosted registry (Harbor, GitLab Registry)
- For learning: Build locally on each node (not recommended for production)

**Option A: Push to Docker Hub (Recommended for Learning)**

```bash
# Login to Docker Hub
docker login

# Build and push Media Stats API
cd /path/to/media-stats-api
docker build -t yourusername/media-stats-api:v1.0.0 .
docker push yourusername/media-stats-api:v1.0.0

# Build and push Reddit Manager
cd /path/to/reddit-manager
docker build -t yourusername/reddit-manager:v1.0.0 .
docker push yourusername/reddit-manager:v1.0.0

# Build and push NBA Stats API
cd /path/to/nba-stats-api
docker build -t yourusername/nba-stats-api:v1.0.0 .
docker push yourusername/nba-stats-api:v1.0.0
```

**Command Breakdown:**
| Command | Purpose |
|---------|---------|
| `docker build` | Creates image from Dockerfile |
| `-t yourusername/image:tag` | Tags image with registry/name:version |
| `docker push` | Uploads image to registry |

> **Best Practice**: Always use specific version tags (v1.0.0) instead of `latest`. This ensures reproducible deployments.

**Option B: Use GitLab Container Registry (Your Setup)**

```bash
# Login to your GitLab registry
docker login gitlab.hrmsmrflrii.xyz:5050

# Build and tag for GitLab
docker build -t gitlab.hrmsmrflrii.xyz:5050/homelab/media-stats-api:v1.0.0 .
docker push gitlab.hrmsmrflrii.xyz:5050/homelab/media-stats-api:v1.0.0
```

---

## 5. Part 2: Creating Kubernetes Manifests

### Step 2.1: Create Namespace

A namespace isolates your application from others in the cluster.

**File: `base/namespace.yaml`**
```yaml
# Namespace: A virtual cluster within your physical cluster
# Think of it as a folder that groups related resources
apiVersion: v1
kind: Namespace
metadata:
  name: glance-system        # Name of your namespace
  labels:
    app.kubernetes.io/name: glance
    app.kubernetes.io/part-of: glance-stack
    # Labels help organize and select resources
```

**Key Concepts:**
| Field | Purpose |
|-------|---------|
| `apiVersion: v1` | API version for this resource type |
| `kind: Namespace` | Type of Kubernetes object |
| `metadata.name` | Unique identifier for this namespace |
| `metadata.labels` | Key-value pairs for organization/selection |

### Step 2.2: Create ConfigMaps

ConfigMaps store non-sensitive configuration data.

**File: `base/configmaps/glance-config.yaml`**
```yaml
# ConfigMap: Stores configuration data as key-value pairs
# Similar to mounting a config file into a container
apiVersion: v1
kind: ConfigMap
metadata:
  name: glance-config
  namespace: glance-system
  labels:
    app.kubernetes.io/name: glance
    app.kubernetes.io/component: config
data:
  # The key becomes the filename when mounted
  glance.yml: |
    server:
      host: 0.0.0.0
      port: 8080

    theme:
      background-color: 15 17 22        # Dark theme
      primary-color: 110 231 183        # Accent color
      contrast-multiplier: 1.1

    pages:
      - name: Home
        columns:
          - size: small
            widgets:
              - type: clock
                hour-format: "12h"
                timezones:
                  - timezone: Asia/Manila
                    label: Manila

              - type: weather
                location: Manila, Philippines
                units: metric

          - size: full
            widgets:
              - type: monitor
                title: Services
                cache: 1m
                sites:
                  # Use Kubernetes service DNS names
                  - title: Media Stats API
                    url: http://media-stats-api:5054/health
                    icon: si:radarr
                  - title: Reddit Manager
                    url: http://reddit-manager:5053/health
                    icon: si:reddit
                  - title: NBA Stats API
                    url: http://nba-stats-api:5060/health
                    icon: si:nba

              - type: extension
                title: Media Statistics
                url: http://media-stats-api:5054/api/stats
                cache: 5m
                allow-potentially-dangerous-html: true

          - size: small
            widgets:
              - type: extension
                title: Reddit Feed
                url: http://reddit-manager:5053/api/feed
                cache: 5m
```

> **Important**: Notice the service URLs use Kubernetes DNS names (`http://media-stats-api:5054`) instead of IP addresses. Kubernetes automatically creates DNS entries for services.

**File: `base/configmaps/api-config.yaml`**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: api-config
  namespace: glance-system
data:
  # Media Stats API config (non-sensitive)
  RADARR_URL: "http://192.168.40.11:7878"
  SONARR_URL: "http://192.168.40.11:8989"

  # Reddit Manager config
  DATA_DIR: "/app/data"
  POSTS_PER_SUBREDDIT: "10"
  CACHE_TTL: "300"

  # NBA Stats API config
  PORT: "5060"
  TIMEZONE: "Asia/Manila"
  FANTASY_UPDATE_HOUR: "14"
```

### Step 2.3: Create Secrets

Secrets store sensitive data like API keys and passwords.

**File: `base/secrets/api-secrets.yaml`**
```yaml
# Secret: Stores sensitive data (base64 encoded)
# NEVER commit real secrets to git - use sealed-secrets or external secret management
apiVersion: v1
kind: Secret
metadata:
  name: api-secrets
  namespace: glance-system
  labels:
    app.kubernetes.io/name: glance
    app.kubernetes.io/component: secrets
type: Opaque    # Generic secret type
stringData:     # Use stringData for plain text (auto-encoded to base64)
  # Media Stats API secrets
  RADARR_API_KEY: "your-radarr-api-key-here"
  SONARR_API_KEY: "your-sonarr-api-key-here"

  # NBA Stats API secrets (Yahoo OAuth)
  YAHOO_CLIENT_ID: "your-yahoo-client-id"
  YAHOO_CLIENT_SECRET: "your-yahoo-client-secret"
  YAHOO_LEAGUE_ID: "418.l.12095"
```

**Creating Secrets via Command Line (More Secure):**
```bash
# Create secret from literal values (doesn't leave traces in shell history with this method)
kubectl create secret generic api-secrets \
  --namespace=glance-system \
  --from-literal=RADARR_API_KEY='21f807cf286941158e11ba6477853821' \
  --from-literal=SONARR_API_KEY='50c598d01b294f929e5ecf36ae42ad2e' \
  --dry-run=client -o yaml > base/secrets/api-secrets.yaml
```

**Command Breakdown:**
| Flag | Purpose |
|------|---------|
| `create secret generic` | Create an Opaque secret |
| `--namespace` | Target namespace |
| `--from-literal` | Create key=value pair |
| `--dry-run=client` | Don't actually create, just generate |
| `-o yaml` | Output as YAML |

> **Best Practice**: Use tools like [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) or [External Secrets Operator](https://external-secrets.io/) in production to safely store secrets in Git.

### Step 2.4: Create Deployments

Deployments manage your application pods.

**File: `base/deployments/glance.yaml`**
```yaml
# Deployment: Manages the desired state of your application
# Handles scaling, updates, and self-healing
apiVersion: apps/v1
kind: Deployment
metadata:
  name: glance
  namespace: glance-system
  labels:
    app.kubernetes.io/name: glance
    app.kubernetes.io/component: dashboard
spec:
  replicas: 2              # Number of pod instances to run

  # Selector must match template labels
  selector:
    matchLabels:
      app.kubernetes.io/name: glance
      app.kubernetes.io/component: dashboard

  # Update strategy - how to roll out changes
  strategy:
    type: RollingUpdate    # Update pods gradually (not all at once)
    rollingUpdate:
      maxSurge: 1          # Max pods over desired count during update
      maxUnavailable: 0    # Keep all pods running during update

  # Pod template - defines the actual containers
  template:
    metadata:
      labels:
        app.kubernetes.io/name: glance
        app.kubernetes.io/component: dashboard
      annotations:
        # Force pod restart when ConfigMap changes
        checksum/config: "{{ include (print $.Template.BasePath \"/configmap.yaml\") . | sha256sum }}"

    spec:
      # Security context for the pod
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000

      containers:
        - name: glance
          image: glanceapp/glance:latest
          imagePullPolicy: Always    # Always check for new image

          ports:
            - name: http
              containerPort: 8080
              protocol: TCP

          # Environment variables from ConfigMap and Secret
          env:
            - name: TZ
              value: "Asia/Manila"

          # Mount ConfigMap as files
          volumeMounts:
            - name: config
              mountPath: /app/config
              readOnly: true

          # Resource limits and requests
          resources:
            requests:           # Minimum resources guaranteed
              memory: "64Mi"
              cpu: "50m"
            limits:             # Maximum resources allowed
              memory: "256Mi"
              cpu: "200m"

          # Liveness probe - restart container if unhealthy
          livenessProbe:
            httpGet:
              path: /
              port: http
            initialDelaySeconds: 10    # Wait before first check
            periodSeconds: 30          # Check every 30 seconds
            timeoutSeconds: 5          # Timeout for each check
            failureThreshold: 3        # Restart after 3 failures

          # Readiness probe - don't send traffic until ready
          readinessProbe:
            httpGet:
              path: /
              port: http
            initialDelaySeconds: 5
            periodSeconds: 10
            failureThreshold: 3

      # Define volumes (mounted above)
      volumes:
        - name: config
          configMap:
            name: glance-config
```

**Deployment Spec Breakdown:**

| Field | Purpose | Best Practice |
|-------|---------|---------------|
| `replicas` | Number of pod copies | 2+ for high availability |
| `selector.matchLabels` | How deployment finds its pods | Must match template labels exactly |
| `strategy` | How updates are performed | RollingUpdate for zero-downtime |
| `resources.requests` | Guaranteed resources | Set based on actual usage |
| `resources.limits` | Maximum resources | Prevent runaway containers |
| `livenessProbe` | Is the app alive? | Restart if failing |
| `readinessProbe` | Is the app ready for traffic? | Remove from service if failing |

**File: `base/deployments/media-stats-api.yaml`**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: media-stats-api
  namespace: glance-system
  labels:
    app.kubernetes.io/name: media-stats-api
    app.kubernetes.io/component: api
spec:
  replicas: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: media-stats-api
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app.kubernetes.io/name: media-stats-api
    spec:
      containers:
        - name: media-stats-api
          image: yourusername/media-stats-api:v1.0.0
          ports:
            - name: http
              containerPort: 5054

          # Load environment from ConfigMap and Secret
          envFrom:
            - configMapRef:
                name: api-config
            - secretRef:
                name: api-secrets

          resources:
            requests:
              memory: "64Mi"
              cpu: "50m"
            limits:
              memory: "128Mi"
              cpu: "100m"

          livenessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 10
            periodSeconds: 30

          readinessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 5
            periodSeconds: 10
```

**File: `base/deployments/reddit-manager.yaml`**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: reddit-manager
  namespace: glance-system
  labels:
    app.kubernetes.io/name: reddit-manager
    app.kubernetes.io/component: api
spec:
  replicas: 1              # Only 1 replica - has persistent storage
  selector:
    matchLabels:
      app.kubernetes.io/name: reddit-manager
  strategy:
    type: Recreate         # Recreate instead of RollingUpdate for PVC
  template:
    metadata:
      labels:
        app.kubernetes.io/name: reddit-manager
    spec:
      containers:
        - name: reddit-manager
          image: yourusername/reddit-manager:v1.0.0
          ports:
            - name: http
              containerPort: 5053

          envFrom:
            - configMapRef:
                name: api-config

          volumeMounts:
            - name: data
              mountPath: /app/data

          resources:
            requests:
              memory: "64Mi"
              cpu: "50m"
            limits:
              memory: "128Mi"
              cpu: "100m"

          livenessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 10
            periodSeconds: 30

          readinessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 5
            periodSeconds: 10

      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: reddit-manager-data
```

> **Note**: `strategy: Recreate` is used when a pod has a PersistentVolumeClaim with `ReadWriteOnce` access mode. Only one pod can mount it at a time.

**File: `base/deployments/nba-stats-api.yaml`**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nba-stats-api
  namespace: glance-system
  labels:
    app.kubernetes.io/name: nba-stats-api
    app.kubernetes.io/component: api
spec:
  replicas: 1              # Only 1 - has OAuth token storage
  selector:
    matchLabels:
      app.kubernetes.io/name: nba-stats-api
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app.kubernetes.io/name: nba-stats-api
    spec:
      containers:
        - name: nba-stats-api
          image: yourusername/nba-stats-api:v1.0.0
          ports:
            - name: http
              containerPort: 5060

          envFrom:
            - configMapRef:
                name: api-config
            - secretRef:
                name: api-secrets

          env:
            - name: YAHOO_TOKEN_PATH
              value: "/data/yahoo_token.json"

          volumeMounts:
            - name: data
              mountPath: /data

          resources:
            requests:
              memory: "128Mi"
              cpu: "100m"
            limits:
              memory: "256Mi"
              cpu: "200m"

          livenessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 15
            periodSeconds: 30

          readinessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 10
            periodSeconds: 10

      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: nba-stats-api-data
```

### Step 2.5: Create Services

Services provide stable networking endpoints for your pods.

**File: `base/services/glance.yaml`**
```yaml
# Service: Provides a stable endpoint for accessing pods
# Pods are ephemeral; Services provide consistent DNS names and IPs
apiVersion: v1
kind: Service
metadata:
  name: glance
  namespace: glance-system
  labels:
    app.kubernetes.io/name: glance
    app.kubernetes.io/component: dashboard
spec:
  type: ClusterIP          # Internal-only access (default)

  # Selector determines which pods receive traffic
  selector:
    app.kubernetes.io/name: glance
    app.kubernetes.io/component: dashboard

  ports:
    - name: http
      port: 8080           # Port the service listens on
      targetPort: http     # Port on the pod (can use name or number)
      protocol: TCP
```

**Service Types Explained:**

| Type | Description | Use Case |
|------|-------------|----------|
| `ClusterIP` | Internal cluster IP only | Inter-service communication |
| `NodePort` | Exposes on each node's IP | Direct node access (debugging) |
| `LoadBalancer` | Cloud provider load balancer | Cloud environments |
| `ExternalName` | DNS alias to external service | Access external databases |

**File: `base/services/media-stats-api.yaml`**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: media-stats-api
  namespace: glance-system
spec:
  type: ClusterIP
  selector:
    app.kubernetes.io/name: media-stats-api
  ports:
    - name: http
      port: 5054
      targetPort: http
```

**File: `base/services/reddit-manager.yaml`**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: reddit-manager
  namespace: glance-system
spec:
  type: ClusterIP
  selector:
    app.kubernetes.io/name: reddit-manager
  ports:
    - name: http
      port: 5053
      targetPort: http
```

**File: `base/services/nba-stats-api.yaml`**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nba-stats-api
  namespace: glance-system
spec:
  type: ClusterIP
  selector:
    app.kubernetes.io/name: nba-stats-api
  ports:
    - name: http
      port: 5060
      targetPort: http
```

### Step 2.6: Create Persistent Volume Claims

PVCs request storage from the cluster.

**File: `base/storage/reddit-manager-pvc.yaml`**
```yaml
# PersistentVolumeClaim: Requests storage from the cluster
# The cluster's StorageClass provisions actual storage
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: reddit-manager-data
  namespace: glance-system
  labels:
    app.kubernetes.io/name: reddit-manager
spec:
  accessModes:
    - ReadWriteOnce        # Can be mounted read-write by one node

  storageClassName: local-path    # Use your cluster's storage class

  resources:
    requests:
      storage: 1Gi         # Request 1GB of storage
```

**Access Modes Explained:**

| Mode | Description | Use Case |
|------|-------------|----------|
| `ReadWriteOnce` (RWO) | Single node read-write | Databases, single-replica apps |
| `ReadOnlyMany` (ROX) | Multiple nodes read-only | Shared config, static content |
| `ReadWriteMany` (RWX) | Multiple nodes read-write | Shared uploads (requires NFS) |

**File: `base/storage/nba-stats-api-pvc.yaml`**
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nba-stats-api-data
  namespace: glance-system
  labels:
    app.kubernetes.io/name: nba-stats-api
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 100Mi       # Small storage for OAuth token
```

---

## 6. Part 3: Deploying to On-Premises Kubernetes

### Step 3.1: Apply Manifests in Order

```bash
# Connect to a machine with kubectl access
ssh hermes-admin@192.168.20.30

# Create the namespace first
kubectl apply -f base/namespace.yaml

# Verify namespace created
kubectl get namespaces | grep glance
```

**Expected Output:**
```
glance-system   Active   5s
```

```bash
# Create ConfigMaps and Secrets
kubectl apply -f base/configmaps/
kubectl apply -f base/secrets/

# Create storage (PVCs)
kubectl apply -f base/storage/

# Create services (before deployments - so DNS is ready)
kubectl apply -f base/services/

# Finally, create deployments
kubectl apply -f base/deployments/
```

**Command Explanation:**

| Command | Purpose |
|---------|---------|
| `kubectl apply -f <file>` | Create or update resource from file |
| `kubectl apply -f <directory>/` | Apply all YAML files in directory |
| `-f` | Specify file or directory |

### Step 3.2: Verify Deployment Status

```bash
# Watch pods come up (press Ctrl+C to exit)
kubectl get pods -n glance-system -w

# Check deployment status
kubectl get deployments -n glance-system

# Check services
kubectl get services -n glance-system

# Check PVCs
kubectl get pvc -n glance-system
```

**Expected Output:**
```
NAME              READY   UP-TO-DATE   AVAILABLE   AGE
glance            2/2     2            2           2m
media-stats-api   2/2     2            2           2m
reddit-manager    1/1     1            1           2m
nba-stats-api     1/1     1            1           2m
```

### Step 3.3: Debugging Commands

```bash
# View pod logs
kubectl logs -n glance-system deployment/glance

# View logs for specific pod
kubectl logs -n glance-system glance-abc123-xyz

# Follow logs in real-time
kubectl logs -n glance-system deployment/glance -f

# View logs for previous crashed container
kubectl logs -n glance-system <pod-name> --previous

# Describe pod (events, status, conditions)
kubectl describe pod -n glance-system <pod-name>

# Execute command in pod (like docker exec)
kubectl exec -it -n glance-system <pod-name> -- /bin/sh

# Port forward for local testing
kubectl port-forward -n glance-system svc/glance 8080:8080
# Then open http://localhost:8080 in browser
```

**Common Debug Scenarios:**

| Issue | Command | What to Look For |
|-------|---------|------------------|
| Pod won't start | `kubectl describe pod <name>` | Events section, image pull errors |
| App crashing | `kubectl logs <pod> --previous` | Stack traces, error messages |
| Can't connect | `kubectl get endpoints` | Ensure endpoints exist |
| Config issues | `kubectl get configmap -o yaml` | Verify data is correct |

---

## 7. Part 4: Exposing Services with Ingress

### Step 4.1: Create Ingress Resource

**File: `base/ingress.yaml`**
```yaml
# Ingress: HTTP(S) routing from outside the cluster
# Works with an Ingress Controller (Traefik, Nginx, etc.)
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: glance-ingress
  namespace: glance-system
  labels:
    app.kubernetes.io/name: glance
  annotations:
    # Traefik-specific annotations
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"

    # For Nginx Ingress Controller, use these instead:
    # kubernetes.io/ingress.class: nginx
    # nginx.ingress.kubernetes.io/ssl-redirect: "true"

    # Certificate management (if using cert-manager)
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: traefik    # Or "nginx" depending on your setup

  tls:
    - hosts:
        - glance-k8s.hrmsmrflrii.xyz
      secretName: glance-tls-cert    # TLS certificate secret

  rules:
    - host: glance-k8s.hrmsmrflrii.xyz
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: glance
                port:
                  number: 8080
```

**Ingress Annotations Explained:**

| Annotation | Purpose |
|------------|---------|
| `traefik.ingress.kubernetes.io/router.entrypoints` | Which Traefik entrypoint to use |
| `traefik.ingress.kubernetes.io/router.tls` | Enable TLS |
| `cert-manager.io/cluster-issuer` | Auto-generate certificates |

### Step 4.2: Apply Ingress

```bash
kubectl apply -f base/ingress.yaml

# Verify ingress
kubectl get ingress -n glance-system

# Check ingress details
kubectl describe ingress -n glance-system glance-ingress
```

### Step 4.3: Configure DNS

Add a DNS record pointing to your Ingress Controller's IP:

```
glance-k8s.hrmsmrflrii.xyz → 192.168.20.40  (Ingress Controller IP)
```

For your OPNsense setup, add this in Unbound DNS overrides.

---

## 8. Part 5: Configuration Management

### Using Kustomize for Environment-Specific Config

Kustomize lets you customize manifests for different environments without duplicating files.

**File: `base/kustomization.yaml`**
```yaml
# Kustomize base configuration
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: glance-system

resources:
  - namespace.yaml
  - configmaps/glance-config.yaml
  - configmaps/api-config.yaml
  - secrets/api-secrets.yaml
  - storage/reddit-manager-pvc.yaml
  - storage/nba-stats-api-pvc.yaml
  - deployments/glance.yaml
  - deployments/media-stats-api.yaml
  - deployments/reddit-manager.yaml
  - deployments/nba-stats-api.yaml
  - services/glance.yaml
  - services/media-stats-api.yaml
  - services/reddit-manager.yaml
  - services/nba-stats-api.yaml
  - ingress.yaml

commonLabels:
  app.kubernetes.io/part-of: glance-stack
  app.kubernetes.io/managed-by: kustomize
```

**File: `overlays/dev/kustomization.yaml`**
```yaml
# Development environment overlay
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base

namePrefix: dev-           # Prefix all resource names with "dev-"
namespace: glance-dev      # Override namespace

# Patch to reduce replicas in dev
patches:
  - patch: |-
      - op: replace
        path: /spec/replicas
        value: 1
    target:
      kind: Deployment
      name: ".*"

# Override ConfigMap values
configMapGenerator:
  - name: api-config
    behavior: merge
    literals:
      - CACHE_TTL=60       # Shorter cache in dev
```

**Applying with Kustomize:**
```bash
# Preview what will be applied
kubectl kustomize overlays/dev

# Apply dev environment
kubectl apply -k overlays/dev

# Apply prod environment
kubectl apply -k overlays/prod
```

---

## 9. Part 6: Persistent Storage

### Understanding Storage in Kubernetes

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Storage Architecture                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   ┌─────────────────┐                                                       │
│   │      Pod        │                                                       │
│   │                 │                                                       │
│   │  ┌───────────┐  │     ┌─────────────────────────────────────────────┐  │
│   │  │ Container │  │     │           PersistentVolumeClaim              │  │
│   │  │           │──┼────▶│                                              │  │
│   │  │ /app/data │  │     │  - Requests: 1Gi                            │  │
│   │  └───────────┘  │     │  - AccessMode: ReadWriteOnce                │  │
│   │                 │     │  - StorageClass: local-path                 │  │
│   └─────────────────┘     └───────────────────┬─────────────────────────┘  │
│                                               │                             │
│                                               │ Binds to                    │
│                                               ▼                             │
│   ┌───────────────────────────────────────────────────────────────────────┐│
│   │                        PersistentVolume                                ││
│   │                                                                        ││
│   │  Created by StorageClass (dynamic provisioning)                       ││
│   │  OR manually created (static provisioning)                            ││
│   │                                                                        ││
│   │  Actual storage: /var/local-path-provisioner/pvc-xxx                  ││
│   └───────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│   Worker Node (192.168.20.43)                                               │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Check Your Storage Classes

```bash
# List available storage classes
kubectl get storageclass

# Example output:
# NAME                   PROVISIONER             AGE
# local-path (default)   rancher.io/local-path   30d
# nfs-client             nfs-subdir-external     30d
```

### Best Practices for Storage

1. **Use StatefulSets for databases** - Provides stable network IDs and ordered scaling
2. **Backup PVCs regularly** - Use Velero or similar tools
3. **Set appropriate storage class** - NFS for shared access, local-path for performance
4. **Monitor storage usage** - Set up alerts for capacity

---

## 10. Part 7: Monitoring & Health Checks

### Health Check Types

| Probe Type | Purpose | Failure Action |
|------------|---------|----------------|
| **Liveness** | Is the app alive? | Restart container |
| **Readiness** | Is the app ready for traffic? | Remove from service |
| **Startup** | Has the app started? | Delay other probes |

### Probe Configuration Best Practices

```yaml
# Good probe configuration
livenessProbe:
  httpGet:
    path: /health          # Dedicated health endpoint
    port: http
  initialDelaySeconds: 10  # Wait for app to start
  periodSeconds: 30        # Don't check too frequently
  timeoutSeconds: 5        # Reasonable timeout
  failureThreshold: 3      # Allow temporary failures
  successThreshold: 1      # One success = healthy

readinessProbe:
  httpGet:
    path: /ready           # Can be different from liveness
    port: http
  initialDelaySeconds: 5   # Can be faster than liveness
  periodSeconds: 10        # Check more frequently
  failureThreshold: 3
  successThreshold: 1
```

### Monitoring with kubectl

```bash
# Check pod resource usage
kubectl top pods -n glance-system

# Check node resource usage
kubectl top nodes

# View events (good for debugging)
kubectl get events -n glance-system --sort-by='.lastTimestamp'

# Watch pod status changes
kubectl get pods -n glance-system -w
```

---

## 11. Part 8: Migrating to Azure Kubernetes Service

### AKS Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              AZURE CLOUD                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                    Azure Kubernetes Service (AKS)                    │   │
│   │                                                                      │   │
│   │   ┌─────────────────────────────────────────────────────────────┐   │   │
│   │   │                  Control Plane (Managed)                     │   │   │
│   │   │     API Server │ etcd │ Scheduler │ Controller Manager      │   │   │
│   │   │                    (Microsoft manages this)                  │   │   │
│   │   └─────────────────────────────────────────────────────────────┘   │   │
│   │                              │                                       │   │
│   │   ┌──────────────────────────┼──────────────────────────────────┐   │   │
│   │   │                    Node Pool                                 │   │   │
│   │   │                                                              │   │   │
│   │   │  ┌─────────┐   ┌─────────┐   ┌─────────┐                   │   │   │
│   │   │  │ Node 1  │   │ Node 2  │   │ Node 3  │                   │   │   │
│   │   │  │(VM)     │   │(VM)     │   │(VM)     │                   │   │   │
│   │   │  └─────────┘   └─────────┘   └─────────┘                   │   │   │
│   │   │                                                              │   │   │
│   │   └──────────────────────────────────────────────────────────────┘   │   │
│   │                                                                      │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│   ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐        │
│   │ Azure Container │    │  Azure Files    │    │ Azure Load      │        │
│   │ Registry (ACR)  │    │  (Storage)      │    │ Balancer        │        │
│   └─────────────────┘    └─────────────────┘    └─────────────────┘        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Step 8.1: Install Azure CLI

```bash
# macOS
brew install azure-cli

# Verify installation
az version
```

### Step 8.2: Login to Azure

```bash
# Interactive login (opens browser)
az login

# List subscriptions
az account list --output table

# Set active subscription
az account set --subscription "Your Subscription Name"
```

### Step 8.3: Create Resource Group

```bash
# Create a resource group (logical container for Azure resources)
az group create \
  --name rg-glance-k8s \
  --location southeastasia

# Command breakdown:
# az group create      - Create a resource group
# --name              - Name of the resource group
# --location          - Azure region (choose closest to you)
```

**Azure Regions Near Philippines:**
| Region | Location |
|--------|----------|
| `southeastasia` | Singapore |
| `eastasia` | Hong Kong |
| `japaneast` | Tokyo |

### Step 8.4: Create Azure Container Registry

```bash
# Create ACR (to store your Docker images)
az acr create \
  --resource-group rg-glance-k8s \
  --name glaboratoryhomelab \
  --sku Basic \
  --admin-enabled true

# Command breakdown:
# az acr create        - Create container registry
# --resource-group    - Resource group to create in
# --name              - Registry name (must be globally unique)
# --sku Basic         - Pricing tier (Basic, Standard, Premium)
# --admin-enabled     - Enable admin account for simple auth

# Get login credentials
az acr credential show --name glaboratoryhomelab
```

### Step 8.5: Push Images to ACR

```bash
# Login to ACR
az acr login --name glaboratoryhomelab

# Tag images for ACR
docker tag yourusername/media-stats-api:v1.0.0 \
  glaboratoryhomelab.azurecr.io/media-stats-api:v1.0.0

docker tag yourusername/reddit-manager:v1.0.0 \
  glaboratoryhomelab.azurecr.io/reddit-manager:v1.0.0

docker tag yourusername/nba-stats-api:v1.0.0 \
  glaboratoryhomelab.azurecr.io/nba-stats-api:v1.0.0

# Push images
docker push glaboratoryhomelab.azurecr.io/media-stats-api:v1.0.0
docker push glaboratoryhomelab.azurecr.io/reddit-manager:v1.0.0
docker push glaboratoryhomelab.azurecr.io/nba-stats-api:v1.0.0
```

### Step 8.6: Create AKS Cluster

```bash
# Create AKS cluster
az aks create \
  --resource-group rg-glance-k8s \
  --name aks-glance \
  --node-count 2 \
  --node-vm-size Standard_B2s \
  --enable-managed-identity \
  --attach-acr glaboratoryhomelab \
  --generate-ssh-keys \
  --network-plugin azure \
  --enable-addons monitoring

# This takes 5-10 minutes to complete

# Command breakdown:
# --node-count 2          - Number of worker nodes
# --node-vm-size          - VM size (Standard_B2s = 2 vCPU, 4GB RAM, cheap)
# --enable-managed-identity - Use Azure managed identity (more secure)
# --attach-acr            - Grant AKS permission to pull from ACR
# --generate-ssh-keys     - Auto-generate SSH keys for node access
# --network-plugin azure  - Use Azure CNI networking
# --enable-addons monitoring - Enable Azure Monitor integration
```

**AKS VM Size Recommendations:**

| Size | vCPU | RAM | Use Case | Cost/Month |
|------|------|-----|----------|------------|
| `Standard_B2s` | 2 | 4GB | Dev/Test | ~$30 |
| `Standard_D2s_v3` | 2 | 8GB | Small Production | ~$70 |
| `Standard_D4s_v3` | 4 | 16GB | Medium Production | ~$140 |

### Step 8.7: Connect kubectl to AKS

```bash
# Get credentials and configure kubectl
az aks get-credentials \
  --resource-group rg-glance-k8s \
  --name aks-glance

# Verify connection
kubectl get nodes

# Expected output:
# NAME                              STATUS   ROLES   AGE   VERSION
# aks-nodepool1-12345678-vmss0000   Ready    agent   5m    v1.28.x
# aks-nodepool1-12345678-vmss0001   Ready    agent   5m    v1.28.x
```

### Step 8.8: Create Azure-Specific Overlay

**File: `overlays/azure/kustomization.yaml`**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base

namespace: glance-system

# Replace image references with ACR
images:
  - name: yourusername/media-stats-api
    newName: glaboratoryhomelab.azurecr.io/media-stats-api
    newTag: v1.0.0
  - name: yourusername/reddit-manager
    newName: glaboratoryhomelab.azurecr.io/reddit-manager
    newTag: v1.0.0
  - name: yourusername/nba-stats-api
    newName: glaboratoryhomelab.azurecr.io/nba-stats-api
    newTag: v1.0.0

# Azure-specific patches
patches:
  # Use Azure storage class
  - patch: |-
      - op: replace
        path: /spec/storageClassName
        value: managed-csi
    target:
      kind: PersistentVolumeClaim
```

**File: `overlays/azure/ingress-azure.yaml`**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: glance-ingress
  namespace: glance-system
  annotations:
    kubernetes.io/ingress.class: addon-http-application-routing
    # Or if using nginx ingress:
    # kubernetes.io/ingress.class: nginx
spec:
  rules:
    - host: glance.YOUR_AZURE_DNS_ZONE.aksapp.io
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: glance
                port:
                  number: 8080
```

### Step 8.9: Deploy to AKS

```bash
# Apply Azure overlay
kubectl apply -k overlays/azure

# Watch deployment
kubectl get pods -n glance-system -w

# Get the external IP (if using LoadBalancer service)
kubectl get svc -n glance-system
```

### Step 8.10: Configure Azure Application Gateway (Optional)

For production, use Azure Application Gateway as your ingress controller:

```bash
# Enable AGIC addon
az aks enable-addons \
  --resource-group rg-glance-k8s \
  --name aks-glance \
  --addons ingress-appgw \
  --appgw-subnet-cidr "10.225.0.0/16" \
  --appgw-name agw-glance
```

---

## 12. Part 9: Best Practices Summary

### Resource Management

| Practice | Why |
|----------|-----|
| Always set `resources.requests` | Scheduler needs this for placement |
| Always set `resources.limits` | Prevent runaway containers |
| Start conservative, scale up | Don't over-provision |
| Use Horizontal Pod Autoscaler | Auto-scale based on metrics |

### Security

| Practice | Why |
|----------|-----|
| Run as non-root | Reduce attack surface |
| Use read-only root filesystem | Prevent tampering |
| Use Secrets for sensitive data | Don't hardcode credentials |
| Enable RBAC | Principle of least privilege |
| Scan images for vulnerabilities | Prevent known exploits |

### Reliability

| Practice | Why |
|----------|-----|
| Use multiple replicas | High availability |
| Set proper health probes | Auto-recovery |
| Use PodDisruptionBudgets | Safe maintenance |
| Implement graceful shutdown | Clean termination |

### Observability

| Practice | Why |
|----------|-----|
| Use structured logging | Easy parsing |
| Export metrics (Prometheus) | Visibility |
| Set up alerts | Proactive response |
| Use tracing (Jaeger) | Debug distributed issues |

### Configuration

| Practice | Why |
|----------|-----|
| Use ConfigMaps for config | Separate config from code |
| Use Kustomize/Helm | Environment management |
| Version your manifests | Reproducibility |
| Use GitOps (ArgoCD/Flux) | Automated deployments |

---

## 13. Troubleshooting

### Common Issues and Solutions

**Pod stuck in `Pending`:**
```bash
# Check events
kubectl describe pod <pod-name> -n glance-system

# Common causes:
# - Insufficient resources → Check node capacity
# - PVC not bound → Check storage class
# - Image pull errors → Check registry access
```

**Pod in `CrashLoopBackOff`:**
```bash
# Check logs
kubectl logs <pod-name> -n glance-system --previous

# Common causes:
# - Application error → Fix code/config
# - Missing env vars → Check ConfigMap/Secret
# - Permission denied → Check security context
```

**Service not reachable:**
```bash
# Check endpoints
kubectl get endpoints -n glance-system

# Test from another pod
kubectl run debug --rm -it --image=busybox -- wget -qO- http://glance:8080

# Check network policies
kubectl get networkpolicies -n glance-system
```

**PVC stuck in `Pending`:**
```bash
# Check storage class
kubectl get storageclass

# Check PVC events
kubectl describe pvc <pvc-name> -n glance-system

# Common causes:
# - No default storage class
# - Storage class doesn't exist
# - Insufficient storage capacity
```

---

## 14. Cleanup

### Remove from On-Premises Cluster

```bash
# Delete all resources in namespace
kubectl delete namespace glance-system

# Or delete specific resources
kubectl delete -k overlays/dev
```

### Remove from Azure

```bash
# Delete AKS cluster
az aks delete \
  --resource-group rg-glance-k8s \
  --name aks-glance \
  --yes

# Delete container registry
az acr delete \
  --resource-group rg-glance-k8s \
  --name glaboratoryhomelab \
  --yes

# Delete resource group (removes everything)
az group delete \
  --name rg-glance-k8s \
  --yes

# Verify deletion
az group list --output table
```

> **Warning**: Deleting the resource group removes ALL resources inside it, including any data in storage. Make sure you've backed up anything important.

---

## Appendix A: Quick Reference Commands

### kubectl Cheat Sheet

```bash
# Cluster info
kubectl cluster-info
kubectl get nodes

# Namespaces
kubectl get namespaces
kubectl create namespace <name>
kubectl delete namespace <name>

# Pods
kubectl get pods -n <namespace>
kubectl get pods -n <namespace> -o wide    # Show node placement
kubectl describe pod <name> -n <namespace>
kubectl logs <pod> -n <namespace>
kubectl logs <pod> -n <namespace> -f       # Follow logs
kubectl exec -it <pod> -n <namespace> -- /bin/sh

# Deployments
kubectl get deployments -n <namespace>
kubectl scale deployment <name> --replicas=3 -n <namespace>
kubectl rollout restart deployment <name> -n <namespace>
kubectl rollout status deployment <name> -n <namespace>
kubectl rollout undo deployment <name> -n <namespace>

# Services
kubectl get svc -n <namespace>
kubectl get endpoints -n <namespace>
kubectl port-forward svc/<name> 8080:8080 -n <namespace>

# ConfigMaps & Secrets
kubectl get configmap -n <namespace>
kubectl get secret -n <namespace>
kubectl create secret generic <name> --from-literal=key=value

# Apply/Delete
kubectl apply -f <file.yaml>
kubectl apply -k <directory>
kubectl delete -f <file.yaml>
kubectl delete -k <directory>
```

### Azure CLI Cheat Sheet

```bash
# Login
az login
az account list --output table
az account set --subscription <name>

# Resource Groups
az group create --name <name> --location <location>
az group list --output table
az group delete --name <name> --yes

# AKS
az aks create --resource-group <rg> --name <name> ...
az aks get-credentials --resource-group <rg> --name <name>
az aks delete --resource-group <rg> --name <name> --yes
az aks list --output table

# ACR
az acr create --resource-group <rg> --name <name> --sku Basic
az acr login --name <name>
az acr repository list --name <name>
```

---

## Appendix B: File Structure Summary

```
k8s-glance/
├── base/
│   ├── kustomization.yaml
│   ├── namespace.yaml
│   ├── ingress.yaml
│   ├── configmaps/
│   │   ├── glance-config.yaml
│   │   └── api-config.yaml
│   ├── secrets/
│   │   └── api-secrets.yaml
│   ├── deployments/
│   │   ├── glance.yaml
│   │   ├── media-stats-api.yaml
│   │   ├── reddit-manager.yaml
│   │   └── nba-stats-api.yaml
│   ├── services/
│   │   ├── glance.yaml
│   │   ├── media-stats-api.yaml
│   │   ├── reddit-manager.yaml
│   │   └── nba-stats-api.yaml
│   └── storage/
│       ├── reddit-manager-pvc.yaml
│       └── nba-stats-api-pvc.yaml
├── overlays/
│   ├── dev/
│   │   └── kustomization.yaml
│   ├── prod/
│   │   └── kustomization.yaml
│   └── azure/
│       ├── kustomization.yaml
│       └── ingress-azure.yaml
└── README.md
```

---

**Document Version**: 1.0.0
**Last Updated**: 2025-12-28
**Author**: Claude (AI Assistant)

**Next Steps**:
1. Follow the tutorial step by step
2. Deploy to on-prem cluster first
3. Experiment with scaling and updates
4. Try the Azure migration when ready
5. Set up GitOps with ArgoCD for automated deployments
