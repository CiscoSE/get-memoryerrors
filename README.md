These scripts search for and report correctable and uncorrectable memory errors for Cisco UCS servers connected to Fabric Interconnects. Two versions are provided:

* One that runs in Python 3.x
* One that runs in PowerShell with Cisco PowerTool

In both cases we report any DIMM visible on a server found in a UCS Domain. Because the properties of DIMMs are no longer readable after being black listed, it is recommended you run one of these scripts to get an inventory of all serial numbers as part of normal deployment. Blacklisted DIMM inventory information can only be obtained through tech support logs once the DIMM is mapped out.