"""
Copyright (c) 2019 Cisco and/or its affiliates.
This software is licensed to you under the terms of the Cisco Sample
Code License, Version 1.0 (the "License"). You may obtain a copy of the
License at
               https://developer.cisco.com/docs/licenses
All use of the material herein must be in accordance with the terms of
the License. All rights not expressly granted by the License are
reserved. Unless required by applicable law or agreed to separately in
writing, software distributed under the License is distributed on an "AS
IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
or implied.
"""

__Version__    = "20191202.1"


import getpass
import sys
import os
import argparse

sys.path.append(os.getcwd()+'/bin')

from common      import inputSupport
from common      import timeFunctions
from common      import urlFunctions
from ucsmRoutine import ucsFunctions
from CRoutine    import ucsCFunctions

timeFunctions   = timeFunctions()
ucsF 	        = ucsFunctions()
ucsC            = ucsCFunctions()
URL             = urlFunctions()
YesNo           = inputSupport()

defaultAdminName  = 'admin'
defaultServerName = 'Put your UCS Manager IP here'

#Argument Handling
helpmsg = '''
This tool connects to UCS and pulls memory information. 
All memory modules in a domain are listed (if visible to UCSM).
Memory statistics are only provided if errors are found.
'''

argsParse = argparse.ArgumentParser(description=helpmsg)
argsParse.add_argument('-server',   action='store',        dest='serverName', default=defaultServerName, required=False,  help='Cluster IP for UCS Manager')
argsParse.add_argument('-user',     action='store',        dest='adminName',  default=defaultAdminName,  required=False,  help='User name to access UCS Manager')
argsParse.add_argument('-d',        action='store',        dest='directory',  default='./reports',       required=False, help='Directory reports are written into (optional)')
argsParse.add_argument('-verbose',  action='store_true',   dest='verbose',    default=False,             required=False, help='Enables verbose messaging for debug purposes (optional)' )
args = argsParse.parse_args()

if (args.verbose):
    print('Server:      {0}'.format(args.serverName))
    print('User:        {0}'.format(args.adminName))
    print('directory:   {0}'.format(args.directory))
    print('verbose:     {0}'.format(args.verbose))

fileTime = timeFunctions.getCurrentTime()
#File Name
path = '{0}/{1}-MemoryErors.log'.format(args.directory, fileTime)

#Clear Existing file and write current time
ucsF.writeTimeStamp(path)

url = 'https://{0}/nuova'.format(args.serverName)
#data = '<aaaLogin inName="ucs-fedlab-ad1\srehling" inPassword="{0}" />'.format(getpass.getpass())

data = '<aaaLogin inName="{0}" inPassword="{1}" />'.format(args.adminName, getpass.getpass())

# Get a cookie. We use this for all further communcations with the server. 
authCookie =  URL.getCookie(url, data)

systemType = URL.getTopInfo(url, authCookie)
if systemType == 'stand-alone':
    print("Stand-Alone Support not yet implemented in this version")
    #We can only get inventory on stand alone servers.
    #Line = ucsC.getServerModel(url, authCookie)
    #ucsF.writeCompute(Line, path)
    #ucsF.returnData("{0}","\nOnly memory modules can be returned on Stand-Alone C series.\n", path)
    #ucsC.getMemory (authCookie, url, Line['dn'], path)
elif systemType == 'cluster':
    #Get all rack units
    for Line in ucsF.getUnit(authCookie, url, "computeRackUnit"):
        ucsF.writeCompute(Line, path)
        ucsF.getMemory (authCookie, url, Line['dn'], path)
    #Get all blade servers
    for Line in ucsF.getUnit(authCookie, url, "computeBlade"):
        ucsF.writeCompute(Line, path)
        ucsF.getMemory (authCookie, url, Line['dn'], path)
#Clean up cookie when script exits normally.
if authCookie:
    print ("Invalidating authCookie")
    URL.getData(url, '<aaaLogout inCookie="{0}"></aaaLogout>'.format(authCookie))
