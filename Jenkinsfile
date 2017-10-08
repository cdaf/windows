node {

  properties(
    [
      [
        $class: 'BuildDiscarderProperty',
        strategy: [$class: 'LogRotator', numToKeepStr: '10']
      ],
        pipelineTriggers([cron('30 08 * * *')]),
    ]
  )

  try {

    stage ('Test the CDAF sample Vagrantfile') {

      checkout scm
  
      bat "cat Jenkinsfile"
      bat "cat Vagrantfile"
      bat "cat automation/CDAF.windows | grep productVersion"

      bat "IF EXIST .vagrant vagrant destroy -f"
      bat "IF EXIST .vagrant vagrant box list"
      bat "vagrant up"
    }

  } catch (e) {
    
    currentBuild.result = "FAILED"
    println currentBuild.result
    notifyFailed()
    throw e

  } finally {

    stage ('Destroy VMs and Discard sample vagrantfile') {
      bat "IF EXIST .vagrant vagrant destroy -f"
    }
  }
}

def notifyFailed() {

  emailext (
    to: "jenkins@SP1.hdc.webhop.net",
    subject: "Jenkins Job [${env.JOB_NAME}] Build [${env.BUILD_NUMBER}] failure",
    body: "Check console output at ${env.BUILD_URL}"
  )

  emailext (
    recipientProviders: [[$class: 'DevelopersRecipientProvider']],
    subject: "Jenkins Job [${env.JOB_NAME}] Build [${env.BUILD_NUMBER}] failure",
    body: "Check console output at ${env.BUILD_URL}"
  )
}