Param
(
  $TenantName, # Name of the Tenant
  $CheckInterval, # Time interval in minutes
  $JobPriorityList, # HPC Job Priority List - Lowest,Lowest+1,Lowest+2,Lowest+3,Lowest+4
  $PriorityLabel, #Highest, Above Normal, Normal, Below Normal, Lowest
  $EventID, # 9999, 9990, 9980
  $LookBackInterval, # Time interval in minutes to look back in time for queued jobs
  $SuppressAlertInterval # Time in minutes for suppressing alerts
)

$NumOfParams = 7
Function LogWrite
{
   Param ([string]$logstring)
   Add-content $Logfile -value "$(Get-Date): $($logstring)"
}

Add-PSSnapin Microsoft.HPC
$BaseDir = "C:\RMS_Monitoring"
$LogDir = "$($BaseDir)\Logs"
$CacheDir = "$($BaseDir)\Cache"
$DTG = Get-Date -format M.d.yyyy_HH.mm.ss
$Logfile = "$LogDir\egc_mon_log_$DTG.log"
#Create Logs Folder if does not exist
If (!(Test-Path $LogDir))
{
	New-Item  -ItemType Directory -Force -Path  $LogDir 
	LogWrite  "Logs directory [$LogDir] created!"
}
If (!(Test-Path $CacheDir))
{
	New-Item  -ItemType Directory -Force -Path  $CacheDir
	LogWrite  "Cache directory [$CacheDir] created!"
}
LogWrite "Starting the EGC job monitoring"
LogWrite "Checking the number of argument supplied: Required [$($NumOfParams)] vs. Supplied[$(($PSBoundParameters.values | Measure-Object | Select-Object -ExpandProperty Count))]"

# Test to see if the script should exit..
If ( ($PSBoundParameters.values | Measure-Object | Select-Object -ExpandProperty Count) -lt $NumOfParams)
{
	LogWrite "Exiting due to insufficient number of arguments supplied!"	
	Write-Output "Exiting due to insufficient number of arguments supplied!"
	EXIT
}

$SourceName = "EGC_Job_Monitoring"
$source = [system.diagnostics.eventlog]::SourceExists("$($SourceName)")

If($source -ne 'True') {
    LogWrite "Creating new Windows Application source $($SourceName)"
    [system.diagnostics.EventLog]::CreateEventSource("$($SourceName)", "Application")
}

$CacheFile = "$($CacheDir)\$($EventID).out"

LogWrite "Cache file path is $($CacheFile)"

#Add exception handling here and null input and default inputs
$Start = (Get-Date).AddMinutes(-$LookBackInterval)
$End = (Get-Date).AddMinutes(-$CheckInterval)

LogWrite "Checking for queued jobs between StartDate: $($Start) & EndDate: $($End)"

$HJobs = Get-HpcJob -BeginSubmitDate $Start -EndSubmitDate $End -State Queued -ErrorAction:SilentlyContinue |  Where-Object { $_.Priority -in ($JobPriorityList)}

LogWrite "$($HJobs.Count) job(s) with [$($JobPriorityList)] priority found in the queue"

If($HJobs.Count -ne 0){

    If(Test-Path -Path $CacheFile)
    {
        $date = Get-Content -Path $CacheFile -ReadCount 1
        $date = $date -as [DateTime];
    }

	LogWrite "Time stamp when last alert was raised: $($date)"
	
    #Raise the alert if the date is invalid or current time is greater than the time we last raised the alert 
    If(!$date -or ($date).AddMinutes($SuppressAlertInterval) -le (Get-Date))
    {   
       LogWrite "Raising the event: $($EventID)"

	   $Message = "Tenant $($TenantName): $($HJobs.Count) job(s) with $($PriorityLabel) priority found in the queue. Please check!)"
			
	   Write-EventLog -LogName "Application" -Source "$($SourceName)" -EventID "$($EventID)" -EntryType Warning -Message $Message
       
       LogWrite "Resetting the time stamp after raising the Windows Event"
	   #Reset the time stamp after every time a windows event is raised!
       (Get-Date) | Set-Content -Path $CacheFile
    }
    else
    {
        LogWrite "We can only raise an event after every $($SuppressAlertInterval) minutes. Suppressing raising an event."
        Write-Output "We can only raise an event after every $($SuppressAlertInterval) minutes. Suppressing raising an event."
    }    
}
else
{
     LogWrite "No $($PriorityLabel) priority job found in the queue. Resetting the time stamp."
     Write-Output "No $($PriorityLabel) priority job found in the queue. Resetting the time stamp."
     '' | Set-Content -Path $CacheFile
}
