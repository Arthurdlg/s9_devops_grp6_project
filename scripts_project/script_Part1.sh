#!/bin/bash

source ./utils.sh

echo "=============== PROJECT PART 1: START ==================="
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

echo "---- Step: Récupération du mot de passe initial de Jenkins"
sleep 3  # Attendre que Jenkins démarre
JENKINS_URL="http://localhost:8080"
JENKINS_PASS=$(docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword)
JENKINS_CRUMB=$(curl -s --user "admin:$JENKINS_PASS" "$JENKINS_URL/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,\":\",//crumb)")
echo "MDP admin à entrer dans Jenkins: $JENKINS_PASS"

# Étape 3 : Créer un réseau Docker
echo "---- Step: Créer un réseau Docker pour l'infrastructure"
docker network create --driver bridge devops_project || echo "Le réseau 'devops_project' existe déjà."

# Arrêter et supprimer tous les conteneurs sauf ceux spécifiés
docker stop s9-do_grp6-project:1 || true
docker rm   s9-do_grp6-project:1 || true
docker rmi s9-do_grp6-project:1 || true

# Exécuter les actions selon l'option choisie
echo "---- Step: Lancement de la pipeline"
DIR_FOR_AGENT="/home/ethor/Documents/S9_DevOps_project" # TO_DEFINED

# Run de l'agent jenkins-slave
sudo apt install openjdk-21-jre-headless -y

read -p "Un agent Jenkins est déjà installé. Voulez-vous le réinstaller ? [Y/n: default=Y]: " choice_download_agent
choice_download_agent=${choice_download_agent:-Y}  # Défaut à "Y" si aucune entrée
if [[ "$choice_download_agent" =~ ^[Yy]$ ]]; then
	# Vérifier si l'agent est déjà téléchargé
	# Téléchargement de la dernière version de l'agent Jenkins
	if [ -f "$DIR_FOR_AGENT/agent.jar" ]; then
	    echo "Suppression de l'agent Jenkins existant pour forcer le téléchargement de la dernière version..."
	    rm "$DIR_FOR_AGENT/agent.jar"
	fi
	echo "Téléchargement de la dernière version de l'agent Jenkins..."
	curl -sO http://localhost:8080/jnlpJars/agent.jar
else
	echo "Utilisation de l'agent déjà téléchargé"
fi

echo "Lancement de l'agent Jenkins..."
# Vérifier si l'agent Jenkins est déjà en cours d'exécution
if pgrep -f "java -jar agent.jar" > /dev/null; then
	# Demander à l'utilisateur s'il souhaite arrêter l'agent
	read -p "Un agent Jenkins est déjà en cours d'exécution. Voulez-vous l'arrêter et le redémarrer ? [Y/n: default=Y]: " user_input
	user_input=${user_input:-Y}  # Défaut à "Y" si aucune entrée

	if [[ "$user_input" =~ ^[Yy]$ ]]; then
	    echo "Arrêt de l'agent Jenkins en cours..."
	    pkill -f "java -jar agent.jar"
	    sleep 3  # Petite pause pour garantir l'arrêt complet du processus

	    # Lancer une nouvelle instance de l'agent Jenkins
	    java -jar agent.jar -url http://localhost:8080/ -secret e93e2fd05838ab381f00107b69a4b64d09776eea014069f03ba1b6edf06e3960 \
-name "jenkins-slave" -webSocket -workDir "$DIR_FOR_AGENT" &
	    sleep 5
	else
	    echo "L'agent en cours d'exécution ne sera pas arrêté ni redémarré. Continuation du script."
	fi
else
	# Aucun agent en cours, lancer une nouvelle instance
	echo "Aucun agent en cours, lancement d'une nouvelle instance"
	java -jar agent.jar -url http://localhost:8080/ -secret e93e2fd05838ab381f00107b69a4b64d09776eea014069f03ba1b6edf06e3960 \
-name "jenkins-slave" -webSocket -workDir "$DIR_FOR_AGENT" &
	sleep 5
fi

# Run de la pipeline
echo "Lancement de la pipeline..."
JOB_NAME="DevOps_project_pipeline" # Nom du job Jenkins # TO_DEFINED
TOKEN_NAME="e93e2fd05838ab381f00107b69a4b64d09776eea014069f03ba1b6edf06e3961" # Jeton d'authentification pour la pipeline # TO_DEFINED
curl -u "admin:$JENKINS_PASS" -H ".crumb:$JENKINS_CRUMB" "$JENKINS_URL/job/$JOB_NAME/build?token=$TOKEN_NAME" # -X POST
sleep 20

# Fin du script
echo "Script terminé. S'il n'y a pas d'erreurs visibles, accédez à http://localhost:8081 pour voir l'application."
echo "=============== PROJECT PART 1: END ==================="