pipeline {
    agent any

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
    }
}
