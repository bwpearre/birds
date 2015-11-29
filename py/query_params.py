import os
import shutil
import glob
import imp
import pickle
import json


def main():
    if not os.path.exists('updated'):
        imp.load_source('generate_param_dump',
         os.path.expanduser('~/Documents/MATLAB/birds/py/generate_param_dump.py')).main()
        data = pickle.load(open(glob.glob('*.pkl')[0], 'rb'))
    else:
        data = pickle.load(open(glob.glob('*.pkl')[0], 'rb'))

    return data

def cp_files(data, key):
    flist = data[key]
    folder_name = '_'.join(list(map(lambda a: str(a), key)))
    print('Copying {} files to {}'.format(len(flist), folder_name))
    if not os.path.exists(folder_name):
        os.mkdir(folder_name)

    for f in flist:
        shutil.copy2(f, folder_name)

    return True

def open_json():
    with open(glob.glob('*.json')[0], 'r') as sa:
        s = json.load(sa)
    return s


if __name__=='__main__':
    data = main()
    params = open_json()
