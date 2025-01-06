def dockerHub_cred_id = "22007e59-f9ea-465f-a987-c024984a3144"
def kubernetesConfigPath = "k8s-config"
pipeline {
    agent {
        label 'jenkins-slave-project'
    }

    environment {
        IMAGE_NAME = "efrei2023/s9_do_grp6_project"
        IMAGE_TAG = "latest"
        DEVELOPMENT_NAMESPACE = "development"
        PRODUCTION_NAMESPACE = "production"
    }

    stages {
        stage('Cloning Git') {
            steps {
                git branch: 'main', url: 'https://github.com/Arthurdlg/s9_devops_grp6_project'
            }
        }

        stage('Building Image') {
            steps {
                script {
                    projectImage = docker.build("${env.IMAGE_NAME}:${env.IMAGE_TAG}")
                }
            }
        }

        stage('Publish project Image') {
            steps {
                script {
                    withDockerRegistry(credentialsId: dockerHub_cred_id) {
                        projectImage.push()
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
                    kubectl apply -f ${kubernetesConfigPath}/dev-deployment.yaml
                    kubectl apply -f ${kubernetesConfigPath}/dev-service.yaml
                    """
                }
            }
        }

        stage('Run Tests') {
            steps {
                script {
                    try {
                        sh '''
                        kubectl run test-runner \
                          --namespace=development \
                          --image=golang:1.21 \
                          --rm -it \
                          --restart=Never \
                          --timeout=200s \
                          -- bash -c "
                            mkdir -p /app/webapi/tests &&
                            mkdir -p /app/webapi &&
                            cp -r * /app/webapi &&
                            cd /app/webapi/tests &&
                            go test -v ./...
                          "
                        '''
                    } catch (Exception e) {
                        error "Tests failed: ${e.message}"
                    }
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
                    kubectl apply -f ${kubernetesConfigPath}/prod-deployment.yaml
                    kubectl apply -f ${kubernetesConfigPath}/prod-service.yaml
                    """
                }
            }
        }
    }
}
