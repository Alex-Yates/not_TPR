node(AgentName) {
    stage('Test1') {
    }
}



/* Jenkinsfile (Declarative Pipeline) */
/* Requires the Docker Pipeline plugin */
pipeline {
    agent { 
        /* Example provided by CM team */ 
        // docker { image 'maven:3.9.0-eclipse-temurin-11' }
        
        /* For Alex's PoC VM */
        label "builtin" 
    }
    stages {
        stage('build') {
            steps {
                sh 'mvn --version'
            }
        }
    }
}