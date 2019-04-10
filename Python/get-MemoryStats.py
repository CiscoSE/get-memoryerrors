__Version__    = "20151007.03.2"


import getpass

from common      import inputSupport
from common      import timeFunctions
from common      import urlFunctions
from ucsmRoutine import ucsFunctions
from CRoutine    import ucsCFunctions

timeFunctions   = timeFunctions()
ucsF 		    = ucsFunctions()
ucsC            = ucsCFunctions()
URL             = urlFunctions()
YesNo           = inputSupport()

serverName = '10.82.6.106'
adminName  = 'admin'

opening = """
This tool lists all memory in a UCS domain and presents any errors associated with each DIMM.
Do you want to test {0} for memory errors (which is the default for this script)? Type "no" if you
wish to enter a different IP address or server name.
""".format(serverName)

userNamePrompt = """
The default user name is "admin". Do you want to use this name to connect to {0}?

""".format(adminName)

if YesNo.answerYesNo(opening) == False:
        serverName = raw_input('Enter new server name:\t')

if YesNo.answerYesNo(userNamePrompt) == False:
        adminName  = raw_input('Enter new admin name:\t')

fileTime = timeFunctions.getCurrentTime()
#File Name
path = '{0}-MemoryErors.log'.format(fileTime)

#Clear Existing file and write current time
ucsF.writeTimeStamp(path)

url = 'https://{0}/nuova'.format(serverName)
#data = '<aaaLogin inName="ucs-fedlab-ad1\srehling" inPassword="{0}" />'.format(getpass.getpass())

data = '<aaaLogin inName="{0}" inPassword="{1}" />'.format(adminName, getpass.getpass())

# Get a cookie. We use this for all further communcations with the server. 
authCookie =  URL.getCookie(url, data)

systemType = URL.getTopInfo(url, authCookie)
if systemType == 'stand-alone':
    print("Standa-Alone Support not yet implemented in this version")
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