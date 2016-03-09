function [ trigger_now ] = trigger(responses, threshold, schmidt_trigger_down, timestep);

% De-bounce the signal


% Look at all trigger events:
trigger_now = responses > threshold;
