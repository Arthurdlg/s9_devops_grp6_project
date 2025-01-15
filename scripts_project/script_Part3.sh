#!/bin/bash

# Charger les fonctions utilitaires
source ./utils.sh

# Vérification que la fonction pause_or_exit est définie
if ! declare -f pause_or_exit > /dev/null; then
    echo "Erreur : la fonction pause_or_exit n'a pas été importée depuis common.sh."
    exit 1
fi

# Si tout est correctement importé, exécuter le reste du script
echo "----- Tout est correctement importé."

# Début du script
echo "================= Début du script: script_Part3.sh ========================"
NAMESPACE_LOKI="grafana-loki"

# Étape 1: Ajouter le dépôt Helm pour Grafana
echo "Ajout du dépôt Helm pour Grafana..."
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
echo "Dépôt Grafana ajouté et mis à jour."

# Étape 2: Générer le fichier loki-custom-values.yaml avec le contenu personnalisé
echo "Génération du fichier de configuration 'loki-custom-values.yaml'..."
# helm show values grafana/loki-stack > loki-custom-values.yaml # Sert pour la template par défaut qu'on a aménagé.
cat <<EOF > loki-custom-values.yaml
test_pod:
  enabled: true
  image: bats/bats:1.8.2
  pullPolicy: IfNotPresent

loki:
  enabled: true
  isDefault: true
  url: http://{{ (include "loki.serviceName" .) }}:{{ .Values.loki.service.port }}
  readinessProbe:
    httpGet:
      path: /ready
      port: http-metrics
    initialDelaySeconds: 45
  livenessProbe:
    httpGet:
      path: /ready
      port: http-metrics
    initialDelaySeconds: 45
  datasource:
    jsonData: "{}"
    uid: ""

promtail:
  enabled: true
  config:
    logLevel: info
    serverPort: 3101
    clients:
      - url: http://{{ .Release.Name }}:3100/loki/api/v1/push
    scrape_configs:
      - job_name: kubernetes-logs
        kubernetes_sd_configs:
          - role: pod
        relabel_configs:
          # Relabel to capture only logs from the namespace "production"
          - source_labels: [__meta_kubernetes_namespace]
            action: keep
            regex: production
          # Add labels to the logs for easier querying in Grafana
          - source_labels: [__meta_kubernetes_pod_name]
            target_label: pod
          - source_labels: [__meta_kubernetes_namespace]
            target_label: namespace
          - source_labels: [__meta_kubernetes_container_name]
            target_label: container

fluent-bit:
  enabled: false

grafana:
  enabled: true
  sidecar:
    datasources:
      label: ""
      labelValue: ""
      enabled: true
      maxLines: 1000
  image:
    tag: 10.2.5
  service:
    type: NodePort

prometheus:
  enabled: false
  isDefault: false
  url: http://{{ include "prometheus.fullname" .}}:{{ .Values.prometheus.server.service.servicePort }}{{ .Values.prometheus.server.prefixURL }}
  datasource:
    jsonData: "{}"

filebeat:
  enabled: false

logstash:
  enabled: false

proxy:
  http_proxy: ""
  https_proxy: ""
  no_proxy: ""
EOF
echo "Fichier 'loki-custom-values.yaml' généré avec succès."

# Étape 3: Installer ou mettre à jour Loki Stack
# Cette commande Helm utilisera le fichier de configuration généré précédemment.
echo "Installation/Mise à jour de Loki Stack avec le fichier 'loki-custom-values.yaml'..."
helm upgrade --install --values loki-custom-values.yaml loki grafana/loki-stack -n $NAMESPACE_LOKI --create-namespace --set loki.auth_enabled=false
echo "Loki Stack installé/mis à jour avec succès."

# Étape 4: Vérifier les pods déployés dans le namespace '$NAMESPACE_LOKI'
echo "Liste des pods dans le namespace '$NAMESPACE_LOKI'..."
kubectl get pods -n $NAMESPACE_LOKI

# Étape 5: Récupérer les informations nécessaires pour Grafana
echo "Récupération des informations Grafana..."
NODE_PORT=$(kubectl get svc loki-grafana -n $NAMESPACE_LOKI -o jsonpath="{.spec.ports[0].nodePort}")
ADMIN_USER=$(kubectl get secret loki-grafana -n $NAMESPACE_LOKI -o jsonpath="{.data.admin-user}" | base64 --decode)
ADMIN_PASSWORD=$(kubectl get secret loki-grafana -n $NAMESPACE_LOKI -o jsonpath="{.data.admin-password}" | base64 --decode)
echo "NodePort Grafana: $NODE_PORT"
echo "Admin User Grafana: $ADMIN_USER"
echo "Admin Password Grafana: $ADMIN_PASSWORD"

# Fin du script
echo "=== Fin du script ==="

