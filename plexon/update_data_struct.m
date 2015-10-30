function [ data ] = update_data_struct(data, detrend_param, handles)


if data.version < 8
    [data.data_aligned data.triggertime data.n_repetitions_actual] ...
        = chop_and_align(data.data_raw, ...
                         data.data_raw(:, 4), ...
                         data.time', ...
                         Inf, ...
                         data.fs);
end    



if data.version < 9
    data.ni.times_aligned = data.times_aligned;
    if isfield(data, 'recording_channel_indices')
        data.ni.index_recording = data.recording_channel_indices(2:end);
    else
        data.ni.index_recording = 3;
    end
    data.ni.stim = data.data_aligned(:, :, 1:2);
    data.ni.response = data.data_aligned(:, :, data.ni.index_recording);
    data.ni.show = 1:length(data.ni.index_recording); % For now, show everything that there is.
    if ndims(data.data_aligned) == 3
        n_repetitions_actual = size(data.data_aligned, 1);
    else
        n_repetitions_actual = 1;
    end
    data.ni.n_repetitions = n_repetitions_actual;
    data.ni.index_trigger = 4;
    data.ni.stim_active = data.data_aligned(1, :, data.ni.index_trigger);
    d = diff(data.ni.stim_active);
    stim_start_i = find(d > 0.5, 1) + 1;
    stim_stop_i = find(d < -0.5, 1) + 1;
    data.ni.stim_active_indices = stim_start_i:stim_stop_i;
    data.ni.recording_amplifier_gain = 515;
    data.ni.fs = data.fs;
    data.ni.triggertime = data.triggertime;
    data.ni.labels = data.labels;
    data.ni.names = data.names;
end    


if data.version < 13
    data.stim_duration = 2 * data.halftime_us / 1e6 + data.interpulse_s;
    if isfield(data, 'tdt')
        stim_start_i = find(data.tdt.times_aligned >= 0, 1) - 1;
        stim_stop_i = find(data.tdt.times_aligned >= data.stim_duration, 1) + 1;
        data.tdt.stim_active_indices = stim_start_i:stim_stop_i;
        data.tdt.stim_active = 0 * data.tdt.times_aligned;
        data.tdt.stim_active(data.tdt.stim_active_indices) = ones(size(data.tdt.stim_active_indices));
    end
end

if data.version < 14
    data.current = floor(data.current);
end


if data.version < 18
    data.detrend_param = detrend_param;
end



if data.version < 19
    data.goodtimes = [ 0.0002 + data.stim_duration,      -0.0003 + 1/data.repetition_Hz ];
     
     if isfield(data, 'tdt')
        [ data.tdt.response_detrended data.tdt.response_trend ] ...
            = detrend_response([], data.tdt, data, detrend_param);
        [ data.tdt.spikes data.tdt.spikes_r ]= look_for_spikes_xcorr(data.tdt, ...
            data, detrend_param, [], handles);
     elseif isfield(data, 'ni')
        [ data.ni.response_detrended data.ni.response_trend ] ...
            = detrend_response([], data.ni, data, detrend_param);
        [ data.ni.spikes data.ni.spikes_r ]= look_for_spikes_xcorr(data.ni, ...
            data, detrend_param, [], handles);
     end
end


