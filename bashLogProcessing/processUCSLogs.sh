#!/bin/bash

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

sleepTimer='5'

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
      --noReport            Prevents the Reports from by written. Used for debugging
      -v                    verbose mode. 
EOF
}

function exitRoutine () {
  #Remove any remaining files from the Exit routine. 
  #rm -fr $workingDirectory/*
  exit
}

function createWorkingDirectory (){
    #Does the working directory exist?
    writeStatus "Checking for $workingDirectory directory."
    if [ -d "${workingDirectory}" ];then 
        writeStatus "Working Directory Exists" "INFO"
        #Make sure it is empty.
        writeStatus "Removing working directory to ensure we start out clean" "INFO"
        rm -rf "${workingDirectory}"
    fi

    #If it isn't, create it
    writeStatus "Creating Working Directory: ${workingDirectory}"
    mkdir "${workingDirectory}"
    if [ $? != 0 ]; then
        writeStatus "Could not create working directory" "FAIL"
    fi
}

function writeStatus (){
    local lineOutput="$(echo -e "$1")"
    case $2 in
        FAIL)
           printf "%5s[ ${red} FAIL ${normal} ] ${1}\n" 
           # Begin Exit Reroutine
           exitRoutine
        ;;
        WARN)
            printf "    [ ${yellow} %s ${normal} ]\t%s \n" "WARN" "$lineOutput"
        ;;
        INFO)
            printf "    [ ${green} %s ${normal} ]\t%s \n" "INFO" "$lineOutput"
        ;;
        *)
            printf "    [ ${green} %s ${normal} ]\t%s \n" "INFO" "$lineOutput"
    esac
}

function writeReport (){
    if [ "$noReport" = 'true' ]; then 
        writeStatus "Report Not being Generated"
        return 
    fi
    if [ -z $2 ]; then 
        local dimmName='none'
    else
        local dimmName="$2"
    fi
    echo -e "${1}" >> "${reportDirectory}/${serialNumber}/${serialNumber}-${dimmName}-${memoryReportDateTime}.report"
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
    writeStatus "Unpacking tar file: ${1}" "INFO"
    writeStatus "Destination: ${workingDirectory}" "INFO"
    tar -xf "${1}" -C "${workingDirectory}"
    if [ $? != 0 ]; then
        writeStatus "Unable to extract TAR file " "FAIL"
    fi
}
get-techSupportFileName () {
    writeStatus "Looking for TechSupport.txt files commonly found on blades" "INFO"
    #Most blades fall into this catagory.
    techSupportFileName="$(find "${workingDirectory}/tmp" -type f -iname "*TechSupport.txt")"
    #Most Stand alone fall into this catagory
    if [ -z "$techSupportFileName" ]; then
        writeStatus "We didn't find TechSupport.txt. Looking for tech_support often found in C series" "INFO"
        techSupportFileName="$(find "${workingDirectory}/tmp" -type f -iname 'tech_support')"
    fi 
    if [ -z "${techSupportFileName}" ]; then
        writeStatus "No Tech support file found" "FAIL"
    fi
    writeStatus "techSupport File Path: ${techSupportFileName}"
}
get-ucsmServerPID (){
    writeStatus "Processing Server Product ID"
    local ucsmServerPIDRaw="$(egrep -iE 'Board Product Name' "${techSupportFileName}" | head -1)"
    serverProperties="${ucsmServerPIDRaw}"
    writeStatus "Board Product Name(PID): $(echo $ucsmServerPIDRaw | cut -d ":" -f2 | xargs)"
}

get-ucsmServerSerial (){
    writeStatus "Processing Server Serial"
    local ucsmServerSerialRaw="$(egrep -iE "Product Serial Number*${SerialNumber}" "${techSupportFileName}" | head -1)"
    serverProperties="$serverProperties\n$ucsmServerSerialRaw"
    writeStatus "Server Serial: $(echo $ucsmServerSerialRaw | cut -d ":" -f2 | xargs)"
}

get-ucsmCIMCVersion (){
    writeStatus "Processing Server CIMC Version"
    local ucsmServerVersionRaw="$(egrep -iE "ver:" "${techSupportFileName}" | head -1)"
    serverProperties="$serverProperties\n$ucsmServerVersionRaw"
    writeStatus "Server CIMC Firmware Version: $(echo $ucsmServerVersionRaw | cut -d ":" -f2 | xargs)"
}
returnDimmsWithErrors () {
    dimmsWithErrorsFull="$(echo "$1" | egrep -ioE "[A-Z][0-9] \([0-9A-F]{2}\).*([1-9][0-9]*.*)" | sed -e 's/  */ /g')"
}

reportDimmsWithErrors () {
    if [ -z "$1" ]; then
        dimmsWithErrors+=("none")
        writeStatus "No errors found in DimmBL log." "INFO"
        writeStatus "Writting Server properties to generic log file." "INFO"
        writeReport "################ Server Preperties ################\n$serverProperties\n################################################"
        writeReport "================ DIMM Error Report From DimmBL Log ================"
        writeStatus "Writing DimmBL error table to generic log file." "INFO"
        writeReport "$dimmErrorCountFullList"
        return
    fi
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
        writeReport "################ Server Preperties ################\n$serverProperties\n################################################" "$dimmWithErrors"
        if [ ! -z "$dimmWithErrors" ]; then
            dimmsWithErrors+=("${dimmWithErrors}")
            writeStatus "DIMM $dimmWithErrors has errors" "WARN"
            writeReport "================ DIMM $dimmWithErrors Error Report ================" "$dimmWithErrors"
        fi
        writeStatus "\tCorrectable Errors Total:\t$correctableErrTotal" "WARN"
        writeReport "\tCorrectable Errors Total:\t$correctableErrTotal" "$dimmWithErrors"
        writeStatus "\tCorrectable Errors This Boot:\t$correctableErrThisBoot" "WARN"
        writeReport "\tCorrectable Errors This Boot:\t$correctableErrThisBoot" "$dimmWithErrors" 
        writeStatus "\tUncorrectable Errors Total:\t$uncorrectableErrTotal" "WARN" 
        writeReport "\tUncorrectable Errors Total:\t$uncorrectableErrTotal" "$dimmWithErrors"
        writeStatus "\tUncorrectable Errors This Boot:\t$uncorrectableErrThisBoot" "WARN"
        writeReport "\tUncorrectable Errors This Boot:\t$uncorrectableErrThisBoot" "$dimmWithErrors"        
        sleep "${sleepTimer}s"
    done <<< "$1"
    # Some DIMM errors are not correctable or uncorrectable, and we still need to report System Related entires
}

process-DimmBL (){
writeStatus "Searching for DIMM Errors in DimmBL.log"
    #Location is not stable, so we search broadly in var
    local ucsmDimmBlFileLoc="$(find "${workingDirectory}/var" -type f -iname "DimmBL.log" -o -iname "DIMM-BL_Status.txt" | head -1)"
    if [ -z "${ucsmDimmBlFileLoc}" ];then
        writeStatus "DimmBL.log Location not found. No reporting from this file is possible" "WARN"
        return
    fi
    
    writeStatus "DimmBL.log Location: $ucsmDimmBlFileLoc"
    dimmErrorCountFullList="$(cat "${ucsmDimmBlFileLoc}" | awk '/[-\s]*PER DIMM ERROR COUNTS/,/^ *$/')"
    returnDimmsWithErrors "${dimmErrorCountFullList}"
    reportDimmsWithErrors "$dimmsWithErrorsFull"
}
function get-MrcOutPathNormal (){
     mrcOutFilePath="$(find "${workingDirectory}" -type f -iname "MrcOut.txt" -o -iname MrcOut | head -1)"
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
        tar -xf "$nvramgzFilePath" -C "${workingDirectory}"
        mrcOutFilePath="$(find "${workingDirectory}/nv" -type f -iname "MrcOut" | egrep -iE "MrcOut$|MrcOut.txt$" | head -1)"
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
    sleep "${sleepTimer}s"
}

report-mrcOutSettings(){
    if [ -z "$1" ]; then
        writeStatus "ADDDC Sparing and Post Package Repair not enabled"
    else 
        while IFS= read -r line; do 
            local property="$(echo "$line" | cut -d ':' -f1 | xargs)"
            local propVal="$(echo "$line" | cut -d ':' -f2 | xargs)"
            writeStatus "\t$property:\t$propVal" "INFO"
            writeReport "\t$property:\t$propVal" "$2"
        done <<< "$1"   
        sleep "${sleepTimer}s"
    fi
}

process-MrcOutForDimms (){
    # Things that we would need for every DIMM that has errors.
    mrcOutDimmInventory=$(cat "$mrcOutFilePath" | awk '/DIMM Inventory:/,/Total Memory*/')
    mrcOutDimmStatus=$(cat "$mrcOutFilePath" | awk '/DIMM Status:/,/Disabled Mem*/')
    mrcOutDimmSettings=$(cat "$mrcOutFilePath" | egrep -iE "Select Memory RAS|Post Package Repair")
    for dimm in "${dimmsWithErrors[@]}"; do
        if [ ! -z "$mrcOutDimmInventory" ] && [ "$dimm" != "none" ]; then 
            report-MrcOutInventory "$(echo "$mrcOutDimmInventory" | egrep -iE "^$dimm" )" "$dimm"
        else
            writeReport "\n\n$mrcOutDimmInventory"
        fi
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
    fi
}

function write-ToEachDimmReport () {
    for dimm in "${dimmsWithErrors[@]}"; do
        writeReport "$1" "${dimm}"
    done
}

function process-obflCorrectableErrors () {
    local correctableErrorList=("$@")
    if [ -z "$correctableErrorList" ]; then
        #write to each log that no entries were found.
        local statusMessage1="---------- No Correctable errors found in obfl logs ----------"
        write-ToEachDimmReport "\n$statusMessage1\n"
        writeStatus "$statusMessage1"
        return
    fi
    for dimm in "${dimmsWithErrors[@]}"; do
        if [ "$dimm" = "none" ]; then
            writeStatus "====== OBFL Correctable DIMM Data ======" "INFO"
            writeReport "\n====== Start Correctable OBFL DIMM Data ======" "$dimm"
            for line in "${correctableErrorList[@]}"; do
                writeStatus "\t$(echo $line | cut -d '|' -f2,3,4,5)" "WARN"
                writeReport "\t$(echo $line | cut -d '|' -f2,3,4,5)" "$dimm"
            done
        else
            writeStatus "====== OBFL Correctable DIMM Data for $dimm ======" "INFO"
            writeReport "\n====== Start Correctable OBFL DIMM Data for $dimm ======" "$dimm"
            for line in "${correctableErrorList[@]}"; do
                if echo "$line" | egrep -qE "DIMM $dimm"; then
                    writeStatus "\t$(echo $line | cut -d '|' -f2,3,4,5)" "WARN"
                    writeReport "\t$(echo $line | cut -d '|' -f2,3,4,5)" "$dimm"
                fi
            done
        fi
    done
}

function process-obflUncorrectableErrors () {
    local uncorrectableErrorList=("$@")
    if [ -z "$uncorrectableErrorList" ]; then
        #write to each log that no entries were found.
        local statusMessage1="---------- No Uncorrectable errors found in obfl logs ----------"
        write-ToEachDimmReport "\n$statusMessage1\n"
        writeStatus "$statusMessage1"
        return
    fi
    for dimm in "${dimmsWithErrors[@]}"; do
        if [ "$dimm" = "none" ]; then
            writeStatus "====== OBFL Uncorrectable DIMM Data ======" "INFO"
            writeReport "====== Start Uncorrectable OBFL DIMM Data ======" "$dimm"
            for line in "${uncorrectableErrorList[@]}"; do
                writeStatus "\t$(echo $line | cut -d '|' -f2,3,4,5,6)" "WARN"
                writeReport "\t$(echo $line | cut -d '|' -f2,3,4,5,6)" "$dimm"
            done
        else
            writeStatus "====== OBFL Uncorrectable DIMM Data for $dimm ======" "INFO"
            writeReport "====== Start Uncorrectable OBFL DIMM Data for $dimm ======" "$dimm"
            for line in "${uncorrectableErrorList[@]}"; do
                if echo "$line" | egrep -qE "DIMM $dimm|${dimm}_ECC"; then
                    writeStatus "\t$(echo $line | cut -d '|' -f2,3,4,5,6)" "WARN"
                    writeReport "\t$(echo $line | cut -d '|' -f2,3,4,5,6)" "$dimm"
                fi
            done
        fi
    done
}

function process-obflCaterr () {
    local caterrList=("$@")
    if [ -z "$caterrList" ]; then
        #write to each log that no entries were found.
        local statusMessage1="---------- No CATERR errors found in obfl logs ----------"
        write-ToEachDimmReport "\n$statusMessage1\n\n"
        writeStatus "$statusMessage1"
        return
    fi
    writeStatus "====== OBFL CATERR Data ======" "WARN"
    write-ToEachDimmReport "====== Start CATERR Data ======"
    for line in "${caterrList[@]}"; do
        if echo "$line" | grep -q '|' ; then
            caterrLine="\t$(echo $line | cut -d '|' -f2,3,4,5)"
        else
            caterrLine="$line"
        fi
        writeStatus "${caterrLine}" "WARN"
        for dimm in "${dimmsWithErrors[@]}"; do
            writeReport "\t${caterrLine}" "$dimm"
        done
    done
}

function process-obfl () {
        declare -a obflCorrectableList
        declare -a obflUncorrectableList
        declare -a obflCaterrList
    # Find Correctable errors or CATERR and write them to the log file. 
    writeStatus "\tSearching OBFl logs for errors" "INFO"
    local obflFirstPass="$(find "${workingDirectory}/obfl" -type f -exec egrep -iE "correct|CATERR|Blacklisted by BMC" {} \;)"
    writeStatus "\tOBFL lines found:    $(echo "$obflFirstPass" | wc -l)"
    # Break down each set of logs into its own variable.
    while IFS= read -r line; do
        if echo "$line" | egrep -qiE " correctable ECC"; then 
            obflCorrectableList+=("${line}")
        fi
        if echo "$line" | egrep -qiE "uncorrectable|Non-recoverable|Blacklisted by BMC"; then 
            obflUncorrectableList+=("${line}") 
        fi
        if echo "$line" | egrep -qE "CATERR"; then 
            obflCaterrList+=("${line}")
        fi
    done <<< "${obflFirstPass}"
    
    process-obflCorrectableErrors "${obflCorrectableList[@]}"
    process-obflUncorrectableErrors "${obflUncorrectableList[@]}"
    process-obflCaterr "${obflCaterrList[@]}"
}

function process-techSupport (){
    techsupportFilePath="$(find "${workingDirectory}/tmp" -type f -iname "CIMC*TechSupport.txt" -o -iname "tech_support" | head -1)"
    adddcSparingEventsCount="$(egrep -E "ADDDC|PPR" "$techsupportFilePath" | wc -l)"
    adddcSparingEvents="$(egrep -E "ADDDC|PPR" "$techsupportFilePath")"
    writeStatus "========== ADDDC /PPR Events from Tech Support Log =========="
    write-ToEachDimmReport "\n========== ADDDC / PPR Events from Tech Support Log ==========\n"
    #Every line needs to go somoewhere. Either to a file it belongs to, or to every file we are writting to.
    while IFS= read -r line; do
        lineWritten="false"
        if [ "${dimmsWithErrors[0]}" = "none" ] && [ $adddcSparingEventsCount -gt 0 ];then
            #If none is reported in dimmsWithErrors, write it to done and move on
            writeStatus "\t$(echo "$line" | cut -d '|' -f 2,3,4,5,6)"
            writeReport "$(echo "$line" | cut -d '|' -f 2,3,4,5,6)" "none"
            lineWritten="true"
        fi
        if [ $lineWritten = "false" ] && [ $adddcSparingEventsCount -gt 0 ]; then
            #if the ADDDC / PPR event can be matched to a DIMM showing errors, we  report it only in that file.
            for dimm in "${dimmsWithErrors[@]}"; do
                if echo "$line" | egrep -qiE "$dimm"; then
                    writeStatus "\t$(echo "$line" | cut -d '|' -f 2,3,4,5,6)"
                    writeReport "$(echo "$line" | cut -d '|' -f 2,3,4,5,6)" "$dimm"
                    lineWritten="true"
                fi
            done
        fi
        if [ $lineWritten = "false" ] && [ $adddcSparingEventsCount -gt 0 ]; then
            # if the ADDDC / PPR event cannot be associated to a DIMM, then write the event to all DIMM file reports
            writeStatus "\t$(echo "$line" | cut -d '|' -f 2,3,4,5,6)"
            write-ToEachDimmReport "$(echo "$line" | cut -d '|' -f 2,3,4,5,6)"
        fi
    done <<< "${adddcSparingEvents}"
}

function get-systemInfo () {
    get-techSupportFileName
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
    writeStatus "Processing tar.gz files" "INFO"
    serverTarFilePath="$(find "${workingDirectory}" -iname "C*.tar.gz" -exec zegrep --with-filename -ilE $serialNumber {} \;)"
    tarFilesReturned="$(echo "$serverTarFilePath" | wc -l)"
    if [ "$tarFilesReturned" -ne 1 ]; then
        writeStatus "Returned File Count for tar.gz files is: ${tarFilesReturned}" "INFO"
        writeStatus "Check your serial number. We find a single CIMC file with the serial number provided, but that isn't what we found." "FAIL"
        exit
    fi
    writeStatus "Processing: ${serverTarFilePath}" "INFO"
    untarFile "${serverTarFilePath}"
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
		--working[Dd]irectory)
		  if [ "$2" ]; then
			  workingDirectory=${2}
				shift
		  fi
		  ;;
		--reportDirectory)
		  if [ "$2" ]; then
			  reportDirectory=$2
				shift
		  fi
		  ;;
        --[Nn]o[rR]eport)
              noReport="true"
                shift
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

declare -a dimmsWithErrors

validateReportDirectory
createWorkingDirectory
if [ ${tarFileName: -4} = '.tar' ]; then
    checkTarFile
    untarFile "${tarFileName}"
elif [ ${tarFileName: -6} = 'tar.gz' ]; then
    cp "$tarFileName" "${workingDirectory}"
else
    writeStatus "File must end in .tar or .tar.gz, or we wont process it." "FAIL"
fi
processTarFile