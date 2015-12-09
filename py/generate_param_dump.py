# from scipy.io import loadmat
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
import subprocess
import h5py
import pickle

def old_matlab_version(f):
    try:
        g = h5py.File(f, 'r')
        g.close()
        return False
    except:
        return True

def convert_matlab():
    matlab_path = '/Applications/MATLAB_R2015a.app/bin/matlab'
    home = os.path.expanduser('~')
    script = 'Documents/MATLAB/birds/plexon'
    out = subprocess.check_output([matlab_path, '-nodesktop', '-nosplash', '-nodisplay', '-r', "addpath('{}');{};exit;".format(os.path.join(home, script),'update_all_stim_files')])

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
    matfile = h5py.File(f, 'r')
    try:
        struct['current'] = float(matfile['data']['stim']['current_uA'].value)
        struct['current_approx'] = int(matfile['data']['stim']['current_uA'].value)
        struct['negative_first'] = tuple(map(lambda a: int(a), matfile['data']['stim']['negativefirst'].value))
        struct['stim_electrodes'] = tuple(map(lambda a: int(a), matfile['data']['stim']['active_electrodes'].value))
        struct['bird'] = matfile['data']['bird'].value.tostring().decode('utf-8')[::2]
        struct['data_version'] = int(matfile['data']['version'].value)
        struct['repetition_freq'] = float(matfile['data']['stim']['repetition_Hz'].value)
        struct['pulse_halftime'] = float(matfile['data']['stim']['halftime_s'].value)
        struct['interpulse_interval'] = float(matfile['data']['stim']['interpulse_s'].value)
    except Exception as e:
        # print('Problem with {}'.format(f))
        # print('Dtypes = {}'.format(matfile['data'].dtype))
        # print(e)
        pass
    return struct

def map_data_to_file(maindata, data, filename):
    for key, value in data.items():
        maindata[(key, value)].append(filename)
    return maindata

def main():
    # data_queue = Queue.Queue()
    path = 'updated'
    mapped_data = defaultdict(list)
    print('Converting matlab data to updated structs and hdf5 format')
    if not os.path.exists(path):
        print('Converting')
        convert_matlab()
    else:
        print('Files have already been converted to proper matlab format')
    files = glob(os.path.join(path,'*.mat'))
    print('Generating parameters file')
    print('Need to go through {} files'.format(len(files)))

    savefile = os.path.basename(os.getcwd()) + '-parameters.json'
    data = defaultdict(set)
    ff = 0
    with ThreadPoolExecutor(max_workers=8) as thread:
        future_res = {thread.submit(generate_data_summary, f):f for f in files}
        for future in conf.as_completed(future_res):
            sys.stdout.write('On file {} \r'.format(ff))
            sys.stdout.flush()
            ff += 1
            struct = future.result()
            mapped_data = map_data_to_file(mapped_data, struct, future_res[future])
            data = add_to_main_data(data, struct)
    data = convert_data(data)

    with open(savefile, 'w') as save:
        d = json.dump(data, save)
    with open(savefile[:-4] + 'txt', 'w') as save:
        pprint.pprint(data, save)

    with open(savefile[:-5] + 'file_db.pkl', 'wb') as save:
        pickle.dump(mapped_data, save)

    print('File database created, enjoy!')
    print('Parameters file created, enjoy!')


if __name__ == '__main__':
    main()
