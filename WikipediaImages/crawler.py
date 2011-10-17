import os
import mwclient

PROJECT_ROOT = os.path.realpath( os.path.join(os.path.dirname(__file__), '../../'))

IMAGE_FOLDER = '%s/4yp_images/test_images' % PROJECT_ROOT
PAGE_NAME = 'List_of_tallest_buildings_in_the_world'

if not os.path.exists(IMAGE_FOLDER):
    os.makedirs(IMAGE_FOLDER)
    print 'Created %s' % IMAGE_FOLDER

site = mwclient.Site('en.wikipedia.org')
site.login('maxjaderberg', 'pascal28')

# get a page
buildings = site.Pages[PAGE_NAME]

print 'Downloading images from %s...' % PAGE_NAME

# iterates through the image objects and saves them
counter = 0
for image in buildings.images():
    fr = image.download()
    fw = open('%s/%s' % (IMAGE_FOLDER, image.page_title), 'wrb')
    while True:
        s = fr.read(4096)
        if not s: break
        fw.write(s)
    fr.close() # Always close those file objects !!!
    fw.close()
    counter += 1
    print 'Downloaded: %s' % image.page_title

print ''
print 'Success! Downloaded %d images to %s' % (counter, IMAGE_FOLDER)
print ''