clear;

rng('shuffle');


if 0
        load('~/r/data/wintest25/out_MANUALCLUST/extracted_data');

        MIC_DATA = agg_audio.data;
elseif 1
        load('/Users/bwpearre/r/data/lg373rblk_2015_01_14/wav/out_MANUALCLUST/extracted_data.mat');
        MIC_DATA = agg_audio.data;
    
else
        load aggregated_data;
end

%%% Code snippet to create songs for audio device input
%some_songs = reshape(MIC_DATA(:, 1:50), [], 1);
%
%audiowrite('birdsongs.ogg', ...
%        some_songs / max([max(max(some_songs)) abs(min(min(some_songs)))]), ...
%        44100);


nsongs = size(MIC_DATA, 2);


%%% Parameter: downsample the "image" (spectrogram) by this much:
%%% [ frequency_bins  time ]
img_ds = [2 10];



% Compute the spectrogram using original parameters (probably far from
% optimal but I have not played with them).  Compute one to get size, then
% preallocate memory and compute the rest in parallel.

% SPECGRAM(A,NFFT=512,Fs=[],WINDOW=[],NOVERLAP=500)
%speck = specgram(MIC_DATA(:,1), 512, [], [], 500) + eps;
NFFT = 512;
WINDOW = 500;
NOVERLAP = WINDOW - 10;

speck = spectrogram(MIC_DATA(:,1), WINDOW, NOVERLAP, NFFT, agg_audio.fs) + eps;
[nfreqs, ntimes] = size(speck);

spectrograms = zeros([nsongs nfreqs ntimes]);
spectrograms(1, :, :) = speck;
disp('Computing spectrograms...');
parfor i = 2:nsongs
        speck = spectrogram(MIC_DATA(:,i), WINDOW, NOVERLAP, NFFT, agg_audio.fs) + eps;
        spectrograms(i, :, :) = speck;
end

% To downsample, chop off the tail of the spectrogram so that we have an
% integer number of bins to downsample into.
ntimes = img_ds(2) * floor(ntimes / img_ds(2));
spectrograms = spectrograms(:, :, 1:ntimes);

% Create a pretty graphic for display (which happens later)
spectrogram_avg_img = squeeze(log(sum(abs(spectrograms(:,5:end,:)))));

% Alright, may as well draw it now, just to show that something's going on
% in that big vacant-looking cylinder with the apple logo on it.
figure(4);
subplot(1,1,1);
imagesc(spectrogram_avg_img);
axis xy;

% Construct "ds" (downsampled) dataset.  This is heavily downsampled to save on computational
% resources.  This would better be done by modifying the spectrogram's
% parameters above (which would only reduce the number of frequency bins,
% not the number of timesteps), but this will do for now.

% Number of samples: (nsongs*(ntimes-time_window))
% Size of each sample: (ntimes-time_window)*length(freq_range)
spectrograms_ds = zeros([nsongs nfreqs-1 ntimes] ./ [1 img_ds]);

disp('Downsampling spectrograms...');
for song = 1:nsongs
        for i = 1:floor((nfreqs-img_ds(1))/img_ds(1))
                irange = i*img_ds(1):(i+1)*img_ds(1)-1;
                for j = 1:floor((ntimes-img_ds(2))/img_ds(2))
                        jrange = j*img_ds(2):(j+1)*img_ds(2)-1;
                        spectrograms_ds(song, i, j) = ...
                                sum(sum(abs(spectrograms(song, ...                            
                                                         irange, ...
                                                         jrange))));
                                              
                end
        end
end
% Normalise the values
spectrograms_ds = spectrograms_ds / prod(img_ds);

% Cut out a region of the spectrum (in space and time) to save on compute
% time:
freq_range_ds = 40:80;
time_window_ds = 30;

[foo, nfreqs_ds, ntimes_ds] = size(spectrograms_ds);

% How big will the neural network's input layer be?
layer0sz = length(freq_range_ds) * time_window_ds;

% The training input set X is made by taking all possible time
% windows.  How many are there?  The training output set Y will be made by
% setting all time windows but the desired one to 0.
nwindows_per_song = ntimes_ds - time_window_ds + 1;

% Hold some data out for final testing.
ntrainsongs = floor(nsongs*6/10);
ntestsongs = ceil(nsongs*4/10);

% On each run of this program, change the presentation order of the
% data, so we get (a) a different subset of the data than last time for
% training vs. final testing and (b) different training data presentation
% order.
randomsongs = randperm(nsongs);
trainsongs = randomsongs(1:ntrainsongs);
testsongs = randomsongs(ntrainsongs+1:end);

disp(sprintf('(Allocating %g MB for training set X.)', ...
        8 * nsongs * nwindows_per_song * layer0sz / (2^20)));
nnsetX = zeros(layer0sz, nsongs * nwindows_per_song);

disp(sprintf('Creating training set from %d songs...', ntrainsongs));
% This loop also shuffles the songs according to randomsongs, so we can use
% contiguous blocks for training / testing

% These are the timesteps (not downsampled--they correspond to the timesteps
% shown in the full-size pretty spectrogram) that we want to try to pick
% out.
tstep_of_interest = [ 964 1460 2125 2410 ];
tstep_of_interest_ds = round(tstep_of_interest/img_ds(2))
ntsteps_of_interest = length(tstep_of_interest);

nnsetY = zeros(length(tstep_of_interest), nsongs * nwindows_per_song);


% Populate the training data.  Infinite RAM makes this so much easier!
for song = 1:nsongs

        for tstep = time_window_ds : ntimes_ds
                
                nnsetX(:, (song-1)*nwindows_per_song + tstep - time_window_ds + 1) ...
                       = reshape(spectrograms_ds(randomsongs(song), ...
                                 freq_range_ds, ...
                                 tstep - time_window_ds + 1  :  tstep), ...
                                 [], 1);
                if any(tstep == tstep_of_interest_ds)
                        nnsetY(:, (song-1)*nwindows_per_song + tstep - time_window_ds + 1) = (tstep == tstep_of_interest_ds);
                end
        end
end

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
%net = feedforwardnet([2*length(tstep_of_interest)]);
net = feedforwardnet([]);
% Once the validation set performance stops improving, it doesn't seem to
% get better, so keep this small.
net.trainParam.max_fail = 3;
%net = train(net, nnsetX(:, nnset_train), nnsetY(:, nnset_train), {}, {}, 0.1 + nnsetY(:, nnset_train));
net = train(net, nnsetX(:, nnset_train), nnsetY(:, nnset_train));
% Oh yeah, the line above was the hard part.

% Test on all the data:
testout = sim(net, nnsetX);
testout = reshape(testout, ntsteps_of_interest, nwindows_per_song, nsongs);

% Display (or not) the spectrograms of all the songs.
if false
        song_montage = spectrograms_ds;
        song_montage = permute(spectrograms_ds, [2 3 4 1]);
        song_montage = repmat(song_montage, [1 1 3 1]);
        song_montage = log(song_montage+eps);
        song_montage = song_montage / max(max(max(max(song_montage))));
        montage(song_montage(:,:,:,testsongs));
end

% Plot the results...
figure(4);
% First, the pretty full-res spectrogram calculated long ago:
subplot(ntsteps_of_interest+1,1,1);
imagesc(spectrogram_avg_img);
colorbar;
% Draw the syllables of interest:
line(repmat(tstep_of_interest, 2, 1), repmat([1 nfreqs], ntsteps_of_interest, 1)', 'Color', [1 0 0]);
ylabel('frequency');
axis xy;


%% Cost of false positives is relative to that of false negatives.
FALSE_POSITIVE_COST = 10
optimal_thresholds = optimise_network_output_unit_trigger_thresholds(...
        testout, ...
        tstep_of_interest_ds, ...
        FALSE_POSITIVE_COST, ...
        timestep_length, ...
        time_window_ds)


SHOW_THRESHOLDS = true;
% For each timestep of interest, draw that output unit's response to all
% timesteps for all songs:
for i = 1:ntsteps_of_interest
        figure(4);
        subplot(ntsteps_of_interest+1,1,i+1);
        foo = reshape(testout(i,:,:), [], nsongs);
        barrr = zeros(time_window_ds, nsongs);

        if SHOW_THRESHOLDS
                foo = foo > optimal_thresholds(i);
                barrr(:, 1:ntrainsongs) = 0.3;
                barrr(:, ntrainsongs+1:end) = 0.6;
        else
                barrr(:, 1:ntrainsongs) = max(max(foo))/2;
                barrr(:, ntrainsongs+1:end) = 3*max(max(foo))/4;
        end
        foo = [barrr' foo'];
        imagesc(foo);
        xlabel('timestep');
        ylabel('Song (random order)');
        text(time_window_ds/2, ntrainsongs/2, 'train', ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'Rotation', 90);
        text(time_window_ds/2, ntrainsongs+ntestsongs/2, 'test', ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'Rotation', 90);
        colorbar;
end

% Draw the hidden units' weights.  Let the user make these square or not
% because lazy...
figure(5);
for i = 1:size(net.IW{1}, 1)
        subplot(size(net.IW{1}, 1), 1, i)
        imagesc(-time_window_ds:0, img_ds(1)*freq_range_ds, ...
                reshape(net.IW{1}(i,:), length(freq_range_ds), time_window_ds));
        axis xy;
        if i == size(net.IW{1}, 1)
                xlabel('time');
        end
        ylabel('frequency');
        %imagesc(reshape(net.IW{1}(i,:), time_window_ds, length(freq_range_ds)));
end
