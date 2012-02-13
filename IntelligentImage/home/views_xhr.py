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
import os

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
def get_log(request):
    session_key = request.GET.get('key')
    filename = '%slogs/%s-log.txt' % (settings.MEDIA_ROOT, session_key)
    try:
        f = open(filename, 'r')
        response = {
            'success': True,
            'lines': f.readlines(),
        }
    except IOError:
        response = {
            'success': False,
            'message': 'Key invalid',
        }
    return response

@json_response
def log_cleanup(request):
    session_key = request.GET.get('key')
    filename = '%slogs/%s-log.txt' % (settings.MEDIA_ROOT, session_key)
    try:
        os.remove(filename)
        response = {
            'success': True,
        }
    except IOError:
        response = {
            'success': False,
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
    
    resp = matlab.run('/Users/jaderberg/Sites/4YP/visualindex/wikilist_dataset/demo_wiki_get_objects.m', {'image_path': query_image_path, 'display': 1, 'log_file': '%slogs/%s-log.txt' % (settings.MEDIA_ROOT, request.POST.get('key'))}, maxtime=999999)

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
        print rectangle
    #    Transform the rectangle to web displayed size
        original_sz = query_image['sz']
        original_width = original_sz[0]
        original_height = original_sz[1]
        scale_factor = float(IMAGE_WIDTH)/float(original_width)

        left = int(scale_factor*rectangle['left'])
        top = int(scale_factor*(original_height-rectangle['top'])) - 9
        width = int(scale_factor*rectangle['width'])
        height = int(scale_factor*rectangle['height'])

        try:
            object_class = match['class']
        except KeyError:
            object_class = object_name[0] if object_name else 'Unknown Object'



        objects.append({
            'label': object_class.replace('_', ' ').title(),
            'url': 'http://en.wikipedia.org/wiki/%s' % object_class,
            'left': left,
            'top': top,
            'width': width,
            'height': height,
        })

    response['success'] = True
    response['html'] = render_to_string('tagged_image.html', {'image': uploaded_image, 'objects': objects}, context_instance=RequestContext(request))

    return response