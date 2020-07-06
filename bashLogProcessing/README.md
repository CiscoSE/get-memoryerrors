processUCSLogs.sh is used to simplify visibility into UCS server log files when assessing events related to memory. It will process .tar CIMC files from UCS Manager or .tar.gz files from stand-alone C series servers. Please consult the Cisco Web Site for current information on downloading these files.

[Visual Guide to Collect UCS Tech Support Files - B, C and S Series](https://www.cisco.com/c/en/us/support/docs/servers-unified-computing/ucs-infrastructure-ucs-manager-software/211587-Visual-Guide-to-collect-UCS-Tech-Support.html)

This script searches common files in UCS Tech Support logs for common memory related information and consolidates that data into a single report. The following files are currently searched by this tool:

- DimmBL.log - This file is used to identify DIMMs with recently reported errors. When errors are found in the DimmBL.log file, individual reports are generated for each DIMM showing errors. When no errors are found in this log, a consolidated reported is generated to help with further review.
- MrcOut - Serial number, black listing and ADDDC sparing / Post Package repair (PPR) information is collected from this log, when available. 
- TechSupport.txt / tech_support - Used to identify firmware version, model, and blade related ADDDC / PPR related events.
- obfl Logs - Events related to CATERR, Correctable and Uncorrectable ECC errors are obtained from these files. When errors are identified in the DimmBL.log, we will match them to the DIMM report generated. CATERR events are reported to the consolidated log, or to each individual DIMM report depending on the types of report generated.
    - Note that not all OBFL related events are written to reports.
- eng-repo logs - For stand-alone C series, eng-repo logs are also searched for ADDDC sparing / PPR logs, if present. 

This script does not address ever kind of possible error situation and is intended to help provide an initial cursory look at logs to find common issues. Cisco TAC may still require additional information from the Tech Support logs, and this script is not intended to over ride TAC direction. 

Additional information regarding the assessment of memory related issues can be found on the Cisco website:

[Troubleshoot DIMM memory issues in UCS](https://www.cisco.com/c/en/us/support/docs/servers-unified-computing/ucs-b-series-blade-servers/200775-Troubleshoot-DIMM-memory-issues-in-UCS.html)


To run this script, you need the following information:

- The tar file or tar.gz file from UCS Manager or the CIMC. This report will not work with UCSM tech support files for UCS Manager. The .tar file must contain the server tech support information for the server serial number to be assessed.
    - This script will only assess one system at a time.
- The serial number of the server to be assessed. This script searches the .tar file for the .tar.gz file the contains the system to be assessed.
- By default the working directory is written to ./Working in the directory the script was run from. This location will be used to unpack the tar files and will be over written if the script finds files in this location at start up. 
    - Due to permissions issues, you may need to chown / chmod this directory after assessing a stand-alone C series server.
- By default the Report directory is created in the ./Reports folder. Each report is written to a sub directory named with the serial number of the server.

>  Usage: processUCSLogs.sh [--tarFileName [Path and File Name]] [--serialNumber [Server Serial Number]] [--workingDirectory [Working Directory Path]] --reportDirectory [Report Directory Path]...
>  Where:
>      -h                    Display this help and exit
>      --tarFileName         Full path to tar file obtained from UCS Managager. (Required)
>      --serialNumber        Serial number of server to be evaluated (Required)
>      --workingDirectory    Directory where files will be temporarily moved to for processing.
>      --ReportDirectory     Directory where finished report will be created.
>      --noReport            Prevents the Reports from by written. Used for debugging
>      -v                    verbose mode.

Example 1:

> ./processUCSlogs.sh --tarfileName /Volumes/RAM\ Disk/someTarfile_bc5_all.tar --serialNumber FCH12345678 --workingDirectory ./681234567_Working --ReportingDirectory ./681234567_Report

Write to specific directory and report directory for serial number FCH12345678 from provided tar file

Example 2:

> ./processUCSlogs.sh --tarfileName /Volumes/RAM\ Disk/someTarfile_bc5_all.tar --serialNumber FCH12345678

Write to default working directory and report directory for serial number FCH12345678 from provided tar file