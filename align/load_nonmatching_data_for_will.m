function [ out, nnonmatches] = load_nonmatching_data_for_will(nnonmatches, ...
    datadir, ...
    nsamples_per_song, ...
    samplerate);
    

MIC_DATA = [];


load(strcat(datadir, filesep, 'AudioDataFiles.mat'));
load(strcat(datadir, filesep, 'cluster_results.mat'));


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
nonmatch_s = nonmatch_samples / AudioData{1}.rate;
disp(sprintf('%d nonmatching chunks, %s seconds, %d song-length chunks.', ...
    nonmatch_n, sigfig(nonmatch_s, 2), floor(nonmatch_s / (nsamples_per_song / samplerate))));


% Load everything in.  Each chunk is much longer than a detected syllable.  Let's use them all!
allsamples = [];
for i = find(nonmatch_i)
    fs = AudioData{i}.rate;
    
    if fs ~= samplerate
        [a b] = rat(samplerate/fs);
        d = double(AudioData{i}.data);
        AudioData{i}.data = resample(d, a, b);
    end
    allsamples = [allsamples; AudioData{i}.data];
end

if length(allsamples) < nnonmatches * nsamples_per_song
    %warning('Not enough nonmatching data: %d chunks, %d seconds, NOW USING ONLY %d nonsongs.', ...
    %    nonmatch_n, ...
    %    floor(length(allsamples)/samplerate), ...
    %    floor(nonmatch_s / (nsamples_per_song / samplerate)));
    nnonmatches = floor(nonmatch_s / (nsamples_per_song / samplerate));
end

MIC_DATA = allsamples(1:nsamples_per_song);
ind = 0;
nnonmatches_so_far = 0;
for i = 2:nnonmatches
    ind = ind + nsamples_per_song;
    MIC_DATA = [MIC_DATA allsamples(ind+1:ind+nsamples_per_song)];
    
    % When we have the requested number, stop adding new ones
    nnonmatches_so_far = nnonmatches_so_far + 1;
    if nnonmatches_so_far >= nnonmatches
        break;
    end
end

[~, nsamples] = size(MIC_DATA);

out = MIC_DATA;
