# Copyright (c) 2017, MIT Licensed, Medicine Yeh

import os
import sys
import sh

import logzero
from logzero import logger

IMAGE_DIR = os.environ.get('IMAGE_DIR')
# The name of ROOTFS_DIR must be .rootfs for safety.
ROOTFS_DIR = os.path.join(IMAGE_DIR, '.rootfs')


def file_exist_or_exit(path):
    if not os.path.isfile(path):
        logger.error('Cannot find "{}"'.format(path))
        exit(1)


def path_exist_or_exit(path):
    if not os.path.exists(path):
        logger.error('Cannot find "{}"'.format(path))
        exit(1)


def try_unmount(mount_point):
    sh.sync()
    try:
        sh.mountpoint(mount_point, '-q')
        sh.sudo.umount(mount_point, '-R', '-l', _fg=True)
    except sh.ErrorReturnCode:
        pass


def safely_clean_dir(mount_point):
    if not os.path.exists(mount_point):
        sh.mkdir('-p', mount_point)
        return 0
    try:
        sh.mountpoint(mount_point, '-q')
        logger.error('Error: Mount point is sill occupied by others: ' + mount_point)
        exit(1)
    except sh.ErrorReturnCode:
        pass
    sh.sudo.rm('-rf', mount_point, _fg=True)
    sh.mkdir('-p', mount_point)
    return 0


def get_mount_options(image, partition=1):
    img = image.get('partitionTable')
    if img is None: return None
    logger.debug(img)

    part = img['partitions'][partition - 1]
    if part['mountable'] == False:
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
        else:
            # Try to get options, return None if it does not require any options
            options = get_mount_options(self.image, self.image.get('targetPartition'))
            sh.sudo.mount(
                source=self.image_file, target=self.mount_point, options=options, _fg=True)

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
            sh.sudo.umount(self.mount_point, '-R', '-l', _ok_code=range(255), _fg=True)
        logger.debug('Clean/Unmount {}'.format(self.mount_point))
