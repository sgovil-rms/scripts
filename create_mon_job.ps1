#$Tenant = 'SCOR'
#$Interval = 5 #minutes
#$PriorityList = "Lowest+4"  # "Lowest+4"
#$PriorityType = 'Highest'
#$EventID = 9999
#$LookBackInterval = 6 #hours
#$SuppressAlertInterval = 60 #minutes

#$Command = "C:\rms_monitoring\egc_job_monitoring.ps1 $Tenant $($Interval) $($PriorityList) $($PriorityType) $($EventID) $($LookBackInterval) $($SuppressAlertInterval)"

$taskName = "EGC Job Monitoring"
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($task -ne $null)
{
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false 
}

#$user = "$env:USERDOMAIN\$env:USERNAME"
#Write-Output $user

$response = Read-host "Enter your password?" -AsSecureString 
$password=[Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($response))

$action = New-ScheduledTaskAction -Execute 'C:\Windows\SysWOW64\WindowsPowerShell\v1.0\powershell.exe' -Argument ' -command C:\rms_monitoring\scripts\egc_job_monitoring.ps1 -TenantName SCOR -CheckInterval 5 -JobPriorityList "Lowest+2","Lowest+4" -PriorityLabel Highest -EventID 9999 -LookBackInterval 1440 -SuppressAlertInterval 60' 
$trigger =  New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration ([System.TimeSpan]::MaxValue)

#$principal = New-ScheduledTaskPrincipal -UserId 'MS\svc-zen' -RunLevel Highest
#-LogonType S4U -RunLevel Highest

$definition = New-ScheduledTask -Action $action -Trigger $trigger -Description "Monitoring Highest Priority EGC Jobs"
				#-Principal $principal `  
				

Register-ScheduledTask -TaskName $taskName -InputObject $definition -User 'MS\SVC-ZEN' -Password $password

#Register-ScheduledTask -Action $action -User $principal -Trigger $trigger -TaskName $taskName -Description "Monitoring Highest Priority EGC Jobs"

$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($task -ne $null)
{
	Write-Output "Created scheduled task: '$($task.ToString())'."
	Write-Output "***********************************************************************************"
	Write-Output ""
	Write-Output "Please make sure to check-off 'Run with Highest privilege check box on the scheduler'"
	Write-Output ""
	Write-Output "***********************************************************************************"
}
else
{
	Write-Output "Created scheduled task: FAILED."
}