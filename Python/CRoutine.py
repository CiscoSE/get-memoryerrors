
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


