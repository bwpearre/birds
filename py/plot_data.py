import seaborn as sns
import matplotlib.pyplot as plt
import numpy as np
import h5py
from glob import glob

def main(y_range=[-2, 2]):
    files = glob('*.mat')
    colors = sns.hls_palette(9, l=0.4, s=0.85)
    for f in files:
        handle_data(f, colors, y_range)

    return True

def handle_data(f, colors, y_range):
    df = h5py.File(f, 'r')
    data = df['data']
    plot(data, f[:-4], colors, y_range)
    df.close()

def plot(data, name, colors, y_range):

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
    plt.xlim([-0.5, 5])
    plt.ylim(y_range)
    plt.title('Current: {} N reps: {}'.format(int(data['stim']['current_uA'].value), int(data['stim']['n_repetitions'].value)))
    plt.savefig(name+'.png')
    plt.clf()
    plt.close()
