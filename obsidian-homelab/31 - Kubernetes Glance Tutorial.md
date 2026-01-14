# Kubernetes Glance Tutorial

> Deploying Glance dashboard on Kubernetes cluster.

Related: [[04 - Kubernetes Cluster]] | [[23 - Glance Dashboard]] | [[26 - Tutorials Index]]

---

## Overview

This tutorial covers deploying Glance dashboard on a Kubernetes cluster as an alternative to Docker Compose deployment.

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  Namespace: glance                                       │    │
│  │                                                          │    │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │    │
│  │  │ Deployment   │  │ ConfigMap    │  │   Service    │   │    │
│  │  │ glance       │  │ glance.yml   │  │ ClusterIP    │   │    │
│  │  └──────────────┘  └──────────────┘  └──────────────┘   │    │
│  │                                                          │    │
│  │  ┌──────────────┐                                        │    │
│  │  │   Ingress    │  → External access via Traefik        │    │
│  │  └──────────────┘                                        │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

- Kubernetes cluster running (see [[04 - Kubernetes Cluster]])
- kubectl configured
- Ingress controller (Traefik or NGINX)
- Persistent storage for config

---

## Deployment Manifests

### Namespace

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: glance
```

### ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: glance-config
  namespace: glance
data:
  glance.yml: |
    server:
      port: 8080
    pages:
      - name: Home
        columns:
          - size: full
            widgets:
              - type: monitor
                title: Services
                sites:
                  - title: Proxmox
                    url: https://192.168.20.20:8006
                    allow-insecure: true
```

### Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: glance
  namespace: glance
spec:
  replicas: 1
  selector:
    matchLabels:
      app: glance
  template:
    metadata:
      labels:
        app: glance
    spec:
      containers:
      - name: glance
        image: glanceapp/glance:latest
        ports:
        - containerPort: 8080
        volumeMounts:
        - name: config
          mountPath: /app/glance.yml
          subPath: glance.yml
      volumes:
      - name: config
        configMap:
          name: glance-config
```

### Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: glance
  namespace: glance
spec:
  selector:
    app: glance
  ports:
  - port: 8080
    targetPort: 8080
  type: ClusterIP
```

### Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: glance
  namespace: glance
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
spec:
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

---

## Apply Manifests

```bash
kubectl apply -f namespace.yaml
kubectl apply -f configmap.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f ingress.yaml

# Verify
kubectl get all -n glance
```

---

## Current Status

> **Note**: Glance is currently deployed on LXC 200 (192.168.40.12) using Docker Compose for simplicity. Kubernetes deployment is available for future scalability needs.

---

## Full Tutorial

For complete implementation details:
- **GitHub**: `docs/KUBERNETES_GLANCE_TUTORIAL.md`

---

## Related Documentation

- [[04 - Kubernetes Cluster]] - K8s cluster details
- [[23 - Glance Dashboard]] - Current Glance setup
- [[30 - LXC Migration Tutorial]] - Alternative LXC deployment
