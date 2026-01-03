#!/bin/bash
# Verify Retries via Fault Injection

NS="petclinic"
echo "Testing Retries..."
# We expect 200 OK because Istio should retry the 500s.
# If you see 500s, it means retries were exhausted or not working.
# Check Sidecar logs to confirm mutiple attempts.

for i in {1..10}; do
  echo "Request $i:"
  # Call via api-gateway
  kubectl exec -n $NS $(kubectl get pod -l app=api-gateway -n $NS -o jsonpath="{.items[0].metadata.name}") -- curl -s -I http://customers-service:8081/owners/1 | head -n 1
done
