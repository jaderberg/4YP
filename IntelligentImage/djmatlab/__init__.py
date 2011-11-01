import urllib2,urllib
from django.conf import settings
from django.utils import simplejson
import os


# Check Matlab webserver is running
from djmatlab.utils import Matlab

MATLAB_FOLDER = '%s/matlab' % os.path.realpath(os.path.dirname(__file__))

matlab = Matlab('http://localhost:4000' if not hasattr(settings, 'MATLAB_SERVER') else settings.MATLAB_SERVER, port=None if not hasattr(settings, 'MATLAB_SERVER_PORT') else settings.MATLAB_SERVER_PORT)
try:
    print 'djmatlab - Connected: ', matlab.is_connected()
    print 'djmatlab - Function processor working: ', matlab.is_function_processor_working()
except urllib2.URLError:
    print 'djmatlab - Matlab server not running'

