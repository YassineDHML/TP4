pipeline {
    agent any

    environment {
        // ID de l'image (à adapter si besoin)
        DOCKER_IMAGE = 'yassinedhml/tp4-devops-app'
        // Identifiant du Credential stocké dans Jenkins
        DOCKER_CREDS_ID = 'dockerhub-credentials'
    }

    tools {
        // Must match the name configured in Jenkins > Global Tool Configuration
        nodejs 'NodeJS' 
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build / Install') {
            steps {
                dir('app') {
                    sh 'npm install'
                }
            }
        }

        stage('Unit Tests') {
            steps {
                dir('app') {
                    sh 'npm test'
                }
            }
        }

        stage('Static Analysis') {
            environment {
                // Must match the name configured in Jenkins > Global Tool Configuration
                SCANNER_HOME = tool 'SonarScanner' 
            }
            steps {
                withSonarQubeEnv('SonarQube') { // Must match server name in Jenkins settings
                    sh "${SCANNER_HOME}/bin/sonar-scanner"
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 1, unit: 'HOURS') {
                    // Fail the pipeline if SonarQube quality gate fails
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Docker Build') {
            steps {
                sh "docker build -t ${DOCKER_IMAGE}:${BUILD_NUMBER} -f Dockerfile ."
            }
        }

        stage('Image Scanning') {
            steps {
                // Utilise le conteneur Trivy pour scanner l'image construite
                // --exit-code 0 permet de ne pas faire échouer le pipeline pour la démo, changez à 1 pour être strict.
                sh "docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:latest image --no-progress --severity HIGH,CRITICAL ${DOCKER_IMAGE}:${BUILD_NUMBER}"
            }
        }

        stage('Docker Push') {
            steps {
                withCredentials([usernamePassword(credentialsId: env.DOCKER_CREDS_ID, passwordVariable: 'DOCKER_PASSWORD', usernameVariable: 'DOCKER_USERNAME')]) {
                    sh "echo \$DOCKER_PASSWORD | docker login -u \$DOCKER_USERNAME --password-stdin"
                    sh "docker push ${DOCKER_IMAGE}:${BUILD_NUMBER}"
                    // (Optionnel) Tagger et pousser en tant que latest
                    sh "docker tag ${DOCKER_IMAGE}:${BUILD_NUMBER} ${DOCKER_IMAGE}:latest"
                    sh "docker push ${DOCKER_IMAGE}:latest"
                }
            }
        }
    }
}
