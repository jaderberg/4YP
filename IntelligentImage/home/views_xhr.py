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
    results = matlab.run('/Users/jaderberg/Sites/4YP/visualindex/demo_getobjects.m', {'image_path': query_image_path, 'display': 1}, maxtime=999999)

    if results['success'] == 'false':
        response['error'] = 'Something went wrong...'
        return response

#    Extract the title
    result = results['result']
    query_image = result['query_image']
    match = result['match']
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

    objects.append({
        'label': object_name[0].replace('_', ' ').title() if object_name else 'Unknown Object',
        'url': 'http://en.wikipedia.org/wiki/%s' % slugify(object_name[0]).title() if object_name else '',
        'left': left,
        'top': top,
        'width': width,
        'height': height,
    })

    print objects[0]


#    objects.append({
#        'label': 'Buckingham Palace',
#        'url': 'http://en.wikipedia.org/wiki/Buckingham_Palace',
#        'left': 200,
#        'top': 120,
#        'width': 300,
#        'height': 100,
#    })
#    objects.append({
#        'label': 'Victoria Memorial',
#        'url': 'http://en.wikipedia.org/wiki/Victoria_Memorial_(London)',
#        'left': 50,
#        'top': 50,
#        'width': 80,
#        'height': 100,
#    })

    response['success'] = True
    response['html'] = render_to_string('tagged_image.html', {'image': uploaded_image, 'objects': objects}, context_instance=RequestContext(request))

    return response