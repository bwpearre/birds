from scipy.io import loadmat
from glob import glob
from collections import defaultdict
import json
import os
# import argparse as args
import sys
import pprint
# import Queue
from concurrent.futures import ThreadPoolExecutor
import concurrent.futures as conf

def add_to_main_data(main, new):
    for (key, value) in new.items():
        main[key].add(value)
    return main

def convert_data(data):
    temp = {}
    for key, value in data.items():
        temp_value = sorted(list(value))
        # if temp_value[0] == list:
        temp[key] = temp_value
    return temp

def generate_data_summary(f):
    struct = {}
    matfile = loadmat(f, squeeze_me=True)
    try:
        struct['current'] = round(float(matfile['data'][('current')]), 3)
        struct['negative_first'] = tuple(map(lambda a: int(a), matfile['data'][('negativefirst')].tolist()))
        struct['stim_electrodes'] = tuple(map(lambda a: int(a), matfile['data'][('stim_electrodes')].tolist()))
        struct['bird'] = str(matfile['data'][('bird')])
        struct['data_version'] = int(matfile['data'][('version')])
        struct['repetition_freq'] = float(matfile['data'][('repetition_Hz')])
        struct['pulse_halftime'] = float(matfile['data'][('halftime_us')])
        struct['interpulse_interval'] = float(matfile['data'][('interpulse_s')])
    except Exception as e:
        # print('Problem with {}'.format(f))
        # print('Dtypes = {}'.format(matfile['data'].dtype))
        pass
    return struct


def main():
    # data_queue = Queue.Queue()
    files = glob('*.mat')
    if not files:
        print('No files in this directory that match stimulation!')
        print('Please navigate to the proper directory')
        return

    print('Need to go through {} files'.format(len(files)))

    savefile = os.path.basename(os.getcwd()) + '-parameters.json'
    data = defaultdict(set)
    ff = 0
    with ThreadPoolExecutor(max_workers=8) as thread:
        future_res = [thread.submit(generate_data_summary, f) for f in files]
        for future in conf.as_completed(future_res):
            sys.stdout.write('On file {} \r'.format(ff))
            sys.stdout.flush()
            ff += 1
            data = add_to_main_data(data, future.result())
    data = convert_data(data)
    with open(savefile, 'w') as save:
        d = json.dump(data, save)
    with open(savefile[:-4] + 'txt', 'w') as save:
        pprint.pprint(data, save)

    print('Parameters file created, enjoy!')



if __name__ == '__main__':
    main()
