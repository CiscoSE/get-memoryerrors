[cmdletbinding()]
param(
    [parameter(mandatory=$false)][pscredential]$Global:Credentials = (Get-Credential -Message "Enter the user name and password for access to UCS. All domains require the same password."),
    [parameter(mandatory=$false)]      [string]$Global:testName = "longMemoryTest",
    [parameter(mandatory=$false)]      [switch]$failSafe = $true
)

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
    try{
        $memTest = Get-UCSOrg root | Add-UcsManagedObject -ClassId diagRunPolicy -propertyMap @{Name = "$($Global:testName)"}
        $memTest_1 = $memTest | add-UcsManagedObject -class diagMemoryTest -propertyMap @{cpuFilter="all-cpus"; id="1"; loopCount="100"; memChunkSize="big-chunk"; memSize="all"; order="1"; pattern="butterfly"; rn="test-1"; type="pmem2"}
        $memTest_2 = $memTest | add-UcsManagedObject -class diagMemoryTest -propertyMap @{cpuFilter="all-cpus"; id="2"; loopCount="100"; memChunkSize="big-chunk"; memSize="all"; order="2"; pattern="prbs-killer"; rn="test-2"; type="pmem2"}
    }
    catch{
        write-screen -type "FAIL" -message "`tUnable to create new policy. Unable to continue"
    }
}

function check-DiagPolicyValues($objExisting){
    #We should get three objects here, or we do not have the right number of policies. 
    if ($objExisting.count -ne 3){
        write-host "Policy is not configured properly"
        return $false
    }
    #We should match all of these parameters on the first memory test policy
    If ($policyCheck[1].LoopCount    -ne "100" -or `
        $policyCheck[1].pattern      -ne "butterfly" -or `
        $policyCheck[1].CpuFilter    -ne "all-cpus" -or `
        $policyCheck[1].MemChunkSize -ne "big-chunk" -or `
        $policyCheck[1].MemSize      -ne "All"
    ){
        return $false
    }
    #We shoudl match all of these parameters on the second memory test policy
    If ($policyCheck[2].LoopCount    -ne "100" -or `
        $policyCheck[2].pattern      -ne "prbs-killer" -or `
        $policyCheck[2].CpuFilter    -ne "all-cpus" -or `
        $policyCheck[2].MemChunkSize -ne "big-chunk" -or `
        $policyCheck[2].MemSize      -ne "All"
    ){
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
    write-screen -type "INFO" -message "Policy Recreation Successful"
}

function check-DiagPolicy(){

    # Check to see if policy already Exists
    $policyCheck = get-ucsdiagRunPolicy -name $Global:testName -Hierarchy

    #Create the policy if it does not already exist
    if ($policyCheck){
        Write-screen -type 'INFO' -message "`t$($Global:testName) Policy Exists"
        if (check-DiagPolicyValues -objExisting $policyCheck){
            write-screen -type "INFO" -message "`tNo changes required for policy"
        }
        else{
            write-screen -type "WARN" -message "`tPolicy is not set properly and will be recreated"
            remove-ucsDiagnosticPolicy
            create-DiagPolicy
        }
    
    }
    else{
        create-DiagPolicy
    }

}

check-DiagPolicy