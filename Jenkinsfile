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
          Write-Host "`nList CDAF Product Version`n"
          Get-Content automation\\CDAF.windows | findstr "productVersion"

          Write-Host "`nList Jenkinsfile`n"
          Get-Content Jenkinsfile

          $edition = foreach ($sProperty in Get-WmiObject -class Win32_OperatingSystem -computername ".") { $sProperty.Caption }
          if ( $edition -eq 'Microsoft Windows Server 2022 Standard' ) {

            Write-Host "`nSample Regression Test on ${edition}`n"
            cd samples
            ./executeSamples.ps1
            cd ..
          } else {
            Write-Host "`nSkipping Sample Regression Test as OS is ${edition}`n"
          }
        '''
      }

      stage ('Test the CDAF sample on Windows Server 2019') {

        powershell '''
          $edition = foreach ($sProperty in Get-WmiObject -class Win32_OperatingSystem -computername ".") { $sProperty.Caption }
          if ( $edition -eq 'Microsoft Windows Server 2019 Standard' ) {
            $env:OVERRIDE_IMAGE = 'cdaf/WindowsServerCore'
            Write-Host "`nOVERRIDE_IMAGE set to ${env:OVERRIDE_IMAGE} as OS is ${edition}`n"
          } elseif ( $edition -eq 'Microsoft Windows Server 2022 Standard' ) {
            $env:OVERRIDE_IMAGE = 'cdaf/WindowsServer2022'
            Write-Host "`nOVERRIDE_IMAGE set to ${env:OVERRIDE_IMAGE} as OS is ${edition}`n"
          } else {
            Write-Host "`nOVERRIDE_IMAGE not set as as OS is ${edition}`n"
          }

          Write-Host "`nList Vagrantfile`n"
          Get-Content Vagrantfile

          if ( Test-Path .vagrant ) {
            vagrant destroy -f
            vagrant box list
          }

          vagrant up
          vagrant destroy -f
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
