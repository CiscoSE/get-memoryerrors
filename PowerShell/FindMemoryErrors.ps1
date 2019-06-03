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

.DESCRIPTION
This script assumes you are already connected to the domain you want to
assess. Please see the connect-ucs commandlet for connecting to a UCS Domain.
#>

$output = ""
#Get Date and time for output file time stamp.
$datetime = get-date -format yyyyMMdd-HHmmss
$FileName = "$($datetime)-MemoryReport.txt"

#If you have bad blade, this ensures the script doesn't fail. 
$ErrorActionPreference = "SilentlyContinue"
#Get a list of servers we want to loop through
$HardwareList = Get-UcsServer

#Loop through the list of servers
Get-ucsserver | %{
    #Get the service profile for this computer only. 
    $profileName = get-ucsserviceprofile -dn ($_.assignedToDn)
    
    #Check to see if the service profile was found (There can be only one).
    if ($profileName.count -eq 1)
        {
        #If it exists we associate it.
        $ServerName = $profileName[0].Name
        }
    else
        {
        #If we did not find a profile we assign default text.
        $ServerName = "Undetermined / Not assigned / $($_.Dn)"
        }
    # Have a seperator and the server name so we know where one server begins and the next ends.
    $output += "#" * 50 + "`n"
    $output += "$ServerName`n" 
    #Hand the server name into the pipeline. You need get-ucsComputeBoard to get to deeper levels.
    #We do not use the output from get-ucscomputeboard or get-ucsmemoryarray, but you could... 
    #They are just there to get us deeper into the system
    $_ | 
        Get-UcsComputeBoard |
            Get-UcsMemoryArray |
                Get-UcsMemoryunit | 
                    sort-object location |   #We sorted them so that they show up in order in the list. 
                        ?{$_.operstate -ne "removed"} | %{
                            #Next line is a place holder we can use the information at deeper levels.
                            $MemoryProp = $_
                            #These are memory errors
                            $MemStat = $_ | Get-UcsMemoryErrorStats
                            #Write each memory module to the screen
                            $output += "Location: $($MemoryProp.Location)",
                                "Array: $($MemoryProp.Array)",
                                "Bank: $($MemoryProp.Bank)",
                                "Capacity: $($MemoryProp.Capacity)",
                                "Mhz: $($MemoryProp.clock)",
                                "Model: $($MemoryProp.Model)",
                                "Vendor: $($MemoryProp.vendor)",
                                "State: $($MemoryProp.Operstate)",
                                "Serial: $($MemoryProp.Serial)`n"
                            #Search the memory errors and only output the ones where the errors show up...
                            foreach ($attribute in ($MemStat | get-member | ?{$_.name -match "error"}).name)
                                {
                                if (($MemStat).($attribute) -ne 0)
                                    {
                                    $output += "     $($attribute): $($Memstat.($attribute))`n"
                                    }
                                }
                            }
 
    }
    $output | out-file $FileName
