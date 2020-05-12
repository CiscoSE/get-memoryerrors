This PowerShell script is based on Cisco PowerTool for PowerShell. This script was developed and tested on PowerShell 5.1 on Windows 10 with PowerTool version 2.5.3.0, though it is likely to work with most recent versions of Cisco PowerTool. Please download Cisco PowerTool from software.cisco.com before attempting to run this script. Current versions of PowerTool can be found under the UCS Integrations software Download area.

This script assumes that your fabric interconnects are connected to the network, and that discovery of the UCS servers has completed successfully. You do not need a service profile to assess memory. 

To run a memory assessment, run this script to capture inventory and assess memory errors prior to run diagnostics. Once the initial report is completed, you can run memory diagnostics and rerun the report. 

This script generates three logs:

* ./Processing/<dateTimeStamp>-Processing.log
    * Contains the output from the screen and is mostly used for troubleshooting
* ./Processing/<dateTimeStamp>/<DomainName>.html
    * A inventory report of all servers and memory found by the script in HTML format.
* ./TACReport/<ServerSerialNumber>.html
    * Each file contains a single server with a report of found memory errors. This report will be over written each time the script is run and errors are found. No report is generated for servers that report no errors. 

To run this script, download the zip file or clone the repository from github. Extract the contents to a folder on a Windows 10 box that has PowerTool installed, and network access to the fabric interconnects. Navigate to the PowerShell directory and run the command:

>.\FindMemoryErrors.ps1 -DomainList <ClusterIpOfYourFIDomain>

You will be prompted for user name and password to access the fabric interconnect. 