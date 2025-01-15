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

# Verify installations
echo "---- Step: Verifying installations..."
kubectl get pods --namespace $NAMESPACE

echo "Installation completed!"
echo "========================================= END OF SETUP ==========================================="
pause_or_exit

echo "=============== PROJECT PART 2 and 3: START ==================="
# Apply Prometheus alerting rules
echo "---- Step: Applying Prometheus alerting rules..."
helm upgrade --reuse-values -f prometheus-alerts-rules.yaml prometheus prometheus-community/prometheus --namespace $NAMESPACE

# Configure AlertManager
echo "Configuring AlertManager..."

# Variables nécessaires
NAMESPACE=${1:-production}              # Namespace par défaut : monitoring
ALERT_RECEIVER=${2:-ethansuissa@gmail.com}  # Email du destinataire des alertes : lazhar.hamel@efrei.fr
ALERT_SENDER=${3:-efreival@gmail.com} # Email Gmail qui envoie les alertes
SMTP_HOST=${4:-smtp.gmail.com:587}      # Serveur SMTP de Gmail
APP_PASSWORD_FILE=${5:-/etc/alertmanager/smtp_pass} # Fichier sécurisé contenant le mot de passe d'application

# Vérifier que le fichier contenant le mot de passe existe
if [ ! -f "$APP_PASSWORD_FILE" ]; then
  echo "Erreur : Le fichier contenant le mot de passe d'application Gmail ($APP_PASSWORD_FILE) est introuvable."
  exit 1
fi

# Lire le mot de passe d'application Gmail
SMTP_PASSWORD=$(sudo cat "$APP_PASSWORD_FILE")
echo "If no error, file of smtp password was successfully readed so you can continue."
pause_or_exit

# Créer le fichier `alertmanager-config.yaml`
cat <<EOF > alertmanager-config.yaml
global:
  resolve_timeout: 5m
  smtp_smarthost: '$SMTP_HOST'  # Hôte et port du serveur SMTP
  smtp_from: '$ALERT_SENDER'   # Adresse de l'expéditeur
  smtp_auth_username: '$ALERT_SENDER'  # Nom d'utilisateur SMTP (votre email)
  smtp_auth_password: '$SMTP_PASSWORD'  # Mot de passe stocké dans un fichier
  smtp_require_tls: true

route:
  receiver: 'email-alerts'  # Nom du receveur principal
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 3h

receivers:
  - name: 'email-alerts'
    email_configs:
      - to: '$ALERT_RECEIVER'  # Adresse email du destinataire
        send_resolved: true           # Notification même après résolution

templates: []  # Pas de template supplémentaire pour le moment

EOF

# Appliquer la configuration avec Helm
helm upgrade --reuse-values -f alertmanager-config.yaml prometheus prometheus-community/prometheus --namespace "$NAMESPACE"

# Nettoyage : supprimer le fichier temporaire `alertmanager-config.yaml`
rm -f alertmanager-config.yaml
echo "Configuration d'Alertmanager appliquée avec succès dans le namespace '$NAMESPACE'."
pause_or_exit

# Expose services for UI access
echo "---- Step: Exposing Prometheus and Grafana"
PROMETHEUS_POD=$(kubectl get pods --namespace $NAMESPACE -l "app.kubernetes.io/name=prometheus,app.kubernetes.io/instance=prometheus" -o jsonpath="{.items[0].metadata.name}")
kubectl --namespace $NAMESPACE port-forward $PROMETHEUS_POD 9090:9090 &

GRAFANA_POD=$(kubectl get pods --namespace $NAMESPACE -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=grafana" -o jsonpath="{.items[0].metadata.name}")
kubectl --namespace $NAMESPACE port-forward $GRAFANA_POD 3000:3000 &

echo "Configuration applied! Access Prometheus at http://localhost:9090, Grafana at http://localhost:3000"
pause_or_exit

