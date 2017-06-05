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

param ( [string]$HomeDrive = 'K:',
		[string]$OffsiteDrive = 'O:'
)

# This pulls the process id of the Veeam session. From that it gets the job command used to start the job and then uses the GUID of the job to get the name of the job
# Credit to /u/poulboren from reddit
# https://www.reddit.com/r/Veeam/comments/6aaxll/veeam_ps_get_name_of_current_job/dhd5x4j/
# https://github.com/poulpreben/powershell/blob/master/VeeamPrnxCacheControl.ps1#L35

$ParentPID = (Get-WmiObject Win32_Process -Filter "ProcessID='$PID'").parentprocessid.ToString()
$ParentCMD = (Get-WmiObject Win32_Process -Filter "ProcessID='$ParentPID'").CommandLine
$VeeamJob = Get-VBRJob | ?{$ParentCMD -like "*"+$_.Id.ToString()+"*"}
$JobName=$VeeamJob.name

#This checks to see if the folder exists on the USB drive and if not creates it.

$Path = Test-Path "$OffsiteDrive\Veeam_Offsite\$JobName"
If (!($Path))
{ New-Item -Name "$OffsiteDrive\Veeam_Offsite\$JobName"}

#This performs the mirror. If it hits an error it will retry twice with 5 seconds between retries.
Robocopy "$HomeDrive\Veeam\Backups\GFS\$JobName" "$OffsiteDrive\Veeam_Offsite\$JobName" /MIR /W:5 /R:2
