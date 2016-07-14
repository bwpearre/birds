clear;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if false
    BIRD='lno57rlg';
    datadir = '/Volumes/Data/song/lno57rlg';
    matching_song_file = 'AudioDataFiles';
    cluster_results_file = 'cluster_results';
    aligned_song_file = 'Will2Ben';
    trim_range = [0.274 0.938];
    nonsinging_fraction = 10;          % At most this much nonsong data will be converted
else
    BIRD='llb5';
    datadir = '/Volumes/Data/song/llb5';
    matching_song_file = 'AudioDataFiles';
    cluster_results_file = 'cluster_results';
    aligned_song_file = 'mic_data';
    %trim_range = [0.274 0.938];
    nonsinging_fraction = 10;          % At most this much nonsong data will be converted
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


% First load all data, because that's where Will keeps the sample rate
load(strcat(datadir, filesep, matching_song_file, '.mat'));
fs = AudioData{1}.rate;


% Now the aligned songs
load(strcat(datadir, filesep, aligned_song_file, '.mat'));
MIC_DATA = mic_data;

if exist('trim_range', 'var')
    trim_range_s = round(trim_range * fs);
    trim_i = trim_range_s(1) : trim_range_s(2);
    MIC_DATA = MIC_DATA(trim_i, :);
end

save(strcat(datadir, filesep, 'song'), 'MIC_DATA', 'fs');



[nsamples_per_song, nmatchingsongs] = size(MIC_DATA);


%% And now identify and convert the nonsong chunks

nnonmatches = nonsinging_fraction * nmatchingsongs;

MIC_DATA = [];

load(strcat(datadir, filesep, cluster_results_file));


n = length(sorted_syllable);

nonmatch_i = zeros(1,n);
nonmatch_samples = 0;
for i = 1:n
    nonmatch_i(i) = isempty(sorted_syllable{i});
    if nonmatch_i(i)
        nonmatch_samples = nonmatch_samples + length(AudioData{i}.data);
    end
end
nonmatch_n = sum(nonmatch_i);
nonmatch_s = nonmatch_samples / fs;
disp(sprintf('%d nonmatching chunks, %s seconds, %d song-length chunks.', ...
    nonmatch_n, sigfig(nonmatch_s, 2), floor(nonmatch_s / (nsamples_per_song / fs))));


% Load everything in.  Each chunk is much longer than a detected syllable.  Let's use them all!
allsamples = zeros(nonmatch_samples, 1);
allsamples_ind = 0;
for i = find(nonmatch_i)
    samplerate = AudioData{i}.rate;
    
    if fs ~= samplerate
        disp(sprintf('AudioData{%d}.rate = %d, but fs = %d.  Converting...', samplerate, fs));
        [a b] = rat(fs/samplerate);
        d = double(AudioData{i}.data);
        AudioData{i}.data = resample(d, a, b);
    end
    allsamples(allsamples_ind+1:allsamples_ind+length(AudioData{i}.data)) = AudioData{i}.data;
    allsamples_ind = allsamples_ind + length(AudioData{i}.data);
end


if length(allsamples) < nnonmatches * nsamples_per_song
    nnonmatches = floor(nonmatch_s / (nsamples_per_song / fs));
    warning('Not enough nonmatching data: %d chunks, %d seconds, NOW USING ONLY %d nonsongs.', ...
        nonmatch_n, ...
        floor(length(allsamples)/samplerate), ...
        nnonmatches);
end

MIC_DATA = zeros(nsamples_per_song, nnonmatches);

ind = 0;
nnonmatches_so_far = 0;
for i = 1:nnonmatches
    MIC_DATA(:, i) = allsamples(ind+1 : ind+nsamples_per_song);
    ind = ind + nsamples_per_song;
end

save(strcat(datadir, filesep, 'nonsong'), 'MIC_DATA', 'fs');
