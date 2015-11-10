function [data_aligned, triggertime, n_repetitions_actual] ...
    = chop_and_align(data, triggers, timestamps, n_repetitions_sought, fs);

%triggerthreshold = (max(abs(triggers)) + min(abs(triggers)))/2;
triggerthreshold = 0.5;
trigger_ind = triggers >= triggerthreshold;
trigger_ind = find(diff(trigger_ind) == 1) + 1;
triggertimes = timestamps(trigger_ind);

if n_repetitions_sought ~= length(trigger_ind)
    disp(sprintf('NOTE: looking for %d triggers, but found %d (threshold %d)', ...
        n_repetitions_sought, length(trigger_ind), triggerthreshold));
end


n_repetitions_actual = length(trigger_ind);
if n_repetitions_actual == 0
    data_aligned = [];
    triggertime = NaN;
    d2 = 0;
    return
end


for n = length(trigger_ind):-1:1
    start_ind = trigger_ind(n) - trigger_ind(1) + 1;
    data_aligned(n,:,:) = data(start_ind:start_ind+ceil(0.025*fs),:);
end


triggertime = timestamps(find(triggers >= triggerthreshold, 1));
if isempty(triggertime)
    disp('No trigger!');
    data_aligned = [];
    triggertime = NaN;
    return;
end


