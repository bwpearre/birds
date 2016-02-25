function [ trigger_now ] = trigger(responses, threshold, schmidt_trigger_down, timestep);

% De-bounce the signal


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

