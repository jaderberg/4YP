import urllib2
from BeautifulSoup import BeautifulSoup
from urlparse import urljoin
import csv
import os

class WikiUrlReader(object):
#    user_agent = "Mozilla/5.0 (Macintosh; U; Intel Mac OS X; en-US; rv:1.8.1.7) Gecko/2007091417 Firefox/2.0.0.7"
    user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_5) AppleWebKit/537.4 (KHTML, like Gecko) Chrome/22.0.1229.79 Safari/537.4"

    def read(self, url, fail_silently=True):
        try:
            headers = {'User-Agent': self.user_agent}
            req = urllib2.Request(url, headers=headers)
            c=urllib2.urlopen(req)
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
        f = open(file, 'wb')
        f.write(self.read(url, fail_silently=fail_silently))
        f.close()
        return file


class Crawler(object):
    num_images = 0
    image_file_urls_csv = None
    image_file_urls_csv_filename = None

    def crawl(self, pages, csv_filename="image_file_urls.csv"):
        """
        This crawls the list pages and downloads the album artwork.
        Structure of the pages are as follows:
        Page: List of no.1 albums from XXXX (e.g. http://en.wikipedia.org/wiki/List_of_number-one_albums_from_the_1990s_(UK))
            |______-> Tables ---> Album column ---> Album page
        """
        try:
            os.remove(csv_filename)
        except OSError:
            # file does not exist
            pass
        print "Saving image links to %s" % csv_filename
        self.image_file_urls_csv_filename = csv_filename
        self.image_file_urls_csv = csv.writer(open(csv_filename, "wb"))
        url_reader = WikiUrlReader()
        album_urls = []
        album_names = []
        album_artists = []
        for page in pages:
            print 'Looking for albums on %s' % page
            try:
                soup = BeautifulSoup(url_reader.read(page))
            except TypeError:
                continue
#            soup = self._get_content_body(soup)
            if soup is None:
                continue
            # First get all the album urls
            tables = soup.findAll('table', {'class': 'wikitable plainrowheaders sortable'})
            for table in tables:
                # see if there is an Album column
                album_col = -1
                artist_col = -1
                trs = table.findAll('tr')
                if not trs:
                    continue
                header_tr = trs[0]
                for i, th in enumerate(header_tr.findAll('th')):
                    if 'Artist' in th.text:
                        artist_col = i
                    if 'Album' in th.text and ('Albums' not in th.text):
                        album_col = i
                        break
                # skip table if it doesn't have an album column
                if album_col == -1:
                    continue
                # now get the urlz
                for i, tr in enumerate(trs):
                    if not i:
                        continue
                    # select the album column
                    tds = tr.findAll('td')
                    if not tds:
                        continue
                    album_td = tds[album_col - 1]
                    link = album_td.find('a')
                    if not link:
                        continue
                    if 'href' in dict(link.attrs):
                        href = link['href']
                        try:
                            album_urls.index(href)
                        except ValueError:
                            # add a new album in
                            album_urls.append(href)
                            album_names.append(link.text.strip('\r\n'))
                            # add the artist name if there
                            if artist_col != -1:
                                artist_td = tds[artist_col - 1]
                                link = artist_td.find('a')
                                if link:
                                    album_artists.append(link.text.replace('&amp;', '&').strip('\r\n'))
                                else:
                                    album_artists.append(None)
                            else:
                                album_artists.append(None)
        print "%d album pages found" % len(album_urls)
        # Now go through all the album pages and get the pics
        for k, album_url in enumerate(album_urls):
            full_url = urljoin(page, album_url)
            print 'Scraping %s' % full_url
            try:
                soup = BeautifulSoup(url_reader.read(full_url))
            except Exception:
                continue
            soup = self._get_content_body(soup)
            if soup is None:
                continue
            # Save the image links to the csv
            # two parts to title: {{wikipedia_url}}|{{readable name}}
            wikipedia_class = self._get_wiki_class(full_url)
            readable_class = ("%s - %s" % (album_artists[k], album_names[k])) if album_artists[k] else self._get_readable_class(full_url)
            page_title = "%s|%s" % (wikipedia_class, readable_class)
            image_links = self._get_image_links(soup)
            for link in image_links:
                if 'href' in dict(link.attrs):
                    self.image_file_urls_csv.writerow([page_title.replace('\u2013', '-').encode('utf8'), urljoin(full_url, link['href'])])
                    self.num_images += 1

        print '%d images crawled!' % self.num_images

    def _get_content_body(self, soup):
        main_content = soup.find('div', {"class": "mw-content-ltr"})
        if main_content is None:
            return None
        # remove navboxes
        navboxes = main_content.findAll('table', {'class': 'navbox'})
        [navbox.extract() for navbox in navboxes]
        return main_content

    def _get_image_links(self, soup):
        return soup.findAll('a', {'class': 'image'})

    def _get_readable_class(self, page):
        return urllib2.unquote(self._get_wiki_class(page).replace('%E2%80%93', '-').replace('%C3%A9', 'e').replace('#', ' ')).replace('_', ' ')

    def _get_wiki_class(self, page):
        return page.split('/')[-1]

class WikipediaImageExtractor(object):

    def __init__(self, csv_filename, out_dir, image_formats=None, max_image_dimension=None):
        self.csv_filename = csv_filename
        self.out_dir = out_dir
        self.image_formats = image_formats
        self.images_extracted = 0
        self.max_image_dimension = max_image_dimension

    def download_images(self):
        # Create output dir
        if not os.path.exists(self.out_dir):
            os.makedirs(self.out_dir)
            print 'Created %s' % self.out_dir
        url_reader = WikiUrlReader()
        c = csv.reader(open(self.csv_filename, 'rb'), lineterminator='\n')
        for i, row in enumerate(c):
            print 'Extracting image %d...' % i
            if len(row) != 2:
                print 'Invalid row format - skipping'
                continue
            dir_name = row[0]
            wiki_class_name = row[0].split('|')[0]
            image_file_url = row[1]
            # check format of image
            image_format = image_file_url.split('.')[-1]
            is_image = False
            if self.image_formats is not None:
                if self.image_formats.count(image_format):
                    is_image = True
            else:
                is_image = True
            if not is_image:
                print 'Image format not allowed %s - skipping' % image_format
                continue

            # go to file page
            try:
                soup = BeautifulSoup(url_reader.read(image_file_url))
            except Exception:
                print 'Something went wrong - skipping'
                continue
            full_media = soup.find('div', {"class": "fullMedia"})
            file_info = full_media.find('span', {'class': 'fileInfo'})
            # get original resolution
            info_string = file_info.string.replace('(', '').replace(')', '')
            info_words = info_string.replace(',', '').split(' ')
            full_width = float(info_words[0])
            full_height = float(info_words[2])
            aspect = float(float(full_width)/float(full_height))
            # get original url
            image_link = full_media.find('a')
            original_image_url = 'http:%s' % image_link['href']
            image_filename = image_link['title']
            # check resolution
            print 'Image has resolution %s x %s' % (int(full_width), int(full_height))
            if self.max_image_dimension is None:
                # no restriction on resolution
                image_download_url = original_image_url
            else:
                # download the appropriate size
                if max(full_width, full_height) > self.max_image_dimension:
                    if full_width > full_height:
                        thumb_width = self.max_image_dimension
                    else:
                        thumb_width = int(aspect*self.max_image_dimension)
                    image_download_url = '%s/%spx-%s' % (original_image_url.replace('/commons/', '/commons/thumb/') if original_image_url.count('/commons/') else original_image_url.replace('/en/', '/en/thumb/'), thumb_width, original_image_url.split('/')[-1])
                else:
                    # original image is smaller than max resolution
                    image_download_url = original_image_url

            # make class dir
            class_dir = '%s/%s' % (self.out_dir, dir_name)
            if not os.path.exists(class_dir):
                os.makedirs(class_dir)
                print 'Created %s' % class_dir

            # download the image
            out_filename = '%s/%s|%s.%s' % (class_dir, str(i), wiki_class_name, image_format.lower())
            try:
                print 'Downloading from %s to %s' % (image_download_url, out_filename)
            except UnicodeDecodeError:
                print 'Downloading to %s' % out_filename
            try:
                url_reader.read_to_file(image_download_url, out_filename)
            except Exception:
                continue
            self.images_extracted += 1
        print '-------------------------------------'
        print 'DOWNLOADED %d IMAGES' % self.images_extracted
        print '-------------------------------------'

album_list_pages = [
    'http://en.wikipedia.org/wiki/List_of_number-one_albums_from_the_1950s_(UK)',
    'http://en.wikipedia.org/wiki/List_of_number-one_albums_from_the_1960s_(UK)',
    'http://en.wikipedia.org/wiki/List_of_number-one_albums_from_the_1970s_(UK)',
    'http://en.wikipedia.org/wiki/List_of_number-one_albums_from_the_1980s_(UK)',
    'http://en.wikipedia.org/wiki/List_of_number-one_albums_from_the_1990s_(UK)',
    'http://en.wikipedia.org/wiki/List_of_number-one_albums_from_the_2000s_(UK)',
    'http://en.wikipedia.org/wiki/List_of_number-one_albums_from_the_2010s_(UK)',
]

crawler = Crawler()
crawler.crawl(album_list_pages, csv_filename='/Volumes/4YP/Images/ukno1albums.csv')
extractor = WikipediaImageExtractor('/Volumes/4YP/Images/ukno1albums.csv', '/Volumes/4YP/Images/ukno1albums_wiki', ['jpeg','jpg','JPG','JPEG'], 1000)
extractor.download_images()