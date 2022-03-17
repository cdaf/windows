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
          Get-ChildItem -Recurse solution
          Get-Content solution\\CDAF.solution
        '''
      }

      stage ('Test the CDAF sample on Windows Server 2019') {
    
        bat '''
          type Jenkinsfile
          type Vagrantfile
          type automation\\CDAF.windows | findstr "productVersion"

          RMDIR /S /Q solution
          cp automation\\solution solution 

          IF EXIST .vagrant vagrant destroy -f & verify >nul
          IF EXIST .vagrant vagrant box list & verify >nul
          vagrant up
        '''
      }

      stage ('Test the CDAF sample on Windows Server 2016') {
        bat '''
          vagrant destroy -f
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
