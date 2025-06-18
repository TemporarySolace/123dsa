#!/bin/bash
set -e

echo "Starting Kind cluster and installing full stack..."

# Resolve script path for relative path resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Step 1: Start Kind cluster
kind create cluster --name test

# Step 2: Load locally built Docker images
docker images | grep test | awk '{print $1":"$2}' | while read image; do
  kind load docker-image "$image" --name test
done

# Step 3: Add Helm repositories
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add kiali https://kiali.org/helm-charts
helm repo update

# Step 4: Install Istio base and control plane
helm install istio-base istio/base -n istio-system --create-namespace
helm install istiod istio/istiod -n istio-system
helm install main-gateway istio/gateway -n istio-system

# Step 5: Install RabbitMQ with FQDN support
echo "Installing RabbitMQ..."
helm install rabbitmq bitnami/rabbitmq \
  -n rabbitmq --create-namespace \
  -f "$PROJECT_ROOT/charts/rabbitmq/values.yaml"

# Step 6: Install Prometheus and Grafana
helm install prometheus prometheus-community/prometheus \
  -f "$PROJECT_ROOT/monitoring/prometheus/values.yaml" \
  -n istio-system --create-namespace

helm install grafana grafana/grafana \
  -f "$PROJECT_ROOT/monitoring/grafana/values.yaml" \
  -n istio-system --create-namespace

# Step 7: Deploy dashboards and telemetry config
helm upgrade --install monitoring "$PROJECT_ROOT/charts/monitoring" -n istio-system

# Step 8: Deploy application services
helm upgrade --install producer "$PROJECT_ROOT/charts/producer" -n producer --create-namespace
helm upgrade --install consumer "$PROJECT_ROOT/charts/consumer" -n consumer --create-namespace

# Step 9: Wait for all pods to be ready
echo "Waiting for pods to be ready..."
kubectl wait --for=condition=Ready pods --all --all-namespaces --timeout=300s

# Step 10: Build and load Docker images
echo "Building Docker images..."
docker build -t producer:latest "$PROJECT_ROOT/producer"
docker build -t consumer:latest "$PROJECT_ROOT/consumer"

echo "Loading images into Kind..."
kind load docker-image producer:latest --name test
kind load docker-image consumer:latest --name test

# Step 11: Apply VirtualServices
kubectl apply -f "$PROJECT_ROOT/istio/virtualservices.yaml"

# Step 12: Install Kiali
helm install kiali-server kiali/kiali-server \
  --namespace istio-system \
  --set auth.strategy="anonymous"

# Optional: Istio telemetry (if chart exists)
if [ -d "$PROJECT_ROOT/charts/istio" ]; then
  helm upgrade --install istio "$PROJECT_ROOT/charts/istio" -n istio-system
fi

# Step 13: Port forward gateway (optional for localhost access)
kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80 &

# Step 14: Run RabbitMQ E2E test
echo "Running RabbitMQ end-to-end test..."
helm install rabbitmq-test "$PROJECT_ROOT/charts/test" -n test --create-namespace

kubectl wait --for=condition=complete job/rabbitmq-e2e-test -n test --timeout=60s

echo "E2E test result:"
kubectl logs job/rabbitmq-e2e-test -n test
