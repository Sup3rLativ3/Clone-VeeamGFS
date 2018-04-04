<#
    .SYNOPSIS
       This script will copy the current Veeam job to an offsite drive.
    
    .DESCRIPTION
       This script is to be run as a Veeam post GFS job script and will mirror your GFS data to an offsite drive.
       It is recommended to use a tool such as USBDLM (http://www.uwe-sieber.de/usbdlm_e.html) to keep all your offsite drives the same letter.
       Default values are K: for the home drive (onsite repo) and O: for the USB offsite drive.

    .EXAMPLE
       .\Clone-VeeamGFS.ps1 -HomeDrive "K:" -OffsiteDrive "O:"
    
    .NOTES
       File Name        : Clone-VeeamGFS.ps1
       Author           : James Smith
       Prerequisites    : Windows, Veeam 9.5+
    
#>

param ( [string]$HomeDrive = '\\10.0.0.116\',
		[string]$OffsiteDrive = 'O:',
        [string]$EventSource = "Veeam GFS Script"
)
start-transcript -Path R:\Shadow\Scripts\Veeam\Transcript.log

Add-PSSnapin -Name VeeamPSSnapIn -ErrorAction SilentlyContinue

# This checks to see if the event viewer source exists and if not it will create it.
$EventSourceExists = Get-EventLog -list | Where-Object {$_.logdisplayname -eq "$EventSource"} 
IF (!($EventSourceExists)) 
    {
        New-EventLog -LogName Application -Source $EventSource -ErrorAction SilentlyContinue
    }

# This pulls the process id of the Veeam session. From that it gets the job command used to start the job and then uses the GUID of the job to get the name of the job
# Credit to /u/poulboren from reddit
# https://www.reddit.com/r/Veeam/comments/6aaxll/veeam_ps_get_name_of_current_job/dhd5x4j/
# https://github.com/poulpreben/powershell/blob/master/VeeamPrnxCacheControl.ps1#L35

$ParentPID = (Get-WmiObject Win32_Process -Filter "ProcessID='$PID'").parentprocessid.ToString()
$ParentCMD = (Get-WmiObject Win32_Process -Filter "ProcessID='$ParentPID'").CommandLine
$VeeamJob = Get-VBRJob | ?{$ParentCMD -like "*"+$_.Id.ToString()+"*"}
#$veeamjob = get-vbrjob -name "server 2016 GFS"
$JobName=$VeeamJob.name

#This checks to see if the folder exists on the USB drive and if not creates it.

$Path = Test-Path "$OffsiteDrive\Veeam_Offsite\$JobName\"
If (!($Path))
{ New-Item -Name "$JobName" -Path "$OffsiteDrive\Veeam_Offsite\" -Type Directory }

#This performs the mirror. If it hits an error it will retry twice with 5 seconds between retries.
Robocopy "$HomeDrive\Veeam_GFS\$JobName" "$OffsiteDrive\Veeam_Offsite\$JobName" /MIR /W:5 /R:2

# This will check the exit code from RoboCopy and if it was not successful, write an error to event viewer under the application directory.
# http://windowsitpro.com/powershell/q-capturing-robocopy-error-codes-powershell
IF (!($LastExitCode -eq 0))
    {
         Write-EventLog -LogName Application -Source $EventSource -EntryType Error -EventId 101 -Message "The clone to the offsite has failed with error code $LastErrorCode"
    }
