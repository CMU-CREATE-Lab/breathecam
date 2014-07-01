from numpy import *
heinz_camera_lla = {'lat': 40.442588, 'lon': -80.001047, 'alt': 335}

# From https://code.google.com/p/pysatel/source/browse/trunk/coord.py?r=22
import math

# Constants defined by the World Geodetic System 1984 (WGS84), in km
a = 6378.137
b = 6356.7523142
esq = 6.69437999014 * 0.001
e1sq = 6.73949674228 * 0.001
f = 1 / 298.257223563

def lla2ecef(lla):
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

def pixel_from_ccxyz(cc, imodel):

    yaw = math.atan2(cc[0], cc[2])
    print '  yaw is %g' % yaw
    pixel_x = yaw * imodel['pixels_per_radian'] + imodel['width'] * 0.5
    print '  pixel_x is %g' % pixel_x

    tilt = math.atan2(cc[1], math.sqrt(cc[0] * cc[0] + cc[2] * cc[2]))
    print '  tilt is %g' % tilt
    pixel_y = tilt * imodel['pixels_per_radian'] + imodel['height'] * 0.5
    print '  pixel_y is %g' % pixel_y
    
    return (pixel_x, pixel_y)
    
heinz_imodel = {
    'height': 1688,
    'width': 7141,
    'pixels_per_radian': 2273,
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


# TODO: use something like scipy.optimize.leastsq to find external and pixels per radian







