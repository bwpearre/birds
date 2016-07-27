clear;

a = load('/Volumes/Data/song/lny64/roboaggregate 1.mat');
song  =  a.audio.data;
fs = a.audio.fs;

nonsong = load_nonmatching_data(size(song, 2)*10, ...
    '/Volumes/Data/song/lny29/2015-11-30/chop_data/wav', ...
    size(song, 1), ...
    fs);
disp(sprintf('Maximum nonsinging fraction: %s', sigfig(size(nonsong, 2) / size(song,2))));

save song song nonsong fs;
