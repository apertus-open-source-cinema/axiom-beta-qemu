# Copyright (c) 2017, MIT Licensed, Medicine Yeh

import os
import sys
import sh
import re

import logzero
from logzero import logger

IMAGE_DIR = os.environ.get('IMAGE_DIR')


def locate_image_path(image):
    tmp = image
    if os.path.isfile(image):
        tmp = os.path.abspath(image)
    if not os.path.isfile(tmp):
        tmp = os.path.join(IMAGE_DIR, tmp)
    if not os.path.isfile(tmp):
        logger.error('Target image not found ' + tmp)
        exit(1)
    return tmp


def get_type(text):
    if 'ASCII cpio archive' in text:
        return 'CPIO'
    elif 'MBR boot sector' in text:
        return 'MBR'
    elif re.match(r'.*Linux .* ext[0-9] filesystem.*', text):
        return 'E2FS'
    return ''


def parse_image_type(image):
    # Trace symbolic link with -L
    image_format = sh.file('-L', image, _ok_code=range(255))
    if 'ASCII cpio archive' in image_format:
        return 'CPIO'
    elif 'MBR boot sector' in image_format:
        return 'MBR'
    elif re.match(r'.*Linux .* ext[0-9] filesystem.*', str(image_format)):
        return 'E2FS'
    return ''


def parse_partition_table(file_path):
    # This is the magic function which makes thing so easy
    def numbers_in_text(text, indexes):
        numbers = [int(s) for s in text.split() if s.isdigit()]
        if isinstance(indexes, int):
            return numbers[indexes]
        else:
            return [numbers[i] for i in indexes]

    info = sh.fdisk('-l', file_path, _tty_out=False).split('\n')
    img = {'sectorSize': numbers_in_text(info[1], 2), 'partitions': []}
    # Starting from the 3rd line, find the lines with file_path text in it.
    partition_infos = [v for v in info[3:] if file_path in v]
    sizelimit = 0
    logger.debug('Partitions of image ' + file_path)
    for p in partition_infos:
        logger.debug(p)
        n = numbers_in_text(p, [0, 1, 2])
        if '83 Linux' in p or 'FAT32' in p:
            mountable = True
        else:
            mountable = False
        sizelimit += n[2]
        img['partitions'].append({
            'name': p.split()[0],
            'start': n[0],
            'end': n[1],
            'size': n[2],
            'offset': n[0] * img['sectorSize'],
            'sizelimit': sizelimit * img['sectorSize'],
            'mountable': mountable,
        })
    return img
