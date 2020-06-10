#!/bin/zsh

# Copyright (c) 2020 Cisco and/or its affiliates.
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
    if [ -d $workingDirectory ];then 
        writeStatus "Working Directory Exists" "INFO"
        #Make sure it is empty.
        writeStatus "Removing working directory to ensure we start out clean" "INFO"
        rm -rf $workingDirectory
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
    printf "${1}\n" >> "$reportDirectory/$serialNumber/$serialNumber-$2-$memoryReportDateTime.report"
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
    serverProperties="${ucsmServerPIDRaw}"
    writeStatus "Board Product Name(PID): $(echo $ucsmServerPIDRaw | cut -d ":" -f2 | xargs)"
}

get-ucsmServerSerial (){
    writeStatus "Processing Server Serial"
    local ucsmServerSerialRaw="$(find "${workingDirectory}/tmp" -type f -iname "*TechSupport.txt" -exec egrep -iE "Product Serial Number*${SerialNumber}" {} \; | head -1)"
    serverProperties="$serverProperties\n$ucsmServerSerialRaw"
    writeStatus "Server Serial: $(echo $ucsmServerSerialRaw | cut -d ":" -f2 | xargs)"
}

get-ucsmCIMCVersion (){
    writeStatus "Processing Server CIMC Version"
    local ucsmServerVersionRaw="$(find "${workingDirectory}/tmp" -type f -iname "*TechSupport.txt" -exec zegrep -iE "ver:" {} \; | head -1)"
    serverProperties="$serverProperties\n$ucsmServerVersionRaw"
    writeStatus "Server CIMC Firmware Version: $(echo $ucsmServerVersionRaw | cut -d ":" -f2 | xargs)"
}
returnDimmsWithErrors () {
    dimmsWithErrors="$(echo "$1" | egrep -ioE "[A-Z][0-9] \([0-9A-F]{2}\).*([1-9][0-9]*.*)" | sed -e 's/  */ /g')"
}

reportDimmsWithErrors () {
    dimmsWithErrors=''
    while IFS= read -r line; do
        correctableErrTotal=''
        correctableErrThisBoot=''
        uncorrectableErrTotal=''
        uncorrectableErrThisBoot=''
        local dimmWithErrors=$(echo "$line" | xargs | cut -d ' ' -f1)
        local correctableErrTotal=$(echo "$line" | xargs | cut -d ' ' -f3) 
        local correctableErrThisBoot=$(echo "$line" | xargs | cut -d ' ' -f4)
        local uncorrectableErrTotal=$(echo "$line" | xargs | cut -d ' ' -f5) 
        local uncorrectableErrThisBoot=$(echo "$line" | xargs | cut -d ' ' -f6)
        writeStatus "DIMM $dimmWithErrors has errors" "WARN"
        writeReport "================ DIMM $dimmWithErrors Error Report ================" "$dimmWithErrors"
        writeReport "################ Server Preperties ################\n$serverProperties\n################################################" "$dimmWithErrors"
        if [ ! -z $dimmWithErrors ]; then
            if [ -z $dimmsWithErrors ]; then
                dimmsWithErrors="$dimmWithErrors"
            else
                dimmsWithErrors="$dimmsWithErrors$dimmWithErrors"
            fi
        fi
        writeStatus "\tCorrectable Errors Total:\t$correctableErrTotal" "WARN"
        writeReport "\tCorrectable Errors Total:\t$correctableErrTotal" "$dimmWithErrors"
        writeStatus "\tCorrectable Errors This Boot:\t$correctableErrThisBoot" "WARN"
        writeReport "\tCorrectable Errors This Boot:\t$correctableErrThisBoot" "$dimmWithErrors" 
        writeStatus "\tUncorrectable Errors Total:\t$uncorrectableErrTotal" "WARN" 
        writeReport "\tUncorrectable Errors Total:\t$uncorrectableErrTotal" "$dimmWithErrors"
        writeStatus "\tUncorrectable Errors This Boot:\t$uncorrectableErrThisBoot" "WARN"
        writeReport "\tUncorrectable Errors This Boot:\t$uncorrectableErrThisBoot" "$dimmWithErrors"        
        sleep 5s
    done <<< "$1"
}

process-DimmBL (){
writeStatus "Searching for DIMM Errors in DimmBL.log"
    #Location is not stable, so we search broadly in var
    local ucsmDimmBlFileLoc="$(find "${workingDirectory}/var" -type f -iname "DimmBL.log" | head -1)"
    if [ -z $ucsmDimmBlFileLoc ];then
        writeStatus "DimmBL.log Location not found. No reporting from this file is possible" "WARN"
        return
    fi
    
    writeStatus "DimmBL.log Location: $ucsmDimmBlFileLoc"
    local dimmErrorCountFullList="$(cat $ucsmDimmBlFileLoc | awk '/[-\s]*PER DIMM ERROR COUNTS/,/^ *$/')"
    dimmsWithErrors=''
    returnDimmsWithErrors "${dimmErrorCountFullList}"
    reportDimmsWithErrors "$dimmsWithErrors"

}
function get-MrcOutPathNormal (){
     mrcOutFilePath="$(find $workingDirectory -type f -iname "MrcOut.txt" | head -1)"
}
function get-MrcOutPathNv (){
    # Looking for the MrcOut file within the nvram gz file normally found in ./tmp/
    # Because the folder has a random sub folder name, we are using find to locate it.
    writeStatus "MrcOut.txt not found in BIOS directory. Trying nvram.tar.gz file" "INFO"
    nvramgzFilePath="$(find "$workingDirectory/tmp" -type f -iname "*-nvram.tar.gz" | head -1)"
    if [ -z "$nvramgzFilePath" ]; then
        #We didn't find the nvram.tar.gz file either with an MrcOut file. We are kind of out options. 
        writeStatus "MrcOut file cannot be found. Serials numbers and black listing data may not be available." "WARN"
        return
    else
        #Unzipping nvram.tar.gz file to access MrcOut file.
        tar -xf "$nvramgzFilePath" -C "$workingDirectory"
        mrcOutFilePath="$(find "$workingDirectory/nv" -type f -iname "MrcOut" | egrep -iE "MrcOut$|MrcOut.txt$" | head -1)"
    fi
}

function locateMrcOut () {
    writeStatus "Searching for MrcOut.txt"
    #We prefer this one as it is the easiest to find.
    get-MrcOutPathNormal   
    if [ -z "$mrcOutFilePath" ]; then
        # Not completely unexpected...
        get-MrcOutPathNv
    fi
}

function report-MrcOutInventory () {
    writeStatus "Inventory for $2 will be reported"

    local mrcoutDimmManufacture="$(echo "$1" | cut -d '|' -f7 | xargs | cut -d " " -f1 | xargs)"
    local mrcoutDimmSize="$(echo "$1" | cut -d '|' -f2 | xargs)"
    local mrcoutDimmSpeed="$(echo "$1" | cut -d '|' -f6 | xargs)"
    local mrcoutDimmSerial="$(echo "$1" | cut -d '|' -f10 | xargs)"
    local mrcoutDimmVendorPID="$(echo "$1" | cut -d '|' -f11 | xargs)"
    
    writeReport "====== MrcOut DIMM Data for $2 ======" "$2"
    writeReport "\tManufacture:\t\t$mrcoutDimmManufacture" "$2"
    writeReport "\tSize:\t\t\t$mrcoutDimmSize" "$2"    
    writeReport "\tSerial:\t\t\t$mrcoutDimmSerial" "$2"
    writeReport "\tVendor PID:\t\t$mrcoutDimmVendorPID" "$2"

    writeStatus "====== MrcOut DIMM Data for $2 ======" "INFO"
    writeStatus "\tManufacture:\t\t$mrcoutDimmManufacture"
    writeStatus "\tSize:\t\t\t$mrcoutDimmSize" 
    writeStatus "\tSerial:\t\t\t$mrcoutDimmSerial"
    writeStatus "\tVendor PID:\t\t$mrcoutDimmVendorPID" 
    sleep 5s
}

report-mrcOutSettings(){
    if [ -z "$1" ]; then
        writeStatus "ADDDC Sparing and Post Package Repair not enabled"
    else   
        for line in $1; do 
            local property="$(echo "$line" | cut -d ':' -f1 | xargs)"
            local propVal="$(echo "$line" | cut -d ':' -f2 | xargs)"
            writeStatus "\t$property:\t$propVal" "INFO"
            writeReport "\t$property:\t$propVal" "$2"
        done
        sleep 5s
    fi
}

process-MrcOutForDimms (){
    # Things that we woud need for every DIMM that has errors.
    mrcOutDimmInventory=$(cat "$mrcOutFilePath" | awk '/DIMM Inventory:/,/Total Memory*/')
    mrcOutDimmStatus=$(cat "$mrcOutFilePath" | awk '/DIMM Status:/,/Disabled Mem*/')
    mrcOutDimmSettings=$(cat "$mrcOutFilePath" | egrep -iE "Select Memory RAS|Post Package Repair")

    for dimm in $dimmsWithErrors; do
        if [ ! -z "$mrcOutDimmInventory" ]; then report-MrcOutInventory "$(echo "$mrcOutDimmInventory" | egrep -iE "^$dimm" )" "$dimm"; fi
        report-mrcOutSettings "${mrcOutDimmSettings}" "$dimm"
        if [ ! -z "$mrcOutDimmStatus" ]; then writeReport "\n\n${mrcOutDimmStatus}" "$dimm"; fi

    done
}

function process-MrcOut () {
    #If we can find it, we want to process it. In some cases it cannot be found.
    # This is false until we find it. If we don't find it we need to get the serial numbers
    # from the dimmsData folder, which is more difficult.
    MrcOutFound=$false 
    locateMrcOut
    writeStatus "MrcOut Path:\t${mrcOutFilePath}"
    if [ -z "$mrcOutFilePath" ];then
        writeStatus "MrcOut file was not found and cannot be processed" "WARN"
    else
        process-MrcOutForDimms
    # TODO Get ADDDC Sparing information
    fi
}

function get-obflUncorrectableErrors (){
    writeStatus "\t====== OBFL Uncorrectable DIMM Data for $2 ======" "INFO"
    writeReport "\t====== Start Uncorrectable OBFL DIMM Data for $2 ======" "$2"

    while IFS= read -r line; do
        local obflUncorrectableTimeStamp="$(echo "$line" | cut -d '|' -f2 | xargs )"
        local obflUncorrectableSystemState="$(echo "$line" | cut -d '|' -f5 | cut -d ':' -f1 | xargs)"
        local obflUncorrectableSystemError="$(echo "$line" | cut -d '|' -f6 | xargs)"

        writeStatus "\t$obflUncorrectableTimeStamp\t\t$obflUncorrectableSystemState\t${obflUncorrectableSystemError}" "WARN"
        writeReport "\t$obflUncorrectableTimeStamp\t\t$obflUncorrectableSystemState\t${obflUncorrectableSystemError}" "$2"
    done <<< $1 
    
    writeReport "\t====== End Uncorrectable OBFL DIMM Data for $2 ======\n" "$2"
    sleep 5s
}
function get-obflCorrectableErrors (){
    writeStatus "\t====== OBFL Correctable DIMM Data for $2 ======" "INFO"
    writeReport "\t====== Start Correctable OBFL DIMM Data for $2 ======" "$2"

    while IFS= read -r line; do
        local obflCorrectableSystemError="$(echo "$line" | cut -d '|' -f2,5 | xargs)"
        #echo "$line"
        #exit

        writeStatus "\t$obflCorrectableSystemError" "WARN"
        writeReport "\t$obflCorrectableSystemError" "$2"
    done <<< $1
    
    writeReport "\t====== End Correctable OBFL DIMM Data for $2 ======\n" "$2"
    sleep 5s
}

function get-obflCATERR (){
    # CATERR log entires are rarely DIMM specific, so we will include these logs in every DIMM report.
    writeStatus "\t====== OBFL CATERR Data ======" "INFO"
    writeReport "\t====== Start CATERR OBFL ======" "$2"

    while IFS= read -r line; do
        local obflCATErr="$(echo "$line" | cut -d '|' -f2,3,4,5 | xargs )"
        writeStatus "\t$obflCATErr" "WARN"
        writeReport "\t$obflCATErr" "$2"
    done <<< $1
    
    writeReport "\t====== End CATERR OBFL ======\n" "$2"
    sleep 5s
}

function process-obfl () {
    # Find Correctable errors or CATERR and write them to the log file. 
    writeStatus "Searching OBFl logs for errors" "INFO"
    obflFirstPass="$(find "$workingDirectory/obfl" -type f -exec egrep -iE "correct|CATERR" {} \;)"
    for dimm in $dimmsWithErrors; do
        #Find only OBFL log entries for DIMMs we are intrested in.
        get-obflUncorrectableErrors "$(echo "${obflFirstPass}" | egrep -iE "uncorrect.*${dimm}")" "$dimm"
        get-obflCorrectableErrors "$( egrep -iE " correctable ECC" <<< $obflFirstPass | egrep -E "DIMM $dimm ")" "$dimm"
        get-obflCATERR "$(echo "$obflFirstPass" | egrep -E "CATERR")" "$dimm"
    done
}

function process-techSupport (){
    techsupportFilePath="$(find "$workingDirectory/tmp" -type f -iname "CIMC*TechSupport.txt" | head -1)"
    adddcSparingEvents="$(egrep -E "ADDDC|PPR" "$techsupportFilePath")"
    if [ ! -z "adddcSparingEvents" ]; then
        writeStatus "\t====== Tech Support ADDDC Sparing Events ======"
        while IFS= read -r line; do
            # We have to figure out the DIMM for each event if we want this to work out properly.
            adddcSparingDimm="$(echo "$line" | cut -d '|' -f6 | xargs | egrep -oE "[A-Z][1-3]\.$" | sed 's/\.$//')"
            if [ ! -z "$adddcSparingDimm" ]; then
                adddcSparingEventLimited="$(echo "$line" | cut -d '|' -f2,3,4,5,6 )"
                writeStatus "====== Dimm $adddcSparingDimm has ADDDC Sparing Events ======" "WARN"
                writeStatus "$adddcSparingEventLimited" "WARN"
                writeReport "====== Dimm $adddcSparingDimm has ADDDC Sparing Events ======\n$adddcSparingEventLimited" "$adddcSparingDimm"
                sleep 5s
            else
                #we cannot write it to the disk report, write a big warning to the screen
                writeStatus "$line" "WARN"
                writeStatus "========================================" "WARN"
                writeStatus "| ADDDC Sparing Events were found, but |" "WARN"
                writeStatus "| could not be associated with a DIMM  |" "WARN"
                writeStatus "| These are not written to the report  |" "WARN"
                writeStatus "| files.                               |" "WARN"
                writeStatus "========================================" "WARN"
                sleep 10s
            fi
        done <<< $adddcSparingEvents
    fi
}

function get-systemInfo () {
    get-ucsmServerPID
    get-ucsmServerSerial
    get-ucsmCIMCVersion
    process-DimmBL    
    process-MrcOut
    process-techSupport
    process-obfl
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
    writeStatus "Checking for ${reportDirectory}/${serialNumber} directory."
    if [ -d "${reportDirectory}/${serialNumber}" ]
    then 
        writeStatus "Report Directory Exists" "INFO"        
    else
        #If it doesn't, create it
        writeStatus "Creating Report Directory: ${reportDirectory}/${serialNumber}"
        mkdir -p "${reportDirectory}/${serialNumber}"
        if [ $? != 0 ]; then
            writeStatus "Could not create Report directory" "FAIL"
        fi
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
memoryReportDateTime="$(date +%Y%m%d-%H%M%S)"
writeStatus "Memory Report will be written here: ${memoryReportFileName}" "INFO"


validateReportDirectory
createWorkingDirectory
checkTarFile
untarFile "$tarFileName"
processTarFile