#!/bin/bash

# Copyright (c) {{current_year}} Cisco and/or its affiliates.
#
# This software is licensed to you under the terms of the Cisco Sample
# Code License, Version 1.1 (the "License"). You may obtain a copy of the
# License at
#
#               https://developer.cisco.com/docs/licenses
#
# All use of the material herein must be in accordance with the terms of
# the License. All rights not expressly granted by the License are
# reserved. Unless required by applicable law or agreed to separately in
# writing, software distributed under the License is distributed on an "AS
# IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
# or implied.

tarFileName=''      # This is the TAR file obtained from UCS Manager
serialNumber=''     # We need the serial number to sort out the files

workingDirectory='./Working'
reportDirectory='./Reports'

argumentExit(){
  # Required for help processing
  printf '%s\n' "$1" >&2
	exit 1
}

#Help File
showHelp() {
  cat << EOF
  Usage: ${0##*/} [--tarFileName [Path and File Name]] [--serialNumber [Server Serial Number]] [--workingDirectory [Working Directory Path]] --reportDirectory [Report Directory Path]...
  Where:
      -h                    Display this help and exit
      --tarFileName         Full path to tar file obtained from UCS Managager. (Required)
      --serialNumber        Serial number of server to be evaluated (Required)
      --workingDirectory    Directory where files will be temporarily moved to for processing.
      --ReportDirectory     Directory where finished report will be created.
      -v                    verbose mode. 
EOF
}

function exitRoutine () {
  #Remove any remaining files from the Exit routine. 
  rm -fr $workingDirectory/*
  exit
}

function createWorkingDirectory (){
    #Does the working directory exist?
    writeStatus "Checking for $workingDirectory directory."
    if [ -d $workingDirectory ]
    then 
        writeStatus "Working Directory Exists" "INFO"
        #Make sure it is empty.
        writeStatus "Removing everything from working directory" "INFO"
        rm -rf $workingDirectory/*
        if [ $? != 0 ]; then
            writeStatus "Could not clean up working directory" "FAIL"
        fi
        return
    fi

    #If it isn't, create it
    writeStatus "Creating Working Directory: $workingDirectory"
    mkdir $workingDirectory
    if [ $? != 0 ]; then
        writeStatus "Could not create working directory" "FAIL"
    fi
}

function writeStatus (){
    case $2 in
        FAIL)
           printf "%5s[ ${red} FAIL ${normal} ] ${1}\n" 
           # Begin Exit Reroutine
           exitRoutine
        ;;
        WARN)
            printf "%5s[ ${yellow} WARN ${normal} ] ${1}\n"
        ;;
        INFO)
            printf "%5s[ ${green} INFO ${normal} ] ${1}\n"
        ;;
        *)
            printf "%5s[ ${green} INFO ${normal} ] ${1}\n"
    esac
}

function writeReport (){
    printf "${1}\n" >> $memoryReportFileName
}

function checkTarFile () {
    if [ -s "$tarFileName" ]; then
        writeStatus "Found tar file" "INFO"
        writeStatus "$tarFileName" "INFO"
    else
        writeStatus "Unable to read tar file" "FAIL"
    fi

}

function untarFile () {
    tar -xf "$1" -C "$workingDirectory"
    if [ $? != 0 ]; then
        writeStatus "Unable to extract TAR file " "FAIL"
    fi
}
get-ucsmServerPID (){
    writeStatus "Processing Server Product ID"
    local ucsmServerPIDRaw="$(find "${workingDirectory}/tmp" -type f -iname "*TechSupport.txt" -exec egrep -iE "Board Product Name" {} \; | head -1)"
    writeReport "$ucsmServerPIDRaw"
    writeStatus "Board Product Name(PID): $(echo $ucsmServerPIDRaw | cut -d ":" -f2 | xargs)"
}

get-ucsmServerSerial (){
    writeStatus "Processing Server Serial"
    local ucsmServerSerialRaw="$(find "${workingDirectory}/tmp" -type f -iname "*TechSupport.txt" -exec egrep -iE "Product Serial Number*${SerialNumber}" {} \; | head -1)"
    writeReport "$ucsmServerSerialRaw"
    writeStatus "Server Serial: $(echo $ucsmServerSerialRaw | cut -d ":" -f2 | xargs)"
}

get-ucsmCIMCVersion (){
    writeStatus "Processing Server CIMC Version"
    local ucsmServerVersionRaw="$(find "${workingDirectory}/tmp" -type f -iname "*TechSupport.txt" -exec zegrep -iE "ver:" {} \; | head -1)"
    writeReport "$ucsmServerVersionRaw"
    writeStatus "Server CIMC Firmware Version: $(echo $ucsmServerVersionRaw | cut -d ":" -f2 | xargs)"
}


get-systemInfo () {
    get-ucsmServerPID
    get-ucsmServerSerial
    get-ucsmCIMCVersion
    #TODO Process DimmBL
    #TODO Process MrcOut
    #TODO Process OBFL
        #TODO Find Correctable and Uncorrectable errors
        #TODO Find CATERR if it exists
    #TODO Process Eng if it exists
        #TODO How do we find ADDDC Sparing Issues?
    }

function processTarFile () {
    #Many customers will send logs for way more servers then we need to evaluate.
    #We use the serial number to figure out which one we really need.
    serverTarFilePath=$(find "$workingDirectory" -iname "CIMC*.gz" -exec zegrep --with-filename -iE $serialNumber {} \; | cut -d " " -f3)
    writeStatus "Processing: $serverTarFilePath" "INFO"
    untarFile $serverTarFilePath
    get-systemInfo
}

function validateReportDirectory () {
    #Does the Report directory exist?
    writeStatus "Checking for ${reportDirectory} directory."
    if [ -d "$reportDirectory" ]
    then 
        writeStatus "Report Directory Exists" "INFO"        
    else
        #If it doesn't, create it
        writeStatus "Creating Report Directory: $reportDirectory"
        mkdir $reportDirectory
        if [ $? != 0 ]; then
            writeStatus "Could not create Report directory" "FAIL"
        fi
    fi

    writeStatus "Attempting to create report file" "INFO"
    touch $memoryReportFileName
    if [ $? != 0 ]; then
        writeStatus "Unable to create report file" "FAIL"
    else
        writeStatus "Report File created" "INFO"
    fi
}

#Color Coding for screen output.
green="\e[1;32m"
red="\e[1;31m"
yellow="\e[1;33m"
normal="\e[1;0m"

while :; do
  case $1 in 
    -h|-\?|--help)
		  showHelp			# Display help in formation in showHelp
			exit
		  ;;
		--serial[Nn]umber)
		  if [ "$2" ]; then
			  serialNumber=$2
				shift
		  fi
		  ;;
		--tar[Ff]ile[Nn]ame)
		  if [ "$2" ]; then
			  tarFileName=${2}
				shift
		  fi
		  ;;
		--workingDirectory)
		  if [ $2 ]; then
			  workingDirectory=${2}
				shift
		  fi
		  ;;
		--reportDirectory)
		  if [ $2 ]; then
			  reportDirectory=$2
				shift
		  fi
		  ;;
		-v|--verbose)
		  verbose=$((verbose + 1))
		  ;;
		*)
		  break
  esac
	shift
done

if [ -z "$serialNumber" ] || [ -z "$tarFileName" ]
then
    echo "serialNumber and tarFileName are requried fields"
    showHelp
    exit
fi

#Memory report file - Time Stamped
memoryReportFileName="${reportDirectory}/$(date +%Y%m%d-%H%M%S)-MemoryReport.txt"
writeStatus "Memory Report will be written here: ${memoryReportFileName}" "INFO"


validateReportDirectory
createWorkingDirectory
checkTarFile
untarFile "$tarFileName"
processTarFile