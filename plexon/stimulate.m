function [ data, response_detected, voltage, errors] = stimulate(stim, hardware, detrend_param, handles)

global currently_reconfiguring;
global scriptdir;
global monitor_struct;
global plexon_newly_initialised;

persistent last_stim;
persistent filenames;
tic

if currently_reconfiguring
    disp('Still reconfiguring the hardware... please wait (about 5 seconds, usually)...');
    pause(2);
    data = [];
    response_detected = [];
    voltage = [];
    errors = {};
    return;
end

set(handles.currentcurrent, 'String', sigfig(stim.current_uA, 3));
set(handles.halftime, 'String', sigfig(stim.halftime_s * 1e6, 3));

% Create new file for each electrode
% Store values for each electrode in cell of structs

if isempty(last_stim)
    same_per_electrode = zeros(size(stim.active_electrodes));
    same_waveform = same_per_electrode;
    same_shared = 0;
    same_monitor = 0;
    same_session = 0;
else
    %% Bypass same-as-last-time settings for faster reprogramming
    % The device was not reconfigured in the meantime:
    same_session = ~plexon_newly_initialised ...
        & stim.n_repetitions == last_stim.n_repetitions ...
        & stim.repetition_Hz == last_stim.repetition_Hz ...
        & stim.interpulse_s == last_stim.interpulse_s;
    
    % This electrode doesn't need updating: 
    same_per_electrode = same_session ...
        & stim.active_electrodes == last_stim.active_electrodes ...
        & stim.prepulse_us == last_stim.prepulse_us ...
        & stim.current_scale == last_stim.current_scale;
    
    %% The loaded waveform is still valid:
    same_waveform = same_session ...
        & same_per_electrode ...
        & stim.current_uA == last_stim.current_uA ...
        & stim.interpulse_s == last_stim.interpulse_s ...
        & stim.halftime_s == last_stim.halftime_s;
    
    %% Using the same monitor channel:
    same_monitor = same_session ...
        & stim.plexon_monitor_electrode == last_stim.plexon_monitor_electrode;
end

if ~same_session
    last_stim = {};
end

for i = 1:16
    if same_waveform(i)
        continue;
    end
    
    if stim.active_electrodes(i)
        % Put all required data into struct
        StimParams.A1 = stim.current_uA*stim.current_scale(i);
        StimParams.A2 = -stim.current_uA*stim.current_scale(i);
        StimParams.W1 = stim.halftime_s * 1e6;
        StimParams.W2 = stim.halftime_s * 1e6;
        StimParams.Delay = stim.interpulse_s * 1e6;
        StimParams.PreDelay = stim.prepulse_us(i);
    else
        % For safety, set unused to null pattern (should be unnecessary)
        StimParams.A1 = 0;
        StimParams.A2 = 0;
        StimParams.W1 = stim.halftime_s * 1e6;
        StimParams.W2 = stim.halftime_s * 1e6;
        StimParams.PreDelay = 0;
        StimParams.Delay = 0;
    end        
    
    % Create a file for each electrode
    filenames{i} = strcat(scriptdir, sprintf('/stimElectrode%0.2d.pat', i));
    
    plexon_write_rectangular_pulse_file(filenames{i}, StimParams);
end



% If no stim.plexon_monitor_electrode is selected, just fail silently and let the user figure
% out what's going on :)
if ~same_monitor
    disp(sprintf('Setting monitor channel to %d', stim.plexon_monitor_electrode));
    err = PS_SetMonitorChannel(hardware.plexon.id, stim.plexon_monitor_electrode);
    if err
        ME = MException('plexon:monitor', 'Could not set monitor channel to %d', stim.plexon_monitor_electrode);
        throw(ME);
    end
end




%% First time: Do the initial setup
if isempty(last_stim)
    for channel = 1:length(stim.active_electrodes)
        disp(sprintf('Setting pattern type for channel %d', channel));
        err = PS_SetPatternType(hardware.plexon.id, channel, 1);
        if err
            ME = MException('plexon:pattern', 'Could not set pattern type on channel %d', channel);
            throw(ME);
        end
    end
    
    disp('Setting trigger mode');
    switch hardware.stim_trigger
        case 'master8'
            err = PS_SetTriggerMode(hardware.plexon.id, 1);
        case 'arduino'
            err = PS_SetTriggerMode(hardware.plexon.id, 1);
        case 'ni'
            err = PS_SetTriggerMode(hardware.plexon.id, 1);
        case 'plexon'
            err = PS_SetTriggerMode(hardware.plexon.id, 0);
    end
    if err
        ME = MException('plexon:trigger', 'Could not set trigger mode on channel %d', channel);
        throw(ME);
    end
    
    newly_maybe_inactive_electrodes = ones(size(stim.active_electrodes));
else
    newly_maybe_inactive_electrodes = ~stim.active_electrodes & last_stim.active_electrodes;
end



%% Now update each channel for 'stim'
for channel = find(stim.active_electrodes | newly_maybe_inactive_electrodes)
    if ~same_waveform(channel)
        % Load patterns into Plexon system
        %disp(sprintf('Loading pattern on %d', channel));
        err = PS_LoadArbPattern(hardware.plexon.id, channel, filenames{channel});
        if err
            ME = MException('plexon:pattern', 'Could not set pattern parameters on channel %d, because %d (%s)', ...
                channel, err, PS_GetExtendedErrorInfo(err));
            throw(ME);
        end
    end
        
    
    if isempty(last_stim) ...
            | stim.n_repetitions ~= last_stim.n_repetitions ...
            | ~stim.active_electrodes(channel) == last_stim.active_electrodes(channel)
        disp(sprintf('Setting repetitions on %d to %d', channel, stim.n_repetitions));
        switch hardware.stim_trigger
            case 'master8'
                err = PS_SetRepetitions(hardware.plexon.id, channel, 1);
            case 'arduino'
                err = PS_SetRepetitions(hardware.plexon.id, channel, 1);
            case 'ni'
                err = PS_SetRepetitions(hardware.plexon.id, channel, stim.n_repetitions);
            case 'plexon'
                err = PS_SetRepetitions(hardware.plexon.id, channel, stim.n_repetitions);
            otherwise
                disp(sprintf('You must set a valid value for hardware.stim_trigger. ''%s'' is invalid.', hardware.stim_trigger));
        end
        if err
            ME = MException('plexon:pattern', 'Could not set repetitions on channel %d', channel);
            throw(ME);
        end
    end
    
    
    if isempty(last_stim) ...
            | stim.repetition_Hz ~= last_stim.repetition_Hz ...
            | ~stim.active_electrodes(channel) == last_stim.active_electrodes(channel)
        disp(sprintf('Setting train rate to %g', stim.repetition_Hz));
        err = PS_SetRate(hardware.plexon.id, channel, stim.repetition_Hz);
        if err
            ME = MException('plexon:pattern', 'Could not set repetition rate on channel %d', channel);
            throw(ME);
        end
    end
    

    if ~same_waveform(channel)
        %disp(sprintf('Loading %d', channel));
        [v, err] = PS_IsWaveformBalanced(hardware.plexon.id, channel);
        if err
            ME = MException('plexon:stimulate', 'Bad parameter for stimbox %d channel %d', hardware.plexon.id, channel);
            throw(ME);
        end
        if ~v
            ME = MException('plexon:stimulate:un_repetitionsnbalanced', 'Waveform is not balanced for stimbox %d channel %d', hardware.plexon.id, channel);
            throw(ME);
        end
    
        
        err = PS_LoadChannel(hardware.plexon.id, channel);
        if err
            ME = MException('plexon:stimulate', 'Could not stimulate on box %d channel %d: %s', hardware.plexon.id, channel, PS_GetExtendedErrorInfo(err));
            throw(ME);
        end
    end
end


if stim.active_electrodes(stim.plexon_monitor_electrode)
    np = PS_GetNPointsArbPattern(hardware.plexon.id, stim.plexon_monitor_electrode);
    target_current = [];
    target_current(1,:) = PS_GetArbPatternPointsX(hardware.plexon.id, stim.plexon_monitor_electrode)/1e6;
    target_current(2,:) = PS_GetArbPatternPointsY(hardware.plexon.id, stim.plexon_monitor_electrode)/1e3;
    target_current = [[-0.001; 0] [0; 0] target_current [target_current(1,end); 0] [target_current(1,end)+0.001; 0]];
else
    target_current = [0 0; 0 0];
end
    
plexon_newly_initialised = false;

if isfield(hardware, 'tdt') && ~isempty(hardware.tdt)
    try
        hardware.tdt.device.SetTagVal('mon_gain', round(hardware.tdt.audio_monitor_gain/5));
    catch ME
        disp('TDT stupid error 203495');
    end
end

switch hardware.stim_trigger
    case 'master8'
        [ event.Data, event.TimeStamps ] = hardware.ni.session.startForeground;
    case 'arduino'
        [ event.Data, event.TimeStamps ] = hardware.ni.session.startForeground;
    case 'ni'
        [ event.Data, event.TimeStamps ] = hardware.ni.session.startForeground;
    case 'plexon'
        hardware.ni.session.startBackground;
        err = PS_StartStimAllChannels(hardware.plexon.id);
        if err
            hardware.ni.session.stop;
            ME = MException('plexon:stimulate', 'Could not stimulate on box %d: %s', hardware.plexon.id, PS_GetExtendedErrorInfo(err));
            throw(ME);
        end
        hardware.ni.session.wait;  % This callback needs to be interruptible!  Apparently it is??
end

%plot(handles.axes4, event.TimeStamps, event.Data(:,4));

try
    if isfield(hardware, 'tdt') && ~isempty(hardware.tdt)
        hardware.tdt.device.SetTagVal('mon_gain', hardware.tdt.audio_monitor_gain);
    end
catch ME
    disp('Caught TDT-is-being-stupid error #2731. Moving on.');
end

stim.target_current = target_current;


[ data, response_detected, voltage, errors ] ...
    = organise_data(stim, hardware, detrend_param, hardware.ni.session, event, handles);

last_stim = stim;

disp(sprintf('stimulate: elapsed time is %s s', sigfig(toc)));

tic
plot_stimulation(data, handles);
disp(sprintf('plot_stimulation: elapsed time is %s s', sigfig(toc)));





% Write out a file that defines an arbitrary rectangular pulse for the
% Plexon. This gives sub-uA control, rather than the 1-uA control given by
% their default rectangular pulse interface.
function plexon_write_rectangular_pulse_file(filename, StimParam)

% Open file
fid = fopen(filename, 'w');
fprintf(fid, 'variable\n');

% Write pre-delay
if isfield(StimParam,'PreDelay')
    if StimParam.PreDelay > 0
        fprintf(fid, '%d\n%d\n', 0, round(StimParam.PreDelay));
    end
end

% Write first square
fprintf(fid, '%d\n%d\n', round(StimParam.A1*1000), round(StimParam.W1));

% Write delay
if StimParam.Delay
    fprintf(fid, '%d\n%d\n', 0, round(StimParam.Delay));
end

% Write second square
fprintf(fid, '%d\n%d\n', round(StimParam.A2*1000), round(StimParam.W2));

% Close file
fclose(fid);

