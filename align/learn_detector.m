clear;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%% Parameters %%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

ntrain = 1000;
nhidden_per_output = 2;
fft_time_shift_seconds_target = 0.0015;
nonsinging_fraction = 0; % Doesn't work right now...
use_jeff_realignment_train = false;
use_jeff_realignment_test = false;
use_nn_realignment_test = false;
confusion_all = false;
testfile_include_nonsinging = false;
samplerate = 44100;
fft_size = 256;
use_pattern_net = true;

% Region of the spectrum (in space and time) to examine:
freq_range = [1000 8000];
time_window = 0.03;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%




p = fileparts(mfilename('fullpath'));
addpath(sprintf('%s/../lib', p));

% What is the value of a non-hit on the training data?  0 or -1 would be
% good choices... should make no difference at all--this is for debugging.
global Y_NEGATIVE;
Y_NEGATIVE = 0;

if 1
    BIRD='lny64';
    load('~/Desktop/lny64/roboaggregate.mat');
    MIC_DATA = audio.data;
    agg_audio.fs = audio.fs;
    %times_of_interest_simultaneous = [0.2 : 0.1 : 0.4 ]
    %times_of_interest_simultaneous = [ 0.15 0.2 0.25 0.3 0.35 0.4 ]
    
    times_of_interest_separate = NaN;
    times_of_interest_separate = [ 0.15:0.05:0.4 ];
    %times_of_interest_separate = [ 0.15 0.3 ];
    %times_of_interest_separate = [0.15:0.05:0.4]
    %times_of_interest_separate = [0.15 0.3 0.4];
    times_of_interest_names = {'t^*_1', 't^*_2', 't^*_3', 't^*_4', 't^*_5', 't^*_6'};
    times_of_interest_separate = [ repmat(times_of_interest_separate, 1, 100)];
elseif 0
    BIRD='lg373rblk';
    load('/Users/Shared/lg373rblk/test/lg373_MANUALCLUST/mat/roboaggregate/roboaggregate.mat');
    MIC_DATA = audio.data;
    agg_audio.fs = audio.fs;
    %times_of_interest = [0.115 0.2 0.325]
    times_of_interest_separate = 0.2;
elseif 0
    BIRD='lw8rhp';
    load('/Users/bwpearre/Desktop/Will/test_MANUALCLUST/mat/roboaggregate/roboaggregate.mat');
    MIC_DATA = audio.data;
    agg_audio.fs = audio.fs;
elseif 0
    BIRD='lw27ry';
    load('~/r/data/lw27ry_extracted_data');
    agg_audio.data = agg_audio.data(1:24000,:);
    clear agg_data;
    MIC_DATA = agg_audio.data;
else
    agg_audio.fs = 44100;
    if false
        BIRD = 'deltawide';
        indices = round(-0.006 * agg_audio.fs) : round(-0.005 * agg_audio.fs);
    else
        BIRD = 'delta';
        indices = round(-0.010 * agg_audio.fs);
    end
    times_of_interest_separate = 0.3;
    samples_of_interest = round(times_of_interest_separate * agg_audio.fs) + 1;
    n = 128;
    MIC_DATA = rand([20000, n])/100;
    
    MIC_DATA(samples_of_interest + indices, :) = rand([length(indices), n])/100 + 1;
end

disp(sprintf('Bird: %s', BIRD));


if ~exist('times_of_interest_names', 'var') | length(times_of_interest_names) < length(times_of_interest_separate)
    for i = 1:length(times_of_interest_separate)
        times_of_interest_names{i} = sprintf('t_{%d}', round(1000*times_of_interest_separate(i)));
    end
end



rng('shuffle');

[orig_nsamples_per_song, nmatchingsongs] = size(MIC_DATA);


%% Downsample the data

if agg_audio.fs ~= samplerate
        disp(sprintf('Resampling data from %g Hz to %g Hz...', agg_audio.fs, samplerate));
        [a b] = rat(samplerate/agg_audio.fs);
        
        MIC_DATA = double(MIC_DATA);
        MIC_DATA = resample(MIC_DATA, a, b);
end
%MIC_DATA = MIC_DATA(1:raw_time_ds:end,:);

MIC_DATA = MIC_DATA / max(max(max(MIC_DATA)), -min(min(MIC_DATA)));

clear agg_audio.data;
clear agg_data;

[nsamples_per_song, nmatchingsongs] = size(MIC_DATA);




ntrain_match = min(nmatchingsongs, ntrain);

disp(sprintf('Found %d songs.  Using %d.', nmatchingsongs, ntrain_match));

%% Add some non-matching sound fragments and songs and such from another
%% bird...
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


if false
    %%%%% REWRITE NONMATCHING STUFF %%%%%
    
    NONMATCHINGBIRD='lg373rblk';
    nonmatch = load('/Users/Shared/lg373rblk/test/lg373_MANUALCLUST/mat/roboaggregate/roboaggregate.mat');
    NONMATCHING_MIC_DATA = nonmatch.audio.data(1:orig_nsamples_per_song, :);
    NONMATCHING_FS = nonmatch.audio.fs;
    if NONMATCHING_FS ~= samplerate
        disp(sprintf('Resampling nonmatching data from %g Hz to %g Hz...', NONMATCHING_FS, samplerate));
        [a b] = rat(samplerate/NONMATCHING_FS);
        
        NONMATCHING_MIC_DATA = double(NONMATCHING_MIC_DATA);
        NONMATCHING_MIC_DATA = resample(NONMATCHING_MIC_DATA, a, b);
    end
    NONMATCHING_MIC_DATA = NONMATCHING_MIC_DATA / max(max(max(NONMATCHING_MIC_DATA)), -min(min(NONMATCHING_MIC_DATA)));
    nonmatchingsongs = NONMATCHING_MIC_DATA;
    disp(sprintf('Loaded %d songs from %s', size(nonmatchingsongs, 2), nonmatchingbird));

else
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
        nonmatching_resample = round([samplerate nonmatchingfs]);
        foo = resample(foo, round(samplerate), round(nonmatchingfs));
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
end

nsongs = size(MIC_DATA, 2)

MIC_DATA = [MIC_DATA nonmatchingsongs];

nmatchingsongs

disp('Bandpass-filtering the data...');
[B A] = butter(4, [0.03 0.9]);
MIC_DATA = single(filtfilt(B, A, double(MIC_DATA)));


% Compute the spectrogram using original parameters (probably far from
% optimal but I have not played with them).  Compute one to get size, then
% preallocate memory and compute the rest in parallel.

noverlap = fft_size - (floor(samplerate * fft_time_shift_seconds_target));
% SPECGRAM(A,NFFT=512,Fs=[],WINDOW=[],noverlap=500)
%speck = specgram(MIC_DATA(:,1), 512, [], [], 500) + eps;

window = hamming(fft_size);

[speck freqs times] = spectrogram(MIC_DATA(:,1), window, noverlap, [], samplerate);
% Adjust "times" to reflect the time at which the information is actually available--i.e. the end,
% rather than the middle, of the window:
times = times - times(1) + fft_size/samplerate;
[nfreqs, ntimes] = size(speck);
speck = speck + eps;

% This will be approximately the same as fft_time_shift_seconds_target, but not quite: the fft_time_shift
% is given by noverlap, and will actually be fft_size/samplerate
fft_time_shift_seconds = (times(end)-times(1))/(length(times)-1);
fprintf('FFT time shift = %d frames, %s... ms\n', ...
    floor(samplerate * fft_time_shift_seconds_target), ...
    sigfig(1000*fft_time_shift_seconds, 8));


%% Define training set
% Hold some data out for final testing.  This includes both matching and non-matching IF THE SONGS
% ARE IN RANDOM ORDER
ntrainsongs = min(floor(nsongs*8/10), ntrain);
ntestsongs = nsongs - ntrainsongs;
% On each run of this program, change the presentation order of the
% data, so we get (a) a different subset of the data than last time for
% training vs. final testing and (b) different training data presentation
% order.
if 1
    randomsongs = randperm(nsongs);
else
    randomsongs = 1:nsongs;
    fprintf('\n    NOT PERMUTING TRAINING SONGS\n\n');
end



spectrograms = zeros([nsongs nfreqs ntimes]);
spectrograms(1, :, :) = speck;
disp('Computing spectrograms...');
parfor i = 2:nsongs
        spectrograms(i, :, :) = spectrogram(MIC_DATA(:,i), window, noverlap, [], samplerate) + eps;
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
% windows.  How many are there?  The training output set Y will be made by
% setting all time windows but the desired one to 0.
nwindows_per_song = ntimes - time_window_steps + 1;


disp(sprintf('%d training songs.  %d remain for test.', ntrainsongs, ntestsongs));
trainsongs = randomsongs(1:ntrainsongs);
testsongs = randomsongs(ntrainsongs+1:end);


%%%%%%%%%% Loop over times_of_interest_loop

separate_syllable_counter = 0;
for times_of_interest = times_of_interest_separate
    
    rng('shuffle');
    randomsongs = randperm(nsongs);
    trainsongs = randomsongs(1:ntrainsongs);
    testsongs = randomsongs(ntrainsongs+1:end);

    separate_syllable_counter = separate_syllable_counter + 1;
    
    if exist('times_of_interest_simultaneous', 'var')
        times_of_interest = times_of_interest_simultaneous;
    end
    
    disp(sprintf('Working on time %d ms', times_of_interest*1000));
    
    if 0
        disp('Looking for promising syllables...');
        tstep_of_interest = suggest_moments_of_interest(5, ...
            spectrogram_avg_img, ...
            time_window_steps, ...
            fft_time_shift_seconds, ...
            layer0sz, ...
            nwindows_per_song, ...
            ntimes, ...
            freq_range_ds);
        times_of_interest = tstep_of_interest * fft_time_shift_seconds
    elseif exist('times_of_interest', 'var') % TUNE
        %tsteps_of_interest_nathan = round((times_of_interest * samplerate - fft_size) / (fft_size - noverlap)) + 1
        %guess = tsteps_of_interest_nathan + length([times(1):-fft_time_shift_seconds:0]) - 1

        for i = 1:length(times_of_interest)
            tsteps_of_interest(i) = find(times >= times_of_interest(i), 1);
        end
        %nathan_correction = (tsteps_of_interest - tsteps_of_interest_nathan) * fft_time_shift_seconds * 1000
        
        %tsteps_of_interest = tsteps_of_interest_nathan
    else
        disp('You must define a timestep in which you are interested');
    end
    
    
    if any(times_of_interest < time_window)
        error('learn_detector:invalid_time', ...
            'All times_of_interest [ %s] must be >= time_window (%g)', ...
            sprintf('%g ', times_of_interest), time_window);
    end
    
    
    ntsteps_of_interest = length(tsteps_of_interest);
    
    
    if use_jeff_realignment_train | use_jeff_realignment_test
        
        %% For each timestep of interest, get the offset of this song from the most typical one.
        disp('Computing target jitter compensation...');
        
        % We'll look for this long around the timestep, to compute the canonical
        % song
        time_buffer = 0.04;
        tstep_buffer = round(time_buffer / fft_time_shift_seconds);
        
        % For alignment: which is the most stereotypical song at each target?
        
        %[B A] = butter(4, [0.01 0.05]);
        %MIC_DATA2 = filtfilt(B, A, double(MIC_DATA));
        
        for i = 1:ntsteps_of_interest
            range = tsteps_of_interest(i)-tstep_buffer:tsteps_of_interest(i)+tstep_buffer;
            range = range(find(range>0&range<=ntimes));
            foo = reshape(spectrograms(1:nmatchingsongs, :, range), nmatchingsongs, []) * reshape(mean(spectrograms(:, :, range), 1), 1, [])';
            [val canonical_songs(i)] = max(foo);
            [target_offsets(i,:) sample_offsets(i,:)] = get_target_offsets_jeff(MIC_DATA(:, 1:nmatchingsongs), tsteps_of_interest(i), samplerate, fft_time_shift_seconds, canonical_songs(i));
        end
        
        target_offsets_test = target_offsets;
        sample_offsets_test = sample_offsets;
        if ~use_jeff_realignment_train
            fprintf('\n               ***** DISCARDING TARGET JITTER COMPENSATION FOR TRAINING *****\n\n');
            target_offsets = 0 * target_offsets;
            sample_offsets = 0 * sample_offsets;
        end
        if ~use_jeff_realignment_test
            fprintf('\n               ***** DISCARDING TARGET JITTER COMPENSATION FOR TEST FILE *****\n\n');
            target_offsets_test = 0 * target_offsets_test;
            sample_offsets_test = 0 * sample_offsets_test;
        end
    else
        target_offsets = zeros(ntsteps_of_interest, nsongs);
        sample_offsets = target_offsets;
        target_offsets_test = target_offsets;
        sample_offsets_test = sample_offsets;
    end
    %hist(target_offsets', 40);

    
    
    disp('Creating spectral power image...');
    
    % Create an image on which to superimpose the results...
    power_img = squeeze((sum(spectrograms, 2)));
    power_img(find(isinf(power_img))) = 0;
    
    pn = 1:nmatchingsongs;
    [vt pt] = sort(target_offsets);
    [vs ps] = sort(sample_offsets);
    figure(4);
    subplot(1,1,1);
    power_img = power_img(1:nmatchingsongs,:);
    imagesc(power_img(pt,:));
    %set(gca, 'xlim', [280.2 300]);

    
    
    %% Draw the pretty full-res spectrogram and the targets
    if 1
        figure(4);
        subplot(1,1,1);
        %subplot(ntsteps_of_interest+1,1,1);
        specfig = imagesc([times(1) times(end)]*1000, [freqs(1) freqs(end)]/1000, spectrogram_avg_img);
        axis xy;
        xlabel('Time (ms)');
        ylabel('Frequency (kHz)');
        % Draw the syllables of interest:
        line(repmat(times_of_interest, 2, 1)*1000, repmat([freqs(1) freqs(end)]/1000, ntsteps_of_interest, 1)', 'Color', [1 0 0]);
        
        for i = 1:ntsteps_of_interest
            windowrect = rectangle('Position', [(times_of_interest(i) - time_window)*1000 ...
                freq_range(1)/1000 ...
                time_window(1)*1000 ...
                (freq_range(2)-freq_range(1))/1000], ...
                'EdgeColor', [1 0 0]);
        end
        
        %set(gca, 'xlim', [(times_of_interest(1)*1000-(time_window_steps)*fft_time_shift_seconds*1000) 1000*times_of_interest(1)]);

        set(gca, 'YLim', [0 10]);

    end
    drawnow;
    
    
    
    %% Create the training set
    disp(sprintf('Creating training set from %d songs...', ntrainsongs));
    % This loop also shuffles the songs according to randomsongs, so we can use
    % contiguous blocks for training / testing
    
    % The following uses nsongs rather than ntrainsongs: build the complete dataset for the neural
    % network to make testing easier.  However, only ntrainsongs will be given to train()
    
    training_set_MB = 8 * nsongs * nwindows_per_song * layer0sz / (2^20);
    
    disp(sprintf('   ...(Allocating %g MB for training set X.)', training_set_MB));
    nnsetX = zeros(layer0sz, nsongs * nwindows_per_song);
    nnsetY = Y_NEGATIVE * ones(ntsteps_of_interest, nsongs * nwindows_per_song);
    
    %% OPTIONAL: MANUAL PER-SYLLABLE TUNING!
    
    % Some syllables are really hard to pinpoint to within the frame rate, so
    % the network has to try to learn "image A is a hit, and this thing that
    % looks identical to image A is not a hit".  For each sample of interest,
    % define a "shotgun function" that spreads the "acceptable" fft_time_shift_secondss in
    % the training set a little.  This could be generalised for multiple
    % syllables, but right now they all share one sigma.
    
    % This only indirectly affects final timing precision, since thresholds are
    % optimally tuned based on the window defined in MATCH_PLUSMINUS.
    if use_pattern_net
        shotgun_max_sec = 0.002;
    else
        shotgun_max_sec = 0.02;
    end
    if strcmp(BIRD, 'delta')
        shotgun_sigma = 0.00001;
    else
        shotgun_sigma = 0.002; % TUNE
    end
    shotgun = normpdf(0:fft_time_shift_seconds:shotgun_max_sec, 0, shotgun_sigma);
    shotgun = shotgun / max(shotgun);
    shotgun = shotgun(find(shotgun>0.1));
    shothalf = length(shotgun);
    if shothalf
        shotgun = [ shotgun(end:-1:2) shotgun ]
    end
    
    % Populate the training data.  Infinite RAM makes this so much easier!
    for song = 1:nsongs
        
        for tstep = time_window_steps : ntimes
            
            nnsetX(:, (song-1)*nwindows_per_song + tstep - time_window_steps + 1) ...
                = reshape(spectrograms(randomsongs(song), ...
                freq_range_ds, ...
                tstep - time_window_steps + 1  :  tstep), ...
                layer0sz, 1);
            
            % Fill in the positive hits, if appropriate...
            if randomsongs(song) > nmatchingsongs
                % If the index is from the non-song region of the corpus, do not mark a hit.  This
                % cannot simply be moved to the outer loop because we still need to put it in nnsetX.
                continue;
            else
                for interesting = 1:ntsteps_of_interest
                    if tstep == tsteps_of_interest(interesting)
                        nnsetY(interesting, (song-1)*nwindows_per_song + tstep + target_offsets(interesting, randomsongs(song)) - time_window_steps - shothalf + 2 : ...
                            (song-1)*nwindows_per_song + tstep + target_offsets(interesting, randomsongs(song)) - time_window_steps + shothalf) = shotgun;
                    end
                end
            end
        end
    end
    
    disp('Converting neural net data to singles...');
    nnsetX = single(nnsetX);
    nnsetY = single(nnsetY);
    
    if use_pattern_net
        nnsetYC = [nnsetY~=0 ; nnsetY==0];
    end
    
    %% Shape only?  Let's try normalising the training inputs:
    nnsetX = zscore(nnsetX);
    %nnsetX = normc(nnsetX);
    %yy=reshape(nnsetY, nwindows_per_song, nsongs);
    %imagesc(yy');
    
    % original order: spectrograms, spectrograms_ds, song_montage
    %   indices into original order: trainsongs, testsongs
    % shuffled: nnsetX, nnsetY, testout
    %   indices into shuffled arrays: nnset_train, nnset_test
    
    % These are contiguous blocks, since the spectrograms have already been
    % shuffled.
    nnset_train = 1:(ntrainsongs * nwindows_per_song);
    nnset_test = ntrainsongs * nwindows_per_song + 1 : size(nnsetX, 2);
    
    % Create the network.  The parameter is the number of units in each hidden
    % layer.  [8] means one hidden layer with 8 units.  [] means a simple
    % perceptron.
    
    if use_pattern_net
        net = patternnet(nhidden_per_output * ntsteps_of_interest);
    else
        net = feedforwardnet([nhidden_per_output * ntsteps_of_interest]);
    end
    net.inputs{1}.processFcns={'mapstd'};
        
    %net.trainParam.goal=1e-3;
        
    fprintf('Training network with %s...\n', net.trainFcn);
  
    
    % Once the validation set performance stops improving, it seldom seems to
    % get better, so keep this small.
    net.trainParam.max_fail = 3;
        
    tic
    
    if use_pattern_net
        [net, train_record] = train(net, nnsetX(:, nnset_train), nnsetYC(:, nnset_train));
    else
        [net, train_record] = train(net, nnsetX(:, nnset_train), nnsetY(:, nnset_train));
    end
    % Oh yeah, the line above was the hard part.
    disp(sprintf('   ...training took %g minutes.', toc/60));
    % Test on all the data:
    
    % Why not test just on the non-training data?  Compute them all, and then only count ntestsongs for statistics (later)
    if use_pattern_net
        testout = net(nnsetX);
        testout = testout(1,:);
    else
        testout = sim(net, nnsetX);
    end
    testout = reshape(testout, ntsteps_of_interest, nwindows_per_song, nsongs);

    % Update the each-song image
    power_img = power_img(randomsongs(1:nmatchingsongs),:);
    power_img = repmat(power_img / max(max(power_img)), [1 1 3]);
    
    disp('Computing optimal output thresholds...');
    
    % How many seconds on either side of the tstep_of_interest is an acceptable match?
    MATCH_PLUSMINUS = 0.02;
    % Cost of false positives is relative to that of false negatives.
    FALSE_POSITIVE_COST = 1 % TUNE
    
    % Which songs should have hits?  The first nmatchingsongs, but permuted to the same order as the
    % training/test sets, as given by randomsongs.
    songs_with_hits = [ones(1, nmatchingsongs) zeros(1, nsongs - nmatchingsongs)]';
    songs_with_hits = songs_with_hits(randomsongs);
    
    % Search for the optimal trigger thresholds using just the training set
    trigger_thresholds = optimise_network_output_unit_trigger_thresholds(...
        testout(:,:,1:ntrainsongs), ...
        nwindows_per_song, ...
        FALSE_POSITIVE_COST, ...
        times_of_interest, ...
        tsteps_of_interest, ...
        MATCH_PLUSMINUS, ...
        fft_time_shift_seconds, ...
        time_window_steps, ...
        songs_with_hits(1:ntrainsongs), ...
        true);
    
    % Now that we've computed the thresholds using just the training set, print the confusion matrices
    % using just the holdout test set.
    if confusion_all
        foo = 1:size(testout, 3);
    else
        foo = ntrainsongs+1:size(testout, 3);
    end
    show_confusion(...
        testout(:, :, foo), ...
        nwindows_per_song, ...
        FALSE_POSITIVE_COST, ...
        times_of_interest, ...
        tsteps_of_interest, ...
        MATCH_PLUSMINUS, ...
        fft_time_shift_seconds, ...
        time_window_steps, ...
        songs_with_hits(foo), ...
        trigger_thresholds, ...
        train_record);
    
    
    %figure(32);
    %plot(times(time_window_steps:end), squeeze(testout(1,:,:)), 'b', ...
    %    times([time_window_steps end]), [1 1]*trigger_thresholds, 'r');
    %title('Network output and threshold');
    
    SHOW_THRESHOLDS = true;
    SHOW_ONLY_TRUE_HITS = true;
    SORT_BY_ALIGNMENT = true;
    raster_colour_left_bar = false;
    % For each fft_time_shift_seconds of interest, draw that output unit's response to all
    % timesteps for all songs:
    
    n_unique_tsteps_of_interest = length(unique(times_of_interest_separate));

    target_offsets_net = zeros(ntsteps_of_interest, nsongs);
    sample_offsets_net = zeros(ntsteps_of_interest, nsongs);
    for i = 1:ntsteps_of_interest
        figure(6);
        if false
            subplot(ntsteps_of_interest, 1, i);
        else
            subplot(n_unique_tsteps_of_interest, 1, ...
                mod(separate_syllable_counter, n_unique_tsteps_of_interest) + 1);
        end
        testout_i_squeezed = reshape(testout(i,:,:), [], nsongs);
        leftbar = zeros(time_window_steps-1, nsongs);
        
        if SHOW_THRESHOLDS
            % "img" is a tricolour image
            img = power_img;
            % de-bounce:
            trigger_img = trigger(testout_i_squeezed', trigger_thresholds(i), 0.1, fft_time_shift_seconds);
            trigger_img = [leftbar' trigger_img];
            [val pos] = max(trigger_img, [], 2);
            
            [targets_with_offsets, target_offsets_net_tmp] = find(trigger_img);
            
            target_offsets_net(i,targets_with_offsets) = target_offsets_net_tmp' - tsteps_of_interest(i) + 1;
            sample_offsets_net(i,:) = target_offsets_net(i,:) * fft_time_shift_seconds * samplerate;
            
            %figure(7);
            %hist([target_offsets_2 ; target_offsets_net]', 50);
            %hist([sample_offsets_test ; sample_offsets_net]', 50);
            %target_offset_mean_difference = mean(target_offsets_test) - mean(target_offsets_net)
            %figure(6);
            
            % img is RGB.  Here I'm playing with colouring the image with triggers
            img(1:ntrainsongs, :, 1) = img(1:ntrainsongs, :, 1) - trigger_img(1:ntrainsongs, :);
            img(1:ntrainsongs, :, 2) = img(1:ntrainsongs, :, 2) + trigger_img(1:ntrainsongs, :);
            img(1:ntrainsongs, :, 3) = img(1:ntrainsongs, :, 3) + trigger_img(1:ntrainsongs, :);
            % Different colour for testsongs
            img(ntrainsongs+1:end, :, 1) = img(ntrainsongs+1:end, :, 1) + trigger_img(ntrainsongs+1:end, :);
            img(ntrainsongs+1:end, :, 2) = img(ntrainsongs+1:end, :, 2) - trigger_img(ntrainsongs+1:end, :);
            img(ntrainsongs+1:end, :, 3) = img(ntrainsongs+1:end, :, 3) - trigger_img(ntrainsongs+1:end, :);
            
            if raster_colour_left_bar
                % Colour the leftbar according to train and test:
                img(1:ntrainsongs, 1:time_window_steps, 3) = 1;
                img(1:ntrainsongs, 1:time_window_steps, 2) = 1;
                img(1:ntrainsongs, 1:time_window_steps, 1) = 0;
                img(ntrainsongs+1:end, 1:time_window_steps, 2) = 0;
                img(ntrainsongs+1:end, 1:time_window_steps, 1) = 1;
                img(ntrainsongs+1:end, 1:time_window_steps, 3) = 0;
            end
                
            if SHOW_ONLY_TRUE_HITS
                img = img(find(songs_with_hits), :, :);
                pos = pos(find(songs_with_hits));
            end
            
            if SORT_BY_ALIGNMENT
                %[a, new_world_order] = sort(sample_offsets(randomsongs(1:nmatchingsongs)));
                [~, new_world_order] = sort(pos);
                img = img(new_world_order,:,:);
            end
            
            % Make sure the image handle has the correct axes
            if SHOW_ONLY_TRUE_HITS
                imh = image([times(1) times(end)]*1000, [1 sum(songs_with_hits)], img);
            else
                imh = image([times(1) times(end)]*1000, [1 nsongs], img);
            end
        else
            leftbar(:, 1:ntrainsongs) = max(max(testout_i_squeezed))/2;
            leftbar(:, ntrainsongs+1:end) = 3*max(max(testout_i_squeezed))/4;
            testout_i_squeezed = [leftbar' testout_i_squeezed'];
            imagesc([times(1) times(end)]*1000, [1 nsongs], testout_i_squeezed);
        end
        xlabel('Time (ms)');
        ylabel('Song');
        %title(sprintf('Detection events for %d ms', round(1000*times_of_interest(i))));
        title(sprintf('Detection events: %s', times_of_interest_names{separate_syllable_counter}));

        if ~SORT_BY_ALIGNMENT
            %% Show coloration by labeling the blocks of training and test songs
            text(time_window/2*1000, ntrainsongs/2, 'train', ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'Rotation', 90);
            text(time_window/2*1000, ntrainsongs+ntestsongs/2, 'test', ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'Rotation', 90);
        elseif raster_colour_left_bar
            %% Show colouration by labeling the largest contiguous blocks of training and test songs
            s = img(:,1,1); % s is now 0 for train, 1 for test
            a = diff(s);
            b = find([a; Inf] ~= 0);
            c = diff([0; b]);
            d = cumsum(c);
            [e f] = max(c(2:2:end)); % even: test
            f = f * 2;
            testcentre = mean(d(f-1:f));
            
            [g h] = max(c(1:2:end)); % odd: train
            h = h * 2 - 1;
            try
                traincentre = mean(d(h-1:h));
            catch ME
                traincentre = mean([0 d(h)]);
            end
            
            if s(1) % Fix parity if it looks to be wrong...
                foo = testcentre;
                testcentre = traincentre;
                traincentre = foo;
            end
            text(time_window/2*1000+3, traincentre, 'train', ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'Rotation', 0);
            text(time_window/2*1000+3, testcentre, 'test', ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'Rotation', 0);
        else
            %% Show colouration via a legend
            if separate_syllable_counter == 1
                prevhold = ishold;
                hold on;
                % Plot some dummy lines offscreen for legend to pick up the colours from:
                xlims = get(gca, 'XLim');
                ylims = get(gca, 'YLim');
                plot([-1 -2], [-1 -2], 'color', [0 1 1], 'LineWidth', 5);
                plot([-1 -2], [-1 -2], 'color', [1 0 0], 'LineWidth', 5);
                if ~prevhold
                    hold off;
                end
                set(gca, 'XLim', xlims, 'YLim', ylims);
                
                legend('Train', 'Test', 'location', 'SouthWest');
            end
        end
    end
    
    drawnow;
    
    
    
    if use_nn_realignment_test
        target_offsets_net = zeros(ntsteps_of_interest, nsongs);
        sample_offsets_net = zeros(ntsteps_of_interest, nsongs);
        for i = 1:ntsteps_of_interest
            testout_i_squeezed = reshape(testout(i,:,:), [], nsongs);
            leftbar = zeros(time_window_steps-1, nsongs);
            trigger_img = trigger(testout_i_squeezed', trigger_thresholds(i), 0.1, fft_time_shift_seconds);
            trigger_img = [leftbar' trigger_img];
            [val pos] = max(trigger_img, [], 2);
            
            [targets_with_offsets, target_offsets_net_tmp] = find(trigger_img);
            target_offsets_net(i,targets_with_offsets) = target_offsets_net_tmp' - tsteps_of_interest(i) + 1;
            sample_offsets_net(i,:) = target_offsets_net(i,:) * fft_time_shift_seconds * samplerate;
            target_offsets_test = target_offsets_net;
            sample_offsets_test = sample_offsets_net;
        end
    end

    
    %% Plot the figure of errors for all networks...
    figure(9);
    confusion = load('confusion_log_perf.txt');
    [sylly bini binj] = unique(confusion(:,1));
    xtickl = {};
    sylly_means = [];
    sylly_counts = [];
    for i = 1:length(sylly)
        xtickl{i} = sprintf('t^*_%d', i);
        sylly_counts(i) = length(find(confusion(:,1)==sylly(i)));
        sylly_means(i,:) = mean(confusion(find(confusion(:,1)==sylly(i)),2:3));
    end
    sylly_means
    colours = distinguishable_colors(length(sylly));
    offsets = (rand(size(confusion(:,1))) - 0.5) * 2 * 0.02;
    if size(confusion, 2) >= 4 & false
        sizes = (mapminmax(-confusion(:,4)')'+1.1)*8;
    else
        sizes = 3;
    end
    subplot(1,2,1);
    scatter(confusion(:,1)+offsets, confusion(:,2)*100, sizes, colours(binj,:), 'filled');
    xlabel('Test syllable');
    ylabel('True Positives %');
    title('Correct detections');
    if min(sylly) ~= max(sylly)
        set(gca, 'xlim', [min(sylly)-0.025 max(sylly)+0.025]);
    end
    set(gca, 'ylim', [97 100]);
    set(gca, 'xtick', sylly, 'xticklabel', xtickl);

    subplot(1,2,2);
    scatter(confusion(:,1)+offsets, confusion(:,3)*100, sizes, colours(binj,:), 'filled');
    xlabel('Test syllable');
    ylabel('False Positives %');
    title('Incorrect detections');
    if min(sylly) ~= max(sylly)
        set(gca, 'xlim', [min(sylly)-0.025 max(sylly)+0.025]);
    end
    set(gca, 'xtick', sylly, 'xticklabel', xtickl);
    set(gca, 'ylim', [0 0.07]);
    sylly_counts

    
    
    % Draw the hidden units' weights.  Let the user make these square or not
    % because lazy...
    if net.numLayers > 1
        figure(5);
        for i = 1:size(net.IW{1}, 1)
            subplot(size(net.IW{1}, 1), 1, i)
            %imagesc([-time_window_steps:0]*fft_time_shift_seconds*1000, linspace(freq_range(1), freq_range(2), length(freq_range_ds))/1000, ...
            %    reshape(net.IW{1}(i,:), length(freq_range_ds), time_window_steps));
            imagesc([times(1:time_window_steps) - times(time_window_steps)]*1000, linspace(freq_range(1), freq_range(2), length(freq_range_ds))/1000, ...
                reshape(net.IW{1}(i,:), length(freq_range_ds), time_window_steps));
            axis xy;
            ylabel('frequency');
            
            if i == 1
                title('Hidden layers');
            end
            if i == size(net.IW{1}, 1)
                xlabel('time (ms)');
            end
            %imagesc(reshape(net.IW{1}(i,:), time_window_steps, length(freq_range_ds)));
        end
    end
    drawnow;
    
    %save learn_detector_latest
    
    %% Save input file for the LabView detector
    % Extract data from net structure, because LabView is too fucking stupid to
    % permit the . operator.
    layer0 = net.IW{1};
    layer1 = net.LW{2,1};
    bias0 = net.b{1};
    bias1 = net.b{2};
    %mmminoffset = net.inputs{1}.processSettings{1}.xoffset;
    %mmmingain = net.inputs{1}.processSettings{1}.gain;
    % The following store the transformation that took nnsetY to actual network training.  So
    % everything is forward.  Allow LabView to do:
    % out = (xmax-xmin)*(rawnetout-ymin)/(ymax-ymin) + xmin
    %     = (xrange/yrange) * (rawnetout - ymin) + xmin
    %     = (rawnetout - ymin) / gain + xmin
    mapstd_xmean = net.inputs{1}.processSettings{1}.xmean;
    mapstd_xstd = net.inputs{1}.processSettings{1}.xstd;
    if use_pattern_net
        mmmout_xmin = 0;
        mmmout_ymin = 0;
        mmmout_gain = 1;
    else
        mmmout_xmin = net.outputs{2}.processSettings{1}.xmin;
        mmmout_ymin = net.outputs{2}.processSettings{1}.ymin;
        mmmout_gain = net.outputs{2}.processSettings{1}.gain;
    end
    
    win_size = fft_size;
    fft_time_shift = fft_size - noverlap;
    scaling = 'linear';
    filename = sprintf('detector_%s%ss_frame%gms_%dhid_%dtrain.mat', ...
        BIRD, sprintf('_%g', times_of_interest), 1000*fft_time_shift_seconds_target, net.layers{1}.dimensions, ntrain);
    fprintf('Saving as ''%s''...\n', filename);
    save(filename, ...
        'net', 'train_record', ...
        'samplerate', 'fft_size', 'win_size', 'fft_time_shift', 'fft_time_shift_seconds', 'freq_range_ds', ...
        'time_window_steps', 'trigger_thresholds', 'freq_range', ...
        'layer0', 'layer1', 'bias0', 'bias1', ...
        'mmmout_xmin', 'mmmout_ymin', 'mmmout_gain', 'mapstd_xmean', 'mapstd_xstd', ...
        'shotgun_sigma', ...
        'ntrain',  'scaling', '-v7');
    %% Save sample data: audio on channel0, canonical hits for first syllable on channel1
    
    if use_nn_realignment_test
        realignNetString = 'realignNet';
    else
        realignNetString = '';
    end
    
    % Let's standardise order for each set of test songs, so that we can compare multiple training
    % runs of the detector on the same songs:
    rng(137);
    
    if testfile_include_nonsinging
        % Re-permute all songs with a new random order
        newrand = randperm(size(MIC_DATA,2));
        orig_songs_with_hits =  [ones(1, nmatchingsongs) zeros(1, nsongs - nmatchingsongs)]';
        new_songs_with_hits = orig_songs_with_hits(newrand);
        songs = reshape(MIC_DATA(:, newrand), [], 1); % Include all singing and non-singing
        %songs = reshape(MIC_DATA(:, 1:nsongs), [], 1); % Just singing
        songs_scale = max([max(songs) -min(songs)]);
        songs = songs / songs_scale;
        hits = zeros(size(MIC_DATA));
        samples_of_interest = round(times_of_interest * samplerate);
        for i = 1:nsongs
            if new_songs_with_hits(i)
                % The baseline signal is recorded only for the first sample
                % of interest:
                hits(samples_of_interest(1) + sample_offsets_2(1, newrand(i)), i) = 1;
            end
        end
        hits = reshape(hits, [], 1);
        songs = [songs hits];
        testfilename = sprintf('songs_%s%ss_%d%%%s.wav',...
            BIRD, sprintf('_%g', times_of_interest), round(100/(1+nonsinging_fraction)), ...
            realignNetString);
    else
        % Just the real songs
        
        % Re-permute just 128 of the positive songs with a new random order -- for oscilloscope
        % 128-sample averages
        ntestsongs = 128; % nmatchingsongs
        newrand = randperm(nmatchingsongs);
        newrand = newrand(1:ntestsongs);

        %songs = reshape(MIC_DATA(:, 1:nmatchingsongs), [], 1); % Include all singing and non-singing
        songs = reshape(MIC_DATA(:, newrand), [], 1); % Just singing
        songs_scale = max([max(songs) -min(songs)]);
        songs = songs / songs_scale;
        hits = zeros(nsamples_per_song, ntestsongs);
        samples_of_interest = round(times_of_interest * samplerate);
        for i = 1:ntestsongs
            hits(samples_of_interest(1) + round(sample_offsets_test(1, i)), i) = 1;
        end
        hits = reshape(hits, [], 1);
        songs = [songs hits];
        
        testfilename = sprintf('songs_128_%s%ss%s.wav',...
            BIRD, sprintf('_%g', times_of_interest), ...
            realignNetString);

    end
    
    audiowrite(testfilename, songs, round(samplerate));
end