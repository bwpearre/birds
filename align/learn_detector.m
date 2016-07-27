clear;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%% Configuration %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% First: where are the data?

% Top-level data directory, which houses bird directories:
if ispc
    data_base_dir = 'z:\song';
else
    data_base_dir = '/Volumes/Data/song';
end
% Bird name:
bird = 'lny64';
%bird = 'lno57rlg';
%bird = 'llb4';
%bird = 'lny29';

% The two required files:
params_file = 'params';                          % data_base_dir/bird/params.m
data_file = 'song';                              % data_base_dir/bird/song.mat



%% These are defaults.  Any of them can be overridden in the parameters file.
nhidden_per_output = 4;                          % How many hidden units per syllable?  2 works and trains fast.  4 works ~20% better...
fft_time_shift_seconds_target = 0.0015;          % FFT frame rate (seconds).  Paper mostly used 0.0015 s: great for timing, but slow to train
use_jeff_realignment_train = false;              % Micro-realign at each detection point using Jeff's time-domain code?  Don't do this.
use_jeff_realignment_test = false;               % Micro-realign test data only at each detection point using Jeff's time-domain code.  Nah.
use_nn_realignment_test = false;                 % Try using the trained network to realign test songs (reduce jitter?)
confusion_all = false;                           % Use both training and test songs when computing the confusion matrix?
nonsinging_fraction = 4;                         % Train on this proportion of nonsinging data (e.g. cage noise, calls)
n_whitenoise = 10;                               % Add this many white noise samples (FIXME simplistic method)
testfile_include_nonsinging = false;             % Include nonsinging data in audio test file
samplerate = 44100;                              % Target samplerate (interpolate data to match this)
fft_size = 256;                                  % FFT size
use_pattern_net = false;                         % Use MATLAB's pattern net (fine, but no control over false-pos vs false-neg cost)
do_not_randomise = false;                        % Use songs in original order?
separate_network_for_each_syllable = true;       % Train a separate network for each time of interest?  Or one network with multiple outs?
nruns = 100;                                     % Perform a few training runs and create beeswarm plot (paper figure 3 used 100)?
freq_range = [1000 8000];                        % Frequencies of the song to examine
time_window = 0.030;                             % How many seconds long is the time window?
false_positive_cost = 1;                         % Cost of false positives is relative to that of false negatives.

%use_previously_trained_network = '5syll_1ms.mat' % Rather than train a new network, use this one? NO ERROR CHECKING!!!!!
%  Finally: where do the aligned song and nonsong data files live?  And which times do we care
%  about?
datadir = strcat(data_base_dir, filesep, bird);

if ~exist('params_file', 'var') | ~exist(strcat(datadir, filesep, params_file, '.m'), 'file')
    error('Please create the parameters file (currently looking for ''%s''), which will eventually contain at least times_of_interest and, optionally, replacement values for other parameters.', ...
        strcat(datadir, filesep, params_file));
end

% Load the user configuration.  This is done by running the params file as a .m file, which adds
% variables to the current workspace:
oldpath = addpath(datadir);
eval(params_file);
path(oldpath);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%% End Configuration %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


if 0 % Delta function is a special test case for measuring detector latency.
    agg_audio.fs = 44100;
    bird = 'delta';
    indices = round(-0.010 * agg_audio.fs);
    times_of_interest = 0.3;
    samples_of_interest = round(times_of_interest * agg_audio.fs) + 1;
    n = 128;
    mic_data = rand([20000, n])/100;
    mic_data(samples_of_interest + indices, :) = rand([length(indices), n])/100 + 1;
end



if exist('use_previously_trained_network', 'var') & ~isempty(use_previously_trained_network)
    disp(sprintf('Loading previously trained network ''%s''...', use_previously_trained_network));
    load(use_previously_trained_network);
end


p = fileparts(mfilename('fullpath'));
addpath(sprintf('%s/../lib', p));


rng('shuffle');


disp(sprintf('bird: %s', bird));


[ mic_data, spectrograms, nsamples_per_song, nmatchingsongs, nsongsandnonsongs, timestamps, nfreqs, freqs, ntimes, times, fft_time_shift_seconds, spectrogram_avg_img, freq_range_ds, time_window_steps, layer0sz, nwindows_per_song, noverlap] ...
    = load_roboaggregate_file(datadir, ...
    data_file, ...
    fft_time_shift_seconds_target, ...
    samplerate, ...
    fft_size, ...
    freq_range, ...
    time_window, ...
    nonsinging_fraction, ...
    n_whitenoise);

%% Draw the spectral image.  If no times_of_interest defined, this is what the user will use to choose some.
figure(4);
subplot(1,1,1);
specfig = imagesc(times([1 end])*1000, freqs([1 end])/1000, spectrogram_avg_img);
axis xy;
xlabel('Time (ms)');
ylabel('Frequency (kHz)');
set(gca, 'YLim', [0 10]);
if ~exist('times_of_interest', 'var') | isempty(times_of_interest)
    error('No times of interest defined.  Please look at the spectrogram in Figure 4 and define one or more in ''%s''.', strcat(datadir, filesep, params_file, '.m'));
end

%% Define training set
% Hold some data out for final testing.  This includes both matching and non-matching IF THE SONGS
% ARE IN RANDOM ORDER
ntrainsongs = floor(nsongsandnonsongs*9.5/10);
ntestsongs = nsongsandnonsongs - ntrainsongs;
disp(sprintf('%d training songs.  %d remain for test.', ntrainsongs, ntestsongs));
disp(sprintf('Found %d songs.', nmatchingsongs));

% If we're using "fit", it'll produce useless warnings (some kludgey analysis I do later uses "fit",
% but I want to disable them outside the loop).  Silence them!
warning('off', 'curvefit:prepareFittingData:nonDouble');
warning('off', 'curvefit:prepareFittingData:sizeMismatch');
warning('off', 'curvefit:prepareFittingData:removingNaNAndInf')


% Just one rudimentary error-check:
if any(times_of_interest < time_window) | any(times_of_interest > times(end))
    error('learn_detector:invalid_time', ...
        'All times_of_interest [ %s] must be >= time_window (%g) and < %s', ...
        sprintf('%g ', times_of_interest), time_window, times(end));
end

% Create informative names for the detection points:
if ~exist('times_of_interest_names', 'var') | length(times_of_interest_names) < length(times_of_interest_separate)
    for i = 1:length(times_of_interest)
        times_of_interest_names{i} = sprintf('t^*_{%d}', round(1000*times_of_interest(i)));
    end
end



% Create a FOR loop over these, if necessary
if separate_network_for_each_syllable
    times_of_interest_separate = times_of_interest;
else
    times_of_interest_separate = NaN;
    times_of_interest_simultaneous = times_of_interest;
end

training_times = [];

for run = 1:nruns
    disp(sprintf('Starting run #%d...', run));
    
    separate_syllable_counter = 0;
    for thetime = times_of_interest_separate
        % thetime will be each of the times_of_interest, or else NaN, which will run once through the
        % loop.
        
        separate_syllable_counter = separate_syllable_counter + 1;


        % On each run of this loop, change the presentation order of the
        % data, so we get (a) a different subset of the data than last time for
        % training vs. final testing and (b) different training data presentation
        % order.
        rng('shuffle');
        
        if do_not_randomise
            randomorder(1:nsongs) = 1:nsongsandnonsongs;
            disp('NOT permuting song order');
        else
            randomorder = randperm(nsongsandnonsongs);
        end
        
        
        
        trainsongs = randomorder(1:ntrainsongs);
        testsongs = randomorder(ntrainsongs+1:end);
        
        if separate_network_for_each_syllable
            % "toi" will be times_of_interest(separate_syllable_counter)
            toi = thetime;
        else
            % This is redundant, but here for readability:
            toi = times_of_interest;
        end
        
        
        
        ntsteps_of_interest = length(toi);
        for i = 1:length(toi)
            tsteps_of_interest(i) = find(times >= toi(i), 1);
        end
        
        disp(sprintf('********** Working on [ %s] ms **********', sprintf('%d ', round(toi*1000))));
        
        
        %% Create the training set
        if strcmp(bird, 'delta')
            shotgun_sigma = 0.00001;
        else
            shotgun_sigma = 0.002; % TUNE
        end
        
        
        
        
        
        if use_jeff_realignment_train | use_jeff_realignment_test
            
            %% For each timestep of interest, get the offset of this song from the most typical one.
            disp('Computing target jitter compensation...');
            
            % We'll look for this long around the timestep, to compute the canonical
            % song
            time_buffer = 0.04;
            tstep_buffer = round(time_buffer / fft_time_shift_seconds);
            
            % For alignment: which is the most stereotypical song at each target?
            
            %[B A] = butter(4, [0.01 0.05]);
            %mic_data2 = filtfilt(B, A, double(mic_data));
            
            for i = 1:ntsteps_of_interest
                range = tsteps_of_interest(i)-tstep_buffer:tsteps_of_interest(i)+tstep_buffer;
                range = range(find(range>0&range<=ntimes));
                foo = reshape(spectrograms(1:nmatchingsongs, :, range), nmatchingsongs, []) * reshape(mean(spectrograms(:, :, range), 1), 1, [])';
                [val canonical_songs(i)] = max(foo);
                [target_offsets(i,:) sample_offsets(i,:)] = get_target_offsets_jeff(mic_data(:, 1:nmatchingsongs), tsteps_of_interest(i), samplerate, fft_time_shift_seconds, canonical_songs(i));
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
            target_offsets = zeros(ntsteps_of_interest, nsongsandnonsongs);
            sample_offsets = target_offsets;
            target_offsets_test = target_offsets;
            sample_offsets_test = sample_offsets;
        end
        %hist(target_offsets', 40);
        
        disp('Creating spectral power image...');
        
        % Create an image on which to superimpose the results...
        power_img = squeeze((sum(spectrograms, 2)));
        power_img(find(isinf(power_img))) = 0;
        
        %pn = 1:nmatchingsongs;
        %[vt pt] = sort(target_offsets);
        %[vs ps] = sort(sample_offsets);
        %figure(4);
        %subplot(1,1,1);
        %power_img = power_img(1:nmatchingsongs,:);
        %imagesc(power_img(pt,:));
        %set(gca, 'xlim', [280.2 300]);
        
        
        
        %% Draw the pretty full-res spectrogram and the targets
        figure(4);
        subplot(1,1,1);
        %subplot(ntsteps_of_interest+1,1,1);
        specfig = imagesc(times([1 end])*1000, freqs([1 end])/1000, spectrogram_avg_img);
        axis xy;
        xlabel('Time (ms)');
        ylabel('Frequency (kHz)');
        % Draw the syllables of interest:

        for i = 1:ntsteps_of_interest
            line(toi(i)*[1;1]*1000, freqs([1 end])/1000, 'Color', [1 0 0]);
            windowrect = rectangle('Position', [(toi(i) - time_window)*1000 ...
                freq_range(1)/1000 ...
                time_window(1)*1000 ...
                (freq_range(2)-freq_range(1))/1000], ...
                'EdgeColor', [1 0 0]);
        end
        set(gca, 'YLim', [0 10]);

            
        
        drawnow;
        
        
        
        disp(sprintf('Creating training set from %d songs...', ntrainsongs));
        [nnsetX nnsetY] = create_training_set(spectrograms, ...
            tsteps_of_interest, ...
            target_offsets, ...
            shotgun_sigma, ...
            randomorder, ...
            nmatchingsongs, ...
            nsongsandnonsongs, ...
            nwindows_per_song, ...
            layer0sz, ...
            fft_time_shift_seconds, ...
            time_window_steps, ...
            ntimes, ...
            freq_range_ds);
        
        if use_pattern_net
            nnsetYC = [nnsetY~=0 ; nnsetY==0];
        end
        
        %yy=reshape(nnsetY, nwindows_per_song, nsongsandnonsongs);
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
        %net.trainFcn = 'trainlm';
        net.trainFcn = 'trainscg';
        
        %net.trainParam.goal=1e-3;
        
        fprintf('Training network with %s...\n', net.trainFcn);
        
        
        % Once the validation set performance stops improving, it seldom seems to
        % get better, so keep this small.
        net.trainParam.max_fail = 3;
        
        tic
        if exist('use_previously_trained_network', 'var') & ~isempty(use_previously_trained_network)
            load(use_previously_trained_network);
        else
            if use_pattern_net
                [net, train_record] = train(net, nnsetX(:, nnset_train), nnsetYC(:, nnset_train));
            else
                [net, train_record] = train(net, nnsetX(:, nnset_train), nnsetY(:, nnset_train));
            end
        end
        
        % Oh yeah, the line above was the hard part.
        training_times = [training_times toc/60];
        disp(sprintf('   ...training took %g minutes (mean %s)', toc/60, sigfig(mean(training_times))));
        % Test on all the data:
        
        % Why not test just on the non-training data?  Compute them all, and then only count ntestsongs for statistics (later)
        if use_pattern_net
            testout = net(nnsetX);
            testout = testout(1,:);
        else
            testout = sim(net, nnsetX);
        end
        testout = reshape(testout, ntsteps_of_interest, nwindows_per_song, nsongsandnonsongs);
        
        % Update the each-song image
        power_img = power_img(randomorder,:);
        power_img = repmat(power_img / max(max(power_img)), [1 1 3]);
        
        disp('Computing optimal output thresholds...');
        
        % How many seconds on either side of the tstep_of_interest is an acceptable match?
        MATCH_PLUSMINUS = 0.02;
        
        % Which songs should have hits?  The first nmatchingsongs, but permuted to the same order as the
        % training/test sets, as given by randomorder.
        songs_with_hits = [ones(1, nmatchingsongs) zeros(1, nsongsandnonsongs - nmatchingsongs)]';
        songs_with_hits = songs_with_hits(randomorder);
        
        % Search for the optimal trigger thresholds using just the training set
        trigger_thresholds = optimise_network_output_unit_trigger_thresholds(...
            testout(:,:,1:ntrainsongs), ...
            nwindows_per_song, ...
            false_positive_cost, ...
            toi, ...
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
            false_positive_cost, ...
            toi, ...
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
                
        target_offsets_net = zeros(ntsteps_of_interest, nsongsandnonsongs);
        sample_offsets_net = zeros(ntsteps_of_interest, nsongsandnonsongs);

        % For each TOI, plot its response graph
        figure(6);
        for i = 1:length(toi)
            if separate_network_for_each_syllable
                subplot(length(times_of_interest), 1, separate_syllable_counter);
            else
                subplot(ntsteps_of_interest, 1, i);
            end
            
            testout_i_squeezed = reshape(testout(i,:,:), [], nsongsandnonsongs);
            leftbar = zeros(time_window_steps-1, nsongsandnonsongs);
            
            if SHOW_THRESHOLDS
                % "img" is a tricolour image
                img = power_img;
                % de-bounce:
                trigger_img = trigger(testout_i_squeezed', trigger_thresholds(i), 0.1, fft_time_shift_seconds);
                trigger_img = [leftbar' trigger_img];
                [val pos] = max(trigger_img, [], 2);
                triggertimes(:,i) = pos * fft_time_shift_seconds;
                
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
                    %[a, new_world_order] = sort(sample_offsets(randomorder(1:nmatchingsongs)));
                    [~, new_world_order] = sort(pos);
                    img = img(new_world_order,:,:);
                end
                
                % Make sure the image handle has the correct axes
                if SHOW_ONLY_TRUE_HITS
                    imh = image([times(1) times(end)]*1000, [1 sum(songs_with_hits)], img);
                else
                    imh = image([times(1) times(end)]*1000, [1 nsongsandnonsongs], img);
                end
            else
                leftbar(:, 1:ntrainsongs) = max(max(testout_i_squeezed))/2;
                leftbar(:, ntrainsongs+1:end) = 3*max(max(testout_i_squeezed))/4;
                testout_i_squeezed = [leftbar' testout_i_squeezed'];
                imagesc([times(1) times(end)]*1000, [1 nsongsandnonsongs], testout_i_squeezed);
            end
            xlabel('Time (ms)');
            ylabel('Song');
            %title(sprintf('Detection events for %d ms', round(1000*toi(i))));
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
        
        triggertimes_backup = triggertimes;
        
        
        % For syllable timing variability analysis, look only for "correct" hits.  Is this what I want?
        triggertimes(find(triggertimes == 0)) = NaN;
        for i = 1:ntsteps_of_interest
            ntt = triggertimes(:,i);
            ntt(find(abs(ntt - toi(i)) > 0.02)) = NaN;
            triggertimes(:,i) = ntt;
        end
        
        %% If possible, plot variability over the course of the day.  This
        % requires one network trained on multiple syllables, and computes timing differences
        % between each of the syllables in the roboaggregate file.
        if ntsteps_of_interest >= 2 & false
            %figure(233);
            %clf;
            %hold on;
            
            tsn = (timestamps - timestamps(1))*24;           
            tsu = unique(tsn);
            
            ncombs = nchoosek(ntsteps_of_interest, 2);
            combs = nchoosek(1:ntsteps_of_interest, 2);
            colours = distinguishable_colors(ncombs);
            
            comb = 0;
            for first = 1:ntsteps_of_interest
                for second = first+1:ntsteps_of_interest
                    comb = comb + 1;
                    for i = 1:length(tsu)
                        inds = find(tsn(randomorder(1:nmatchingsongs)) == tsu(i));
                        measure = (triggertimes(inds, first) - triggertimes(inds, second)) * 1e3;
                        binsize(i,first,second) = length(measure) - sum(isnan(measure));
                        means(i,first,second) = nanmean(measure);
                        stds(i,first,second) = nanstd(measure);
                        %plot(tsu(i)*ones(size(measure)), measure, '.', 'Color', colours(comb,:));
                    end
                end
            end
            ste = stds ./ binsize.^(1/2);
            %hold off;
            stds(find(stds==0)) = NaN;
            
            figure(234);
            clf;
            for first = 1:ntsteps_of_interest
                for second = first+1:ntsteps_of_interest
                    subplot(ntsteps_of_interest-1, ntsteps_of_interest-1, (first-1)*(ntsteps_of_interest-1)+second-1);
                    includ = find(~isnan(stds(:,first,second)));
                    [tsup stdsp] = prepareCurveData(tsu, stds(:,first,second));
                    xl = [min(tsup) max(tsup)];
                    if length(tsup) > 2
                        f0 = fit(tsup, stdsp, 'poly1', 'weights', binsize(includ,first,second));
                        hold on;
                        scatter(tsup, stdsp, binsize(includ,first,second), [0 0 1], 'filled');
                        plot(xl, f0(xl), 'Color', [0 0 1]);
                        hold off;
                        xlabel('Time (hours)');
                        ylabel('Intersyllable std dev (ms)');
                        yl = get(gca, 'YLim');
                        yl(1) = 0;
                        set(gca, 'XLim', xl, 'YLim', yl);
                        confs = confint(f0);
                        title(sprintf('%d-%d: slope %s (95%%)', first, second, sigfig(confs(1:2), 2)));
                    end
                end
            end
        end
        
        drawnow;
        
        
        
        %% Realign test output according to the neural network's detection point?
        if use_nn_realignment_test
            target_offsets_net = zeros(ntsteps_of_interest, nsongsandnonsongs);
            sample_offsets_net = zeros(ntsteps_of_interest, nsongsandnonsongs);
            for i = 1:ntsteps_of_interest
                testout_i_squeezed = reshape(testout(i,:,:), [], nsongsandnonsongs);
                leftbar = zeros(time_window_steps-1, nsongsandnonsongs);
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
        
        
        if nruns > 1 & separate_network_for_each_syllable
            %% Plot the figure of errors for all networks over all trials...
            figure(9);
            % This file is created in show_confusion.m.  No effort is made to ensure that it
            % doesn't contain values for different configurations, or even different-sized columns!
            % So if you want to use it, best make sure you start by deleting the previous
            % confusion_log_perf.txt.  That is not done automatically in order to allow restart of
            % partially completed jobs, since 6 syllables, 100 runs, 1000 training songs, etc., can
            % take around 4 days to complete.
            confusion = load('confusion_log_perf.txt');
            [sylly bini binj] = unique(confusion(:,1));
            xtickl = {};
            sylly_means = [];
            sylly_counts = [];
            for i = 1:length(sylly)
                xtickl{i} = sprintf('t^*_%d', i);
                sylly_counts(i) = length(find(confusion(:,1)==sylly(i)));
                sylly_means(i,:) = mean(confusion(find(confusion(:,1)==sylly(i)),2:3), 1);
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
            %set(gca, 'ylim', [97 100]);
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
            %set(gca, 'ylim', [0 0.07]);
            sylly_counts
        end
        
        
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
        % Extract data from net structure, because LabView's MathScript is too stupid to
        % permit the . operator.
        layer0 = net.IW{1};
        layer1 = net.LW{2,1};
        bias0 = net.b{1};
        bias1 = net.b{2};
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
            bird, sprintf('_%g', toi), 1000*fft_time_shift_seconds_target, net.layers{1}.dimensions, ntrainsongs);
        fprintf('Saving as ''%s''...\n', filename);
        save(filename, ...
            'bird', 'times_of_interest', 'toi', 'net', 'train_record', ...
            'samplerate', 'fft_size', 'win_size', 'fft_time_shift', 'fft_time_shift_seconds', 'fft_time_shift_seconds_target', ...
            'freq_range_ds', ...
            'time_window_steps', 'trigger_thresholds', 'freq_range', ...
            'layer0', 'layer1', 'bias0', 'bias1', ...
            'mmmout_xmin', 'mmmout_ymin', 'mmmout_gain', 'mapstd_xmean', 'mapstd_xstd', ...
            'shotgun_sigma', ...
            'ntrainsongs',  'scaling', '-v7');
        %% Save sample data: audio on channel0, canonical hits for first syllable on channel1
        if use_nn_realignment_test
            realignNetString = 'realignNet';
        else
            realignNetString = '';
        end
        
        % Let's standardise order for each set of test songs, so that we can compare multiple training
        % runs of the detector on the same songs:
        %rng(137);
        
        if testfile_include_nonsinging
            % Re-permute all songs with a new random order
            newrand = randperm(size(mic_data,2));
            orig_songs_with_hits =  [ones(1, nmatchingsongs) zeros(1, nsongsandnonsongs - nmatchingsongs)]';
            new_songs_with_hits = orig_songs_with_hits(newrand);
            songs = reshape(mic_data(:, newrand), [], 1); % Include all singing and non-singing
            %songs = reshape(mic_data(:, 1:nsongsandnonsongs), [], 1); % Just singing
            songs_scale = max([max(songs) -min(songs)]);
            songs = songs / songs_scale;
            hits = zeros(size(mic_data));
            samples_of_interest = round(toi * samplerate);
            for i = 1:nsongsandnonsongs
                if new_songs_with_hits(i)
                    % The baseline signal is recorded only for the first sample
                    % of interest:
                    hits(samples_of_interest(1) + sample_offsets_2(1, newrand(i)), i) = 1;
                end
            end
            hits = reshape(hits, [], 1);
            songs = [songs hits];
            testfilename = sprintf('songs_%s%ss_%d%%%s.wav',...
                bird, sprintf('_%g', toi), round(100/(1+nonsinging_fraction)), ...
                realignNetString);
        else
            % Just the real songs
            
            % Re-permute just 128 of the positive songs with a new random order -- for oscilloscope
            % 128-sample averages
            ntestsongs = nmatchingsongs;
            newrand = randperm(nmatchingsongs);
            newrand = newrand(1:ntestsongs);
            
            %songs = reshape(mic_data(:, 1:nmatchingsongs), [], 1); % Include all singing and non-singing
            songs = reshape(mic_data(:, newrand), [], 1); % Just singing
            songs_scale = max([max(songs) -min(songs)]);
            songs = songs / songs_scale;
            hits = zeros(nsamples_per_song, ntestsongs);
            samples_of_interest = round(toi * samplerate);
            for i = 1:ntestsongs
                hits(samples_of_interest(1) + round(sample_offsets_test(1, i)), i) = 1;
            end
            hits = reshape(hits, [], 1);
            songs = [songs hits];
            
            testfilename = sprintf('songs_%d_%s%ss%s.wav', ...
                ntestsongs, ...
                bird, sprintf('_%g', toi), ...
                realignNetString);
            
        end
        
        audiowrite(testfilename, songs, round(samplerate));
    end
end

