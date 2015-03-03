function [ trigger_now ] = trigger(responses, threshold);

[ val pos ] = max(responses > threshold, [], 2);
%pos = pos(find(pos == 1)) = ;

trigger_now = zeros(size(responses));

for i = 1:length(pos)
        trigger_now(i, pos(i)) = 1;
end
