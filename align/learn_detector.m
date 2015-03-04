clear;

rng('shuffle');


if 0
        load('~/r/data/wintest25/out_MANUALCLUST/extracted_data');
        MIC_DATA = agg_audio.data;
elseif 0
        load('/Users/bwpearre/r/data/lg373rblk_2015_01_14/wav/out_MANUALCLUST/extracted_data.mat');
        MIC_DATA = agg_audio.data;
elseif 1
        load('~/r/data/lw27ry_extracted_data');
        agg_audio.data = agg_audio.data(1:20000,:);
        clear agg_data;
        MIC_DATA = agg_audio.data;
else
        load aggregated_data;
        agg_audio.fs = fs;
end

%%% Code snippet to create songs for audio device input
%some_songs = reshape(MIC_DATA(:, 1:50), [], 1);
%
%audiowrite('birdsongs.ogg', ...
%        some_songs / max([max(max(some_songs)) abs(min(min(some_songs)))]), ...
%        44100);



%% Downsample the data
if agg_audio.fs > 40000
        raw_time_ds = 2;
else
        raw_time_ds = 1;
end
MIC_DATA = MIC_DATA(1:raw_time_ds:end,:);

clear agg_audio.data;
clear agg_data;
agg_audio.fs = agg_audio.fs / raw_time_ds;

disp('Filtering the data...');
[B A] = butter(4, [0.05 0.9]);
MIC_DATA = filter(B, A, MIC_DATA);

nsongs = size(MIC_DATA, 2);


% Compute the spectrogram using original parameters (probably far from
% optimal but I have not played with them).  Compute one to get size, then
% preallocate memory and compute the rest in parallel.

% SPECGRAM(A,NFFT=512,Fs=[],WINDOW=[],NOVERLAP=500)
%speck = specgram(MIC_DATA(:,1), 512, [], [], 500) + eps;
NFFT = 256;
WINDOW = 256;
FFT_TIME_SHIFT = 0.003;                        % seconds
NOVERLAP = WINDOW - (floor(agg_audio.fs * FFT_TIME_SHIFT));



[speck freqs times] = spectrogram(MIC_DATA(:,1), WINDOW, NOVERLAP, [], agg_audio.fs);
[nfreqs, ntimes] = size(speck);
speck = speck + eps;

% This _should_ be the same as FFT_TIME_SHIFT, but let's use this because
% round-off error is a possibility
timestep = (times(end)-times(1))/(length(times)-1);

spectrograms = zeros([nsongs nfreqs ntimes]);
spectrograms(1, :, :) = speck;
disp('Computing spectrograms...');
parfor i = 2:nsongs
        spectrograms(i, :, :) = spectrogram(MIC_DATA(:,i), WINDOW, NOVERLAP, [], agg_audio.fs) + eps;
end


% Create a pretty graphic for display (which happens later)
spectrograms = abs(spectrograms);
spectrogram_avg_img = squeeze(log(sum(spectrograms)));

%% Draw the pretty full-res spectrogram and the targets
figure(4);
subplot(2,1,1);
imagesc([times(1) times(end)]*1000, [freqs(1) freqs(end)]/1000, spectrogram_avg_img);
axis xy;
xlabel('Time (ms)');
ylabel('Frequency (kHz)');
colorbar;

% Construct "ds" (downsampled) dataset.  This is heavily downsampled to save on computational
% resources.  This would better be done by modifying the spectrogram's
% parameters above (which would only reduce the number of frequency bins,
% not the number of timesteps), but this will do for now.

% Number of samples: (nsongs*(ntimes-time_window))
% Size of each sample: (ntimes-time_window)*length(freq_range)



%% Cut out a region of the spectrum (in space and time) to save on compute
%% time:
freq_range = [2000 7000];
time_window = 0.07;
%%%%%%%%%%%%


freq_range_ds = find(freqs >= freq_range(1) & freqs <= freq_range(2));
disp(sprintf('Using frequencies in [ %g %g ] Hz: %d frequency samples.', ...
        freq_range(1), freq_range(2), length(freq_range_ds)));
time_window_steps = double(floor(time_window / timestep));
disp(sprintf('Time window is %g ms, %d samples.', time_window*1000, time_window_steps));

% How big will the neural network's input layer be?
layer0sz = length(freq_range_ds) * time_window_steps;

% The training input set X is made by taking all possible time
% windows.  How many are there?  The training output set Y will be made by
% setting all time windows but the desired one to 0.
nwindows_per_song = ntimes - time_window_steps + 1;

%% Define training set
% Hold some data out for final testing.
ntrainsongs = min(floor(nsongs*8/10), 100);
ntestsongs = nsongs - ntrainsongs;
% On each run of this program, change the presentation order of the
% data, so we get (a) a different subset of the data than last time for
% training vs. final testing and (b) different training data presentation
% order.
randomsongs = randperm(nsongs);

%randomsongs = 1:nsongs

trainsongs = randomsongs(1:ntrainsongs);

if 0
        disp('Looking for promising syllables...');
        tstep_of_interest = suggest_moments_of_interest(5, ...
                spectrogram_avg_img, ...
                time_window_steps, ...
                timestep, ...
                layer0sz, ...
                nwindows_per_song, ...
                ntimes, ...
                freq_range_ds);
        times_of_interest = tstep_of_interest * timestep
else
        %tstep_of_interest = 0.775;
        times_of_interest = [ 0.285 0.775];
        tstep_of_interest = round(times_of_interest / timestep);
end


ntsteps_of_interest = length(tstep_of_interest);

%% For each timestep of interest, get the offset of this song from the most typical one.
disp('Computing target jitter compensation...');

% We'll look for this long around the timestep, to compute the canonical
% song
time_buffer = 0.04;
tstep_buffer = round(time_buffer / timestep);

% For alignment: which is the most stereotypical song at each target?
for i = 1:ntsteps_of_interest
        range = tstep_of_interest(i)-tstep_buffer:tstep_of_interest(i)+tstep_buffer;
        range = range(find(range>0&range<=ntimes));
        foo = reshape(spectrograms(:, :, range), nsongs, []) * reshape(mean(spectrograms(:, :, range), 1), 1, [])';
        [val canonical_songs(i)] = max(foo);
        target_offsets(i,:) = get_target_offsets_jeff(MIC_DATA, tstep_of_interest(i), agg_audio.fs, timestep, canonical_songs(i));
end

hist(target_offsets', 40);

%% Draw the pretty full-res spectrogram and the targets
figure(4);
subplot(ntsteps_of_interest+1,1,1);
imagesc([times(1) times(end)]*1000, [freqs(1) freqs(end)]/1000, spectrogram_avg_img);
axis xy;
xlabel('Time (ms)');
ylabel('Frequency (kHz)');
colorbar;
% Draw the syllables of interest:
line(repmat(times_of_interest, 2, 1)*1000, repmat([freqs(1) freqs(end)]/1000, ntsteps_of_interest, 1)', 'Color', [1 0 0]);
drawnow;




%% Create the training set
disp(sprintf('Creating training set from %d songs...', ntrainsongs));
% This loop also shuffles the songs according to randomsongs, so we can use
% contiguous blocks for training / testing


disp(sprintf('   ...(Allocating %g MB for training set X.)', ...
        8 * nsongs * nwindows_per_song * layer0sz / (2^20)));
nnsetX = zeros(layer0sz, nsongs * nwindows_per_song);
nnsetY = zeros(ntsteps_of_interest, nsongs * nwindows_per_song);


% Populate the training data.  Infinite RAM makes this so much easier!
for song = 1:nsongs

        for tstep = time_window_steps : ntimes
                
                nnsetX(:, (song-1)*nwindows_per_song + tstep - time_window_steps + 1) ...
                       = reshape(spectrograms(randomsongs(song), ...
                                 freq_range_ds, ...
                                 tstep - time_window_steps + 1  :  tstep), ...
                                 [], 1);
                         
                         
                for interesting = 1:ntsteps_of_interest
                        if tstep == tstep_of_interest(interesting) 
                                %nnsetY(interesting, (song-1)*nwindows_per_song + tstep + target_offsets(interesting, randomsongs(song)) - time_window_steps + 1) = 1;
                                nnsetY(interesting, (song-1)*nwindows_per_song + tstep + target_offsets(interesting, randomsongs(song)) - time_window_steps - 1 : ...
                                                    (song-1)*nwindows_per_song + tstep + target_offsets(interesting, randomsongs(song)) - time_window_steps + 3) = [ 0.5 0.9 1 0.9 0.5 ];
                        end
                end
        end
end

%yy=reshape(nnsetY, nwindows_per_song, nsongs);
%imagesc(yy');

% original order: spectrograms, spectrograms_ds, song_montage
%   indices into original order: trainsongs, testsongs
% shuffled: nnsetX, nnsetY, testout
%   indices into shuffled arrays: nnset_train, nnset_test

disp('Training...');

% These are contiguous blocks, since the spectrograms have already been
% shuffled.
nnset_train = 1:(ntrainsongs * nwindows_per_song);
nnset_test = ntrainsongs * nwindows_per_song + 1 : size(nnsetX, 2);

% Create the network.  The parameter is the number of units in each hidden
% layer.  [8] means one hidden layer with 8 units.  [] means a simple
% perceptron.
net = feedforwardnet(ceil([1.5 * length(tstep_of_interest)]));
%net = feedforwardnet([]);
% Once the validation set performance stops improving, it doesn't seem to
% get better, so keep this small.
net.trainParam.max_fail = 3;
%net = train(net, nnsetX(:, nnset_train), nnsetY(:, nnset_train), {}, {}, 0.1 + nnsetY(:, nnset_train));
net = train(net, nnsetX(:, nnset_train), nnsetY(:, nnset_train));
% Oh yeah, the line above was the hard part.

% Test on all the data:
testout = sim(net, nnsetX);
testout = reshape(testout, ntsteps_of_interest, nwindows_per_song, nsongs);


% Create an image for plotting the results...
power_img = squeeze((sum(spectrograms, 2)));
power_img(find(isinf(power_img))) = 0;
power_img = power_img(randomsongs,:);
power_img = repmat(power_img / max(max(power_img)), [1 1 3]);

disp('Computing optimal output thresholds...');

% How many seconds on either side of the tstep_of_interest is an acceptable match?
MATCH_PLUSMINUS = 0.02;
% Cost of false positives is relative to that of false negatives.
FALSE_POSITIVE_COST = 1

optimal_thresholds = optimise_network_output_unit_trigger_thresholds(...
        testout, ...
        FALSE_POSITIVE_COST, ...
        times_of_interest, ...
        tstep_of_interest, ...
        MATCH_PLUSMINUS, ...
        timestep, ...
        time_window_steps);


SHOW_THRESHOLDS = true;
SORT_BY_ALIGNMENT = true;
% For each timestep of interest, draw that output unit's response to all
% timesteps for all songs:
for i = 1:ntsteps_of_interest
        figure(4);
        subplot(ntsteps_of_interest+1,1,i+1);
        foo = reshape(testout(i,:,:), [], nsongs);
        barrr = zeros(time_window_steps-1, nsongs);

        if SHOW_THRESHOLDS
                img = power_img / 2;
                fooo = trigger(foo', optimal_thresholds(i));
                fooo = [barrr' fooo];
                [val pos] = max(fooo,[],2);

                img(:, :, 1) = img(:, :, 1) + fooo;
                img(:, :, 2) = img(:, :, 2) - fooo;
                img(:, :, 3) = img(:, :, 3) - fooo;
                
                img(1:ntrainsongs, 1:time_window_steps, 3) = 1;
                img(1:ntrainsongs, 1:time_window_steps, 2) = 0;
                img(1:ntrainsongs, 1:time_window_steps, 1) = 0;
                img(ntrainsongs+1:end, 1:time_window_steps, 2) = 0;
                img(ntrainsongs+1:end, 1:time_window_steps, 1) = 1;
                img(ntrainsongs+1:end, 1:time_window_steps, 3) = 0;

                if SORT_BY_ALIGNMENT
                        %[~, new_world_order] = sort(target_offsets);
                        [~, new_world_order] = sort(pos);
                        img = img(new_world_order,:,:);
                end
                image([times(1) times(end)]*1000, [1 nsongs], img);
        else
                barrr(:, 1:ntrainsongs) = max(max(foo))/2;
                barrr(:, ntrainsongs+1:end) = 3*max(max(foo))/4;
                foo = [barrr' foo'];
                imagesc([times(1) times(end)]*1000, [1 nsongs], foo);
        end
        xlabel('Time (ms)');
        ylabel('Song (random order)');
        if ~SORT_BY_ALIGNMENT
                text(time_window/2, ntrainsongs/2, 'train', ...
                        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'Rotation', 90);
                text(time_window/2, ntrainsongs+ntestsongs/2, 'test', ...
                        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'Rotation', 90);
        end
        colorbar; % If nothing else, this makes it line up with the spectrogram.
end

% Draw the hidden units' weights.  Let the user make these square or not
% because lazy...
if 0
        figure(5);
        for i = 1:size(net.IW{1}, 1)
                subplot(size(net.IW{1}, 1), 1, i)
                imagesc(-time_window_steps:0, img_ds(1)*freq_range_ds, ...
                        reshape(net.IW{1}(i,:), length(freq_range_ds), time_window_steps));
                axis xy;
                if i == size(net.IW{1}, 1)
                        xlabel('time');
                end
                ylabel('frequency');
                %imagesc(reshape(net.IW{1}(i,:), time_window_steps, length(freq_range_ds)));
        end
end