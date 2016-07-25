clear;

a = load('/Volumes/Data/song/lny64/roboaggregate 1.mat');
song  =  a.audio.data;
fs = a.audio.fs;

nonsong = load_nonmatching_data(size(song, 2)*10, ...
    '/Volumes/Data/song/lny64/2015-10-23/chop_data/wav', ...
    size(song, 1), ...
    fs);

save song song nonsong fs;
