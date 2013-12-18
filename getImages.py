#!/usr/bin/python

from datetime import datetime
from urllib import urlretrieve
from time import gmtime, strftime, mktime
import time
import socket

username = "admin"
password = "illah123"
ip = "192.168.4.13" # was 4.15
addr = username + ":" + password + "@" + ip 
config = "res=full&x0=0&y0=0&x1=3648&y1=2752&quality=21&doublescan=0"

while True:

    if int(strftime("%S", gmtime())) == 0:

      curDate = str(int(time.mktime(datetime.utcnow().timetuple())))
      socket.setdefaulttimeout(10)

      # retrieve the images
      try:
        urlretrieve('http://'+addr+'/image3?'+config, 'image1_'+curDate+'.jpg')
      except:
        continue
    
      try:
        urlretrieve('http://'+addr+'/image2?'+config, 'image2_'+curDate+'.jpg')
      except:
        continue
    
      try:
          urlretrieve('http://'+addr+'/image4?'+config, 'image3_'+curDate+'.jpg')
      except:
        continue
    
      try:
        urlretrieve('http://'+addr+'/image1?'+config, 'image4_'+curDate+'.jpg')
      except:
        continue