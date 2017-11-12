# Copyright (c) 2017, MIT Licensed, Medicine Yeh

import os
import sys
import subprocess

import sh
import logzero
from logzero import logger

IMAGE_DIR = os.environ.get('IMAGE_DIR')
# The name of ROOTFS_DIR must be .rootfs for safety.
ROOTFS_DIR = os.path.join(IMAGE_DIR, '.rootfs')
LOOP_DIR = os.path.join(IMAGE_DIR, '.loops')


def automount(image, mount_point, user=False, withFork=False):
    path_exist_or_exit(mount_point)
    try_unmount(mount_point, user)
    if withFork:
        pid = os.fork()
        # parent process, return and keep running
        if pid > 0: return
    if image['type'] == 'MBR':
        sh.mkdir('-p', LOOP_DIR)
        if user:
            try_unmount(LOOP_DIR, user)
            sh.mbrfs(image['path'], LOOP_DIR)
        for idx, part in enumerate(image['partitionTable']):
            source_file = os.path.join(LOOP_DIR, str(idx + 1))
            target_folder = os.path.join(mount_point, 'p' + str(idx + 1))
            try_unmount(target_folder, user)
            if user:
                sh.mkdir('-p', target_folder)
                # TODO mount FAT/BTRFS/etc. with fuse
                sh.ext4fuse(source_file, target_folder, _ok_code=range(255))
            else:
                sh.sudo.mkdir('-p', target_folder, _fg=True)
                options = get_mount_options(image, idx + 1, noerror=True)
                if options:
                    sh.sudo.mount(image['path'], target_folder, options=options, _fg=True)
    elif image['type'] == 'CPIO':
        safely_clean_dir(mount_point, user)
        if user:
            os.system('cd {} && cpio -idu --quiet < "{}"'.format(mount_point, image['path']))
        else:
            os.system('cd {} && sudo cpio -idu --quiet < "{}"'.format(mount_point, image['path']))
    else:
        try_unmount(mount_point, user)
        if user:
            sh.ext4fuse(image['path'], mount_point, _fg=True)
        else:
            sh.sudo.mount(source=image['path'], target=mount_point, _fg=True)


def autounmount(image, mount_point, user=False):
    path_exist_or_exit(mount_point)
    if image['type'] == 'MBR':
        try_unmount(mount_point, user)
        try_unmount(LOOP_DIR, user=True)
        for idx, part in enumerate(image['partitionTable']):
            target_folder = os.path.join(mount_point, 'p' + str(idx + 1))
            try_unmount(target_folder, user)
            if user and os.path.exists(target_folder):
                sh.rmdir(target_folder, _fg=True, _ok_code=range(255))
            if not user and os.path.exists(target_folder):
                sh.sudo.rmdir(target_folder, _fg=True, _ok_code=range(255))
    elif image['type'] == 'CPIO':
        if not user:
            os.system('cd {} && sudo find . | sudo cpio -H newc --quiet -o > "{}"'.format(
                mount_point, image['path']))
        safely_clean_dir(mount_point, user)
    else:
        try_unmount(mount_point, user)


def file_exist_or_exit(path):
    if not os.path.isfile(path):
        logger.error('Cannot find "{}"'.format(path))
        exit(1)


def path_exist_or_exit(path):
    if not os.path.exists(path):
        logger.error('Cannot find "{}"'.format(path))
        exit(1)


def try_unmount(mount_point, user=False):
    sh.sync()
    try:
        sh.mountpoint(mount_point, '-q')
        if user:
            sh.fusermount('-quz', mount_point, _fg=True)
        else:
            sh.sudo.umount(mount_point, '-R', '-l', _fg=True)
    except sh.ErrorReturnCode:
        pass


def safely_clean_dir(mount_point, user=False):
    if not os.path.exists(mount_point):
        sh.mkdir('-p', mount_point)
        return 0
    try:
        sh.mountpoint(mount_point, '-q')
        logger.error('Error: Mount point is sill occupied by others: ' + mount_point)
        exit(1)
    except sh.ErrorReturnCode:
        pass
    if user:
        sh.rm('-rf', mount_point, _fg=True)
    else:
        sh.sudo.rm('-rf', mount_point, _fg=True)
    sh.mkdir('-p', mount_point)
    return 0


def get_mount_options(image, partition=1, noerror=False):
    img = image.get('partitionTable')
    if img is None: return None
    logger.debug(img)

    part = img['partitions'][partition - 1]
    if part['mountable'] == False:
        if noerror:
            return None
        logger.error('Target partition is not mountable')
        print(part)
        exit(1)
    options = 'loop,offset={},sizelimit={}'.format(part['offset'], part['sizelimit'])
    return options


class Cpio():
    def __init__(self, *args, **kwargs):
        try:
            self.image_file = kwargs['source']
            self.mount_point = kwargs['target']
        except KeyError:
            self.image_file = args[0]
            self.mount_point = args[1]

        file_exist_or_exit(self.image_file)
        path_exist_or_exit(self.mount_point)
        logger.debug('Unfold {} onto {}'.format(self.image_file, self.mount_point))
        try_unmount(self.mount_point)
        safely_clean_dir(self.mount_point)
        os.system('cd {} && sudo cpio -idu --quiet < "{}"'.format(self.mount_point,
                                                                  self.image_file))

    def __enter__(self):
        return self

    def __exit__(self, type, value, traceback):
        sh.sync()
        os.system('cd {} && sudo find . | sudo cpio -H newc --quiet -o > "{}"'.format(
            self.mount_point, self.image_file))
        safely_clean_dir(self.mount_point)
        logger.debug('Clean {}'.format(self.mount_point))


class Mount():
    def __init__(self, *args, **kwargs):
        try:
            self.image_file = kwargs['source']
            self.mount_point = kwargs['target']
        except KeyError:
            self.image_file = args[0]
            self.mount_point = args[1]

        file_exist_or_exit(self.image_file)
        path_exist_or_exit(self.mount_point)
        logger.debug('Mount {} onto {}'.format(self.image_file, self.mount_point))
        try_unmount(self.mount_point)
        sh.sudo.mount(args, kwargs, _fg=True)

    def __enter__(self):
        return self

    def __exit__(self, type, value, traceback):
        sh.sync()
        # Try to umount and ignore any errors
        sh.sudo.umount(self.mount_point, '-R', '-l', _ok_code=range(255), _fg=True)
        logger.debug('Unmount {}'.format(self.mount_point))


class AutoMount():
    def __init__(self, *args, **kwargs):
        self.image = args[0]
        self.mount_point = ROOTFS_DIR
        self.image_file = self.image['path']
        self.image_type = self.image['type']

        file_exist_or_exit(self.image_file)
        path_exist_or_exit(self.mount_point)
        logger.debug('Unfold/Mount {} onto {}'.format(self.image_file, self.mount_point))

        try_unmount(self.mount_point)
        if self.image_type == 'CPIO':
            safely_clean_dir(self.mount_point)
            os.system('cd {} && sudo cpio -idu --quiet < "{}"'.format(self.mount_point,
                                                                      self.image_file))
        elif self.image_type == 'MBR':
            # Try to get options, return None if it does not require any options
            options = get_mount_options(self.image, self.image.get('targetPartition'))
            # Try to umount and ignore any errors
            sh.sudo.mount(self.image_file, self.mount_point, options=options, _fg=True)
        else:
            sh.sudo.mount(self.image_file, self.mount_point, _fg=True)

    def __enter__(self):
        return self

    def __exit__(self, type, value, traceback):
        sh.sync()
        if self.image_type == 'CPIO':
            os.system('cd {} && sudo find . | sudo cpio -H newc --quiet -o > "{}"'.format(
                self.mount_point, self.image_file))
            safely_clean_dir(self.mount_point)
        else:
            # Try to umount and ignore any errors
            subprocess.Popen('sudo umount -R -l {}'.format(self.mount_point).split())
        logger.debug('Clean/Unmount {}'.format(self.mount_point))
