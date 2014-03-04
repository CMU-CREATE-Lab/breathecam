## Canny Edge Detection 
## This script is used for finding the thresholds for Hysteresis Thresholding
## Usage: python edge.py [imagePath]
## e.g. python edge.py images/1.jpg

import sys
import urllib2
import cv2.cv as cv

# some definitions
win_name = "Edge"
trackbar_name1 = "Low"
trackbar_name2 = "High"
scale = 3
lowThreshold = 1
highThreshold = 1

# the callback on the trackbar
def on_trackbar1(position):
    global lowThreshold
    lowThreshold = position
    recompute()

# the callback on the trackbar
def on_trackbar2(position):
    global highThreshold
    highThreshold = position
    recompute()

# the callback on the trackbar
def recompute():
    cv.Smooth(gray, edge, cv.CV_BLUR, 3, 3, 0)
    cv.Not(gray, edge)
    # run the edge dector on gray scale
    cv.Canny(gray, edge, lowThreshold, highThreshold, 3)
    # reset
    cv.SetZero(col_edge)
    # copy edge points
    cv.Copy(im, col_edge, edge)
    # show the im
    cv.ShowImage(win_name, col_edge)

if __name__ == '__main__':
    if len(sys.argv) > 1:
        src = cv.LoadImage( sys.argv[1], cv.CV_LOAD_IMAGE_COLOR)
        im = cv.CreateImage((src.width/scale, src.height/scale), 8, 3)
        cv.Resize(src, im)
    else:
        url = 'https://raw.github.com/Itseez/opencv/master/samples/c/fruits.jpg'
        filedata = urllib2.urlopen(url).read()
        imagefiledata = cv.CreateMatHeader(1, len(filedata), cv.CV_8UC1)
        cv.SetData(imagefiledata, filedata, len(filedata))
        im = cv.DecodeImage(imagefiledata, cv.CV_LOAD_IMAGE_COLOR)

    # create the output im
    col_edge = cv.CreateImage((im.width, im.height), 8, 3)

    # convert to grayscale
    gray = cv.CreateImage((im.width, im.height), 8, 1)
    edge = cv.CreateImage((im.width, im.height), 8, 1)
    cv.CvtColor(im, gray, cv.CV_BGR2GRAY)

    # create the window
    cv.NamedWindow(win_name, cv.CV_WINDOW_AUTOSIZE)

    # create the trackbar
    cv.CreateTrackbar(trackbar_name1, win_name, 1, 1000, on_trackbar1)
    cv.CreateTrackbar(trackbar_name2, win_name, 1, 1000, on_trackbar2)

    # show the im
    recompute()

    # wait a key pressed to end
    cv.WaitKey(0)
    cv.DestroyAllWindows()
