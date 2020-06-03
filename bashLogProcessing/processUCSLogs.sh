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
  if [ "${2}" = "FAIL" ]; then 
    printf "%5s[ ${red} FAIL ${normal} ] ${1}\n"
    # Begin Exit Reroutine
    exitRoutine
  fi
  
  printf "%5s[ ${green} INFO ${normal} ] ${1}\n"

  if [ "${writeLog}" = 'enabled' ]; then
    printf "%5s[ ${green} INFO ${normal} ] ${1}\n" >> $writeLogFile
  fi
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
    tar -xf "$tarFileName" -C "$workingDirectory"
    if [ $? != 0 ]; then
        writeStatus "Unable to extract TAR file " "FAIL"
    fi
}

function processTarFile () {
    serverTarFilePath=$(find "$workingDirectory" -iname "CIMC*.gz" -exec zegrep --with-filename -iE $serialNumber {} \; | cut -d " " -f3)
    writeStatus "Processing: $serverTarFilePath" "INFO"
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

createWorkingDirectory
checkTarFile
untarFile
processTarFile