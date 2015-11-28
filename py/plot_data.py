import seaborn as sns
import matplotlib.pyplot as plt
import numpy as np
import h5py
import os
from glob import glob

def main():
    files = glob(os.path.join('updated','*.mat'))
    colors = sns.hls_palette(9, l=0.4, s=0.85)
    for f in files:
        handle_data(f, colors)

    return True

def handle_data(f, colors):
    df = h5py.File(f, 'r')
    data = df['data']
    plot(data, f[:-4], colors)
    df.close()

def plot(data, name, colors):

    t = np.array(data['tdt']['times_aligned'])
    t_ind = np.where(((t>-0.0005)*(t<0.006)))[0]
    stim = data['tdt']['response']
    plt.figure(figsize=(10,8))
    if len(stim.shape) > 2:
        lines = plt.plot(t[t_ind]*1000, stim[1,t_ind,:]*1000, color=colors[4])
    else:
        lines = plt.plot(t[t_ind]*1000, stim[t_ind,:]*1000, color=colors[4])
    plt.xlabel('Time (ms)')
    plt.ylabel('Voltage (mV)')
    plt.title('Current: {} N reps: {}'.format(int(data['stim']['current_uA'].value), int(data['stim']['n_repetitions'].value)))
    plt.savefig(name+'.png')
    plt.clf()
    plt.close()
