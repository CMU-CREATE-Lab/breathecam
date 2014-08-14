from numpy import *
#heinz_camera_lla = {'lat': 40.442588, 'lon': -80.001047, 'alt': 335}
heinz_camera_lla = {'lat':40.442503, 'lon':-80.001199, 'alt':328}

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

#constants that we use
heightImage = 1733
widthImage  = 8970
home_plate_lla = {'lat':40.447057, 'lon':-80.006170, 'alt':222}
pixel_from_ecef(lla2ecef(home_plate_lla), heinz_imodel)



#TODO if necessary:write parsing script to read from json file into datastructures

tempRead = open('listOfKnownPoints.txt','r').read()
listOfKnownPoints = eval(tempRead)
'''
listOfKnownPoints = [
({'lat':40.446247,'lon': -80.004498, 'alt': 221  },{'xPixel': 3920  , 'yPixel': 1528 }),
({'lat':40.443270,'lon': -80.004716, 'alt': 299  },{'xPixel': 1772  , 'yPixel': 1308 }),
({'lat':40.447973,'lon': -80.002204, 'alt': 255  },{'xPixel': 5156  , 'yPixel': 1185 }),
({'lat':40.447769,'lon': -80.000556, 'alt': 257  },{'xPixel': 5865  , 'yPixel': 1188 }),
({'lat':40.445897,'lon': -79.998206, 'alt': 248  },{'xPixel': 7366  , 'yPixel': 1371 }),
({'lat':40.446126,'lon': -80.007509, 'alt': 256  },{'xPixel': 2893  , 'yPixel': 1228 }),
({'lat':40.449067,'lon': -79.997707, 'alt': 239  },{'xPixel': 6735  , 'yPixel': 1134 }),
({'lat':40.447510,'lon': -80.009500, 'alt': 259  },{'xPixel': 2951  , 'yPixel': 1111 }),
({'lat':40.447309,'lon': -80.003277, 'alt': 245  },{'xPixel': 4635  , 'yPixel': 1280 }),
({'lat':40.451433,'lon': -79.998886, 'alt': 276  },{'xPixel': 6155  , 'yPixel': 941  })]
'''
#paramters to the cost function that need to be optimized. pixels per radian, and quarternion
#We start of with the following guess


parameters = [2855 , 0.1414 , 0.1414 , 0.1414 , 0.1414]#would have preferred dictionary, but optimizer takes lists TODO: see if you can find a way out

def totalErrorInPixels(para):
    error = 0
    errorList = []
    cam_model = {
        'height': heightImage,            
        'width' : widthImage ,
        'pixels_per_radian': para[0],
        'ecef':     lla2ecef(heinz_camera_lla), 
        'rotation': (para[1], para[2], para[3], para[4])
    }

    for point in range(len(listOfKnownPoints)):
        llaKnown   = listOfKnownPoints[point][0]
	pixelKnown = (listOfKnownPoints[point][1]['xPixel'],listOfKnownPoints[point][1]['yPixel'])
	pixelCalc  = pixel_from_ecef(lla2ecef(llaKnown),cam_model)
        errorList.append((pixelKnown[0] - pixelCalc[0]  ,  pixelKnown[1] - pixelCalc[1]))
  	error      = error  + (pixelKnown[0] - pixelCalc[0])**2 + (pixelKnown[1] - pixelCalc[1])**2
    print "The errors obtained with these parameters are ", errorList , " \n   "
    return error


latLongTest1  = {'lat':40.453250,'lon': -80.003403, 'alt': 266  }
pixelValTest1 = {'xPixel':5084  ,'yPixel':939}  
latLongTest2  = {'lat':40.444333,'lon': -80.000954, 'alt': 290  }
pixelValTest2 = {'xPixel':5914, 'yPixel':1502}

#Various Optimizers attempted.

#res = scipy.optimize.anneal(totalErrorInPixels, parameters,lower = [0,-1,-1,-1,-1],upper=[10000.234,1,1,1,1]) 
#res = scipy.optimize.leastsq(errorOnePoint, parameters,args = (LatLongAlt,Pixulus)) 
res = scipy.optimize.fmin(totalErrorInPixels, parameters, maxiter = 10**6,maxfun = 10**6 ,ftol = 0.00001, xtol = 0.00001)
# check http://docs.scipy.org/doc/scipy/reference/generated/scipy.optimize.fmin.html downhill simplex algorithm

print res
print len(res)

parametersAll = list(res) + list(lla2ecef(heinz_camera_lla))
def totalErrorInPixelsAllParams(parameters):
    error = 0
    errorList = []
    cam_model = {
        'height'  : heightImage,
        'width'   : widthImage ,
        'pixels_per_radian': parameters[0],
        'ecef'    : array(parameters[-3:]), #lla2ecef(heinz_camera_lla), 
        'rotation': (parameters[1], parameters[2], parameters[3], parameters[4])
    }

    for point in range(len(listOfKnownPoints)):
        llaKnown   = listOfKnownPoints[point][0]
        pixelKnown = (listOfKnownPoints[point][1]['xPixel'],listOfKnownPoints[point][1]['yPixel'])
        pixelCalc  = pixel_from_ecef(lla2ecef(llaKnown),cam_model)
        errorList.append((pixelKnown[0] - pixelCalc[0]  ,  pixelKnown[1] - pixelCalc[1]))
        error      = error  + (pixelKnown[0] - pixelCalc[0])**2 + (pixelKnown[1] - pixelCalc[1])**2
    print "The errors obtained with these parameters are ", errorList , " \n   "
    return error



resAllParam = scipy.optimize.fmin(totalErrorInPixelsAllParams, parametersAll, maxiter = 10**6,maxfun = 10**6 ,ftol = 0.00001, xtol = 0.00001)
print resAllParam

parametersOptimized     =  list(resAllParam)

##########
#For testing
##########
def errorForOnePoint(para,latLong,pixelVal):
    cam_model = {
        'height': heightImage,  
        'width' : widthImage ,
        'pixels_per_radian': para[0],#['ppr'], 
        'ecef': lla2ecef(heinz_camera_lla),
        'rotation': (para[1], para[2], para[3], para[4]) #para['quaternion']
    }
    pixelCalc     = pixel_from_ecef(lla2ecef(latLong),cam_model)
    errorOnePoint = tuple([pixelVal['xPixel'] - pixelCalc[0] ,pixelVal['yPixel'] - pixelCalc[1]])
    return errorOnePoint , pixelCalc



def errorForOnePointAllParam(para,latLong,pixelVal):
    cam_model = {
        'height': heightImage,   #duplicating the data from previous function. Will try to avoid it once code is good for all other purposes         
        'width' : widthImage ,
        'pixels_per_radian': para[0],
        'ecef': array(para[-3:]), # lla2ecef(heinz_camera_lla),
        'rotation': (para[1], para[2], para[3], para[4])
    }
    pixelCalc     = pixel_from_ecef(lla2ecef(latLong),cam_model)
   # pixelCalc     = pixel_from_ecef(array(para[-3:]),cam_model)
    errorOnePoint = tuple([pixelVal['xPixel'] - pixelCalc[0] ,pixelVal['yPixel'] - pixelCalc[1]])
#    print "The pixel value observed is", pixelCalc,pixelVal 
    print pixelCalc, tuple([pixelVal['xPixel'],pixelVal['yPixel']])
    #return errorOnePoint , pixelCalc
    return None


'''
for i in range(len(listOfKnownPoints)):
    errorForOnePointAllParam(parametersOptimized,listOfKnownPoints[i][0],listOfKnownPoints[i][1])



print "Absolute sum of Errors of test location one and pixel caluclated are" , errorForOnePointAllParam(parametersOptimized , latLongTest1 , pixelValTest1)
print "Absolute sum of Errors of test location one and pixel caluclated are" , errorForOnePoint(res , latLongTest1 , pixelValTest1)
print "Absolute sum of Errors of test location two and pixel calculated are" , errorForOnePointAllParam(parametersOptimized , latLongTest2 , pixelValTest2)
print "Absolute sum of Errors of test location one and pixel caluclated are" , errorForOnePoint(res , latLongTest1 , pixelValTest1)
'''
