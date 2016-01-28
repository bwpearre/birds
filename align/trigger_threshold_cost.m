function [cost truepositiverate falsepositiverate ] = trigger_threshold_cost(threshold, ...
        responses, ...
        positive_interval, ...
        FALSE_POSITIVE_COST, ...
        songs_with_hits);
% responses should be a [[ 1 x ] song x timestep ] array of song responses
% for the relevant output neuron. positive_interval is the interval, in samples,
% around the aligned data that counts as a positive.

if ~exist('FALSE_POSITIVE_COST')
        FALSE_POSITIVE_COST = 1;
end

responsest = squeeze(responses);

nresponses = size(responsest, 1);
% Cost is (weighting constant times) the number of songs for which there's
% a false positive + the number of songs for which there's a false
% negative.


% NOT TRUE anymore: just count every prediction
%    FALSE POSITIVES: One false positive for every song for which there is a
%    trigger outside the target area.

%    FALSE NEGATIVE SONG: One false negative for every song for which there is
%    no trigger inside the target area, and the song is in songs_with_hits

responsest = responsest > threshold;

true_positives = sum(responsest(:, positive_interval), 2);
true_positives = sum((true_positives > 0) & songs_with_hits);

% First, the false negatives in the songs that should have hits:
foo = sum(responsest(:, positive_interval), 2);
false_negatives = sum((foo == 0) & songs_with_hits);

% Compute false positives: Max 1 per song?  Or 1 per frame?
false_positives_per_song = false;

% Kill the true positives, and what's left is the false positives:
responsest(find(songs_with_hits), positive_interval) = zeros(sum(songs_with_hits), length(positive_interval));

if false_positives_per_song
    % Sum of responses of all (non-true-pos) timesteps in each song
    foo = sum(responsest, 2);
    % How many songs had positives outside the positive time region
    false_positives = sum(foo > 0);
else
    false_positives = sum(sum(responsest));
end


cost = FALSE_POSITIVE_COST * false_positives + false_negatives;

truepositiverate = true_positives / sum(songs_with_hits);
falsepositiverate = false_positives / (prod(size(responsest)) - (nresponses * length(positive_interval)));

