#!/bin/bash

function get-Serialandtar (){
    printf "Enter the serial number to find memory errors for:\n"
    read serialNumber
    printf "Enter the tar file full name with path:\n"
    read tarFileName
}

function print-tar (){
   printf "TAR File Location: ${tarFileName}\n" 

}

function print-serial (){
   printf "Serial Number: ${serialNumber}\n" 

}

get-Serialandtar
print-serial
print-tar
