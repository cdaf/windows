timeout(time: 4, unit: 'HOURS') {
  node {

    properties(
      [
        [
          $class: 'BuildDiscarderProperty',
          strategy: [$class: 'LogRotator', numToKeepStr: '10']
        ],
          pipelineTriggers([cron('30 22 * * *')]),
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
            $env:CDAF_DELIVERY = 'WORKGROUP'
            cd samples
            ./executeSamples.ps1
            cd ..
          } elseif ( $edition -eq 'Microsoft Windows Server 2019 Standard' ) {
            cd samples
            $env:CDAF_DELIVERY = 'WORKGROUP'
            ./executeSamples.ps1 native
            cd ..
          } else {
            Write-Host "`nSkipping Sample Regression Test as OS is ${edition}`n"
          }
        '''
      }
    } catch (e) {
      
      currentBuild.result = "FAILED"
      println currentBuild.result
      notifyFailed()
      throw e

    } finally {

      stage ('Unconditional Clean-up') {
        powershell '''
          Write-Host "`nApply clean-up here`n"
        '''
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
