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
pause_or_exit

# Part 1: Mise à jour du système et installation des dépendances de base
echo "---- Step: Mise à jour des paquets et installation des dépendances de base"
sudo apt-get update
sudo apt-get install -y curl ca-certificates gnupg lsb-release

# Part 2: Clé publique et dépôt Docker
echo "---- Step: Ajout de la clé publique et du dépôt Docker"
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Part 3: Installation de Docker
echo "---- Step: Installation de Docker"
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker $USER
sudo systemctl start docker &
sudo systemctl enable docker &
sg docker -c "echo 'Le groupe docker est activé. Testons une commande Docker...'" && docker run hello-world

# Part 6: Mise à jour du système
echo "---- Step: Mise à jour et installation des mises à jour de sécurité"
sudo apt update && sudo apt upgrade -y

# Part 7: Installation de Minikube
echo "---- Step: Installation de Minikube"
curl -LO https://storage.googleapis.com/minikube/releases/v1.31.2/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/miniku

# Part 8: Installation de Kubernetes CLI (kubectl)
echo "---- Step: Installation de Kubernetes CLI (kubectl)"
curl -LO "https://dl.k8s.io/release/v1.28.3/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Part 9: Installation de Docker Compose
echo "---- Step: Installation de Docker Compose"
curl -SL "https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-$(uname -s)-$(uname -m)" -o docker-compose
chmod +x docker-compose
sudo mv docker-compose /usr/local/bin/docker-compose

# Ensure Minikube is started
echo "Starting Minikube..."
minikube start --driver=docker

# Part 10: Installation de Git
echo "---- Step: Installation de Git"
sudo apt install git -y

# Part 12: Installation de GitHub CLI
echo "---- Step: Installation de GitHub CLI (gh)"
type -p curl >/dev/null || sudo apt install curl -y
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install gh -y

# Part 11: Installation de Jenkins
echo "---- Step: Installation de Jenkins"
sudo docker run -d -p 8080:8080 -p 50000:50000 --name jenkins --restart unless-stopped jenkins/jenkins:lts-jdk17
echo """Mettez jenkins admin pour la suppression en ajoutant cette ligne dans sudo visudo (sert pour test pipeline) : 
echo "jenkins ALL=(ALL) NOPASSWD:/usr/bin/rm" >> /etc/sudoers
"""
sudo visudo

echo "---- Step: Installation de Buildpack"
sudo add-apt-repository ppa:cncf-buildpacks/pack-cli
sudo apt update
sudo apt install pack-cli
pack config default-builder gcr.io/buildpacks/builder:google-22

# Part 14: Vérification des installations
echo "---- Step: Vérification des installations"
docker --version            # Doit afficher Docker 24.0.7 ou supérieur
minikube version            # Doit afficher Minikube v1.31.2 ou supérieur
kubectl version --client    # Doit afficher kubectl v1.28.3 ou supérieur
docker-compose --version    # Doit afficher Docker Compose v2.23.0 ou supérieur
git --version               # Doit afficher Git 2.41.0 ou supérieur
gh --version                # Doit afficher GitHub CL


