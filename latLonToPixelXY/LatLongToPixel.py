from numpy import *
heinz_camera_lla = {'lat': 40.442588, 'lon': -80.001047, 'alt': 335}

# From https://code.google.com/p/pysatel/source/browse/trunk/coord.py?r=22
import math, IPython, scipy.optimize

# Constants defined by the World Geodetic System 1984 (WGS84), in km
'''
a = 6378.137
b = 6356.7523142
esq = 6.69437999014 * 0.001
e1sq = 6.73949674228 * 0.001
f = 1 / 298.257223563
'''
def lla2ecef(lla):

    # Constants defined by the World Geodetic System 1984 (WGS84), in km
    a = 6378.137
    b = 6356.7523142
    esq = 6.69437999014 * 0.001
    e1sq = 6.73949674228 * 0.001
    f = 1 / 298.257223563



    lat = lla['lat']
    lon = lla['lon']
    alt = lla['alt'] / 1000.0
    """Convert geodetic coordinates to ECEF."""
    lat, lon = math.radians(lat), math.radians(lon)
    xi = math.sqrt(1 - esq * math.sin(lat))
    x = (a / xi + alt) * math.cos(lat) * math.cos(lon)
    y = (a / xi + alt) * math.cos(lat) * math.sin(lon)
    z = (a / xi * (1 - esq) + alt) * math.sin(lat)
    return array((x * 1000.0, y * 1000.0, z * 1000.0))

print lla2ecef(heinz_camera_lla)



def pixel_from_ccxyz(cc, imodel):  #pixel from camera centered xyz coordinates

    yaw = math.atan2(cc[0], cc[2])  
    #print '  yaw is %g' % yaw
    pixel_x = yaw * imodel['pixels_per_radian'] + imodel['width'] * 0.5
    #print '  pixel_x is %g' % pixel_x

    tilt = math.atan2(cc[1], math.sqrt(cc[0] * cc[0] + cc[2] * cc[2]))
    #print '  tilt is %g' % tilt
    pixel_y = tilt * imodel['pixels_per_radian'] + imodel['height'] * 0.5
    #print '  pixel_y is %g' % pixel_y
    
    return (pixel_x, pixel_y)
    
heinz_imodel = {
    'height': 1688,              #size of the panoramic image ? 
    'width': 7141,               
    'pixels_per_radian': 2273,   #width/angle covered. Here 7141/pi
    'ecef': lla2ecef(heinz_camera_lla),
    'rotation': (1, 0, 0, 0)
}

straight_ahead_cc = array((0, 0, 1000))      
right_face_cc = array((500, 0, 0))
left_face_cc = array((-500, 0, 0))
upwards_45_cc = array((0, -25, 25))
downwards_45_cc = array((0, 25, 25))
downwards_45_left_face_cc = array((-25, 25, 0))

print 'straight ahead'
pixel_from_ccxyz(straight_ahead_cc, heinz_imodel)
print 'right face'
pixel_from_ccxyz(right_face_cc, heinz_imodel)
print 'left face'
pixel_from_ccxyz(left_face_cc, heinz_imodel)
print 'upwards 45'
pixel_from_ccxyz(upwards_45_cc, heinz_imodel)
print 'downwards 45'
pixel_from_ccxyz(downwards_45_cc, heinz_imodel)
print 'downwards 45 left face'
pixel_from_ccxyz(downwards_45_left_face_cc, heinz_imodel)

# Quaternions, from http://stackoverflow.com/questions/4870393/rotating-coordinate-system-via-a-quaternion

def normalize(v, tolerance=0.00001):
    mag2 = sum(n * n for n in v)
    if abs(mag2 - 1.0) > tolerance:
        mag = sqrt(mag2)
        v = tuple(n / mag for n in v)
    return v

def q_mult(q1, q2):
    w1, x1, y1, z1 = q1
    w2, x2, y2, z2 = q2
    w = w1 * w2 - x1 * x2 - y1 * y2 - z1 * z2
    x = w1 * x2 + x1 * w2 + y1 * z2 - z1 * y2
    y = w1 * y2 + y1 * w2 + z1 * x2 - x1 * z2
    z = w1 * z2 + z1 * w2 + x1 * y2 - y1 * x2
    return w, x, y, z

def q_conjugate(q):
    q = normalize(q)
    w, x, y, z = q
    return (w, -x, -y, -z)

def qv_mult(q1, v1):
    v1 = normalize(v1)
    q2 = (0.0,) + v1
    return q_mult(q_mult(q1, q2), q_conjugate(q1))[1:]

def pixel_from_ecef(ecef, model):
    # Convert from ecef to camera-centered
    cc = qv_mult(model['rotation'], ecef - model['ecef'])
    return pixel_from_ccxyz(cc, model)

# PNC Park home plate, from Google Earth
# TO DO:  locate ~10 reference points

home_plate_lla = {'lat':40.447057, 'lon':-80.006170, 'alt':222}
pixel_from_ecef(lla2ecef(home_plate_lla), heinz_imodel)







#listOfKnownPoints =  []
#listOfKnownPoints.append(({'lat':40.447057,'lon': -80.006170,'alt': 222  },{'xPixel': 1244.64  , 'yPixel': 2002.26 }))
#TODO if necessary:write parsing script to read from json file into datastructures
listOfKnownPoints = [
({'lat':40.441366,'lon': -79.994775, 'alt': 222  },{'xPixel': 4144.083  , 'yPixel': 760.187  }),
({'lat':40.441823,'lon': -80.012776, 'alt': 206  },{'xPixel': 2752.402  , 'yPixel': 1642.679 }),
({'lat':40.444209,'lon': -80.009189, 'alt': 243  },{'xPixel': 2645.539  , 'yPixel': 1307.134 }),
({'lat':40.438913,'lon': -80.011329, 'alt': 222  },{'xPixel': 4265.726  , 'yPixel': 1557.211 }),
({'lat':40.445889,'lon': -80.015228, 'alt': 212  },{'xPixel': 1133.514  , 'yPixel': 1447.93  }),
({'lat':40.436114,'lon': -80.018811, 'alt': 231  },{'xPixel': 8372.991  , 'yPixel': 1288.094 }),
({'lat':40.437190,'lon': -80.017578, 'alt': 213  },{'xPixel': 6084.036  , 'yPixel': 1382.086 }),
({'lat':40.437054,'lon': -80.016465, 'alt': 234  },{'xPixel': 5754.627  , 'yPixel': 1463.708 }),
({'lat':40.432715,'lon': -79.989217, 'alt': 231  },{'xPixel': 5258.228  , 'yPixel': 1074.379 }),
({'lat':40.441829,'lon': -80.003713, 'alt': 234  },{'xPixel': 3736.978  , 'yPixel': 1274.988 })]

#paramters to the cost function that need to be optimized. pixels per radian, and quarternion
#We start of with the following guess
parameters = [2855 , 1 , 0 , 0 , 0]

#Functions takes in the paramerters and spits out the total cost(error). All the points that we handselected are put in the global varibale "listOfKnownPoints" which is used in the function.
def totalErrorInPixels(para):
    error = 0
    global errorList        #I use it to print out the error list and the end of optimization.
    errorList = []
    cam_model = {
        'height': 1733,            
        'width' : 8970 ,
        'pixels_per_radian': para[0], 
        'ecef': lla2ecef(heinz_camera_lla),
        'rotation': (para[1], para[2], para[3], para[4])
    }

    for point in range(len(listOfKnownPoints)):
        llaKnown   = listOfKnownPoints[point][0]
	pixelKnown = (listOfKnownPoints[point][1]['xPixel'],listOfKnownPoints[point][1]['yPixel'])
	pixelCalc  = pixel_from_ecef(lla2ecef(llaKnown),cam_model)
        errorList.append((pixelKnown[0] - pixelCalc[0]  ,  pixelKnown[1] - pixelCalc[1]))
  	error      = error  + (pixelKnown[0] - pixelCalc[0])**2 + (pixelKnown[1] - pixelCalc[1])**2
#    print "The errors obtained with these parameters are ", errorList , " \n   "
    return error



#Function written to get leastsq in optimize to work. Can be safely ignored
latLong  = {'lat':40.441366,'lon': -79.994775, 'alt': 222  }
pixelVal = (4144.083, 760.187 )

def errorOnePoint(para,latLong,pixelVal):
#latLong is a dictionary of lat,long and alt. example = {'lat':40.447057, 'lon':-80.006170, 'alt':222}
#pixelVal is a tuple  (xpixel,ypixel)
    cam_model = {
        'height': 1733,            
        'width' : 8970 ,
        'pixels_per_radian': para[0], 
        'ecef': lla2ecef(heinz_camera_lla),
        'rotation': (para[1], para[2], para[3], para[4])
    }
    pixelCalc     = pixel_from_ecef(lla2ecef(latLong),cam_model)
    errorOnePoint = (pixelVal[0] - pixelCalc[0])**2 + (pixelVal[1] - pixelCalc[1])**2
    return errorOnePoint


#Test to check if the function runs without error
#testCostFunction =  totalErrorInPixels(parameters)
#print "The cost of the points observed is  ", testCostFunction


#Various Optimizers attempted.

#res = scipy.optimize.anneal(totalErrorInPixels, parameters,lower = [0,-1,-1,-1,-1],upper=[10000.234,1,1,1,1]) 
#res = scipy.optimize.leastsq(errorOnePoint, parameters,args = (LatLongAlt,Pixulus)) 
res = scipy.optimize.fmin(totalErrorInPixels, parameters, maxiter = 10**6,maxfun = 10**6 ,ftol = 0.00001, xtol = 0.00001)
# check http://docs.scipy.org/doc/scipy/reference/generated/scipy.optimize.fmin.html downhill simplex algorithm

global errorList
print "The optimum parameters found are " , res , " and the error observed is  ", errorList
IPython.embed()

#To test the data
normQuat   =  normalize(res[1:])
newRes     = [res[0]] +  list(normQuat)
print "The new Res looks like " , newRes
print "\n The total error is "  , totalErrorInPixels(newRes) , " \n and the list of error values is ", errorList
print "\n error of one location is " , errorOnePoint(newRes,latLong,pixelVal)








