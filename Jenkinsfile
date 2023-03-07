timeout(time: 4, unit: 'HOURS') {
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

      stage ('Samples Verification Test') {

        checkout scm

        powershell '''
          Write-Host "`nList Jenkinsfile`n"
          Get-Content Jenkinsfile

          Write-Host "`nList Vagrantfile`n"
          Get-Content Vagrantfile

          Write-Host "`nList CDAF Product Version`n"
          Get-Content automation\\CDAF.windows | findstr "productVersion"

          Write-Host "`nNodeJS Test`n"
          cd samples/containerBuild-nodejs
          ../../automation/ci.bat
          cd ../..

          Write-Host "`n.NET Test`n"
          cd samples/containerBuild-dotnet
          ../../automation/ci.bat
          cd ../..
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
