node {

  properties(
    [
      [
        $class: 'BuildDiscarderProperty',
        strategy: [$class: 'LogRotator', numToKeepStr: '10']
      ],
        pipelineTriggers([cron('15 07 * * *')]),
    ]
  )

  try {

    stage ('Test the CDAF sample on Windows Server 2019') {

      checkout scm
  
      bat 'type Jenkinsfile'
      bat 'type Vagrantfile'
      bat 'type automation\\CDAF.windows | findstr "productVersion"'

      bat 'IF EXIST .vagrant vagrant destroy -f'
      bat 'IF EXIST .vagrant vagrant box list'
      bat 'vagrant up'
    }

    stage ('Test the CDAF sample on Windows Server 2016') {
      bat 'vagrant destroy -f'
      bat '''
      	SET OVERRIDE_IMAGE=cdaf/WindowsServer
      	vagrant up
      '''
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
    recipientProviders: [[$class: 'DevelopersRecipientProvider']],
    subject: "Jenkins Job [${env.JOB_NAME}] Build [${env.BUILD_NUMBER}] failure",
    body: "Check console output at ${env.BUILD_URL}"
  )

  if (env.DEFAULT_NOTIFICATION) {
    emailext (
      to: "${env.DEFAULT_NOTIFICATION}",
      subject: "Jenkins Default FAILURE Notification for [${env.JOB_NAME}] Build [${env.BUILD_NUMBER}]",
      body: "Check console output at ${env.BUILD_URL}"
    )
  }

}