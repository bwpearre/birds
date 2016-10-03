function [ data ] = update_data_struct(data, detrend_param, handles)


if ~isfield(data, 'version')
    data.version = 0;
    
    npts = size(data.data, 1);
    data.data_raw = [data.data zeros(npts, 1)];
    
    % Add timing pulse to channel 4
    data.data_raw(4, find(abs(data.data(:,3)) > 0.5, 1)) = 1;
    
end

if data.version < 8
    [data.data_aligned data.triggertime data.n_repetitions_actual] ...
        = chop_and_align(data.data_raw, ...
                         data.data_raw(:, 4), ...
                         data.time', ...
                         data.n_repetitions, ...
                         data.fs);
    data.times_aligned = data.time - data.triggertime;
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
    
    if any(size(data.negativefirst) ~= size(data.stim_electrodes))
        data.negativefirst = ones(size(data.stim_electrodes)) * data.negativefirst;
    end
end    




if data.version == 12
    % Repair my stupidity -- version 12 has unscaled data.
    data.ni.stim(:,:,1) = data.ni.stim(:,:,1) * 4;
    data.ni.stim(:,:,2) = data.ni.stim(:,:,2) * 400;
end






if data.version < 14
    data.stim_duration = 2 * data.halftime_us / 1e6 + data.interpulse_s;
    if isfield(data, 'tdt')
        stim_start_i = find(data.tdt.times_aligned >= 0, 1) - 1;
        stim_stop_i = find(data.tdt.times_aligned >= data.stim_duration, 1) + 1;
        data.tdt.stim_active_indices = stim_start_i:stim_stop_i;
        data.tdt.stim_active = 0 * data.tdt.times_aligned;
        data.tdt.stim_active(data.tdt.stim_active_indices) = ones(size(data.tdt.stim_active_indices));
    end

    data.current = floor(data.current);
end



if data.version < 16
    data.ni.times_aligned = data.ni.times_aligned';
end



if data.version < 18
    
    if isempty(detrend_param)
        detrend_param.model = 'fourier8';
        detrend_param.range = [0.003 0.025];
        detrend_param.response_roi = [0.003 0.008];
        detrend_param.response_baseline = [0.012 0.025];
        detrend_param.response_detection_threshold = Inf;
    end
    data.detrend_param = detrend_param;
end



if data.version < 19
    % data.stim_duration appears earlier!  But it was mis-calculated.
    data.stim_duration = 2 * data.halftime_us / 1e6 + data.interpulse_s;
    data.goodtimes = [ 0.0002 + data.stim_duration,      -0.0003 + 1/data.repetition_Hz ];
     
    data.detrend_param.response_detection_threshold = 2e-10;
    if isfield(data, 'tdt')
        [ data.tdt.response_detrended data.tdt.response_trend data.detrend_param ] ...
            = detrend_response(data.tdt, data, detrend_param);
        % look_for_spikes output format changed at v.22 or so, so that's
        % down there...
     elseif isfield(data, 'ni')
        [ data.ni.response_detrended data.ni.response_trend data.detrend_param ] ...
            = detrend_response(data.ni, data, detrend_param);
     end
     
     data.current_uAmps = data.current;
     data.active_electrodes = data.stim_electrodes;
     data.plexon_monitor_electrode = data.monitor_electrode;
end



if data.version < 20
    data.stim.repetition_Hz = data.repetition_Hz;
    data.stim.halftime_s = data.halftime_us / 1e6;
    data.stim.interpulse_s = data.interpulse_s;
    data.stim.duration_s = 2 * data.stim.halftime_s + data.interpulse_s;
    data.stim.current_uA = data.current_uAmps;
    data.stim.negativefirst = data.negativefirst;
    data.stim.active_electrodes = data.active_electrodes;
    data.stim.plexon_monitor_electrode = data.plexon_monitor_electrode;
end



if data.version < 21
    target_current = [ 0                                   0 ; ...
        0                                                  data.stim.current_uA ; ...
        data.stim.halftime_s                               data.stim.current_uA ; ...
        data.stim.halftime_s                               0 ; ...
        data.stim.halftime_s+data.stim.interpulse_s        0 ; ...
        data.stim.halftime_s+data.stim.interpulse_s        -data.stim.current_uA ; ...
        data.stim.duration_s                               -data.stim.current_uA ; ...
        data.stim.duration_s                               0]';
    if data.stim.negativefirst(data.stim.plexon_monitor_electrode) == 1
        target_current(2,:) = target_current(2,:) * -1;
    end
    data.stim.target_current = target_current;
end



if data.version < 22
    global look_for_spikes;
    
     % These could be corrected if needed...
    data.time = 0;
    data.filename = '';
    
    % These were added for v25, but needed here.
    data.detrend_param.response_sigma = 5;
    data.detrend_param.response_prob = NaN; % This forces detrend_param != detrend_param
    
    if isfield(data, 'tdt')
        [ data.tdt.spikes data.tdt.spikes_r ]= look_for_spikes(data.tdt, ...
            data, [], []);
     elseif isfield(data, 'ni')
        [ data.ni.spikes data.ni.spikes_r ]= look_for_spikes(data.ni, ...
            data, [], []);
     end

end


if data.version < 23
    data.voltage = max(max(abs(data.ni.stim(:, :, 1))));
end

if data.version < 24
    if length(data.detrend_param.response_detection_threshold) == 1
        data.detrend_param.response_detection_threshold = ones(1, 16) * data.detrend_param.response_detection_threshold;
    end
end


if data.version < 25
    % Here I changed response detection to look_for_spikes_peaks.m, which uses a different
    % threshold: RMS noise = sigma; spike >= 5sigma.
    data.stim.prepulse_us = zeros(1,16);
    data.stim.current_scale = zeros(1,16);
    data.detrend_param.response_sigma = 5;
    data.detrend_param.response_prob = NaN;
end


if data.version < 26
    % Introduce Sam's changes: individualised current_uA scaling and timing
    data.stim.current_scale = (data.stim.negativefirst - 0.5) * -2;
    data.stim.prepulse_s = zeros(1,16);
    data.detrend_param.response_prob = 0.5; % With spike_detect (below) this is obviated.
    data.detrend_param.spike_detect = @look_for_spikes_peaks;
end

if data.version >= 26
    % This will be broken if stim_scale strays from {-1,1}, but is needed
    % for plot_max_voltage_bar.m and reanalyse_threshlds.m
    data.stim.negativefirst = (data.stim.current_scale / -2) + 0.5;
end

if data.version < 27
    data.voltage_range = [-data.voltage data.voltage];
end

