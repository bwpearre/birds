function [ nnsetX nnsetY ] = create_training_set(spectrograms, ...
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

ntsteps_of_interest = length(tsteps_of_interest);

training_set_MB = 8 * nsongsandnonsongs * nwindows_per_song * layer0sz / (2^20);

disp(sprintf('   ...(Allocating %g MB for training set X.)', training_set_MB));

nnsetX = zeros(layer0sz, nsongsandnonsongs * nwindows_per_song);
nnsetY = zeros(ntsteps_of_interest, nsongsandnonsongs * nwindows_per_song);

%% OPTIONAL: MANUAL PER-SYLLABLE TUNING!

% Some syllables are really hard to pinpoint to within the frame rate, so
% the network has to try to learn "image A is a hit, and this thing that
% looks identical to image A is not a hit".  For each sample of interest,
% define a "shotgun function" that spreads the "acceptable" fft_time_shift_secondss in
% the training set a little.  This could be generalised for multiple
% syllables, but right now they all share one sigma.

% This only indirectly affects final timing precision, since thresholds are
% optimally tuned based on the window defined in MATCH_PLUSMINUS.
shotgun_max_sec = 0.02;
shotgun = normpdf(0:fft_time_shift_seconds:shotgun_max_sec, 0, shotgun_sigma);
shotgun = shotgun / max(shotgun);
shotgun = shotgun(find(shotgun>0.1));
shothalf = length(shotgun);
if shothalf
    shotgun = [ shotgun(end:-1:2) shotgun ]
end

% Populate the training data.  Infinite RAM makes this so much easier!
for song = 1:nsongsandnonsongs
    
    for tstep = time_window_steps : ntimes
        
        nnsetX(:, (song-1)*nwindows_per_song + tstep - time_window_steps + 1) ...
            = reshape(spectrograms(randomorder(song), ...
            freq_range_ds, ...
            tstep - time_window_steps + 1  :  tstep), ...
            layer0sz, 1);
        
        % Fill in the positive hits, if appropriate...
        if randomorder(song) > nmatchingsongs
            % If the index is from the non-song region of the corpus, do not mark a hit.  This
            % cannot simply be moved to the outer loop because we still need to put it in nnsetX.
            continue;
        else
            for interesting = 1:ntsteps_of_interest
                if tstep == tsteps_of_interest(interesting)
                    nnsetY(interesting, (song-1)*nwindows_per_song + tstep + target_offsets(interesting, randomorder(song)) - time_window_steps - shothalf + 2 : ...
                        (song-1)*nwindows_per_song + tstep + target_offsets(interesting, randomorder(song)) - time_window_steps + shothalf) ...
                        = shotgun;
                end
            end
        end
    end
end

if max(nnsetY) == 0
    error('create_training_set', 'No positive Y data');
end

disp('Converting neural net data to singles...');
nnsetX = zscore(single(nnsetX));
nnsetY = single(nnsetY);
