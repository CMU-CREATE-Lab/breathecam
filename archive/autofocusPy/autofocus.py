## Compute the sum of differences between every two pixels along the x axis
## This script is used for autofocusing breathecam
## Usage: python autofocus.py [IP] [lenseNumber] [isLoop]
## e.g. python autofocus.py 192.168.4.13 1 True

import cv2
import numpy as np
from PIL import Image
import sys
from urllib import urlretrieve
import socket
import time

sumDiff_max = 0

loan_camera_lense_order = ["4","2","1","3"]
camera2_lense_order = ["1","4","2","3"]
camera3_lense_order = ["1","3","4","2"]
camera4_lense_order = ["1","3","4","2"]

## Change this one according to the camera being used
current_camera = camera2_lense_order

def computeImage(ip, lenseNumber):
    username = "admin"
    password = "illah123"
    addr = username + ":" + password + "@" + ip 
    config = "res=full&x0=0&y0=0&x1=3648&y1=2752&quality=21&doublescan=0"
    socket.setdefaulttimeout(10)
    folderPath = 'images/breathecam/'
    fileName = lenseNumber + '.jpg'
    urlretrieve('http://' + addr + '/image' + current_camera[int(lenseNumber)-1] + '?' + config, folderPath + fileName)
    computeSumDiff(folderPath, fileName)
    
def computeSumDiff(folderPath, fileName):
    global sumDiff_max
    path = folderPath + fileName
    img = cv2.imread(path, 0)
    kernel = np.array([1, -1])
    diff = cv2.filter2D(img,-1,kernel)
    sumDiff = np.sum(diff);
    if sumDiff_max < sumDiff:
        sumDiff_max = sumDiff
    #Image.fromarray(diff).save(folderPath + 'diff_' + fileName)
    print sumDiff, '/', sumDiff_max, ':', folderPath + fileName

def computeAllImages(folderPath):
    computeSumDiff(folderPath, '1.jpg')
    computeSumDiff(folderPath, '2.jpg')
    computeSumDiff(folderPath, '3.jpg')
    computeSumDiff(folderPath, '4.jpg')

if __name__ == '__main__':
    if len(sys.argv) > 3:
        if sys.argv[3] == 'True':
            while True:
                computeImage(sys.argv[1], sys.argv[2])
        else:
            computeImage(sys.argv[1], sys.argv[2])
    else:
        computeAllImages('images/test/')
