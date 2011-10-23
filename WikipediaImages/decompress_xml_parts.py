import os
import bz2
import glob

PATH_TO_PARTS = '/Volumes/4YP/wiki_parts'

FOLDER_FOR_XML = '/Volumes/4YP/wiki_parts/xml_parts'

if not os.path.exists(FOLDER_FOR_XML):
    os.makedirs(FOLDER_FOR_XML)
    print 'Created %s' % FOLDER_FOR_XML

counter = 0
os.chdir(PATH_TO_PARTS)
total_num = len(glob.glob('*.bz2'))
for file in glob.glob('*.bz2'):

    fr = open(file)
    filename = '%s/%s' % (FOLDER_FOR_XML, file.replace('.bz2', ''))
    try:
        fw = open(filename)
        print '+ %s already decompressed' % file
    except IOError:
        fw = open(filename, 'wrb')
        s = bz2.decompress(fr.read())
        fw.write(s)
        print '+ Decompressed %s' % file
    fr.close() # Always close those file objects !!!
    fw.close()
    counter += 1
    print '%d percent complete' % int(counter*100/total_num)

print '--------------------------------'
print 'Decompressed %d bz2 files to %s' % (counter, FOLDER_FOR_XML)