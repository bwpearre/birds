clear;

rng('shuffle');

load aggregated_data;

%some_songs = reshape(MIC_DATA(:, 1:50), [], 1);
%
%audiowrite('birdsongs.ogg', ...
%        some_songs / max([max(max(some_songs)) abs(min(min(some_songs)))]), ...
%        44100);

%disp('Tossing most of MIC_DATA so things go faster!');
%MIC_DATA = MIC_DATA(:, 1:11);



nsongs = size(MIC_DATA, 2);

speck = specgram(MIC_DATA(:,1), 512, [], [], 500) + eps;
[nfreqs ntimes] = size(speck);
spectrograms = zeros([nsongs nfreqs ntimes]);
spectrograms(1, :, :) = speck;
disp('Computing spectrograms...');
parfor i = 2:nsongs
        speck = specgram(MIC_DATA(:,i), 512, [], [], 500) + eps;
        spectrograms(i, :, :) = speck;
end

spectrogram_avg_img = squeeze(log(sum(abs(spectrograms(:,5:end,:)))));


% Construct dataset.
% Number of samples: (nsongs*(ntimes-time_window))
% Size of each sample: (ntimes-time_window)*length(freq_range)

img_ds = [2 10];

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
spectrograms_ds = spectrograms_ds / prod(img_ds);


freq_range_ds = 40:80;
time_window_ds = 30;

[foo nfreqs_ds ntimes_ds] = size(spectrograms_ds);
layer0sz = length(freq_range_ds) * time_window_ds;
nwindows_per_song = ntimes_ds - time_window_ds + 1;

ntrainsongs = floor(nsongs*8/10);
ntestsongs = ceil(nsongs*2/10);
randomsongs = randperm(nsongs);

trainsongs = randomsongs(1:ntrainsongs);
testsongs = randomsongs(ntrainsongs+1:end);

disp(sprintf('(Allocating %g MB for training set X.)', ...
        8 * nsongs * nwindows_per_song * layer0sz / (2^20)));
nnsetX = zeros(layer0sz, nsongs * nwindows_per_song);

disp(sprintf('Creating training set from %d songs...', ntrainsongs));
% This loop also shuffles the songs according to randomsongs, so we can use
% contiguous blocks for training / testing

tstep_of_interest = [ 840 1335 1820 ];
tstep_of_interest_ds = round(tstep_of_interest/img_ds(2))
ntsteps_of_interest = length(tstep_of_interest);

nnsetY = zeros(length(tstep_of_interest), nsongs * nwindows_per_song);


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

net = feedforwardnet([4]);
net.trainParam.max_fail = 3;
%net = train(net, nnsetX(:, nnset_train), nnsetY(:, nnset_train), {}, {}, 0.1 + nnsetY(:, nnset_train));
net = train(net, nnsetX(:, nnset_train), nnsetY(:, nnset_train));


testout = sim(net, nnsetX);
testout = reshape(testout, ntsteps_of_interest, nwindows_per_song, nsongs);

if false
        song_montage = spectrograms_ds;
        song_montage = permute(spectrograms_ds, [2 3 4 1]);
        song_montage = repmat(song_montage, [1 1 3 1]);
        song_montage = log(song_montage+eps);
        song_montage = song_montage / max(max(max(max(song_montage))));
        montage(song_montage(:,:,:,testsongs));
end

% Plot the results from the unseen test set
figure(4);
subplot(ntsteps_of_interest+1,1,1);
imagesc(spectrogram_avg_img);
line(repmat(tstep_of_interest, 2, 1), repmat([1 nfreqs], ntsteps_of_interest, 1)', 'Color', [1 0 0]);
ylabel('frequency');
axis xy;

for i = 1:ntsteps_of_interest
        figure(4);
        subplot(ntsteps_of_interest+1,1,i+1);
        foo = reshape(testout(i,:,:), [], nsongs);
        barrr = zeros(time_window_ds, nsongs);
        barrr(:, 1:ntrainsongs) = max(max(foo))/2;
        barrr(:, ntrainsongs+1:end) = 3*max(max(foo))/4;
        foo = [barrr' foo'];
        imagesc(foo);
        xlabel('timestep');
        ylabel('Song (random order)');
        text(time_window_ds/2, ntrainsongs/2, 'train', ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'Rotation', 90);
        text(time_window_ds/2, ntrainsongs+ntestsongs/2, 'test', ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'Rotation', 90);
        
end

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
