<#
.NOTES
Copyright (c) 2022 Cisco and/or its affiliates.
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

.DESCRIPTION
This script is intended for new environments to test memory on the servers and generate processor / memory utilization 
for the purposes of stress testing the server prior to production deployment. 

This script was written for the UCS Mini, but should work with any UCS Manager based deployment. 

Because the script makes changes, you should fully review how this script works before running it on your network. If you
have production servers this script can cause harm to running production environments. This script will trigger a reboot
of any servers it is directed towards, and by default that means blades 1 through 8 in chassis 1. If you run this with
default settings, you can expect blades 1 through 8 to go down immidiately to run a memory test. It also creates or over 
writes a diag policy called longMemoryTest as part of this process. 

We trigger two tests in this script by default.

    100 Passes of butterfly memory testing
    100 Passes of prbs-killer memory testing

For the average M5 server, you can expect this to run 12 to 24 hours depending on the amount of memory and the speed of the processor.

.PARAMETER DomainList
The domain list is a list of domains to be processed. All domains must have the same logon and password for them to be run 
by the script at the same time. Multiple domains can be included by using commas to seperate the domain names or IPs. 
Do not include spaces in the seperated values. 

.PARAMETER failSafe
The script will not run unless you use this switch. This is intended to prevent accidental trigger of the script.

.PARAMETER butterFlyCount
Set the number of passes the butterfly test should be completed.

.PARAMETER prbskillerCount
Set the number of passes the prbs-killer test should be completed.

.PARAMETER Global:testName
Set the name of the memory test policy. By default this is longMemoryTest

.PARAMETER ServerList
This array lists all of the servers to be rebooted (immediately) for memory testing. It is critical that you review this list
before running this script. By default we reboot blades 1 through 8 on chassis 1. The two common formats for servers are:

    Blade 1 on Chassis 1 as an example of a blade 
    sys/chassis-1/blade-1

    Rack mount Server 1 as an example
    sys/rack-unit-1

.EXAMPLE
./set-diagnostic.ps1 -DomainList 1.1.1.10 -failsafe

Running against a single domain using default settings. This will create a policy called longMemoryTest and then reboot
all eight blade servers in chassis 1 if they exist.

.EXAMPLE
./set-diagnostic.ps1 -DomainList 1.1.1.10 -failsafe -prbskillerCount 2 -butterFlyCount 2

Creates a policy called longMemoryTest on the 1.1.1.10 fabric interconnect domain with loop counts of 2 for the
butterfly and PRBS-Killer tests.

.EXAMPLE
./set-diagnostic.ps1 -DomainList 1.1.1.10,1.1.2.10 -failsafe

Creates policies in two different domains and reboots all 8 servers in both domains to perform the memory test. 


#>
[cmdletbinding()]
param(
    [parameter(mandatory=$false)][pscredential]$Global:Credentials = (Get-Credential -Message "Enter the user name and password for access to UCS. All domains require the same password."),
    [parameter(mandatory=$false)]      [string]$Global:testName = "longMemoryTest",
    [parameter(mandatory=$false)]      [switch]$failSafe = $false,
    [parameter(mandatory=$true)]       [array]$DomainList,
    [parameter(mandatory=$false)]      [int]$butterFlyCount=100,
    [parameter(mandatory=$false)]      [int]$prbskillerCount=100,
    [parameter(mandatory=$false)]      [array]$serverList = @(
        "sys/chassis-1/blade-1",
        "sys/chassis-1/blade-2",
        "sys/chassis-1/blade-3",
        "sys/chassis-1/blade-4",
        "sys/chassis-1/blade-5",
        "sys/chassis-1/blade-6",
        "sys/chassis-1/blade-7",
        "sys/chassis-1/blade-8") 
)

if ($failSafe -eq $false){
    write-host "This script makes changes to UCS that can take down servers and make policy changes that cannot be undone."
    write-host "WARNING: THIS SHOULD NEVER BE RUN AGAINST A DOMAIN WITH ACTIVE SERVERS. THEY WILL ALL GO DOWN!" -ForegroundColor "Red"
    write-host "The intent of this script is to create a memory test for a new domain that has no active servers. The script will create a memory test policy and configure all discovered servers in the domain to run the 
memory diagnostics immidiately. 

If you understand the risks, rerun this script with the -failsafe switch
"
    exit
}
if (-not ($Global:Credentials)){
    write-host "Credentials required. Script will exit."
    exit
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
function create-DiagPolicy(){
    write-verbose "Writting Butterfly count of $butterFlyCount"
    write-verbose "Writting prbs-killer count of $prbsKillerCount"
    try{
        $memTest = Get-UCSOrg root | Add-UcsManagedObject -ClassId diagRunPolicy -propertyMap @{Name = "$($Global:testName)"}
        $memTest_1 = $memTest | add-UcsManagedObject -class diagMemoryTest -propertyMap @{cpuFilter="all-cpus"; id="1"; loopCount="$butterFlyCount";  memChunkSize="big-chunk"; memSize="all"; order="1"; pattern="butterfly"; rn="test-1"; type="pmem2"}
        $memTest_2 = $memTest | add-UcsManagedObject -class diagMemoryTest -propertyMap @{cpuFilter="all-cpus"; id="2"; loopCount="$prbsKillerCount"; memChunkSize="big-chunk"; memSize="all"; order="2"; pattern="prbs-killer"; rn="test-2"; type="pmem2"}
    }
    catch{
        write-screen -type "FAIL" -message "`tUnable to create new policy. Unable to continue"
    }
}

function check-DiagPolicyValues($objExisting){
    #We should get three objects here, or we do not have the right number of policies. 
    if ($objExisting.count -eq 3){
        write-screen -type "INFO" -message "`tCorrect number of objects found in existing policy. Checking settings"
    }
    else{
        write-verbose "`tWe should have 3 objects, but we returned $($objExisting.count)"
        write-verbose "$($objExisting)"
        write-screen -type "WARN" -message "`tPolicy is not configured properly"
        return $false
    }
    #We should match all of these parameters on the first memory test policy
    If ($policyCheck[1].LoopCount    -ne "$($butterFlyCount)" -or `
        $policyCheck[1].pattern      -ne "butterfly" -or `
        $policyCheck[1].CpuFilter    -ne "all-cpus" -or `
        $policyCheck[1].MemChunkSize -ne "big-chunk" -or `
        $policyCheck[1].MemSize      -ne "All"
    ){
        write-screen -type "WARN" -message "`tButterfly test has a different settings. Recreating the policy"
        return $false
    }
    #We shoudl match all of these parameters on the second memory test policy
    If ($policyCheck[2].LoopCount    -ne "$($prbsKillerCount)" -or `
        $policyCheck[2].pattern      -ne "prbs-killer" -or `
        $policyCheck[2].CpuFilter    -ne "all-cpus" -or `
        $policyCheck[2].MemChunkSize -ne "big-chunk" -or `
        $policyCheck[2].MemSize      -ne "All"
    ){
        write-screen -type "WARN" -message "`tPRBS-Killer test has a different settings. Recreating the policy"
        return $false
    }    
    # We think everything matches up. 
    return $True
}
function remove-ucsDiagnosticPolicy(){
    try{
        $removeResult = Remove-UcsManagedObject -dn "org-root/diag-policy-$($Global:testName)" -ClassID "diagRunPolicy" -confirm:$false -force
    }
    catch{
        write-screen -type "FAIL" -message "`tUnable to remove policy and cannot continue"
    }
    write-screen -type "INFO" -message "`tPolicy Recreation Successful"
}

function check-DiagPolicy(){

    # Check to see if policy already Exists
    $policyCheck = get-ucsdiagRunPolicy -name $Global:testName -Hierarchy -org root
    #Create the policy if it does not already exist
    if ($policyCheck){
        Write-screen -type 'INFO' -message "`t$($Global:testName) Policy Exists"
        if (check-DiagPolicyValues -objExisting $policyCheck){
            write-screen -type "INFO" -message "`tNo changes required for policy"
        }
        else{
            write-screen -type "INFO" -message "`tRemoving Existing Policy"
            remove-ucsDiagnosticPolicy
            write-screen -type "INFO" -message "`tCreating New Policy"
            create-DiagPolicy
        }
    
    }
    else{
        write-screen -type "INFO" -message "`tCreating Memory Testing Policy: $($Global:testName)"
        create-DiagPolicy
    }

}

Function toolLoadCheck {
    param()
    #These modules need to be loaded to move on.
    $modules = get-module
    
    if ("Cisco.UCSManager" -in $modules.name){
        write-screen -type INFO -message "`tModules are loaded"
        return $true
    }
    else{
        write-screen -type "WARN" -message "`tModules are not present"
        return $false
    }
}
function triggerMemoryTest{
    param()
    $serverList | %{
        $currentServer = $_
        if ((get-ucsManagedObject -dn $_).count -eq 0){
            write-screen -type "WARN" -message "`tServer $currentServer couldn't be found in this domain and will not be tested"
        }
        else{
            write-screen -type "INFO" -message "`tProcessessing Server for memory testing: $($_)"
            #Change the name of the diagnostic test name associated with the specified server 
            $removeResult1 = Set-UcsManagedObject -ClassID "diagSrvCtrl" -propertyMap @{runPolicyName="$($Global:testName)";dn="$_"} -confirm:$false -force
            #Start the test
            $removeResult2 = set-UcsManagedObject -ClassID "diagSrvCtrl" -propertyMap @{dn="$_"; adminState="trigger"} -confirm:$false -force
        }
    }
}

function main {
    param(
        [string]$Domain
    )
    write-screen -type "INFO" -message "Processing Domain $Domain"
    if ($defaultUCS){
        #If the variable $defaultUCS exists, we need to close the connection or the script will fail. 
        write-screen "WARN" "We found $($defaultUCS.Ucs) is already connected. We will disconnect that domain before we continue"
        # We already have a connected domain, and we need to fix that. 
        $hideDisconnectResult = disconnect-ucs 
    }
    if ((toolLoadCheck) -eq $false){
        write-screen -type "INFO" -message "PowerShell modules for UCS are not active. Importing required modules"
        get-module -ListAvailable -name Cisco.UCSManager | import-module -verbose:$false 
        if (-not (toolLoadCheck)){
            write-screen -type "FAIL" -message "Tool loading failed, and we cannot run without it."

        }
    }
    #Connect to UCS
    $hideConnectionResult = connect-ucs -Name $domain -Credential $Credentials -ErrorAction:SilentlyContinue
    if ("$?" -eq "False"){
        write-screen -type "FAIL" -message "`tFailed to connect to domain. Script cannot continue.`n$($error[0])"
    }
    else{
        write-screen -type "INFO" "`tConnection Successful"
    } 
    check-DiagPolicy
    triggerMemoryTest
    $hideDisconnectResult = disconnect-ucs
}
function validateServers{
    param()
    # We look for up to 160 rack mounts, or up to 20 chassis of blades (8 per chassis).
    $serverList | %{
        write-verbose "Validating Server: $_"
        if ($_ -notmatch "sys/chassis-([1-9]|[1][0-9]|[2][0])/blade-([1-8])|/sys/rack-unit-([1-9]|[1-9][0-9]|[1][0-6][0-9])"){
            write-screen -type "FAIL" -message "Format for servers to modify could not be vaildated. Script cannot continue."
        }
    }
}

validateServers
$DomainList | %{
    main -domain $_
}