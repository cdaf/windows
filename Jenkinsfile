timeout(time: 80, unit: 'MINUTES') {
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

      stage ('Prepare Workspace') {

        checkout scm

        powershell '''
          Write-Host "`nList Jenkinsfile`n"
          Get-Content Jenkinsfile

          Write-Host "`nList Vagrantfile`n"
          Get-Content Vagrantfile

          Write-Host "`nList CDAF Product Version`n"
          Get-Content automation\\CDAF.windows | findstr "productVersion"

          Write-Host "`nCopy solution to workspace`n"
          if ( Test-Path solution ) { Remove-Item -Recurse solution }
          Copy-Item -Recurse automation\\solution solution
          if ( Test-Path solution\\CDAF.solution ) {
            Get-Content solution\\CDAF.solution
          } else {
            exit 8833
          }
        '''
      }

      stage ('Test the CDAF sample on Windows Server 2019') {
    
        bat '''
          IF EXIST .vagrant vagrant destroy -f & verify >nul
          IF EXIST .vagrant vagrant box list & verify >nul
          vagrant up
          vagrant destroy -f
        '''
      }

      stage ('Test the CDAF sample on Windows Server 2016') {
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
