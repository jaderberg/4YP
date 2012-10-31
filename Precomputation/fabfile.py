# Fabric script for precomputation
from fabric.api import env, cd, run, local, put, get, prompt
from fabric.contrib.files import exists
from fabric.contrib.console import confirm
import time
import paramiko
import sys

host_template = 'engs-station%s.eng.ox.ac.uk'
env.host_string = 'kebl3465@engs-station49.eng.ox.ac.uk'
env.host = 'engs-station49.eng.ox.ac.uk'
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

data_dir = "d_colourmodel"


exclude_hosts = [44,53,64]


good_hosts = []

def precompute():
    # The main process
    upload_matlab = confirm('Upload new matlab?', default=False)
    if not upload_matlab:
        upload_scripts_flab = confirm('Upload new scripts', default=False)
    else:
        upload_scripts_flab = True
    start_machine_num = prompt('Starting machine #: ', key='start_machine', default='39')
    stop_machine_num = prompt('Stop machine #: ', key='stop_machine', default='70')
    matlab_func = prompt('Matlab function to run: ', key='matlab_func', default='dist_wikilist_db_creator')
    env.suppress_errors = confirm('Suppress Matlab errors?', default=True)
    run_mongodb_flag = confirm('Run mongodb?', default=True)
    if run_mongodb:
        prompt('Mongodb data directory: ', key='mongo_data', default='~/4YP/data/%s/mongodb' % data_dir)
        prompt('Mongodb log directory: ', key='mongo_logs', default='~/4YP/data/%s/mongo_logs' % data_dir)


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
        print_message('CANCELLED!')
        return False

    run_on_each_host()

    wait_for_all_finish()

    print_message('PRECOMPUTE DONE')

def full_precompute():
    # The main process
    upload_matlab = confirm('Upload new matlab?', default=False)
    if not upload_matlab:
        upload_scripts_flab = confirm('Upload new scripts', default=False)
    else:
        upload_scripts_flab = True
    start_machine_num = prompt('Starting machine #: ', key='start_machine', default='39')
    stop_machine_num = prompt('Stop machine #: ', key='stop_machine', default='70')
    env.suppress_errors = confirm('Suppress Matlab errors?', default=True)

    prompt('Mongodb data directory: ', key='mongo_data', default='~/4YP/data/%s/mongodb' % data_dir)
    prompt('Mongodb log directory: ', key='mongo_logs', default='~/4YP/data/%s/mongo_logs' % data_dir)

    skip_vocab = confirm('Use existing vocab?', default=True)
    if skip_vocab:
        vocab_file = prompt('Existing vocab.mat file to use: ', default='./kebl3465@engs-station49.eng.ox.ac.uk/vocab_colour.mat')
        root_dir = prompt('Project root dir: ', default='~/4YP/data/%s' % data_dir)

    tasks = []

    tasks.append(get_good_hosts)
    if upload_matlab:
        tasks.append(upload_current_matlab)

    if upload_scripts_flab:
        tasks.append(upload_scripts)

    tasks.append(run_mongodb)

    for subtask in tasks:
        subtask()

    if not confirm('Continue with Matlab?', default=True):
        print_message('CANCELLED!')
        return False

    # build db
    env.matlab_func = 'dist_wikilist_db_creator'
    run_on_each_host()
    wait_for_all_finish()

    # extract features
    env.matlab_func = 'dist_compute_features'
    run_on_each_host()
    wait_for_all_finish()

    # create vocab
    if not skip_vocab:
        env.matlab_func = 'dist_vocab_creation'
        run_single(0)
        wait_for_single_finish(0)
    else:
        if good_hosts:
            use_host(0)
        put(vocab_file, '%s/data/model/vocab.mat' % root_dir)
        print_message('Uploaded vocab file')

    # create words
    env.matlab_func = 'dist_compute_words'
    run_on_each_host()
    wait_for_all_finish()

    # compute weights
    env.matlab_func = 'dist_compute_weights'
    run_single(0)
    wait_for_single_finish(0)

    # compute histograms
    env.matlab_func = 'dist_compute_histograms'
    run_on_each_host()
    wait_for_all_finish()

    # concatenate histogram fragments
    env.matlab_func = 'dist_cat_histograms'
    run_single(0)
    wait_for_single_finish(0)

#    # NOW FOR BING EXPANSION!
##    env.matlab_func = 'dist_bing_expansion_download'
##    run_on_each_host()
##    wait_for_all_finish()
##
##    env.matlab_func = 'dist_bing_expansion_weights'
##    run_single(0)
##    wait_for_single_finish(0)
##
##    env.matlab_func = 'dist_bing_expansion_histograms'
##    run_on_each_host()
##    wait_for_all_finish()
##
##    env.matlab_func = 'dist_bing_expansion_cat'
##    run_single(0)
##    wait_for_single_finish(0)
##
##    # OBJECT REGION ESTIMATION
##    env.matlab_func = 'dist_object_location_estimation_weighted'
##    run_on_each_host()
##    wait_for_all_finish()
##
##    env.matlab_func = 'dist_object_location_estimation_convhullkmeans'
##    run_on_each_host()
##    wait_for_all_finish()


    print_message('PRECOMPUTE DONE')

    # NOW VALIDATION

    env.matlab_func = 'dist_validate_model'
    run_on_each_host()
    wait_for_all_finish()

    env.matlab_func = 'dist_validate_model_report'
    run_single(0)
    wait_for_single_finish(0)

    print_message('VALIDATION COMPLETE')

#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-#


def kill_all():
    start_machine_num = prompt('Starting machine #: ', key='start_machine', default='39')
    stop_machine_num = prompt('Stop machine #: ', key='stop_machine', default='70')
    get_good_hosts()
    for i, host in enumerate(good_hosts):
        use_host(i)
        env.warn_only = True
        run('killall MATLAB')
        run('killall mongod')
        env.warn_only = False


def run_single(i):
    if good_hosts:
        use_host(i)
    with cd(env.visualindex_path):
        run('sh matlab_logs_cleanup.sh')
    ssh_matlab_run(env.matlab_func, 1, 1)


def wait_for_single_finish(i):
    if good_hosts:
        use_host(i)
    m_func = env.matlab_func
    finished = False
    while not finished:
        with cd(env.visualindex_path):
            finished = exists('finished_flags/%s-%s-finished.mat' % (i+1, m_func))
            print '%s finished? %s' % (env.host, finished)
            error = exists('error_logs/%s-%s-error.txt' % (i+1, m_func))
            if finished:
                print_message('Finished computing %s' % m_func)
                break
            elif error:
                print_message('ERRORS!!!!!')
                break
            else:
                print 'Not finished %s yet...' % m_func
            time.sleep(20)
    return finished



def wait_for_all_finish():
    while not all_jobs_finished(env.matlab_func):
        time.sleep(20)

def get_file(file_path):
    # gets a file from the server
    print_message('Downloaded %s' % get(file_path))

def all_jobs_finished(m_func):
    # checks that all the completed flags are there i.e. that matlab has all run and finished on each host
    if good_hosts:
        use_host(0)
    all_exist = True
    errors = False
    with cd(env.visualindex_path):
        for i, host in enumerate(good_hosts):
            finished = exists('finished_flags/%s-%s-finished.mat' % (i+1, m_func))
            print '%s finished? %s' % (host, finished)
            all_exist = all_exist and finished
            error = exists('error_logs/%s-%s-error.txt' % (i+1, m_func))
            errors = errors or error
    if all_exist:
        print_message('All hosts finished computing %s' % m_func)
    else:
        print 'Not finished %s yet...' % m_func

    if errors:
        print_message('ERRORS!!!!!')
        all_exist = True
        sys.exit()
    return all_exist

def upload_scripts():
    if good_hosts:
        use_host(0)
    put('dist_matlab_suppress.sh', '%(root_path)s/visualindex/dist_matlab_suppress.sh' % env)
    put('dist_matlab.sh', '%(root_path)s/visualindex/dist_matlab.sh' % env)
    put('matlab_logs_cleanup.sh', '%(root_path)s/visualindex/matlab_logs_cleanup.sh' % env)
    put('run_mongo.sh', '%(root_path)s/run_mongo.sh' % env)

def run_mongodb():
    # run mongodb on the first good host
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

    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(env.host, username=env.user, password=env.password)
    stdin, stdout, stderr = ssh.exec_command('killall mongod')
    print stdout.readlines()
    print stderr.readlines()
    cmd = 'cd %s && sh run_mongo.sh %s %s/mongolog.txt' % (env.root_path, env.mongo_data, env.mongo_logs)
    print 'running %s' % cmd
    stdin, stdout, stderr = ssh.exec_command(cmd)
    print stdout.readlines()
    print stderr.readlines()
    print_message('Mongo process started on %s...' % env.host)
    


def run_on_each_host():
    # run matlab on each good host
    ps = []
    N = len(good_hosts)
    # delete logs
    if good_hosts:
        use_host(0)
    with cd(env.visualindex_path):
        run('sh matlab_logs_cleanup.sh')
    for i, host in enumerate(good_hosts):
        use_host(i)
        ps.append(ssh_matlab_run(env.matlab_func, i+1, N))


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
        if i in exclude_hosts:
            continue
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
        put('./visualindex.zip','%(root_path)s/visualindex.zip' % env)
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
    stdin, stdout, stderr = ssh.exec_command(cmd)
    print stdout.readlines()
    print stderr.readlines()
    print_message('%s running...' % cmd)
    return ssh

    

def use_host(i):
    env.host = good_hosts[i]
    env.host_string = '%s@%s' % (env.user, env.host)
    
def print_message(msg):
    print '=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-='
    print '-----------------------------------------------------------------'
    print msg
    print '-----------------------------------------------------------------'
    print '=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-='
