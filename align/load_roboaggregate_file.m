function [ MIC_DATA, spectrograms, nsongsandnonsongs, timestamps, nfreqs, freqs, ntimes, times, fft_time_shift_seconds, spectrogram_avg_img, freq_range_ds, time_window_steps, layer0sz, nwindows_per_song, noverlap] ...
    = load_roboaggregate_file(filename, ...
    fft_time_shift_seconds_target, ...
    target_samplerate, ...
    fft_size, ...
    freq_range, ...
    time_window)

load(filename);

if ~exist('MIC_DATA', 'var') & exist('audio', 'var') & isfield(audio, 'data')
    MIC_DATA = audio.data;
    fs = audio.fs;
end

[orig_nsamples_per_song, nmatchingsongs] = size(MIC_DATA);

timestamps = zeros(1, nmatchingsongs);
for i = 1:nmatchingsongs
    foo = strsplit(strrep(extract_filename{i}, '\', '/'), '/'); % Make sure directories are separated with /, and split
    cow = strsplit(foo{end}, '.'); % Filename component contains timestamp
    cor = strsplit(cow{6}, '-'); % Seems this field has a relevant number and then a -
    cow{6} = cor{1}; % reinsert expurgated value
    timestamps(i) = datenum([str2double(cow(2:6)) 0]); % pad seconds=0, store timestamp
end

%% Downsample the data to match target samplerate?
if fs ~= target_samplerate
        disp(sprintf('Resampling data from %g Hz to %g Hz...', fs, target_samplerate));
        [a b] = rat(target_samplerate/fs);
        
        MIC_DATA = double(MIC_DATA);
        MIC_DATA = resample(MIC_DATA, a, b);
end

MIC_DATA = MIC_DATA / max(max(max(MIC_DATA)), -min(min(MIC_DATA)));

[nsamples_per_song, nmatchingsongs] = size(MIC_DATA);


%% Add some non-matching sound fragments and songs and such from another
%% bird... THIS IS DISABLED FOR NOW...
if false
    nonmatchingbird = 'lblk121rr';
    if strcmp(BIRD, nonmatchingbird)
        fprintf('ERROR: using the same bird--%s--for training and for nonmatching data!\n', BIRD);
        a(0);
    end
    nonmatchingloc = '/Volumes/disk2/winData';
    l = dir(sprintf('%s/%s', nonmatchingloc, nonmatchingbird));
    nonmatchingsongs = zeros(round(size(MIC_DATA) .* [1 nonsinging_fraction]));
    need_n_songs = size(nonmatchingsongs, 2);

    fprintf('Borrowing %d non-matching songs from ''%s/%s''...\n', need_n_songs, nonmatchingloc, nonmatchingbird);


    %%%%% REWRITE NONMATCHING STUFF %%%%%
    
    NONMATCHINGBIRD='lg373rblk';
    nonmatch = load('/Users/Shared/lg373rblk/test/lg373_MANUALCLUST/mat/roboaggregate/roboaggregate.mat');
    NONMATCHING_MIC_DATA = nonmatch.audio.data(1:orig_nsamples_per_song, :);
    NONMATCHING_FS = nonmatch.audio.fs;
    if NONMATCHING_FS ~= target_samplerate
        disp(sprintf('Resampling nonmatching data from %g Hz to %g Hz...', NONMATCHING_FS, target_samplerate));
        [a b] = rat(target_samplerate/NONMATCHING_FS);
        
        NONMATCHING_MIC_DATA = double(NONMATCHING_MIC_DATA);
        NONMATCHING_MIC_DATA = resample(NONMATCHING_MIC_DATA, a, b);
    end
    NONMATCHING_MIC_DATA = NONMATCHING_MIC_DATA / max(max(max(NONMATCHING_MIC_DATA)), -min(min(NONMATCHING_MIC_DATA)));
    nonmatchingsongs = NONMATCHING_MIC_DATA;
    disp(sprintf('Loaded %d songs from %s', size(nonmatchingsongs, 2), nonmatchingbird));


    % incorporate nonmatching data
    done = false;
    nnewsongs = 0;
    for i = 1:length(l)
        if ~strncmp(l(i).name(end:-1:1), 'vaw.', 4)
            continue;
        end
        fprintf('reading ''%s''\n', l(i).name);
        [foo, nonmatchingfs] = audioread(sprintf('%s/%s/%s', nonmatchingloc, nonmatchingbird, l(i).name));
        
        % downsample
        nonmatching_resample = round([target_samplerate nonmatchingfs]);
        foo = resample(foo, round(target_samplerate), round(nonmatchingfs));
        % normalise
        foo = foo / max(max(foo), -min(foo));
        
        % append to the extant audio
        songs_available = floor(length(foo) / nsamples_per_song);
        foo = reshape(foo(1:(songs_available*nsamples_per_song)), nsamples_per_song, songs_available);
        
        take_n_songs = min(need_n_songs, songs_available);
        
        nonmatchingsongs(:, nnewsongs+1:min(size(nonmatchingsongs, 2), nnewsongs+songs_available)) = foo(:, 1:take_n_songs);
        nnewsongs = nnewsongs + songs_available;
        need_n_songs = need_n_songs - take_n_songs;
        if need_n_songs <= 0
            break;
        end
    end
    
    MIC_DATA = [MIC_DATA nonmatchingsongs];
end

[nsamples_per_song, nsongsandnonsongs] = size(MIC_DATA);

disp('Bandpass-filtering the data...');
[B A] = butter(4, [0.03 0.9]);
MIC_DATA = single(filtfilt(B, A, double(MIC_DATA)));


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
