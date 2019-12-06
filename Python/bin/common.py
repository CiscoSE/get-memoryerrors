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

__Version__    = "20191206.01"
import requests
import ssl
import time
import os
import xml.dom.minidom as XML

red =   '\033[31m'
green = '\033[32m'
blue =  '\033[34m'
reset = '\033[0m]'
sepLine = '#' * 20

#Required for self signed certificate handling.
from urllib3.exceptions import InsecureRequestWarning
requests.packages.urllib3.disable_warnings(category=InsecureRequestWarning)

class timeFunctions:
    def __init__(self):
        return

    def getCurrentTime(self):
        return time.strftime("%Y%m%d%H%M%S")

class urlFunctions:
    def __init__(self, args):
        self.args = args
        return
    def getData(self, url, data):
        headers = {"Content-Type": "text/xml"}
        request = requests.post(url, data=data, headers=headers, verify=False)
        if (self.args.verbose >= 3):
            print("     {0}{1} Begin Request {1}\n".format(blue,sepLine))
            print("     {0}url:      {1}".format(red,headers))
            print("     {0}Headers:  {1}".format(red,url))
            print("     {0}Data:     {1}".format(red,data))
            print("     {0}Response: {1}".format(red,request.text))
            print("     {0}{1} End Request {1}{2}\n".format(blue,sepLine,reset))
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
