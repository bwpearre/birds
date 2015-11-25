import os
import shutil
import glob
import imp
import pickle


def main():
    if not glob.glob('*.pkl'):
        imortlib.imp.load_module('generate_param_dump').main()
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


if __name__=='__main__':
    main()
