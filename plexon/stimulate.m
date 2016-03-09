function [ data, response_detected, voltage, errors] = stimulate(stim, hardware, detrend_param, handles)

global currently_reconfiguring;
global scriptdir;
global monitor_struct;


while currently_reconfiguring
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
filenames = cell(16,1);

for i = 1:16
    % Put all required data into struct
    StimParams.A1 = stim.current_uA*stim.electrode_stim_scaling(i);
    StimParams.A2 = -stim.current_uA*stim.electrode_stim_scaling(i);
    StimParams.W1 = stim.halftime_s * 1e6;
    StimParams.W2 = stim.halftime_s * 1e6;
    StimParams.Delay = stim.interpulse_s * 1e6;
    StimParams.PreDelay = stim.prepulse_s(i) * 1e6;
    
    % Create a file for each electrode
    filenames{i} = strrep(strcat(scriptdir, sprintf('/stimElectrode%0.2d.pat',i)), '/', filesep); % Not entirely sure what's going on with this line, or if I'm doing it right. 'filesep' does not seem to be defined
    
    plexon_write_rectangular_pulse_file(filenames{i},StimParams);
end

%
% %
% % % Remove once separate stim scaling is implemented
% %
%

% A is amplitude, W is width, Delay is interphase delay.

StimParamPos.A1 = stim.current_uA;
StimParamPos.A2 = -stim.current_uA;
StimParamPos.W1 = stim.halftime_s * 1e6;
StimParamPos.W2 = stim.halftime_s * 1e6;
StimParamPos.Delay = stim.interpulse_s * 1e6;

StimParamNeg.A1 = -stim.current_uA;
StimParamNeg.A2 = stim.current_uA;
StimParamNeg.W1 = stim.halftime_s * 1e6;
StimParamNeg.W2 = stim.halftime_s * 1e6;
StimParamNeg.Delay = stim.interpulse_s * 1e6;


NullPattern.W1 = 0;
NullPattern.W2 = 0;
NullPattern.A1 = 0;
NullPattern.A2 = 0;
NullPattern.Delay = 0;

filenamePos = strrep(strcat(scriptdir, '/stimPos.pat'), '/', filesep);
filenameNeg = strrep(strcat(scriptdir, '/stimNeg.pat'), '/', filesep);
plexon_write_rectangular_pulse_file(filenamePos, StimParamPos);
plexon_write_rectangular_pulse_file(filenameNeg, StimParamNeg);

%
% %
% % % End remove
% %
%

% If no stim.plexon_monitor_electrode is selected, just fail silently and let the user figure
% out what's going on :)
if stim.plexon_monitor_electrode > 0 & stim.plexon_monitor_electrode <= 16
    err = PS_SetMonitorChannel(hardware.plexon.id, stim.plexon_monitor_electrode);
    if err
        ME = MException('plexon:monitor', 'Could not set monitor channel to %d', stim.plexon_monitor_electrode);
        throw(ME);
    end
end

%disp('stimulating on channels:');
%stim
for channel = find(stim.active_electrodes)
    err = PS_SetPatternType(hardware.plexon.id, channel, 1);
    if err
        ME = MException('plexon:pattern', 'Could not set pattern type on channel %d', channel);
        throw(ME);
    end
    
    % Load patterns into Plexon system
    err = PS_LoadArbPattern(hardware.plexon.id, channel, filenames{channel});
    
%     if stim.negativefirst(channel)
%         err = PS_LoadArbPattern(hardware.plexon.id, channel, filenameNeg);
%     else
%         err = PS_LoadArbPattern(hardware.plexon.id, channel, filenamePos);
%     end
    if err
        ME = MException('plexon:pattern', 'Could not set pattern parameters on channel %d, because %d (%s)', ...
            channel, err, PS_GetExtendedErrorInfo(err));
        throw(ME);
    end
    
    if channel == stim.plexon_monitor_electrode
        np = PS_GetNPointsArbPattern(hardware.plexon.id, channel);
        target_current = [];
        target_current(1,:) = PS_GetArbPatternPointsX(hardware.plexon.id, channel)/1e6;
        target_current(2,:) = PS_GetArbPatternPointsY(hardware.plexon.id, channel)/1e3;
        target_current = [[-0.001; 0] [0; 0] target_current [target_current(1,end); 0] [target_current(1,end)+0.001; 0]]; % Add zeros for cleaner look
    end
    
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
    
    err = PS_SetRate(hardware.plexon.id, channel, stim.repetition_Hz);
    if err
        ME = MException('plexon:pattern', 'Could not set repetition rate on channel %d', channel);
        throw(ME);
    end
    
    [v, err] = PS_IsWaveformBalanced(hardware.plexon.id, channel);
    if err
        ME = MException('plexon:stimulate', 'Bad parameter for stimbox %d channel %d', hardware.plexon.id, channel);
        throw(ME);
    end
    if ~v
        ME = MException('plexon:stimulate:unbalanced', 'Waveform is not balanced for stimbox %d channel %d', hardware.plexon.id, channel);
        throw(ME);
    end
    
    
    err = PS_LoadChannel(hardware.plexon.id, channel);
    if err
        ME = MException('plexon:stimulate', 'Could not stimulate on box %d channel %d: %s', hardware.plexon.id, channel, PS_GetExtendedErrorInfo(err));
        throw(ME);
    end
end

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



plot_stimulation(data, handles);






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