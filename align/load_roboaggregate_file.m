function [ MIC_DATA, spectrograms, nsamples_per_song, nmatchingsongs, nsongsandnonsongs, timestamps, nfreqs, freqs, ntimes, times, fft_time_shift_seconds, spectrogram_avg_img, freq_range_ds, time_window_steps, layer0sz, nwindows_per_song, noverlap] ...
    = load_roboaggregate_file(filename, ...
    fft_time_shift_seconds_target, ...
    target_samplerate, ...
    fft_size, ...
    freq_range, ...
    time_window, ...
    nonsinging_fraction, ...
    nonsinging_wav_src, ...
    load_exec_conversions, ...
    trim_range)

load(filename);

if exist('load_exec_conversions', 'var')
    for i = 1:length(load_exec_conversions)
        eval(load_exec_conversions{i});
    end
end

if ~exist('MIC_DATA', 'var') & exist('audio', 'var') & isfield(audio, 'data')
    MIC_DATA = audio.data;
    fs = audio.fs;
end

if exist('trim_range', 'var')
    trim_range_s = round(trim_range * fs);
    trim_i = trim_range_s(1) : trim_range_s(2);
    MIC_DATA = MIC_DATA(trim_i, :);
end


[orig_nsamples_per_song, nmatchingsongs] = size(MIC_DATA);

timestamps = zeros(1, nmatchingsongs);
if exist('extract_filename', 'var')
    for i = 1:nmatchingsongs
        foo = strsplit(strrep(extract_filename{i}, '\', '/'), '/'); % Make sure directories are separated with /, and split
        cow = strsplit(foo{end}, '.'); % Filename component contains timestamp
        cor = strsplit(cow{6}, '-'); % Seems this field has a relevant number and then a -
        cow{6} = cor{1}; % reinsert expurgated value
        timestamps(i) = datenum([str2double(cow(2:6)) 0]); % pad seconds=0, store timestamp
    end
    
    disp(sprintf('File %s: %s -- %s', filename, datestr(timestamps(1)), datestr(timestamps(end))));
end

%% Downsample the data to match target samplerate?
if fs ~= target_samplerate
        disp(sprintf('Resampling data from %g Hz to %g Hz...', fs, target_samplerate));
        [a b] = rat(target_samplerate/fs);
        
        MIC_DATA = double(MIC_DATA);
        MIC_DATA = resample(MIC_DATA, a, b);
end

%MIC_DATA = MIC_DATA / max(max(max(MIC_DATA)), -min(min(MIC_DATA)));

[nsamples_per_song, nmatchingsongs] = size(MIC_DATA);



%% Add non-singing data (or actually just allthedata)
MIC_DATA_NO = load_nonmatching_data(nonsinging_fraction * nmatchingsongs, ...
    nonsinging_wav_src, ...
    nsamples_per_song, ...
    target_samplerate);

MIC_DATA = [MIC_DATA MIC_DATA_NO];

[nsamples_per_song, nsongsandnonsongs] = size(MIC_DATA);

%disp('Bandpass-filtering the data...');
%[B A] = butter(4, [0.03 0.9]);
%MIC_DATA = single(filtfilt(B, A, double(MIC_DATA)));


% Compute the spectrogram using original parameters (probably far from
% optimal but I have not played with them).  Compute one to get size, then
% preallocate memory and compute the rest in parallel.

noverlap = fft_size - (floor(target_samplerate * fft_time_shift_seconds_target));
% SPECGRAM(A,NFFT=512,Fs=[],WINDOW=[],noverlap=500)
%speck = specgram(MIC_DATA(:,1), 512, [], [], 500) + eps;

window = hamming(fft_size);

[speck freqs times] = spectrogram(MIC_DATA(:,1), window, noverlap, [], target_samplerate);
% Adjust "times" to reflect the time at which the information is actually available--i.e. the end,
% rather than the middle, of the window:
times = times - times(1) + fft_size/target_samplerate;
[nfreqs, ntimes] = size(speck);
speck = speck + eps;

% This will be approximately the same as fft_time_shift_seconds_target, but not quite: the fft_time_shift
% is given by noverlap, and will actually be fft_size/target_samplerate
fft_time_shift_seconds = (times(end)-times(1))/(length(times)-1);
fprintf('FFT time shift = %d frames, %s... ms\n', ...
    floor(target_samplerate * fft_time_shift_seconds_target), ...
    sigfig(1000*fft_time_shift_seconds, 8));


spectrograms = zeros([nsongsandnonsongs nfreqs ntimes]);
spectrograms(1, :, :) = speck;
disp('Computing spectrograms...');
parfor i = 2:nsongsandnonsongs
        spectrograms(i, :, :) = spectrogram(MIC_DATA(:,i), window, noverlap, [], target_samplerate) + eps;
end

spectrograms = single(spectrograms);


% Create a pretty graphic for display (which happens later)
spectrograms = abs(spectrograms);
spectrogram_avg_img = squeeze(log(sum(spectrograms(1:nmatchingsongs,:,:))));

%% Draw the pretty full-res spectrogram and the targets
figure(4);
imagesc([times(1) times(end)]*1000, [freqs(1) freqs(end)]/1000, spectrogram_avg_img);
axis xy;
xlabel('Time (ms)');
ylabel('Frequency (kHz)');

% Construct "ds" (downsampled) dataset.  This is heavily downsampled to save on computational
% resources.  This would better be done by modifying the spectrogram's
% parameters above (which would only reduce the number of frequency bins,
% not the number of timesteps), but this will do for now.

% Number of samples: (nsongs*(ntimes-time_window))
% Size of each sample: (ntimes-time_window)*length(freq_range)

%%%%%%%%%%%%


freq_range_ds = find(freqs >= freq_range(1) & freqs <= freq_range(2));
disp(sprintf('Using frequencies in [ %g %g ] Hz: %d frequency samples.', ...
    freq_range(1), freq_range(2), length(freq_range_ds)));
time_window_steps = double(floor(time_window / fft_time_shift_seconds));
disp(sprintf('Time window is %g ms, %d samples.', time_window*1000, time_window_steps));

% How big will the neural network's input layer be?
layer0sz = length(freq_range_ds) * time_window_steps;

% The training input set X is made by taking all possible time
% windows.  How many are there?  The training roboaggregateput set Y will be made by
% setting all time windows but the desired one to 0.
nwindows_per_song = ntimes - time_window_steps + 1;
