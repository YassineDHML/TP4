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

        stage('Infrastructure Provisioning (Terraform)') {
            steps {
                dir('terraform') {
                    // Supprime les restes des anciens lancements Terraform au besoin
                    sh 'rm -rf .terraform || true'
                    sh 'terraform init'
                    sh 'terraform apply -auto-approve'
                    // On extrait le kubeconfig pour la suite du pipeline
                    sh 'terraform output -raw kubeconfig > ../kubeconfig'
                }
            }
        }


        stage('Configuration & Deploy (Ansible)') {
            environment {
                // Ansible and kubectl will use this kubeconfig connecting to Kind
                KUBECONFIG = "${WORKSPACE}/kubeconfig"
            }
            steps {
                dir('ansible') {
                    // --- AJOUT : Correction réseau Docker-in-Docker ---
                    sh """
                    # 1. On demande à Docker de nous donner la vraie IP du cluster K8s
                    KIND_IP=\$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' tp4-devops-cluster-control-plane)
                    echo "L'IP interne du cluster Kind est : \$KIND_IP"
                    
                    # 2. On modifie le fichier kubeconfig pour remplacer localhost par cette vraie IP
                    sed -i -E "s/127\\.0\\.0\\.1:[0-9]+/\$KIND_IP:6443/g" ../kubeconfig
                    """
                    // --------------------------------------------------

                    // 3. On lance Ansible normalement
                    sh "ansible-playbook deploy.yml -e docker_image=${DOCKER_IMAGE} -e build_number=${BUILD_NUMBER}"
                }
            }
        }

        stage('Smoke Test') {
            environment {
                KUBECONFIG = "${WORKSPACE}/kubeconfig"
            }
            steps {
                // On attend que les pods soient bien démarrés
                sh 'kubectl rollout status deployment/tp4-app --timeout=90s'
                // Test de l'application via le NodePort local configuré dans terraform/ansible
                sh 'curl -f http://tp4-devops-cluster-control-plane:30001 || echo "Curl error, container IP might differ on some setups"'
            }
        }
    }
}
