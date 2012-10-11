#!/usr/bin/python

# Max Jaderberg 2012
#
# Downloads verification images from Google
# Input is directory path with class names as folders
# e.g. Images
#      |_______Class1-----1.jpg, 2.jpg, ...
#      |_______Class2-----1.jpg, 2.jpg, ...
# Output is the same structure but containing verification images

import os
import urllib2
from google import Google, ImageOptions, ImageType

IN_DIR = '/Volumes/4YP/Images/ukno1albums_wiki'
OUT_DIR = '/Volumes/4YP/Images/ukno1albums_google'
IMS_PER_CLASS = 5
EXCLUDE_DOMAIN = 'wikipedia.org'

def error(msg):
    import sys
    sys.exit("ERROR: %s" % msg)

class WikiUrlReader(object):
#    user_agent = "Mozilla/5.0 (Macintosh; U; Intel Mac OS X; en-US; rv:1.8.1.7) Gecko/2007091417 Firefox/2.0.0.7"
    user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_5) AppleWebKit/537.4 (KHTML, like Gecko) Chrome/22.0.1229.79 Safari/537.4"

    def read(self, url, fail_silently=True):
        try:
            headers = {'User-Agent': self.user_agent}
            req = urllib2.Request(url, headers=headers)
            c=urllib2.urlopen(req, timeout=10)
        except urllib2.HTTPError, e:
            if fail_silently:
                print "Could not open %s" % url
                print e
                return None
            else:
                raise urllib2.HTTPError, e
        return c.read()

    def read_to_file(self, url, file, fail_silently=True):
        try:
            os.remove(file)
        except OSError:
            # file does not exist
            pass
        data = self.read(url, fail_silently=fail_silently)
        if data:
            f = open(file, 'wb')
            f.write(data)
            f.close()
            return file
        else:
            return None

url_reader = WikiUrlReader()

# Check directories
if not os.path.exists(IN_DIR):
    error("Input directory %s does not exist" % IN_DIR)
if not os.path.exists(OUT_DIR):
    os.makedirs(OUT_DIR)
    print 'Created %s' % OUT_DIR

# Get class names
dir_names = [name for name in os.listdir(IN_DIR) if os.path.isdir(os.path.join(IN_DIR, name))]

opts = ImageOptions()
opts.image_type = ImageType.PHOTO

num_downloaded = 0

# Download images for each class
for dir_name in dir_names:
    wiki_class = dir_name.split('|')[0]
    readable_name = dir_name.split('|')[-1]
    num_class_downloaded = 0
    # search google
    res = Google.search_images("-%s %s" % (EXCLUDE_DOMAIN, readable_name) if EXCLUDE_DOMAIN else readable_name, opts)
    # class directory
    class_dir = os.path.join(OUT_DIR, dir_name)
    if not os.path.exists(class_dir):
        os.makedirs(class_dir)
        print 'Created %s' % class_dir
    for i, image_result in enumerate(res):
        if num_class_downloaded == IMS_PER_CLASS:
            break
        # download image
        out_filename = os.path.join(class_dir, "%d|%s.jpg" % (i, wiki_class))
        try:
            print 'Downloading %s to %s' % (image_result.link, out_filename)
        except UnicodeDecodeError:
            print 'Downloading to %s' % out_filename
        try:
            out = url_reader.read_to_file(image_result.link, out_filename)
            if out:
                num_class_downloaded += 1
                num_downloaded += 1
        except Exception:
            continue
print '-------------------------------------'
print 'DOWNLOADED %d IMAGES' % num_downloaded
print '-------------------------------------'