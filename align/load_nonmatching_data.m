function [ out ] = load_nonmatching_data(nnonmatches, ...
    datadir, ...
    mic_data_samples, ...
    samplerate);
    

wavs = dir(strcat(datadir, filesep, '*.wav'));

MIC_DATA = [];
for i = 1:length(wavs)
    filename = strcat(datadir, filesep, wavs(i).name);
    
    [ d, fs ] = audioread(filename);
        
    if fs ~= samplerate
        [a b] = rat(samplerate/fs);
        d = double(d);
        d = resample(d, a, b);
    end
    MIC_DATA = [MIC_DATA d'];
end

[~, nsamples] = size(MIC_DATA);

for i = 1:nnonmatches
    tstep = ceil(random('unif', 0, nsamples - mic_data_samples - 1));
    out(:, i) = MIC_DATA(1, tstep:tstep + mic_data_samples - 1);
end
