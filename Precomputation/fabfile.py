# Fabric script for precomputation

from fabric.api import env, cd, run, local, put

host_template = 'engs-station%d.eng.ox.ac.uk'
env.host_string = 'kebl3465@engs-station40.eng.ox.ac.uk'
env.host = 'engs-station40.eng.ox.ac.uk'
env.port = '22'
env.user = 'kebl3465'
env.password = 'multipack'
env.root_path = '~/4YP'
env.visualindex_path = '%s/visualindex' % env.root_path
env.skip_bad_hosts = True
env.connection_attempts = 1
env.timeout = 10

good_hosts = []

def test_server():
    with cd(env.root_path):
        run('mkdir test_server')
        run('rmdir test_server')

def get_good_hosts():
    # Test for good machines to use
    for i in range(39, 70, 1):
        env.host = host_template % i
        env.host_string = '%s@%s' % (env.user,  env.host)
        try:
            test_server()
            print 'Connected %s' % env.host
            good_hosts.append(env.host)
        except Exception:
            print 'Timeout %s' % env.host

    print '%d good hosts to connect to' % len(good_hosts)
    return good_hosts

def upload_current_matlab():
    # Uploads all the current matlab to the matlab folder
    # zip up folder
    local('rm -f visualindex.zip')
    local('zip -r visualindex.zip ../visualindex/')
    if good_hosts:
        use_host(0)
    with cd(env.root_path):
        # remove existing
        run('rm -f visualindex.zip')
        # upload
        put('/Users/jaderberg/Sites/4YP/Precomputation/visualindex.zip','%(root_path)s/visualindex.zip' % env)
        # remove existing
        run('rm -rf visualindex')
        # unzip
        env.warn_only = True
        run('unzip visualindex.zip')
        env.warn_only = False
        # cleanup
        run('rm -f visualindex.zip')
    # local cleanup
    local('rm -f visualindex.zip')
    print_message('Uploaded current code to %s' % env.visualindex_path)

def run_matlab_function(m_file):

    with cd(env.visualindex_path):
        run


def use_host(i):
    env.host = host_template % good_hosts[i]
    env.host_string = '%s@%s' % (env.use, env.host)
    
def print_message(msg):
    print '=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-='
    print '-----------------------------------------------------------------'
    print msg
    print '-----------------------------------------------------------------'
    print '=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-='
