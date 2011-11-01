import urllib2,urllib

# Check Matlab webserver is running

from django.conf import settings
from django.utils import simplejson

test_data = urllib.urlencode({'app_name': 'InetlligentImage'})
try:
    page = urllib2.urlopen('%s/test_connect.m' % ('http://localhost:4000' if not hasattr(settings, 'MATLAB_SERVER') else settings.MATLAB_SERVER), test_data, 1)
    response = simplejson.loads(page.read())
    print response['message']

    test_data = urllib.urlencode({
        'func_path': '/Users/jaderberg/Sites/4YP/IntelligentImage/djmatlab/test_sum.m',
        'arguments': simplejson.dumps({
            'echo': 'Function processor is working',
        })
    })
    page = urllib2.urlopen('%s/web_feval.m' % ('http://localhost:4000' if not hasattr(settings, 'MATLAB_SERVER') else settings.MATLAB_SERVER), test_data, 1)
    response = simplejson.loads(page.read())
    if response['success'] == 'true':
        print response['result']
    else:
        print response['message']
except urllib2.URLError:
    print 'Matlab server not running'

