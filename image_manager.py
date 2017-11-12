#!/usr/bin/env python3
# Copyright (c) 2017, MIT Licensed, Medicine Yeh

# Import settings must be the first line to take effect on all custom modules
from tools.imageManagerUtils import settings

import os
import sys
import subprocess
import re
import logging
from itertools import chain

import sh
import logzero
from logzero import logger

# Utils designed for this script
from tools.imageManagerUtils import imageParser
from tools.imageManagerUtils import mount

# Define global variables
SCRIPT_PATH = os.path.dirname(os.path.abspath(sys.argv[0]))
IMAGE_DIR = os.environ.get('IMAGE_DIR')
# The name of ROOTFS_DIR must be .rootfs for safety.
ROOTFS_DIR = os.path.join(IMAGE_DIR, '.rootfs')

# Set a minimum log level
logzero.loglevel(logging.INFO)
# Set up debug mode settings
if os.environ.get('DEBUG'):
    logzero.loglevel(logging.DEBUG)


# ================ Util Functions ================
def check_input_image_format(arg):
    if arg is None or '@' not in arg:
        logger.error('image format error')
        exit(1)


def inform_user_sudo(mesg=''):
    print(mesg, file=sys.stderr)
    ret = os.system('sudo >&2 echo -e "\033[1;33mRunning with root privilege now...\033[0m";'
                    '[[ $? != 0 ]] && >&2 echo -e "\033[1;31mAbort\033[0m" && exit 4;'
                    'exit 0;')
    # First 8 bits is signal used by os, latter 8 bits is the return code of command
    ret = ret >> 8
    if ret:
        exit(1)


def parse_image(image_with_dir):
    image = {}
    image['path'] = imageParser.locate_image_path(image_with_dir.split('@')[0])
    image['targetPath'] = '/'.join(image_with_dir.split('@')[1:])
    # Removing the leading slash
    image['targetPath'] = image['targetPath'][1:]
    image['type'] = imageParser.parse_image_type(image['path'])
    if image['type'] == 'MBR':
        if len(image['targetPath'].split('/')) >= 2:
            image['targetPartition'] = int(image['targetPath'].split('/')[0][1:])
            # Set with default '/'
            image['targetPath'] = '/'.join(image['targetPath'].split('/')[1:])
        # Set up partition table
        image['partitionTable'] = imageParser.parse_partition_table(image['path'])
    return image


def cut_argv(argv, num=0):
    (command_argv, extended_argv) = (argv[:num], argv[num:])
    logger.debug('Command argv: ', command_argv)
    logger.debug('Extended argv: ', extended_argv)
    return (command_argv, extended_argv)


def remove_control_chars(text):
    # A map to remove control characters
    mpa = dict.fromkeys(range(32))
    return text.translate(mpa)


def find_ownership(path):
    dir_path = os.path.dirname(path)
    ret = subprocess.check_output('sudo stat -c "%u:%g" {}'.format(dir_path), shell=True)
    return remove_control_chars(ret.decode('utf-8'))


# ============= End of Util Functions ============


def find_image_list():
    def generate_type_list(a_list):
        b_list = [['-name', name, '-o'] for name in a_list]
        # Flatten the list and take out the last '-o'
        return list(chain.from_iterable(b_list))[:-1]

    black_list = ['rootfs', 'bootfs', 'linux*', 'build*', '*.fs']
    white_list = ['*.ext[1-5]', '*.cpio', '*.dd', '*.image', '*.img']

    opt_b = [*'-type d'.split(), '(', generate_type_list(black_list), ')']
    opt_w = [*'( -type l -o -type f )'.split(), '(', generate_type_list(white_list), ')']

    logger.debug(opt_b)
    logger.debug(opt_w)

    sh.cd(IMAGE_DIR)
    img_list = []
    exec_opt = ['-exec', 'file', '-L', '{}', ';']
    img_list = sh.find(*opt_b, '-prune', '-o', *opt_w, *exec_opt, _tty_out=False)
    # Remove empty string and strip the first two characters "./"
    img_list = [remove_control_chars(file_name)[2:] for file_name in img_list if file_name]
    # Cut the string into two folds. [NAME: TYPE]
    img_list = [[text.split(':')[0], ''.join(text.split(':')[1:])] for text in img_list]
    # Transform into dictionary and parse type string
    img_list = [{'name': kv[0], 'type': imageParser.get_type(kv[1])} for kv in img_list]
    logger.debug(img_list)

    return img_list


def do_single_arg_cmd(argv, command, extra_argv=[]):
    command_argv, extended_argv = cut_argv(argv, 1)
    if len(command_argv) != 1:
        logger.error('Number of arguments is not enough')
        exit(1)
    # Filter arguments with leading -
    extended_argv = [arg for arg in extended_argv if arg.startswith('-')]

    check_input_image_format(command_argv[0])
    image = parse_image(command_argv[0])
    logger.debug(image)

    inform_user_sudo('Need sudo to unfold/mount')
    with mount.AutoMount(image) as m:
        path = os.path.join(m.mount_point, image['targetPath'])
        try:
            sh.sudo(command, path, *extra_argv, *extended_argv, _fg=True)
        except sh.ErrorReturnCode:
            logger.error('Fail to execute command')
            exit(1)


def do_push(argv, extra_argv=[]):
    command_argv, extended_argv = cut_argv(argv, 2)
    if len(command_argv) != 2:
        logger.error('Number of arguments is not enough')
        exit(1)
    # Filter arguments with leading -
    extended_argv = [arg for arg in extended_argv if arg.startswith('-')]

    host_file, image_file = command_argv
    check_input_image_format(image_file)
    image = parse_image(image_file)
    logger.debug(image)

    inform_user_sudo('Need sudo to unfold/mount')
    with mount.AutoMount(image) as m:
        path = os.path.join(m.mount_point, image['targetPath'])
        try:
            ownership = find_ownership(path)
            logger.debug(host_file, path, ownership)
            sh.sudo.rsync('-a', '-o', '-g', '--chown=' + ownership, host_file, path, _fg=True)
        except sh.ErrorReturnCode:
            logger.error('Fail to execute command')
            exit(1)


def do_pull(argv, extra_argv=[]):
    command_argv, extended_argv = cut_argv(argv, 2)
    if len(command_argv) != 2:
        logger.error('Number of arguments is not enough')
        exit(1)
    # Filter arguments with leading -
    extended_argv = [arg for arg in extended_argv if arg.startswith('-')]

    image_file, host_file = command_argv
    check_input_image_format(image_file)
    image = parse_image(image_file)
    logger.debug(image)

    inform_user_sudo('Need sudo to unfold/mount')
    with mount.AutoMount(image) as m:
        path = os.path.join(m.mount_point, image['targetPath'])
        try:
            ownership = find_ownership(host_file)
            logger.debug(path, host_file, ownership)
            sh.sudo.rsync('-a', '-o', '-g', '--chown=' + ownership, path, host_file, _fg=True)
        except sh.ErrorReturnCode:
            logger.error('Fail to execute command')
            exit(1)


def do_query(argv, subcommand):
    # Match any of command, i.e. *of, e.g. typeof.
    if re.match(r'^\w+of$', subcommand):
        if os.path.isfile(argv[0]):
            path = argv[0]
        else:
            path = os.path.join(IMAGE_DIR, argv[0])

    if subcommand == 'list':
        image_list = find_image_list()
        for image in image_list:
            print(image['name'])
    elif subcommand == 'listWithType':
        image_list = find_image_list()
        for image in image_list:
            print('{} {}'.format(
                image['name'],
                image['type'],
            ))
    elif subcommand == 'typeof':
        print(imageParser.parse_image_type(path))
    elif subcommand == 'sizeof':
        image_size_text = sh.du('-L', '-h', path, _ok_code=range(255))
        print(image_size_text.split()[0])
    elif subcommand == 'pathof':
        print(imageParser.locate_image_path(path))
    elif subcommand == 'partitionTableof':
        path = imageParser.locate_image_path(path)
        img = imageParser.parse_partition_table(path)
        for idx, part in enumerate(img['partitions']):
            # index, start, end, size, offset, sizelimit, mountable
            print('{} {} {} {} {} {} {}'.format(idx + 1, part['start'], part['end'], part['size'],
                                                part['offset'], part['sizelimit'],
                                                part['mountable']))
    else:
        logger.error('Query command not supported: ' + str(subcommand))
        exit(1)


def do_mount(argv, user=False):
    if not user:
        inform_user_sudo('Need sudo to unfold/mount')
    image = parse_image(argv[0])
    mount.automount(image, argv[1], user)


def do_umount(argv, user=False):
    if not user:
        inform_user_sudo('Need sudo to unfold/mount')
    image = parse_image(argv[0])
    mount.autounmount(image, argv[1], user)


def print_help():
    print('''
Usage:
       {} <OPERATION> [IMAGE NAME] [OPTIONS...]
  Do something with disk images for simulation.

TYPE - 0: Information from outside
       list      : List all existing images

TYPE - 1: Do <OP> in image
       <OP>  <IMAGE>@/[PART]/<PATH> [OPTIONS...]

       where <OP> can be one of the followings:
       ls, rm, mkdir, file, etc.
       [OPTIONS...] can be empty or options to <OP>

       Example: list all the files in partition 2 with -alh
       {} ls test/image.img@/p2/ -alh
TYPE - 2:
       push  <PATH> <IMAGE>@/<PATH>  : Push a file/folder into image
       pull  <IMAGE>@/<PATH> <PATH>  : Pull a file/folder from image

'''.format(sys.argv[0], sys.argv[0]))


def main(argv):
    if not os.path.exists(IMAGE_DIR):
        logger.error('Cannot find IMAGE_DIR: ' + IMAGE_DIR)
        exit(1)

    # Create ROOTFS_DIR if not present
    sh.mkdir(ROOTFS_DIR, "-p")

    if len(argv) == 0 or argv[0] == '-h' or argv[0] == '--help':
        print_help()
        exit(0)
    single_arg_cmds = ['ls', 'rm', 'mkdir', 'file']
    auto_color_cmds = ['ls']

    # Remove one element from argument list
    command = argv.pop(0)
    if command == 'list':
        image_list = find_image_list()
        print('{:<40}{:<20}{:<20}'.format('IMAGE NAME', 'TYPE', 'SIZE'))
        for image in image_list:
            image_size_text = sh.du('-L', '-h', image['name'], _ok_code=range(255))
            image['sizeB'] = image_size_text.split()[0]
            print('{:<40}{:<20}{:<20}'.format(image['name'], image['type'], image['sizeB']))
    elif command == 'push':
        do_push(argv)
    elif command == 'pull':
        do_pull(argv)
    elif command in single_arg_cmds:
        extra_argv = []
        if command in auto_color_cmds:
            extra_argv += ['--color=auto']
        do_single_arg_cmd(argv, command, extra_argv)
    elif command == 'query':
        subcommand = argv.pop(0)
        do_query(argv, subcommand)
    elif command == 'mount':
        do_mount(argv)
    elif command == 'umount':
        do_umount(argv)
    elif command == 'userMount':
        do_mount(argv, user=True)
    elif command == 'userUmount':
        do_umount(argv, user=True)
    else:
        logger.error('Command not supported: ' + str(command))
        exit(1)


if __name__ == '__main__':
    main(sys.argv[1:])
