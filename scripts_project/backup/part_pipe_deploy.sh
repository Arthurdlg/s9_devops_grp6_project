DEPLOYMENT_NAME="project-app"
DEVELOPMENT_NAMESPACE="development"
kubernetesConfigPath="."

kubectl delete service ${DEPLOYMENT_NAME} -n ${DEVELOPMENT_NAMESPACE} || true
kubectl delete deployment ${DEPLOYMENT_NAME} -n ${DEVELOPMENT_NAMESPACE} || true
kubectl apply -f ${kubernetesConfigPath}/dev-deployment.yaml
kubectl wait --for=condition=available --timeout=45s deployment/${DEPLOYMENT_NAME} -n ${DEVELOPMENT_NAMESPACE}
kubectl get pods,deployments,services -n ${DEVELOPMENT_NAMESPACE}
minikube service ${DEPLOYMENT_NAME} -n ${DEVELOPMENT_NAMESPACE}

