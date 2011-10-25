#put it to your app/shared/decorators.py and than import when required
from django.http import HttpResponse
from django.utils import simplejson

def json_response(view_fn):
    """
    Converts a dictionary returned by a view into a JSON response to the client.
    """
    def wrapper(*args, **kwargs):
        response = view_fn(*args, **kwargs)
        if isinstance(response, HttpResponse):
            return response
        return HttpResponse(simplejson.dumps(response, ensure_ascii=False), mimetype='text/javascript; charset=utf-8')
    return wrapper
