<#
.NOTES
Copyright (c) 2019 Cisco and/or its affiliates.
This software is licensed to you under the terms of the Cisco Sample
Code License, Version 1.0 (the "License"). You may obtain a copy of the
License at
               https://developer.cisco.com/docs/licenses
All use of the material herein must be in accordance with the terms of
the License. All rights not expressly granted by the License are
reserved. Unless required by applicable law or agreed to separately in
writing, software distributed under the License is distributed on an "AS
IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
or implied.
#>
[cmdletbinding()]
param(
    [parameter(mandatory=$true)][array]$DomainList,
    [parameter(mandatory=$false)][pscredential]$Gobal:Credentials = (Get-Credential -Message "Enter the user name and password for access to UCS. All domains require the same password."),
    [parameter(mandatory=$false)][string]$Global:ProcessingLogName = "$(get-date -Format yyyyMMdd-HHmmss-processing.log)",
    [parameter(mandatory=$false)][string]$Global:ProcessingLogPath = './Processing',
    [parameter(mandatory=$false)][string]$Global:TACReportPath = './' + (get-date -Format yyyyMMdd-HHmmss) + '-TACReport'
)

if (-not ($Credentials)){
    write-host "Credentials required. Script will exit."
    exit
}


$output = ""
#Get Date and time for output file time stamp.
$datetime = get-date -format yyyyMMdd-HHmmss
$FileName = "$($datetime)-MemoryReport.txt"

#If you have bad blade, this ensures the script doesn't fail. 
$ErrorActionPreference = "Continue"

#TODO Establish Connection
#TODO Get a list of blades
#TODO GEt a list of RACK Mount Servers

#We are creating this as an array so we can collect data from more then one.

function Write-Event{
    param(
        [parameter(mandatory=$false,position=0)]
            [ValidatePattern("INFO|FAIL|WARN")]
            [string]$type = "INFO",
        [parameter(mandatory=$true,Position=1)][string]$message
    )
    switch($type){
    "INFO" {$Color = "Green";  break}
    "FAIL" {$Color = "RED";    break}
    "WARN" {$Color = "Yellow"; break}
    }
    write-host " [ " -NoNewline
    write-host $type -ForegroundColor $color -NoNewline
    write-host " ]     " -NoNewline
    write-host $message
    if ($type -eq "FAIL") {
        exit
    }
} 

function validateDirectory {
    param(
        [parameter(mandatory=$true)][string]$Directory
    )
    begin {
        Write-Event -type INFO -message "checking $Directory Exists"
    }
    process{
        $error.clear()
        if ( -not (test-path $directory)){
            $result = md $directory
            if ($error[0]){
                Write-Event -type WARN -message "Directory $Directory does not exist and could not be created"
                Write-Event -type FAIL -message "Directory $Directory must be created and writable to continue."
            }
            else{
                Write-Event -type INFO -message "Directory $Directory created"
            }
        }
        else{
            Write-Event -type INFO -message "$Directory Directory Exists"
        }
    }
}

function validePowerTool {
    Param()
    Begin {
        write-verbose "We need Cisco PowerTool to function. Checking for it now."
    }
    Process{
        $modules = get-Module -ListAvailable -Name Cisco.UCSManager
        If ($Modules.count -eq "1") {
            Write-Event -message "Powertool Available"
            return $true
        else
            Write-Event -message "Powertool Not available"
            return $false
        }
    end {
    }
    }
}


Function toolLoadCheck {
    param()
    #These modules need to be loaded to move on.
    $modules = get-module
    if ("Cisco.Ucs.Core" -in $modules.name -and "Cisco.UCSManager" -in $modules.name){
        Write-Event -type INFO -message "`tModules are loaded"
        return $true
    }
    else{
        write-Event -type "WARN" -message "`tModules did not load. "
        return $false
    }
}


function main {
    param(
        [parameter(mandatory=$true)][string]$targetHost
    )
    begin{
        Write-Event -type INFO -message "Processing $targetHost"
    }
    process{
        $DomainReport = @{}
        #Load PowerShell Modules if needed.
        if (-not (toolLoadCheck)){
            get-module -ListAvailable -name Cisco.UCSManager | import-module -verbose:$false 
            if (-not (toolLoadCheck)){
                write-Event -type FAIL -message "Failed to load tools, script cannot continue"
            }
        }
        $ucsConnection = connect-ucs -name $targetHost -Credential $Credentials
        if ($ucsConnection){
            write-event -type INFO -message "`tConnected to $targetHost"
            $DomainReport['Version'] = $ucsConnection.Version
            $DomainReport['DomainName'] = $ucsConnection.Name
            $serverList = Get-UcsServer
            $serverList | 
                %{
                    $thisServerReport += $_ | 
                        select Serial, Model, TotalMemory, availableMemory, MemorySpeed, dn |
                                ConvertTo-Html -As List -Fragment -PreContent "<h2>Server Report for $($_.Serial)</h2>"
                    #TODO Write Memory Report 
                } 
             
        }
        else{
            write-event -type WARN -message "`tFailed to connect to $targetHost. This domain is not processed"
            write-event -type WARN -message "`t$($error[0].Exception)"
        }


        if ($ucsConnection) { 
            $disconnect = (disconnect-ucs)
            write-Event -type INFO -message "`tDisconnecting from $targetHost"
        }
    }
}

validateDirectory -Directory $ProcessingLogPath
validateDirectory -Directory $TACReportPath

if (validePowerTool) {
    $DomainList | %{
        
        main -targetHost $_
    }
}
else {
    Write-verbose "PowerTool Modules are required for this script. Please obtain them from software.cisco.com"
}

#TODO Recheck failure of UCS Modules to load.