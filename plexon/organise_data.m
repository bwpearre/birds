% We got some data, through the NI and the TDT. Grab it, chop it up,
% reorganise it into the "data" structure.
function [ data response_detected voltage] = organise_data(stim, hardware, ...
    detrend_param, obj, event, handlefigure)

global saving_stimulations;
global bird;
global datadir;
global ni_trigger_index;
global ni_recording_channel_ranges;
global comments;
global recording_time;
global tdt_show;
global axes2;


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

    tdata = hardware.tdt.device.ReadTagVEX('Data', 0, curidx, 'F32', 'F64', 16)';
    tddata = hardware.tdt.device.ReadTagV('DData', 0, curidx2)';
    tdata = tdata(1:goodlength, :);
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
else
    tdata = [];
    tddata = [];
end

VOLTAGE_RANGE_LAST_STIM = [min(edata(:,1)) max(edata(:,1))];

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
    return;
end

%%%%%
%%%%% Chop/align the multiple stimulations from the TDT
%%%%%

if ~isempty(hardware.tdt)
    [tdata_aligned, tdt_triggertime, n_repetitions_actual_tdt] = chop_and_align(tdata, ...
        tddata, ...
        tdt_TimeStamps, ...
        stim.n_repetitions, ...
        hardware.tdt.samplerate);
    plot(axes2, tdt_TimeStamps - tdt_triggertime, tddata);
end

if n_repetitions_actual_tdt == 0
    disp('...no triggers on TDT; aborting this train...');
    return;
end

%%%%% Increment the version whenever adding anything to the savefile format!
data.version = 19;

data.repetition_Hz = repetition_Hz;
data.halftime_us = halftime_us;
data.interpulse_s = interpulse_s;
data.stim_duration = 2 * data.halftime_us / 1e6 + data.interpulse_s;
data.current = current_uAmps;
data.negativefirst = negfirst;
data.stim_electrodes = active_electrodes;
data.monitor_electrode = monitor_electrode;
data.comments = comments;
data.bird = bird;
data.detrend_param = detrend_param;
data.goodtimes = [ 0.0002 + data.stim_duration ...
    -0.0003 + 1/repetition_Hz ];

data.ni.index_recording = ni_recording_channel_indices;
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
data.ni.recording_amplifier_gain = intan_gain;
data.ni.fs = obj.Rate;
data.ni.triggertime = triggertime;
for i=1:nchannels
	data.ni.labels{i} = obj.Channels(i).ID;
	data.ni.names{i} = obj.Channels(i).Name;
end

if ~isempty(tdt)
    data.tdt.response = tdata_aligned;
    data.tdt.show = find(tdt_show);
    data.tdt.index_recording = 1:size(data.tdt.response, 3);
    data.tdt.index_trigger = [];
    data.tdt.n_repetitions = n_repetitions_actual_tdt;
    data.tdt.time = tdt_TimeStamps;
    data.tdt.times_aligned = tdt_TimeStamps(1:size(tdata_aligned,2)) - tdt_triggertime;
    data.tdt.recording_amplifier_gain = 1;
    data.tdt.fs = hardware.tdt_samplerate;
    data.tdt.triggertime = triggertime;
    for i=1:size(data.tdt.response, 3)
        data.tdt.labels{i} = sprintf('tdt %d', i);
        data.tdt.names{i} = sprintf('tdt %d', i);
    end
    data.tdt.stim_active = tddata;
    
    d = diff(data.tdt.stim_active);
    stim_start_i = find(d > 0.5, 1) + 1;
    stim_stop_i = find(d < -0.5, 1) + 1;
    %data.tdt.stim_active_indices = find(data.tdt.times_aligned >= 0 ...
    %    & data.tdt.times_aligned <= data.stim_duration);
    data.tdt.stim_active_indices = stim_start_i:stim_stop_i;
    
    [ data.tdt.response_detrended data.tdt.response_trend ] ...
        = detrend_response([], data.tdt, data, data.detrend_param);
    [ data.tdt.spikes data.tdt.spikes_r ] = look_for_spikes_xcorr(data.tdt, data, [], []);
end

handles = guihandles(handlefigure);
set(handles.baseline1, 'String', sprintf('%.2g', data.goodtimes(2)*1000));
plot_stimulation(data, handles);


if saving_stimulations
    datafile_name = [ file_basename '_' datestr(now, file_format) '.mat' ];
    if ~exist(datadir, 'dir')
        mkdir(datadir);
    end

    save(fullfile(datadir, datafile_name), 'data');
end

response_detected = any(data.tdt.spikes);
voltage = max(abs(VOLTAGE_RANGE_LAST_STIM));


