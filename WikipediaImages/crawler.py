import os
import mwclient

PATH_ROOT = os.path.realpath( os.path.join(os.path.dirname(__file__), '../../'))

site = mwclient.Site('en.wikipedia.org')
site.login('maxjaderberg', 'pascal28')

# get a page
buildings = site.Pages['List_of_tallest_buildings_in_the_world']


# iterates through the image objects and saves them
for image in buildings.images():
    fr = image.download()
    fw = open('%s/images/%s' % (os.path.realpath(os.path.dirname(__file__)), image.page_title), 'wrb')
    while True:
        s = fr.read(4096)
        if not s: break
        fw.write(s)
    fr.close() # Always close those file objects !!!
    fw.close()