# Service Mesh Deliverables (Istio)

This document provides a comprehensive guide to the Service Mesh implementation for the Spring PetClinic Microservices on Kubernetes.

## 1. Configuration: mTLS & Authorization Policy

We have implemented a **Zero Trust** security model using Istio.

### mTLS Configuration
**File**: `templates/peer-authentication.yaml`
- **Default Policy**: `STRICT` mTLS integration mesh-wide.
- **Exceptions**: `PERMISSIVE` mode for specific ports (8080, 8888) on `api-gateway` and `config-server` to allow external or non-mesh traffic where necessary, scoped via `selector`.

### Authorization Policy
**File**: `templates/authorization-policies.yaml`
- **Default Deny**: A catch-all policy blocks all service-to-service communication by default.
- **Allowed Rules**: explicit `ALLOW` policies grant access based on `ServiceAccount` identities (principals).
    - `api-gateway` &#8594; `customers`, `vets`, `visits`, `genai`
    - `genai-service` &#8594; `vets-service`
    - All &#8594; `config-server`

## 2. Observability: Kiali Topology

*(Place your Kiali Topology Screenshot here)*
> **Screenshot Explanation**:
> The Kiali graph visualizes the mesh traffic. You should see directional arrows from `api-gateway` to the backend services. 
> - **Green lines**: Successful mTLS connections.
> - **Lock icon**: Indicates traffic is encrypted (mTLS).
> - **Red lines (if testing denied paths)**: Blocked traffic due to Authorization Policy.

## 3. Test Plan & Logs

### 3.1. Connectivity & Authorization Test
**Objective**: Verify that allowed paths work and disallowed paths are blocked.

**Test Commands:**
```bash
# 1. Allowed Path: api-gateway -> customers
kubectl exec -n petclinic deploy/api-gateway -- curl -s -o /dev/null -w "%{http_code}" http://customers-service:8081/owners/1
# Result: 200 (OK)

# 2. Denied Path: visits-service -> customers
kubectl exec -n petclinic deploy/visits-service -- curl -s -o /dev/null -w "%{http_code}" http://customers-service:8081/owners/1
# Result: 403 (Forbidden)
```

### 3.2. Retry Policy Evidence
**Objective**: Verify that the system automatically retries on 5xx errors.
**Configuration**: `templates/virtual-services.yaml` (Retry 3 times on 5xx).

**Test Procedure (Fault Injection):**
1.  Temporarily inject 50% fault in `customers-service`:
    ```yaml
    http:
      - fault:
          abort:
            httpStatus: 500
            percentage:
              value: 50
    ```
2.  Make repeated requests. Istio will retry failures transparently.
    ```bash
    for i in {1..10}; do kubectl exec -n petclinic deploy/api-gateway -- curl -s -I http://customers-service:8081/owners/1 | head -n 1; done
    ```
3.  **Logs**: Inspect `api-gateway` sidecar logs to see multiple attempts for a single request.

## 4. Deployment Guide

### Step 1: Deploy/Update Helm Chart
Apply the changes to the cluster.
```bash
helm upgrade --install petclinic . -f values-staging.yaml
# OR via ArgoCD
argocd app sync petclinic
```

### Step 2: Verify Resources
Ensure all Istio resources are created:
```bash
kubectl get virtualservices,peerauthentications,authorizationpolicies -n petclinic
```

### Step 3: Verify Pods & Sidecars
Ensure all pods are running (2/2 containers, indicating sidecar injection).
```bash
kubectl get pods -n petclinic
```

### Step 4: Run Verification
Execute the test commands in **Section 3** to validate the implementation.
