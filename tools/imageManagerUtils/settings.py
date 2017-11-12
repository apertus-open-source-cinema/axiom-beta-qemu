# Copyright (c) 2017, MIT Licensed, Medicine Yeh

# This file helps to read settings from bash script into os.environ

import os
import sys
import subprocess

# This path is the location of the caller script
MAIN_SCRIPT_PATH = os.path.dirname(os.path.abspath(sys.argv[0]))
# Set up the path to settings.sh
settings_path = os.path.join(MAIN_SCRIPT_PATH, 'settings.sh')
if not os.path.isfile(settings_path):
    print('Cannot find settings.sh in ' + MAIN_SCRIPT_PATH)
    exit(1)
# This is a tricky way to read bash envs in the script
env_str = subprocess.check_output('source {} && env'.format(settings_path), shell=True)
# Transform to list of python strings (utf-8 encodings)
env_str = env_str.decode('utf-8').split('\n')
# Transform from a list to a list of pairs and filter out invalid formats
env_list = [kv.split('=') for kv in env_str if len(kv.split('=')) == 2]
# Transform from a list to a dictionary
env_dict = {kv[0]: kv[1] for kv in env_list}
# Update the os.environ globally
os.environ.update(env_dict)
