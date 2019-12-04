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
import requests
import ssl
import time
import os
import xml.dom.minidom as XML

#Required for self signed certificate handling.
from urllib3.exceptions import InsecureRequestWarning
requests.packages.urllib3.disable_warnings(category=InsecureRequestWarning)

class inputSupport:
    def __init__(self):
        return

    def answerYesNo(self, message):
        questionExit = True
        while questionExit == True:
            os.system('clear')
            print (message + "[Yes / No]")
            newServerName = input().lower()
            if newServerName in ['yes', 'y', 'ye']:
                return True
            elif newServerName in ['no','n']:
                return False

class timeFunctions:
    def __init__(self):
        return

    def getCurrentTime(self):
        return time.strftime("%Y%m%d%H%M%S")

class urlFunctions:
    def __init__(self):
        return
    def getData(self, url, data):
        headers = {"Content-Type": "text/xml"}
        request = requests.post(url, data=data, headers=headers, verify=False)
        #request = urllib3.Request(url, data, {"Content-Type": "text/xml"})
        #response = urllib3.urlopen(request)
        return (request.text)

    def getCookie(self, url, data):
        response = self.getData(url, data)
        return XML.parseString(response).documentElement.getAttributeNode('outCookie').nodeValue

    def getTopInfo(self, url, authCookie):
        #reportFile = open(fileName, 'w')
        initialRequest = '<configResolveClass cookie="{0}" classId="topSystem"></configResolveClass>'.format(authCookie)
        topSystemInfoRaw = self.getData(url, initialRequest)
        try:
            topSystemInfo = XML.parseString(topSystemInfoRaw).getElementsByTagName('topSystem')[0].attributes['mode'].value
            return topSystemInfo.lower()
        except Exception as e:
            print('Unable to determine the mode of the device (cluster or stand-alone. Script exiting')
            print(str(e))
            self.getData(url, '<aaaLogout inCookie="{0}"></aaaLogout>'.format(authCookie))
            quit()
