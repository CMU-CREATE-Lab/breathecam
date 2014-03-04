## Canny Edge Detection 
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

pixels_edge_max = 0

loan_camera_lense_order = ["4","2","1","3"]
camera2_lense_order = ["1","4","2","3"]
camera3_lense_order = ["1","3","4","2"]
camera4_lense_order = ["1","3","4","2"]

## Change this one according to the camera being used
current_camera = camera2_lense_order

def getImages(ip, lenseNumber):
    username = "admin"
    password = "illah123"
    addr = username + ":" + password + "@" + ip 
    config = "res=full&x0=0&y0=0&x1=3648&y1=2752&quality=21&doublescan=0"
    socket.setdefaulttimeout(10)
    folderPath = 'images/breathecam/'
    fileName = lenseNumber + '.jpg'
    urlretrieve('http://' + addr + '/image' + current_camera[int(lenseNumber)-1] + '?' + config, folderPath + fileName)
    computeEdge(folderPath, fileName)
    
def computeEdge(folderPath, fileName):
    global pixels_edge_max
    path = folderPath + fileName
    img = cv2.imread(path, 0)
    edge = cv2.Canny(img, 100, 200)
    pixels_edge = np.sum(edge) / 255
    if pixels_edge_max < pixels_edge:
        pixels_edge_max = pixels_edge
    Image.fromarray(edge).save(folderPath + 'edge_' + fileName)
    print 'Edges :', pixels_edge, '/', pixels_edge_max, ':', folderPath + fileName
    return [img, edge, pixels_edge]

def computeAllEdges(folderPath):
    [img1, edge1, pixels_edge1] = computeEdge(folderPath, '1.jpg')
    [img2, edge2, pixels_edge2] = computeEdge(folderPath, '2.jpg')
    [img3, edge3, pixels_edge3] = computeEdge(folderPath, '3.jpg')
    [img4, edge4, pixels_edge4] = computeEdge(folderPath, '4.jpg')
    pixels_edge = pixels_edge1 + pixels_edge2 + pixels_edge3 + pixels_edge4
    return pixels_edge

if __name__ == '__main__':
    if len(sys.argv) > 3:
        if sys.argv[3] == 'True':
            while True:
                getImages(sys.argv[1], sys.argv[2])
        else:
            getImages(sys.argv[1], sys.argv[2])
    else:
        computeAllEdges('images/test/')
