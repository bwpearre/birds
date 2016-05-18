function [ trigger_now val pos] = trigger_max(responses, threshold, varargin);

% De-bounce the signal

% This just returns the best hit per song...
responses(find(responses<threshold)) = NaN;

[ val pos ] = max(responses, [], 2);

trigger_now = zeros(size(responses));

for i = 1:length(pos)
    if isnan(val(i))
        pos(i) = NaN;
    else
        trigger_now(i, pos(i)) = 1;
    end
end
