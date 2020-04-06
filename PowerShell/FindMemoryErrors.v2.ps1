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
    [parameter(mandatory=$false)][pscredential]$Gobal:Credentials = (Get-Credential -Message "Enter the user name and password for access to UCS. All domains require the same password.")
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

function validePowerTool {
    Param()
    Begin {
        Write-Verbose "We need Cisco PowerTool to function. Checking for it now."
    }
    Process{
        $modules = get-Module -ListAvailable -Name Cisco.UCSManager
        If ($Modules.count -eq "1") {
            Write-Verbose "Powertool Available"
            return $true
        else
            write-verbose "Powertool Not available"
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
        write-verbose "Modules are loaded"
        return $true
    }
    else{
        write-host "Modules did not load. "
        return $false
    }
}

function write-event{
    param(
        [parameter(mandatory=$true)][string]$message,
        [parameter(mandatory=$false)]
            [ValidatePattern("INFO|FAIL|WARN")]
            [string]$type = "INFO"
    )
    switch($type){
    "INFO" {$Color = "Green";  break}
    "FAIL" {$Color = "RED";    break}
    "WARN" {$Color = "Yellow"; break}
    }
    write-host " [ " -NoNewline
    write-host $type -ForegroundColor Green -NoNewline
    write-host " ]     " -NoNewline
    write-host $message
} 


function main {
    param(
        [parameter(mandatory=$true)][string]$targetHost
    )
    begin{
        write-verbose "Processing $targetHost"
    }
    process{
        #Load PowerShell Modules if needed.
        if (-not (toolLoadCheck)){
            get-module -ListAvailable -name Cisco.UCSManager | import-module -verbose:$false 
            if (-not (toolLoadCheck)){
                write-Host "Failed to load tools, script cannot continue"
                exit
            }
        }
        $ucsConnection = connect-ucs -name $targetHost -Credential $Credentials
        if ($ucsConnection){
            write-event -type INFO -message "Connected to $targetHost"
        }
        else{
            write-event -type WARN -message "Failed to connect to $targetHost. This domain is not processed"
            write-event -type WARN -message $error[0].Exception
        }

    }
}

if (validePowerTool) {
    $DomainList | %{
        
        main -targetHost $_
    }
}
else {
    Write-verbose "PowerTool Modules are required for this script. Please obtain them from software.cisco.com"
}

#TODO Recheck failure of UCS Modules to load.