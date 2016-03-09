function [ trigger_now ] = trigger_max(responses, threshold, schmidt_trigger_down, timestep);

% De-bounce the signal

% This just returns the best hit per song...
[ val pos ] = max(responses > threshold, [], 2);

trigger_now = zeros(size(responses));

for i = 1:length(pos)
        trigger_now(i, pos(i)) = 1;
end
