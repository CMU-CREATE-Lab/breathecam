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

loan_camera_lense_order = ["4","2","1","3"]
camera3_lense_order = ["1","3","4","2"]
camera4_lense_order = ["1","3","4","2"]

current_camera = camera3_lense_order

while True:

    if int(strftime("%S", gmtime())) == 0:

      curDate = str(int(time.mktime(datetime.utcnow().timetuple())))
      socket.setdefaulttimeout(10)

      # retrieve the images
      try:
        urlretrieve('http://'+addr+'/image1?'+config, curDate+'_image'+current_camera[0]+'.jpg')
      except:
        continue
      try:
        urlretrieve('http://'+addr+'/image2?'+config, curDate+'_image'+current_camera[1]+'.jpg')
      except:
        continue
      try:
        urlretrieve('http://'+addr+'/image3?'+config, curDate+'_image'+current_camera[2]+'.jpg')
      except:
        continue
      try:
        urlretrieve('http://'+addr+'/image4?'+config, curDate+'_image'+current_camera[3]+'.jpg')
      except:
        continue
