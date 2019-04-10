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

__Version__    = "20150912.03.02"


import time
import xml.dom.minidom as XML
from common import urlFunctions
URL = urlFunctions()

class ucsCFunctions:
    def __init__(self):
        return

    def getServerModel(self, url, authCookie):
        result = {}
        finalList = []
        systemRequest = '<configResolveClass cookie="{0}" classId="computeRackUnit"></configResolveClass>'.format(
            authCookie)
        systemInfoRaw = URL.getData(url, systemRequest)
        systemAttributes = XML.parseString(systemInfoRaw).getElementsByTagName('computeRackUnit')[0].attributes
        result['serial'] = systemAttributes['serial'].value.encode('ascii')
        result['model']  = systemAttributes['model'].value.encode('ascii')
        result['dn']     = systemAttributes['dn'].value.encode('ascii')
        finalList.append(result)
        return result


