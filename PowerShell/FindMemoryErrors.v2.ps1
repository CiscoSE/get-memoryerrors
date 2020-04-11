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
    [parameter(mandatory=$false)][pscredential]$Global:Credentials = (Get-Credential -Message "Enter the user name and password for access to UCS. All domains require the same password."),
    [parameter(mandatory=$false)][string]$ProcessingLogName,
    [parameter(mandatory=$false)][string]$ProcessingLogPath = '.\Processing',
    [parameter(mandatory=$false)][string]$TACReportPath = '.\TACReport'
)

if (-not ($Global:Credentials)){
    write-host "Credentials required. Script will exit."
    exit
}

$Global:InventoryReportFragments = ''
#Get Date and time for output file time stamp.
$datetime = get-date -format yyyyMMdd-HHmmss

#If you have bad blade, this ensures the script doesn't fail. 
$ErrorActionPreference = "Stop" # Other Options: "Continue" "SilentlyContinue" "Stop"

$Global:CSS = @"
    <Title>Memory Error TAC Report</Title>
    <Style type='text/css'>
    SrvProp{
        boarder:20pt;
    }

    td, th { border:0px solid black; 
         border-collapse:collapse;
         white-space:pre; }
    th { color:white;
     background-color:black; }
    table, tr, td, th { padding: 2px; margin: 0px ;white-space:pre; }
    tr:nth-child(odd) {background-color: lightgray}
    table { width:95%;margin-left:5px; margin-bottom:20px;}

    </Style>
"@


function write-screen {
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

function Write-Event{
    param(
        [parameter(mandatory=$false,position=0)]
            [ValidatePattern("INFO|FAIL|WARN")]
                                               [string]$type = "INFO",
        [parameter(mandatory=$true,Position=1)][string]$message,
        [parameter(mandatory=$false)]          [switch]$logOnly = $false #When True, we only write this data to the log file.
    )

    ("[ $type ] $message") | out-file -Append -FilePath $Global:ProcessingLogFile

    if ($logOnly){
        return
    }

    write-screen -type $type -message $message
    if ($type -eq "FAIL") {
        exit
    }
} 

function write-screen {
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

Function format-Log {
    param(
        $LogFilePath,
        $LogFileName
    )
    if ($LogFilePath -notmatch "\$"){
        return ($LogFilePath + "\" + $LogFileName)
    }
    Else{
        return ($LogFilePath + $LogFileName)
    
    }

}

function validateDirectory {
    param(
        [parameter(mandatory=$true)][string]$Directory
    )
    begin {
        write-screen -type INFO -message "Checking $Directory Exists"
    }
    process{
        $error.clear()
        if ( -not (test-path $directory)){
            $result = md $directory
            if ($error[0]){
                write-screen -type WARN -message "Directory $Directory does not exist and could not be created"
                Write-screen -type FAIL -message "Directory $Directory must be created and writable to continue."
            }
            else{
                Write-screen -type INFO -message "Directory $Directory created"
            }
        }
        else{
            Write-Screen -type INFO -message "$Directory Directory Exists"
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

Function memVendorLookup {
    param(
        $VendorCode
    )

    $returnVendorCode = switch ($VendorCode){
        '0x2C00' {'Micron';  break}
        '0x802C' {'Micron';  break}
        '0x80AD' {'Hynix';   break}
        '0x80CE' {'Samsung'; break}
        '0xAD00' {'Hynix';   break}
        '0xCE00' {'Samsung'; break}
        Default {$_}
    }
    return $returnVendorCode
}

function process-MemoryStats {
    param (
        [parameter(mandatory=$true)]$MemoryStats,
        [parameter(mandatory=$true)]$MemoryProperties,
        [parameter(mandatory=$true)]$InventoryPath
    )
    begin{
        write-event -type INFO -message "`t`t`tProcessing Server Memory Statistics for $($MemoryProperties.Location)"
        # We write all results to the logs, but only DIMMs that show errrors should go into the TAC report.
    }
    process{
        
        $MemoryStatReport = New-Object -type psobject
        #All of the memory attributes written to the log. 
        $errorFound = $false
        
        $MemorySubProperties = $MemoryProperties |
            select `
                location, 
                capacity, 
                Clock, 
                Type, 
                @{Name='Vendor';Expression={memVendorLookup -VendorCode $_.Vendor }},
                Serial, 
                Model, 
                state
        
        foreach ($Attribute in ($MemoryStats | get-member | ?{$_.name -match "error"}).name){
            if (($MemoryStats).($Attribute) -ne 0){
                $memoryStatReport | add-member -MemberType NoteProperty -Name $Attribute -value $MemoryStats.($Attribute)
                Write-Event -type WARN -message "`t`t`t$($Attribute):`t$($MemoryStats.($attribute))"
                $errorFound = $true
            }
        }
        if ($errorFound){
            $MemorySubPropertiesHTML = ($MemorySubProperties | convertto-html -As table -Fragment -PreContent "<h2>Memory Properties</h2>")
            $MemoryStatReportComplete = $MemorySubPropertiesHTML + ($MemoryStatReport | convertto-html -As Table -Fragment)
        } 
        
        return $ErrorFound, ($MemoryStatReportComplete)
    }
    end{}
}

function Process-BaseServer {
    Param (
        [parameter(mandatory=$true)]$ServerProperties,
        [parameter(mandatory=$true)]$ServerFirmware,
        [parameter(mandatory=$true)]$InventoryPath
    )
    begin{Write-Event -type INFO -message "`t`tProcessing $($ServerProperties.Serial)"}
    process{
       $report = $ServerProperties | 
        Select `
            Serial, 
            Model, 
            ServerID, 
            TotalMemory, 
            AvailableMemory, 
            MemorySpeed, 
            Ucs, 
            NumOfCores, 
            NumOfCPUs, 
            AdminState,  
            Lc,
            @{Name="BiosVersion"; Expression={($ServerFirmware | ?{$_.type -match 'bios'})[0].version}},
            @{Name="CIMCVersion"; Expression={($ServerFirmware | ?{$_.type -match "(blade|rack)-controller" -and $_.deployment -match 'system'})[0].version}},
            @{Name="BoardControllerVersion"; Expression={($ServerFirmware | ?{$_.type -match "board-controller" -and $_.deployment -match 'system'})[0].version}}
       # Process HTML Output.
       $report | Select `
            Serial, 
            Model, 
            ServerID, 
            TotalMemory, 
            AvailableMemory, 
            MemorySpeed, 
            NumOfCores, 
            NumOfCPUs, 
            AdminState,  
            Lc,
            BiosVersion,
            CIMCVersion,
            BoardControllerVersion |  
                convertto-html -as List -fragment -PreContent "<h1 id='$($ServerProperties.serial)' >Server Serial Number: $($ServerProperties.Serial)</h1>" |
                    Out-File -FilePath $InventoryPath -append
       Return ($report | convertto-html -As List -Fragment -PreContent "<h1>System Report</h1>")
   }
    
}


function write-MemoryInventory {
    Param(
        $InventoryFilePath,
        $Inventory
    )
    $Inventory | Select `
        Location,
        Serial,
        @{Name='Vendor'; Expression={memVendorLookup -VendorCode $_.vendor}},
        Model,
        Capacity,
        Clock,
        FormFactor,
        OperState,
        Operability,
        Presence |
            ConvertTo-Html -as Table -Fragment |
                out-file -FilePath $InventoryFilePath -Append
}

function main {
    param(
        [parameter(mandatory=$true)][string]$targetHost,
        [parameter(mandatory=$True)][string]$tacReportName
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
        #Connect to UCS
        $ucsConnection = connect-ucs -name $targetHost -Credential $Credentials
        if ($ucsConnection){
            write-event -type INFO -message "`tConnected to $targetHost"
            $serverList = Get-UcsServer

            #Create a header for our Inventory File

            $ServerListHTML = $serverList | 
                select `
                    serial,
                    @{Name='ServiceProfile'; Expression={($_.AssignedToDn) -replace ".+ls-",''}} | 
                        convertto-html -as Table -fragment
            $ServerList | %{
                $Serial = $_.serial
                $serverListHTML = $ServerListHTML -replace "<td>$($serial)</td>","<td><a href='#$($serial)' >$($serial)</a></td>"
            }

            $ServerListHTML | out-file -FilePath ($InventoryReportPath + "\" + $targetHost + '.html') -append

            $serverList |
                %{
                    $ServerErrorCount = 0
                    if ($ServerReport){remove-variable ServerReport}
                    $ServerProperties =  (process-BaseServer -InventoryPath ($InventoryReportPath + "\" + $targetHost + '.html') -ServerProperties $_ -serverFirmware (Get-UcsFirmwareRunning -filter "dn -ilike $($_.dn)*" ))
                    $ServerReport = $ServerProperties
                    $memoryList = ($_ | Get-UCSComputeBoard | Get-UcsMemoryArray | get-ucsMemoryUnit | sort location )
                    write-MemoryInventory -InventoryFilePath ($InventoryReportPath + "\" + $targetHost + '.html') -Inventory $MemoryList
                    $memoryList | %{
                        $ErrorFound = $False
                        if ($MemoryReport){Remove-Variable -Name MemoryReport}
                        $MemoryStats = ($_ | Get-UcsMemoryErrorStats)
                        if ($MemoryStats){
                            $ErrorFound, $MemoryReport = (process-MemoryStats -InventoryPath ($InventoryReportPath + "\" + $targetHost + '.html') -MemoryProperties $_ -MemoryStats ($_ | Get-UcsMemoryErrorStats ))
                        }
                        if($errorFound) {
                            $TacReportName = ($TACReportPath + "\" + $_.serial + ".html")
                            $ServerErrorCount += 1
                            $serverReport += $MemoryReport
                        } 
                    }
                    if ($serverErrorCount -gt 0) {ConvertTo-Html -Head $Global:CSS -body $ServerReport |
                        Out-File -FilePath $tacReportName -Append}
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
        $inventoryReport = get-content ($InventoryReportPath + "\" + $targetHost + '.html')
        convertto-html -Head $Global:CSS -Body $inventoryReport | Out-File ($InventoryReportPath + "\" + $targetHost + '.html')
    }
}

$Global:InventoryReportPath = ($ProcessingLogPath + '\' + $datetime)

validateDirectory -Directory $ProcessingLogPath
validateDirectory -Directory $TACReportPath
validateDirectory -Directory $Global:InventoryReportPath

if (-not ($ProcessingLogName)){
    $ProcessingLogName = ($datetime + "-Processing.log")
}

$Global:ProcessingLogFile = format-Log -LogFilePath $ProcessingLogPath -LogFileName $ProcessingLogName 

write-screen -type INFO -message "Processing Log File:`t$Global:ProcessingLogFile"


$DomainCount = 1
if (validePowerTool) {
    $DomainList | %{
    $TACReportFile = format-log -LogFilePath $TACReportPath -LogFileName ($datetime + "-TacReport-"+ $DomainCount +".html")        
        main -targetHost $_ -tacReportName $TACReportFile
        $DomainCount += 1
    }
}
else {
    Write-verbose "PowerTool Modules are required for this script. Please obtain them from software.cisco.com"
}

#TODO Recheck failure of UCS Modules to load.