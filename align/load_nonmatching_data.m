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

tstep = 0;
out = zeros(mic_data_samples, nnonmatches);
for i = 1:nnonmatches
    out(:, i) = MIC_DATA(1, tstep+1 : tstep+mic_data_samples);
    tstep = tstep + mic_data_samples;
    if tstep + mic_data_samples > nsamples
        warning('Could only get %d nonmatching ''songs''.', i);
        out = out(:, 1:i);
        break;
    end
end
