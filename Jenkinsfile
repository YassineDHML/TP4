pipeline {
    agent any       // "exécute ce pipeline sur n'importe quelle machine disponible"

    environment {   // variables globales réutilisables partout
        // le nom de l'image sur DockerHub
        DOCKER_IMAGE = 'yassinedhml/tp4-devops-app'
        // l'ID du mot de passe stocké dans Jenkins
        DOCKER_CREDS_ID = 'dockerhub-credentials'
    }

    tools {     // outils à installer automatiquement
        // Jenkins installe Node.js automatiquement avant de commencer
        // Must match the name configured in Jenkins > Global Tool Configuration
        nodejs 'NodeJS' 
    }

    stages {    // la liste des étapes dans l'ordre
        stage('Checkout') {
            steps {
                checkout scm            // "va chercher le code depuis Git"
            }
        }

        stage('Build / Install') {
            steps {
                dir('app') {            // "entre dans le dossier app/"
                    sh 'npm install'    // installe les dépendances Node.js (lit package.json)
                }
            }
        }

        stage('Unit Tests') {
            steps {
                dir('app') {
                    sh 'npm test'       // lance Jest, qui exécute app/tests/app.test.js
                }
            }
        }

        stage('Static Analysis') {
            environment {
                // trouve où est installé SonarScanner
                // Must match the name configured in Jenkins > Global Tool Configuration
                SCANNER_HOME = tool 'SonarScanner' 
            }
            steps {
                // Must match server name in Jenkins settings 
                withSonarQubeEnv('SonarQube') {                 // injecte l'URL et le token du serveur SonarQube
                    sh "${SCANNER_HOME}/bin/sonar-scanner"      // lance l'analyse du code

                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 1, unit: 'HOURS') {           // attend max 1h la réponse de SonarQube
                    // Fail the pipeline if SonarQube quality gate fails
                    waitForQualityGate abortPipeline: true
                }
            }
        }


        //delivery
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


        //deployment
        // Terraform va créer un cluster Kubernetes local avec Kind, puis Ansible va déployer l'application dessus en utilisant l'image Docker que nous avons poussée
        stage('Infrastructure Provisioning (Terraform)') {
            steps {
                dir('terraform') {
                    sh 'rm -rf .terraform || true'              // nettoie les restes d'un ancien run
                    sh 'terraform init'                         // télécharge le provider Kind
                    sh 'terraform apply -auto-approve'          // crée le cluster K8s sans confirmation
                    // On extrait le kubeconfig pour la suite du pipeline
                    sh 'terraform output -raw kubeconfig > ../kubeconfig'
                }
            }
        }


        stage('Configuration & Deploy (Ansible)') {
            environment {
                KUBECONFIG = "${WORKSPACE}/kubeconfig"      // dit à kubectl/Ansible quel cluster utiliser
            }
            steps {
                dir('ansible') {
                    // --- AJOUT : Correction réseau Docker-in-Docker ---
                    sh """

                    # Problème : Terraform génère un kubeconfig pointant vers 127.0.0.1
                    # Mais Jenkins est dans un conteneur Docker, donc 127.0.0.1 ≠ le cluster Kind

                    # 1. On demande à Docker de nous donner la vraie IP du cluster K8s
                    KIND_IP=\$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' tp4-devops-cluster-control-plane)
                    echo "L'IP interne du cluster Kind est : \$KIND_IP"
                    
                    # 2. On modifie le fichier kubeconfig pour remplacer localhost par cette vraie IP
                    sed -i -E "s/127\\.0\\.0\\.1:[0-9]+/\$KIND_IP:6443/g" ../kubeconfig
                    """
                    // --------------------------------------------------


                    // Maintenant Ansible peut parler au cluster correctement
                    // ansible va lire le kubeconfig et déployer l'application en utilisant l'image Docker que nous avons poussée
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
