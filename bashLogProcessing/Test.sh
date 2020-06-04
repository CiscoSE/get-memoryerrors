#!/bin/bash

function get-Serialandtar (){
    printf "Enter the serial number to find memory errors for:\n"
    read serialNumber
    printf "Enter the tar file full name with path:"
    read tarFileName
}

get-Serialandtar
printf "TAR File Location: ${tarFileName}"
printf "Serial Number: ${serialNumber}"