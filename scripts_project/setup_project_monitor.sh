#!/bin/bash
source ./utils.sh

echo "========================================= SETUP FOR PROJECT ==========================================="
echo "================ A) Importations for all parts ================="
echo "---- Step: verify importations"
# Vérification que la variable NAMESPACE est définie
if [[ -z "${NAMESPACE+x}" ]]; then
    echo "Erreur : la variable NAMESPACE n'a pas été importée depuis common.sh."
    exit 1
fi

# Vérification que la fonction pause_or_exit est définie
if ! declare -f pause_or_exit > /dev/null; then
    echo "Erreur : la fonction pause_or_exit n'a pas été importée depuis common.sh."
    exit 1
fi

# Si tout est correctement importé, exécuter le reste du script
echo "Namespace utilisé : $NAMESPACE"
echo "----- Tout est correctement importé."

echo "================ B) Importations for parts 2 and 3 ================="
# Create namespace for production
kubectl create namespace $NAMESPACE || echo "Namespace $NAMESPACE already exists"
# kubectl config set-context --current --namespace=$NAMESPACE

# Add Helm repositories
echo "---- Step: Adding Helm repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Prometheus
echo "---- Step: Installing Prometheus..."
helm install prometheus prometheus-community/prometheus --namespace $NAMESPACE

# Install Grafana
echo "---- Step: Installing Grafana..."
helm install grafana grafana/grafana --namespace $NAMESPACE --set adminPassword=admin

# Install Loki
echo "---- Step: Installing Loki..."
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

# Verify installations
echo "---- Step: Verifying installations..."
kubectl get pods --namespace $NAMESPACE

echo "Installation completed!"
echo "========================================= END OF SETUP ==========================================="
pause_or_exit