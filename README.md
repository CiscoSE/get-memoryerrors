These scripts search for report correctable and uncorrectable memory errors for Cisco UCS servers connected to Fabric Interconnects. Two versions are provided:

* One that runs in Python 3.x
* One that runs in PowerShell with Cisco PowerTool

In both cases we report any DIMM visible on a server. Because the properties of DIMMs are no longer readable after being black listed, it is recommended you run this script to get an inventory of all serial numbers as part of normal deployment. Blacklisted DIMM inventory information can only be obtained through tech support logs. 