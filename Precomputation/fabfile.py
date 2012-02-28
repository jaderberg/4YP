# Fabric script for precomputation
from fabric.api import env, cd, run, local, put, get, prompt
from fabric.network import disconnect_all
from multiprocessing import Process
from fabric.contrib.console import confirm
import time

host_template = 'engs-station%s.eng.ox.ac.uk'
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
env.start_machine = '39'
env.stop_machine = '70'
env.matlab_func = 'test_server'


good_hosts = []

def precompute():
    # The main process
    upload_matlab = confirm('Upload new matlab?', default=False)
    start_machine_num = prompt('Starting machine #: ', key='start_machine', default='39')
    stop_machine_num = prompt('Stop machine #: ', key='stop_machine', default='70')
    matlab_func = prompt('Matlab function to run:', key='matlab_func', default='test_server')

    tasks = []

    tasks.append(get_good_hosts)
    if upload_matlab:
        tasks.append(upload_current_matlab)

    for subtask in tasks:
        subtask()

    run_on_each_host()

    print_message('PRECOMPUTE DONE')

def run_on_each_host():
    # run matlab on each good host
    disconnect_all()
    ps = []
    N = len(good_hosts)
    for i, host in enumerate(good_hosts):
        use_host(i)
        ps.append(run_matlab_function(env.matlab_func, i+1, N))

    # Thou shalt not pass till all processes be exited
    processes_done = False
    while not processes_done:
        time.sleep(5)
        processes_done = True
        for p in ps:
            processes_done = processes_done and (not p.is_alive())

def test_server():
    with cd(env.root_path):
        env.warn_only = True
        run('rmdir test_server')
        env.warn_only = False
        run('mkdir test_server')
        run('rmdir test_server')

def get_good_hosts():
    # Test for good machines to use
    for i in range(int(env.start_machine), int(env.stop_machine), 1):
        env.host = host_template % i
        env.host_string = '%s@%s' % (env.user,  env.host)
        try:
            test_server()
            print 'Connected %s' % env.host
            good_hosts.append(env.host)
        except Exception:
            print 'Timeout %s' % env.host

    print_message('%d good hosts to connect to' % len(good_hosts))

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

def run_matlab_function(m_function, n, N):
    # runs in a new process to allow parallel execution
    p = Process(target=_remote_matlab_run, args=(m_function,n,N))
    p.start()
    print_message('%s is running (%s of %s)...' % (m_function, n, N))
    return p

def _remote_matlab_run(m_function, n, N):
    with cd(env.visualindex_path):
        run("nohup nice matlab -nodesktop -nosplash -r '%s(%s,%s)' -logfile matlab_log%s.txt" % (m_function, n, N, n))

def use_host(i):
    env.host = good_hosts[i]
    env.host_string = '%s@%s' % (env.user, env.host)
    
def print_message(msg):
    print '=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-='
    print '-----------------------------------------------------------------'
    print msg
    print '-----------------------------------------------------------------'
    print '=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-='
