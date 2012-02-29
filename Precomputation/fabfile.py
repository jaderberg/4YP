# Fabric script for precomputation
from fabric.api import env, cd, run, local, put, get, prompt
from fabric.network import disconnect_all
from multiprocessing import Process
from fabric.contrib.console import confirm
import time
import paramiko

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
env.suppress_errors = True
env.mongo_data = None
env.mongo_logs = None


good_hosts = []
mongo_p = None

def precompute():
    # The main process
    upload_matlab = confirm('Upload new matlab?', default=False)
    upload_scripts_flab = confirm('Upload new scripts', default=False)
    start_machine_num = prompt('Starting machine #: ', key='start_machine', default='39')
    stop_machine_num = prompt('Stop machine #: ', key='stop_machine', default='70')
    matlab_func = prompt('Matlab function to run: ', key='matlab_func', default='dist_wikilist_db_creator')
    env.suppress_errors = confirm('Suppress Matlab errors?', default=True)
    run_mongodb_flag = confirm('Run mongodb?', default=True)
    if run_mongodb:
        prompt('Mongodb data directory: ', key='mongo_data', default='~/4YP/data/bing_expansion/mongodb')
        prompt('Mongodb log directory: ', key='mongo_logs', default='~/4YP/data/bing_expansion/mongo_logs')

    tasks = []

    tasks.append(get_good_hosts)
    if upload_matlab:
        tasks.append(upload_current_matlab)
        
    if upload_scripts_flab:
        tasks.append(upload_scripts)

    if run_mongodb:
        tasks.append(run_mongodb)

    for subtask in tasks:
        subtask()

    if not confirm('Continue with Matlab?', default=True):
        if mongo_p:
            mongo_p.terminate()
        print_message('CANCELLED!')
        return False

    run_on_each_host()

    if mongo_p:
        mongo_p.terminate()

    print_message('PRECOMPUTE DONE')

def upload_scripts():
    disconnect_all()
    if good_hosts:
        use_host(0)
    put('dist_matlab_suppress.sh', '%(root_path)s/visualindex/dist_matlab_suppress.sh' % env)
    put('dist_matlab.sh', '%(root_path)s/visualindex/dist_matlab.sh' % env)
    put('run_mongo.sh', '%(root_path)s/run_mongo.sh' % env)

def run_mongodb():
    # run mongodb on the first good host
    disconnect_all()
    if good_hosts:
        use_host(0)
    # delete mongo logs
    env.warn_only = True
    run('mkdir -p %s' % env.mongo_data)
    run('mkdir -p %s' % env.mongo_logs)
    env.warn_only = False
    with cd(env.mongo_logs):
        env.warn_only = True
        run('rm -f *.txt')
        env.warn_only = False

    mongo_p = Process(target=run_mongod)
    mongo_p.start()
    print_message('Mongo process started...')
    

def run_mongod():
    # run the daemon
    disconnect_all()
    with cd(env.root_path):
        env.warn_only = True
        run('killall mongod')
        time.sleep(5)
        env.warn_only = False
        run('sh run_mongo.sh %s %s/mongolog.txt' % (env.mongo_data, env.mongo_logs))
        time.sleep(5)
    print_message('Mongodb running on %s' % good_hosts[0])

def run_on_each_host():
    # run matlab on each good host
    disconnect_all()
    ps = []
    N = len(good_hosts)
    # delete logs
    with cd(env.visualindex_path):
        run('rm -f matlab_log*.txt nohup*.out error*.txt')
    disconnect_all()
    for i, host in enumerate(good_hosts):
        time.sleep(0.1)
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
        env.warn_only = True
        run('rm -rf visualindex')
        env.warn_only = False
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
    p = Process(target=ssh_matlab_run, args=(m_function,n,N))
    p.start()
    print_message('%s is running (%s of %s)...' % (m_function, n, N))
    return p

def _remote_matlab_run(m_function, n, N):
    with cd(env.visualindex_path):
        if env.suppress_errors:
            run("sh dist_matlab_suppress.sh %s %s %s %s %s" % (m_function, n, N, good_hosts[0], env.host))
        else:
            run("sh dist_matlab.sh %s %s %s %s %s" % (m_function, n, N, good_hosts[0], env.host))

def ssh_matlab_run(m_function, n, N):
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(env.host, username=env.user, password=env.password)
    if env.suppress_errors:
        matlab_run = "sh dist_matlab_suppress.sh %s %s %s %s %s" % (m_function, n, N, good_hosts[0] if good_hosts else env.host, env.host)
    else:
        matlab_run = "sh dist_matlab.sh %s %s %s %s %s" % (m_function, n, N, good_hosts[0] if good_hosts else env.host, env.host)
    cmd = 'cd %s && %s' % (env.visualindex_path, matlab_run)
    print 'running %s' % cmd
    ssh.exec_command(cmd)
    print_message('%s run!' % cmd)

    

def use_host(i):
    env.host = good_hosts[i]
    env.host_string = '%s@%s' % (env.user, env.host)
    
def print_message(msg):
    print '=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-='
    print '-----------------------------------------------------------------'
    print msg
    print '-----------------------------------------------------------------'
    print '=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-='
