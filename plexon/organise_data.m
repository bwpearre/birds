% We got some data, through the NI and the TDT. Grab it, chop it up,
% reorganise it into the "data" structure.
function [ data, response_detected, voltage, errors] = organise_data(stim, hardware, ...
    detrend_param, obj, event, handlefigure)

global saving_stimulations;
global bird;
global datadir;
global ni_trigger_index;
global ni_recording_channel_ranges;
global comments;
global recording_time;
global axes2;
global voltage_range_last_stim;
global show_device;
global voltage_limit;
global stop_button_pressed;

errors.val = 0;
errors.name = {};



% Just to be confusing, the Plexon's voltage monitor channel scales its
% output because, um, TEXAS!
scalefactor_V = 1/PS_GetVmonScaling(1);
scalefactor_i = 400; % uA/mV, always!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
edata = event.Data;
for i = 1:length(ni_recording_channel_ranges)
    %disp(sprintf('Channel %d (%g V)', ...
    %            i, max(abs(edata(:,i)))));
    if any(abs(edata(i,:)) > ni_recording_channel_ranges(i))
        disp(sprintf('WARNING: Channel %d peak (%g V) exceeds expected max measurement voltage %g', ...
                i, max(abs(edata(i,:))), ni_recording_channel_ranges(i)));
    end
end
edata(:,1) = event.Data(:,1) * scalefactor_V;
edata(:,2) = event.Data(:,2) * scalefactor_i;
edata(:,hardware.ni.recording_channel_indices) = event.Data(:,hardware.ni.recording_channel_indices) / hardware.intan.gain;

if ~isempty(hardware.tdt)
    

    %% If recording with TDT, block until the data buffer has enough samples:
    tdt_TimeStamps = 0:1/hardware.tdt.samplerate:(recording_time+0.01);

    try
        curidx = hardware.tdt.device.GetTagVal('DataIdx');
        %disp(sprintf('TDT contains %d samples', curidx));
        lastidx = curidx;
        while curidx < hardware.tdt.nsamples
            disp(sprintf('Waiting for TDT: buffer now contains %d samples', curidx));
            curidx = hardware.tdt.device.GetTagVal('DataIdx');
            if lastidx == curidx
                disp('TDT doesn''t seem to be getting triggers.  Discarding...');
                return;
            end
            lastidx = curidx;
        end
        curidx2 = hardware.tdt.device.GetTagVal('DDataIdx');
        
        % These should be the same. But TDT!
        goodlength = min(curidx/16, curidx2);
        
        index_recording = find(stim.tdt_valid);
        
        tdata = hardware.tdt.device.ReadTagVEX('Data', 0, curidx, 'F32', 'F64', 16)';
        tddata = hardware.tdt.device.ReadTagV('DData', 0, curidx2)';
        tdata = tdata(1:goodlength, index_recording);
        tddata = tddata(1:goodlength, :);
        
        
        
        tdt_TimeStamps = tdt_TimeStamps(1:goodlength);
        if false
            figure(1);
            subplot(3, 1, [1 2]);
            plot(tdt_TimeStamps, tdata);
            subplot(3,1,3);
            plot(tdt_TimeStamps, tddata);
            set(gca, 'YLim', [-0.1 6]);
        end
        
        %set(gca, 'XScale', 'linear');
        % [a b] = rat(NIsession.Rate / tdt_samplerate);
        % tdata = resample(tdata, a, b);
        % tddata = resample(double(tddata), a, b);
        %subplot(1,2,2);
        %plot(tddata);
        
        %figure(1);
        %subplot(3,1,[1 2]);
        %plot(tdata);
        %subplot(3,1,3);
        %plot(tddata);
    catch ME
        warning('Ignoring TDT-is-stupid error #546, WHICH IS ONLY OKAY IF YOU JUST PRESSED STOP!');
        data = [];
        response_detected = NaN;
        voltage = NaN;
        errors.val = bitor(errors.val, 256);
        return;
    end
else
    tdata = [];
    tddata = [];
end

voltage_range_last_stim = [min(edata(:,1)) max(edata(:,1))];

file_basename = 'stim';
file_format = 'yyyymmdd_HHMMSS.FFF';
nchannels = length(obj.Channels);

%%%%%
%%%%% Chop/align the multiple stimulations from the NI
%%%%%

[data_aligned triggertime n_repetitions_actual] = chop_and_align(edata, ...
    edata(:, ni_trigger_index), ...
    event.TimeStamps', ...
    stim.n_repetitions, ...
    obj.Rate);
% times_aligned is data.time aligned so spike=0
edata = mean(data_aligned, 1);
if length(size(data_aligned)) == 3
    edata = squeeze(edata);
end

if n_repetitions_actual == 0
    data = [];
    response_detected = NaN;
    voltage = NaN;
    %errors.val = errors.val | 4;
    disp('No triggers found on NI. Aborting this run.');
    return;
end

%%%%%
%%%%% Chop/align the multiple stimulations from the TDT
%%%%%

if ~isempty(hardware.tdt)
%     if ~exist('tdata', 'var')
%         data = [];
%         response_detected = NaN;
%         voltage = NaN;
%         disp('No triggers found on NI. Aborting this run.');
%         return;
%     end
    [tdata_aligned, tdt_triggertime, n_repetitions_actual_tdt] = chop_and_align(tdata, ...
        tddata, ...
        tdt_TimeStamps, ...
        stim.n_repetitions, ...
        hardware.tdt.samplerate);
    %plot(axes2, tdt_TimeStamps - tdt_triggertime, tddata);
end

if n_repetitions_actual_tdt == 0
    data = [];
    response_detected = NaN;
    voltage = NaN;
    %errors.val = errors.val | 8;
    disp('No triggers found on TDT. Aborting this run.');
    return;
end


%%%%% Increment the version whenever adding anything to the savefile format!
data.version = 26;


data.bird = bird;
data.time = datenum(now);
data.comments = comments;
data.stim = stim;
data.stim.duration = 2 * stim.halftime_s + stim.interpulse_s;
data.goodtimes = [ 0.0002 + data.stim.duration ...
    -0.0003 + 1/stim.repetition_Hz ];
data.voltage = max(abs(voltage_range_last_stim));

data.ni.index_recording = hardware.ni.recording_channel_indices;
data.ni.stim = data_aligned(:, :, 1:2);
data.ni.response = data_aligned(:, :, data.ni.index_recording);
data.ni.show = 1:length(data.ni.index_recording); % For now, show everything that there is.
data.ni.n_repetitions = n_repetitions_actual;
data.ni.index_trigger = ni_trigger_index;
data.ni.stim_active = edata(:, ni_trigger_index); % version 15
d = diff(data.ni.stim_active);
stim_start_i = find(d > 0.5, 1) + 1;
stim_stop_i = find(d < -0.5, 1) + 1;

data.ni.stim_active_indices = stim_start_i:stim_stop_i;
data.ni.n_repetitions = n_repetitions_actual;
data.ni.times_aligned = event.TimeStamps(1:size(edata,1))' - triggertime;
data.ni.time = event.TimeStamps';
data.ni.recording_amplifier_gain = hardware.intan.gain;
data.ni.fs = obj.Rate;
data.ni.triggertime = triggertime;
for i=1:nchannels
	data.ni.labels{i} = obj.Channels(i).ID;
	data.ni.names{i} = obj.Channels(i).Name;
end
if ~isempty(data.ni.index_recording)
    tic;
    [ data.ni.response_detrended data.ni.response_trend data.detrend_param ] ...
        = detrend_response(data.ni, data, detrend_param);
    [ data.ni.spikes data.ni.spikes_r ] = look_for_spikes_xcorr(data.ni, data, [], []);
    fprintf('Time for detrending and detecting on NI: %s s\n', sigfig(toc, 2));
end

if ~isempty(hardware.tdt)
    data.tdt.response = tdata_aligned;
    data.tdt.index_recording = index_recording;
    % Whoops. 'show' should be indices into 'index_recording'...
    data.tdt.show = find(stim.tdt_show(index_recording));
    data.tdt.index_trigger = [];
    data.tdt.n_repetitions = n_repetitions_actual_tdt;
    data.tdt.time = tdt_TimeStamps;
    data.tdt.times_aligned = tdt_TimeStamps(1:size(tdata_aligned,2)) - tdt_triggertime;
    data.tdt.recording_amplifier_gain = 1;
    data.tdt.fs = hardware.tdt.samplerate;
    data.tdt.triggertime = triggertime;
    data.tdt.labels = hardware.tdt.channel_labels(index_recording);
    data.tdt.names = data.tdt.labels;
    data.tdt.stim_active = tddata;
    
    d = diff(data.tdt.stim_active);
    stim_start_i = find(d > 0.5, 1) + 1;
    stim_stop_i = find(d < -0.5, 1) + 1;
    %data.tdt.stim_active_indices = find(data.tdt.times_aligned >= 0 ...
    %    & data.tdt.times_aligned <= data.stim_duration_s);
    data.tdt.stim_active_indices = stim_start_i:stim_stop_i;

    if ~isempty(data.tdt.index_recording)
        [ data.tdt.response_detrended data.tdt.response_trend data.detrend_param ] ...
            = detrend_response(data.tdt, data, detrend_param);
        %[ data.tdt.spikes data.tdt.spikes_r ] = look_for_spikes_xcorr(data.tdt, data, [], []);
        [ data.tdt.spikes data.tdt.spikes_r ] = look_for_spikes_peaks(data.tdt, data, [], []);
    end
    
    %fprintf('Time for detrending and detecting on TDT: %s s\n', sigfig(toc, 2));
end

if isstruct(handlefigure)
    handles = handlefigure;
else
    handles = guihandles(handlefigure);
end




%% Look for current delivery error:
f = stim.target_current;
u = find(data.ni.times_aligned >= -0.00002 & data.ni.times_aligned < 0.00002 + data.stim.duration);
resample_times = data.ni.times_aligned(u);
resample_currents = zeros(size(resample_times));
ind = 1;
next_time = f(1,ind+1);
for i = 1:length(resample_times)
    while resample_times(i) >= next_time
        ind = ind+1;
        if ind < size(f, 2)
            next_time = f(1, ind+1);
        else
            next_time = Inf;
        end
        
    end
    resample_currents(i) = f(2,ind);
end
v = find(resample_times > -0.001 & resample_times < 0.001 + data.stim.duration);
meanstim = mean(data.ni.stim(:,:,2), 1);
current_frac = sum(abs(meanstim(1, u, 1))) / sum(abs(resample_currents(v)));
if current_frac < 0.5
    errors.val = errors.val | 2;
    errors.name{end+1} = sprintf('TERMINATE: Channel %d current delivered is only %s%% of target. Bad circuit!', ...
          stim.plexon_monitor_electrode, ...
          sigfig(current_frac*100, 2));
end





%% Look for voltage delivery error:
voltage = max(abs(voltage_range_last_stim));
if voltage > voltage_limit
    errors.val = errors.val | 1;
    errors.name{end+1} = sprintf('TERMINATE: Voltage over limit: %s V delivered.', sigfig(voltage, 2));
end




set(handles.baseline1, 'String', sprintf('%.2g', data.goodtimes(2)*1000));


if saving_stimulations
    
    data.filename = [ file_basename '_' datestr(data.time, file_format) '.mat' ];
    fullfilename = fullfile(datadir, data.filename);
    if ~exist(datadir, 'dir')
        mkdir(datadir);
    end

    save(fullfilename, 'data', '-v7.3');
end

response_detected = any(data.tdt.spikes);


