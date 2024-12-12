#!/bin/bash

# Namespace for monitoring
NAMESPACE="monitoring"

pause_or_exit() {
    echo "Appuyez sur une touche pour continuer ou tapez 'out' pour quitter."
    read -r -n 3 input
    if [[ "$input" == "out" ]]; then
        echo "Sortie du script."
        exit 0
    fi
}

# Ensure Minikube is started
echo "Starting Minikube..."
minikube start --driver=docker

# Create namespace for monitoring
kubectl create namespace $NAMESPACE

# Add Helm repositories
echo "Adding Helm repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Prometheus
echo "Installing Prometheus..."
helm install prometheus prometheus-community/prometheus --namespace $NAMESPACE

# Install Grafana
echo "Installing Grafana..."
helm install grafana grafana/grafana --namespace $NAMESPACE --set adminPassword=admin

# Install Loki
echo "Installing Loki..."
cat <<EOF > loki-values.yaml
loki:
  auth_enabled: false  # Ajout ici pour désactiver le mode multitenant
  commonConfig:
    replication_factor: 1
  schemaConfig:
    configs:
      - from: "2024-04-01"
        store: tsdb
        object_store: s3
        schema: v13
        index:
          prefix: loki_index_
          period: 24h
  pattern_ingester:
      enabled: true
  limits_config:
    allow_structured_metadata: true
    volume_enabled: true
    retention_period: 672h # 28 days retention
  compactor:
    retention_enabled: true
    delete_request_store: s3
  ruler:
    enable_api: true

minio:
  enabled: true

deploymentMode: SingleBinary

singleBinary:
  replicas: 1

# Zero out replica counts of other deployment modes
backend:
  replicas: 0
read:
  replicas: 0
write:
  replicas: 0

ingester:
  replicas: 0
querier:
  replicas: 0
queryFrontend:
  replicas: 0
queryScheduler:
  replicas: 0
distributor:
  replicas: 0
compactor:
  replicas: 0
indexGateway:
  replicas: 0
bloomCompactor:
  replicas: 0
bloomGateway:
  replicas: 0
EOF

helm install loki grafana/loki -f loki-values.yaml --namespace $NAMESPACE

kubectl port-forward --namespace monitoring svc/loki-gateway 3100:80
# Verify installations
echo "Verifying installations..."
kubectl get pods --namespace $NAMESPACE

echo "Installation completed!"
pause_or_exit