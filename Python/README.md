This script was written for python 3.6 and is untested on other versions. 

You must install the requests package for this script to run.
    pip3 install requests

The following options are available when running this script.

-s or --server      The UCS cluster IP you want to connect to.
-u or --user        The user name for access to UCS Manager (Default is Admin)
-d or --directory   The directory for writing error and serial number information
                    By default these are written to ./reports
-v or --verbose     Verbose logging can be enabled
                    -v output of arguments passed, and minor details about blades and rack mounts
                    -vv Output reserved for future development not currently implemented
                    -vvv Output includes all XML to and from the UCS including passwords in clear text

Defaults are assigned in the arguments section of get-MemoryStats.py. If you populate those defaults with your preferred options, you can skip any arguments above. Password is always manually entered in this version of the script.

Examples:
Show only errors and memory serial numbers and use the default directory. This is how most would run this script.

    python3 get-MemoryStats.py -s 1.1.1.1 -u admin

To add basic verbose output including validation of arguments passed and blade / chassis numbering (green text output)
    python3 get-MemoryStats.py -s 1.1.1.1 -u admin -v 
    

By default reports are written to the ./reports directory. 

