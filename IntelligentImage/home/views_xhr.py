import re
from django.http import HttpResponseRedirect
from django.template.context import RequestContext
from django.template.defaultfilters import slugify
from django.template.loader import render_to_string
from djmatlab import matlab
from home.decorators import json_response
from django.core.urlresolvers import reverse
from home.forms import UploadedImageForm
from home.models import UploadedImage
import time
from os.path import basename
from django.conf import settings

IMAGE_WIDTH = 560

@json_response
def upload_image(request):

    if not request.method == 'POST':
        return HttpResponseRedirect(reverse('home'))

    response = {
        'success': False
    }

    ########### TAKE THIS OUT IN PRODUCTION!!!!
    time.sleep(1)
    ###################################
    image_form = UploadedImageForm(request.POST, request.FILES)

    if image_form.is_valid():
        image = image_form.save(commit=False)
        # TODO: Hash files to avoid duplicates
        image.save()
        response['success'] = True
        response['url'] = image.image.url
        response['html'] = render_to_string('untagged_image.html', {'image': image}, context_instance=RequestContext(request))
    else:
        response['error'] = image_form.errors

    return response

@json_response
def get_session_key(request):
    response = {
        'success': True,
        'key': request.session.session_key,
    }
    return response

@json_response
def get_log(request, session_key):
    filename = '%slogs/%s-log.txt' % (settings.MEDIA_ROOT, session_key)
    f = open(filename, 'r')
    response = {
        'success': True,
        'lines': f.readlines(),
    }
    return response

@json_response
def tag_image(request, image_id):

    if not request.method == 'POST':
        return HttpResponseRedirect(reverse('home'))

    response = {
        'success': False
    }

    try:
        uploaded_image = UploadedImage.objects.get(id=image_id)
    except UploadedImage.DoesNotExist:
        response['error'] = 'Image does not exist'
        return response

    # List of recognised objects
    objects = []

    # DO SOMETHING WITH THE IMAGE
    query_image_path = uploaded_image.image.path

#    Retrieve a match
    while matlab.running:
#       Matlab is already processing something, wait
        time.sleep(2)
    
    resp = matlab.run('/Users/jaderberg/Sites/4YP/visualindex/demo_mongo_getobjects.m', {'image_path': query_image_path, 'display': 1, 'log_file': '%slogs/%s-log.txt' % (settings.MEDIA_ROOT, request.POST.get('key'))}, maxtime=999999)

    if resp['success'] == 'false':
        response['error'] = 'Something went wrong...'
        return response

#    Extract the title
    result = resp['result']
    query_image = result['query_image']
    matches = result['matches']
    for match in matches:
        object_name = re.findall(r'(?P<name>\w+)_\d+\.\w+', basename(match['path']))
        rectangle = match['rectangle']
    #    Transform the rectangle to web displayed size
        original_width = uploaded_image.image.width
        original_height = uploaded_image.image.height
        scale_factor = float(IMAGE_WIDTH)/float(original_width)

        left = int(scale_factor*rectangle['left'])
        top = int(scale_factor*(original_height-rectangle['top']))
        width = int(scale_factor*rectangle['width'])
        height = int(scale_factor*rectangle['height'])

        try:
            object_class = match['class']
        except KeyError:
            object_class = object_name[0] if object_name else 'Unknown Object'



        objects.append({
            'label': object_class.replace('_', ' ').title(),
            'url': 'http://en.wikipedia.org/wiki/%s' % slugify(object_class).title(),
            'left': left,
            'top': top,
            'width': width,
            'height': height,
        })

    response['success'] = True
    response['html'] = render_to_string('tagged_image.html', {'image': uploaded_image, 'objects': objects}, context_instance=RequestContext(request))

    return response