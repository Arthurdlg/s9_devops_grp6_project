def dockerHub_cred_id = ''
pipeline {

  agent {
    label 'jenkins-slave'
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
	  projectImage = docker.build("dlgart/s9_do_grp6_project:latest")
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
	  

    stage('Deploy project container') {
      steps {
      	echo "Stopping and removing existing project container if it exists"
      	sh """
      		docker stop main_project || true
      		docker rm main_project || true
      	"""
        echo "Running project container"
	sh """
		docker run -p 8081:80 --name main_project dlgart/s9_do_grp6_project:1
	"""
      }
    }
	  
  }
}
