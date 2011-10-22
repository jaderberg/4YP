import os
import mwclient


PAGE_NAME = 'List_of_structures_in_London'
IMAGE_FOLDER = '/Volumes/4YP/Images/%s' % PAGE_NAME


if not os.path.exists(IMAGE_FOLDER):
    os.makedirs(IMAGE_FOLDER)
    print 'Created %s' % IMAGE_FOLDER

site = mwclient.Site('en.wikipedia.org')
site.login('maxjaderberg', 'pascal28')

def download_images(page, no_flags=False, no_graphics=False, no_logos=False):
    """
    Downloads all the images on a Page object (e.g site.Pages['Albert_Einstein'])
    """
    page_url = 'http://en.wikipedia.org/wiki/%s' % page.normalize_title(page.page_title)

    print '------------------------------------------------------------------'
    print 'Downloading images from %s' % page_url
    print '...'

    # iterates through the image objects and saves them
    counter = 0
    for image in page.images():

        # Skip commons logo
        if image.page_title.find('Commons-logo') == 0:
            continue

        if image.page_title.lower().find('.svg') >= 0 and no_graphics:
            print '- .svg not downloaded (%s)' % image.page_title
            continue
        if image.page_title.lower().find('.png') >= 0 and no_graphics:
            print '- .png not downloaded (%s)' % image.page_title
            continue

        if image.page_title.find('logo') >= 0 and no_logos:
            continue

        # Skip flags
        if image.page_title.find('Flag of ') == 0 and no_flags:
            continue

        fr = image.download()
        filename = '%s/%s|%s' % (IMAGE_FOLDER, page.normalize_title(page.page_title), page.normalize_title(image.page_title))
        # Avoid downloading duplicates
        duplicate = False
        try:
            fw = open(filename)
            duplicate = True
        except IOError:
            fw = open(filename, 'wrb')
            while True:
                s = fr.read(4096)
                if not s: break
                fw.write(s)
        fr.close() # Always close those file objects !!!
        fw.close()
        counter += 1
        print '+ Downloaded: %s' % filename if not duplicate else '+ Already downloaded: %s' % filename

    return counter


# get a page - this should be a list page
list_page = site.Pages[PAGE_NAME]

total_links = 0
for link in list_page.links():
    total_links += 1

counter = 0
links_crawled = 0
for link in list_page.links():
    if link.page_title.find('List of ') == 0:
        # its a link to a list, so dont download
        print '-- Link to a list (%s) - not downloading images' % link.page_title
        continue
    try:
        counter += download_images(link, no_flags=True, no_graphics=True, no_logos=True)
    except Exception, exc:
        print '-- Error (%s): %s' % (link.page_title, exc)
        continue
    links_crawled += 1
    print 'crawler.py: %d percent complete' % int(links_crawled*100/total_links)

print ''
print 'Success! Downloaded %d images to %s' % (counter, IMAGE_FOLDER)
print ''


