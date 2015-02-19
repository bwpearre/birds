function [cost] = trigger_threshold_cost(threshold, ...
        responses, ...
        positive_interval, ...
        FALSE_POSITIVE_COST);
% responses should be a [[ 1 x ] song x timestep ] array of song responses for the
% relevant output neuron.

if ~exist('FALSE_POSITIVE_COST')
        FALSE_POSITIVE_COST = 1;
end

responses = squeeze(responses);
% Cost is (weighting constant times) the number of songs for which there's a false positive + the
% number of songs for which there's a false negative.

responses = responses > threshold;

% First, the false negatives:
foo = sum(responses(:, positive_interval), 2);
false_negatives = sum(foo == 0);


% Kill those, and what's left is the false positives:
responses(:, positive_interval) = zeros(size(responses, 1), length(positive_interval));
foo = sum(responses, 2);
false_positives = sum(foo > 0);

cost = FALSE_POSITIVE_COST * false_positives + false_negatives;
