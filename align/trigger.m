function [ trigger_now ] = trigger(responses, threshold, schmidt_trigger_down, timestep);

% This just returns the first one per song...
[ val pos ] = max(responses > threshold, [], 2);
%pos = pos(find(pos == 1)) = ;

trigger_now = zeros(size(responses));

for i = 1:length(pos)
        trigger_now(i, pos(i)) = 1;
end

% Look at all trigger events:
trigger_now = responses > threshold;
trigger_schmidt = zeros(size(responses));

% How about a Schmidt Trigger?
if exist('schmidt_trigger_down')
        schmidt_trigger_down_steps = schmidt_trigger_down / timestep;
        for i = 1:size(responses, 1)
                pos = find(trigger_now(i,:) > 0);
                while ~isempty(pos)
                        trigger_schmidt(i, min(pos)) = 1;
                        pos(find(pos <= min(pos) + schmidt_trigger_down_steps)) = [];
                end
        end
        trigger_now = trigger_schmidt;
end

