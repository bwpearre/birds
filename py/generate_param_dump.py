from scipy.io import loadmat
from glob import glob
from collections import defaultdict
import json
import os
import argparse as args

def add_to_main_data(main, new):
    for (key, value) in new.items():
        main[key].add(value)
    return main

def generate_data_summary(f):
    struct = {}
    matfile = loadmat(f, squeeze_me=True)
    struct['current'] = float(matfile['data'][('current')])
    struct['negative_first'] = list(matfile['data'][('negativefirst')].tolist())
    struct['stim_electrodes'] = list(matfile['data'][('stim_electrodes')].tolist())
    struct['bird'] = str(matfile['data'][('bird')])
    struct['data_version'] = int(matfile['data'][('version')])
    struct['repetition_freq'] = float(matfile['data'][('repetition_Hz')])
    struct['pulse_halftime'] = float(matfile['data'][('halftime_us')])
    struct['interpulse_interval'] = float(matfile['data'][('interpulse_s')])
    return struct


def main():
    files = glob('*.mat')
    if not files:
        print('No files in this directory that match stimulation!')
        print('Please navigate to the proper directory')
        return

    savefile = os.path.basename(os.getcwd()) + '-parameters.json'
    data = defaultdict(set)
    for f in files:
        data = add_to_main_data(data, generate_data_summary(f))

    with open(savefile, 'w') as save:
        json.dump(data, save)

    print('Parameters file created, enjoy!')



if __name__ == '__main__':
    main()
