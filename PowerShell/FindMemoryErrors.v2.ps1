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
[cdmletbinding()]
$output = ""
#Get Date and time for output file time stamp.
$datetime = get-date -format yyyyMMdd-HHmmss
$FileName = "$($datetime)-MemoryReport.txt"

#If you have bad blade, this ensures the script doesn't fail. 
$ErrorActionPreference = "SilentlyContinue"

#TODO Establish Connection
#TODO Get a list of blades
#TODO GEt a list of RACK Mount Servers

[array]DomainList = "1.1.42.110"

function getBladeHardware {

}
