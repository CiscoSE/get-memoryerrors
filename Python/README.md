This script was written for python 3.6 and is untested on other versions. 

You must install the requests package for this script to run.

	pip3 install requests

Examples
Get memory from 10.1.1.1 using the admin account:

	python3 get-MemoryStats.py --server 10.1.1.1 --user admin

You will prompted for the password. 

All DIMMS are listed, but statistics only are displayed if errors are found.

By default reports are written to the ./reports directory. 

