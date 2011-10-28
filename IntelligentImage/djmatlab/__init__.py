import urllib2,urllib

# Check Matlab webserver is running

from django.conf import settings
from django.utils import simplejson

test_data = urllib.urlencode({'app_name': 'InetlligentImage'})
try:
    page = urllib2.urlopen('%s/test_connect.m' % ('http://localhost:4000' if not hasattr(settings, 'MATLAB_SERVER') else settings.MATLAB_SERVER), test_data, 1)
    response = simplejson.loads(page.read())
    print response['message']
except urllib2.URLError:
    print 'Matlab server not running'

