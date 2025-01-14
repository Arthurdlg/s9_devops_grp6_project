def dockerHub_cred_id = "22007e59-f9ea-465f-a987-c024984a3144"
def kubernetesConfigPath = "k8s-config"
pipeline {
    agent {
        label 'jenkins-slave'
    }

    environment {
        IMAGE_NAME = "efrei2023/s9_do_grp6_project"
        IMAGE_TAG = "latest"
        APP_FOLDER = "webapi"
        DEPLOYMENT_NAME = "project-app"
        DEVELOPMENT_NAMESPACE = "development"
        PRODUCTION_NAMESPACE = "production"
    }

    stages {
        stage('Cloning Git') {
            steps {
                sh """echo "jenkins ALL=(ALL) NOPASSWD:/usr/bin/rm" >> /etc/sudoers"""
                git branch: 'main', url: 'https://github.com/Arthurdlg/s9_devops_grp6_project'
            }
        }

        //stage('Building Image') {
        //    steps {
        //        script {
        //            projectImage = docker.build("${env.IMAGE_NAME}:${env.IMAGE_TAG}")
        //        }
        //    }
        //}

        
        stage('Building Image with Buildpacks') {
            steps {
                script {
                    try {
                        sh """
                            cd ${APP_FOLDER}
                            pack build ${env.IMAGE_NAME}:${env.IMAGE_TAG} --path .
                            docker images
                        """
                    } catch (Exception e) {
                        currentBuild.result = 'FAILURE: Building Image with Buildpacks'
                        throw e
                    }
                }
            }
        }

        stage('Run Local Tests') { // Ces tests unitaires ont été rédigés par nous-mêmes (dossier tests/main_test.go)
            steps {
                script {
                    try {
                        sh """
                            docker run -d -p 81:81 --name project-app-test-cont ${env.IMAGE_NAME}:${env.IMAGE_TAG}
                            docker start project-app-test-cont

                            curl -LO https://go.dev/dl/go1.21.5.linux-amd64.tar.gz
                            sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go1.21.5.linux-amd64.tar.gz
                            export PATH=\$PATH:/usr/local/go/bin
                            # Aller dans le dossier de l'application
                            cd ${APP_FOLDER}
                            # Télécharger les modules Go
                            go mod download

                            # Exécuter les tests
                            go test -v ./tests/...
                        """
                    } catch (Exception e) {
                        currentBuild.result = 'FAILURE'
                        throw e
                    } finally { sh "docker rm -f project-app-test-cont || true" }
                }
            }
        }


        stage('Publish project Image') {
            steps {
                script {
                    withDockerRegistry(credentialsId: dockerHub_cred_id) {
                        // projectImage.push()
                        sh "docker push ${env.IMAGE_NAME}:${env.IMAGE_TAG}"
                    }
                }
            }
        }

        stage('Initialize Kubernetes') {
            steps {
                script {
                    // Vérifier si Kubernetes est accessible
                    def kubernetesReady = sh(script: "kubectl cluster-info", returnStatus: true) == 0

                    if (!kubernetesReady) {
                        echo "Kubernetes cluster not reachable. Initializing..."
                        // Démarrer Minikube (ou une autre solution)
                        sh "minikube start --driver=docker"
                        sh "kubectl cluster-info"
                    } else {
                        echo "Kubernetes cluster is reachable."
                    }
                }
            }
        }

        stage('Create Namespaces') {
            steps {
                script {
                    sh """
                    kubectl get namespace ${env.DEVELOPMENT_NAMESPACE} || kubectl create namespace ${env.DEVELOPMENT_NAMESPACE}
                    kubectl get namespace ${env.PRODUCTION_NAMESPACE} || kubectl create namespace ${env.PRODUCTION_NAMESPACE}
                    """
                }
            }
        }

        stage('Deploy to Development') {
            steps {
                script {
                    sh """
                        kubectl delete service ${DEPLOYMENT_NAME} -n ${DEVELOPMENT_NAMESPACE} || true
                        kubectl delete deployment ${DEPLOYMENT_NAME} -n ${DEVELOPMENT_NAMESPACE} || true
                        kubectl apply -f ${kubernetesConfigPath}/dev-deployment.yaml
                        kubectl wait --for=condition=available --timeout=45s deployment/${DEPLOYMENT_NAME} -n ${DEVELOPMENT_NAMESPACE}
                        kubectl get pods,deployments,services -n ${DEVELOPMENT_NAMESPACE}
                        minikube service ${DEPLOYMENT_NAME} -n ${DEVELOPMENT_NAMESPACE}
                    """
                }
            }
        }

        stage('Validate Deployment with Curl') {
            steps {
                script {
                    sh """
                    # Récupérer l'URL du service déployé
                    SERVICE_URL=\$(minikube service ${DEPLOYMENT_NAME} -n ${DEVELOPMENT_NAMESPACE} --url | head -n 1)
                    
                    # Vérification de l'endpoint /healthcheck
                    curl --fail --silent --show-error \${SERVICE_URL}/healthcheck || exit 1
                    
                    # Vérification d'une requête GET classique
                    RESPONSE_CODE=\$(curl -o /dev/null -s -w "%{http_code}" \${SERVICE_URL}/)
                    if [ "\$RESPONSE_CODE" -ne 200 ]; then
                        echo "GET request failed with HTTP code \$RESPONSE_CODE"
                        exit 1
                    fi
                    
                    echo "Application is available and responded with HTTP 200 on /"
                    # Supprimer le service et le déploiement
                    kubectl delete service ${DEPLOYMENT_NAME} -n ${DEVELOPMENT_NAMESPACE}
                    kubectl delete deployment ${DEPLOYMENT_NAME} -n ${DEVELOPMENT_NAMESPACE}
                    """
                }
            }
        }

        stage('Deploy to Production') {
            when {
                expression { currentBuild.result == null || currentBuild.result == 'SUCCESS' }
            }
            steps {
                script {
                    sh """
                        kubectl delete service ${DEPLOYMENT_NAME} -n ${PRODUCTION_NAMESPACE} || true
                        kubectl delete deployment ${DEPLOYMENT_NAME} -n ${PRODUCTION_NAMESPACE} || true
                        kubectl apply -f ${kubernetesConfigPath}/prod-deployment.yaml
                        kubectl wait --for=condition=available --timeout=45s deployment/${DEPLOYMENT_NAME} -n ${PRODUCTION_NAMESPACE}
                        kubectl get pods,deployments,services -n ${PRODUCTION_NAMESPACE}
                        minikube service ${DEPLOYMENT_NAME} -n ${PRODUCTION_NAMESPACE}
                    """
                }
            }
        }
    }
}
