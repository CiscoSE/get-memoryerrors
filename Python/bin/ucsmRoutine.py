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
__Version__    = "20191205.3"

import xml.dom.minidom as XML
import re as regex
import time

from common import urlFunctions

red = '\033[31m'
green = '\033[32m'

class ucsFunctions:
    def __init__(self,args):
        self.args = args
        self.noPrintAttributes = ["fsmFlags"]
        self.URL = urlFunctions(self.args)
        return

    def getUnit (self, authCookie, url, location):
        FinalList = []
        queryXML = '<configScope dn="sys" cookie="{0}" inClass="{1}" inHierarchical="false" inRecursive="false"> <inFilter></inFilter> </configScope>'.format(authCookie, location )
        ucsRackMountsRaw = self.URL.getData(url, queryXML)
        ucsRackMounts = XML.parseString(ucsRackMountsRaw).getElementsByTagName(location)
        for ucsRackMount in ucsRackMounts:
            if (self.args.verbose >= 3):
                for attribute in ucsRackMount.attributes.items():
                    if (attribute[0] not in self.noPrintAttributes):
                        print("     {0}{1}:  {2}".format(red, attribute[0], attribute[1]))
            result = {}
            result['serial'] = (ucsRackMount.attributes['serial'].value)
            result['model']  = (ucsRackMount.attributes['model' ].value)
            result['dn']     = (ucsRackMount.attributes['dn'    ].value)
            FinalList.append(result)
        return FinalList

    def getMemory (self,authCookie, url, targetDN, path):
        FullMemoryList = []
        queryXML = '<configResolveChildren cookie="{0}" inDn="{1}" inHierarchical="true"></configResolveChildren>'.format(authCookie, targetDN)
        ucsMemoryRaw = self.URL.getData(url, queryXML)
        ucsMemory = sorted(XML.parseString(ucsMemoryRaw).getElementsByTagName('memoryUnit'), key=lambda x: str(x.attributes['location'].value))
        for module in ucsMemory:
            self.writeModule(module, path)
            MemoryStats =  self.getMemoryStats(module, path)
            if MemoryStats:
                self.processMemoryStats(MemoryStats, path)

    def getMemoryStats (self, module, path):
        Status = False
        memoryErrorStats = module.getElementsByTagName('memoryErrorStats')
        for memoryErrorStat in memoryErrorStats:
            fields = memoryErrorStat._get_attributes().items()
            for field in fields:
                if regex.match("^[1-9][0-9]*$", field[1]) and regex.match(".+[e|E]rror.+", field[0]):
                    self.writeError(field, path)

    def writeTimeStamp(self, path):
        timeStamp = time.asctime(time.localtime())
        self.returnData("{0}", timeStamp, path)

    def writeCompute (self, Line, path):
        serial = (Line['serial']).replace("'",'')
        model  = (Line['model' ]).replace("'",'')
        computeData    = [serial, model]
        computeStr = "\n\nSerial: {0:<20s} Model: {1:<20s}"
        self.returnData(computeStr,computeData, path)

    def writeModule (self, module, path):
        location     = (module.attributes['location'].value).replace('DIMM_','')
        capacity     = (module.attributes['capacity'].value)
        serialNumber = (module.attributes['serial'  ].value)
        model        = (module.attributes['model'   ].value)
        vendor       = (module.attributes['vendor'  ].value)
        if (model or serialNumber):
            moduleData = [location, capacity, serialNumber, model, vendor]
            moduleStr = "Location: {0:6s}Capacity: {1:<10s}Serial: {2:<12s} Model: {3:<20s} Vendor: {4:<15}"
            self.returnData(moduleStr, moduleData, path)

    def writeError (self, field, path):
        file = open(path, 'a')
        eventName  = repr(field[0].encode('ascii')).ljust(30)
        eventCount = field[1]
        file.write("\t\t{0}\t{1}\n".format(eventName.replace("'",''), eventCount))
        file.close()

    def returnData(self, strText, data, path):
        file = open(path, 'a')
        print(     strText.format(*data))
        file.write("{}\n".format(strText.format(*data)))
        file.close()
