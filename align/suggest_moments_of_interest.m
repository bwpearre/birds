function [ tstep_of_interest ] = suggest_moments_of_interest(ntsteps, ...
                                             spectrogram_avg_img, ...
                                             img_ds, ...
                                             time_window_ds, ...
                                             layer0sz, ...
                                             nwindows_per_song, ...
                                             ntimes_ds, ...
                                             freq_range_ds);
                                             

if 0  % Look for unique moments
        dists = squareform(pdist(spectrogram_avg_img(:,time_window_ds:end)'));
else   % Look for unique segments from the training set
        if any(img_ds ~= 1)
                tstep_of_interest = [];
                error(learn_detector:missingFeature, 'Missing Feature');
        end
        
        pdistset = zeros(layer0sz, nwindows_per_song);
        for tstep = time_window_ds : ntimes_ds
                pdistset(:, tstep - time_window_ds + 1) ...
                        = reshape(spectrogram_avg_img(freq_range_ds, ...
                        tstep - time_window_ds + 1  :  tstep), ...
                        [], 1);
        end

        dists = squareform(pdist(pdistset'));
end

figure(6);
imagesc(dists);

%% We want to find the row such that the minimum distance to that point is
%% maximised--not counting points close to the row.  So set the diagonal high.
for i = 1:size(dists, 1)
        for j = i:size(dists, 1)
                if abs(i-j) < 20
                        dists(i, j) = NaN;
                        dists(j, i) = NaN;
                end
        end
end


tstep_of_interest = [];

%% Pick the maximally-distal spot on the distance image, add it to the
%% timesteps we might care about, delete it from the image, repeat.
for i = 1:3
        [val pos] = max(min(dists));
        tstep_of_interest(i) = pos;
        
        dists(pos-40:pos+40,:) = NaN * zeros(81, nwindows_per_song);
        dists(:, pos-40:pos+40) = NaN * zeros(nwindows_per_song, 81);
        hold on;
        scatter(pos, pos, 100, 'r*');
        hold off;
end
tstep_of_interest = tstep_of_interest + time_window_ds - 1
tstep_of_interest = sort(tstep_of_interest);

drawnow;
