<#
.SYNOPSIS
Script creates a schedule task on the host computer that will then initate the PxTools conform operation at a scheduled time. 

.DESCRIPTION
The script creates a schedule task on the host computer named "PxTools Conform Set" in the "Tipton" task folder. The script
can be initiated on a series of computers by utilizing the Invoke-Command cmdlet. Note, Powershell remoting must be enabled 
on on all target computers with an account with appropriate admin credentials. 

Example: Invoke-Command -ComputerName $Computers -Credential DOMAIN\AdminUser -FilePath .\Schedule-PXTConform.ps1 -Start

The schedule task is only configured to run once to initiate the conform operation. Use the '-StartTime' to give a specific time
or by default it will initiate after 30 minutes.
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$False)]
    [datetime]$StartTime = (Get-Date).AddMinutes(30)
)

#############################
## Variables to Configure
#############################

    $TaskPath = "<FolderName>"
    $TaskName = "PxTools Conform Action"
    $TaskDescription = "Intiates PxTools Conform Action via the '.\PxContext_Machine.ps1 -conform' "
    $TaskTrigger = New-ScheduledTaskTrigger -Once -At $StartTime
    $TaskAction = New-ScheduledTaskAction -Execute 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' `
                  -Argument '-ExecutionPolicy Bypass -Command "\\NETWORKSHAREPATH\_Scripts\PXTools\Resources\PxContext_Machine.ps1 -logMode:Verbose -exitMode:CloseConsole -conform -hidden"'
    $TaskSettings = New-ScheduledTaskSettingsSet -Hidden -DontStopIfGoingOnBatteries -WakeToRun

    $TaskUser = "<DOMAIN\SVC_PXT-Install>"
    $TaskUserPW = "<Password>"

#############################
## Begining of Script
#############################

Function New-ScheduledTaskFolder {
    Param ($TaskPath)
    $ErrorActionPreference = "stop"
    $scheduleObject = New-Object -ComObject schedule.service
    $scheduleObject.connect()
    $rootFolder = $scheduleObject.GetFolder("\")
        Try {$null = $scheduleObject.GetFolder($TaskPath)}
        Catch {$null = $rootFolder.CreateFolder($TaskPath)}
        Finally {$ErrorActionPreference = "continue"}
}

Write-Verbose "Creating schedule task folder: $TaskPath"
New-ScheduledTaskFolder -TaskPath $TaskPath

Write-Verbose "Creating and registering schedule task: $TaskName"
Register-ScheduledTask -Action $TaskAction -Trigger $TaskTrigger -TaskName $TaskName -Description $TaskDescription -TaskPath $TaskPath -User $TaskUser -Password $TaskUserPW -RunLevel Highest -Force

Write-Verbose "Modfing schedule task settings for $TaskName"
Set-ScheduledTask -TaskName $TaskName -Settings $TaskSettings -TaskPath $TaskPath -User $TaskUser -Password $TaskUserPW
