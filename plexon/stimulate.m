function [ data response_detected voltage ] = stimulate(stim, hardware, handles);

% stim = [ current_uA, halftime_us, interpulse_s, n_repetitions,
% repetition_Hz, active_electrodes, polarities ]

% hardware = [ NIsession, tdt, hardware.plexon_id, hardware.plexon_monitor_channel ]

global stim_trigger;
global currently_reconfiguring;
global scriptdir;
global VOLTAGE_RANGE_LAST_STIM;

if currently_reconfiguring
    disp('Still reconfiguring the hardware... please wait (about 3 seconds, usually)...');
    return;
end

set(handles.currentcurrent, 'String', sigfig(stim.current_uA, 2));
set(handles.halftime, 'String', sprintf('%.1f', stim.halftime_us));

       

% A is amplitude, W is width, Delay is interphase delay.

StimParamPos.A1 = stim.current_uA;
StimParamPos.A2 = -stim.current_uA;
StimParamPos.W1 = stim.halftime_us;
StimParamPos.W2 = stim.halftime_us;
StimParamPos.Delay = stim.interpulse_s * 1e6;

StimParamNeg.A1 = -stim.current_uA;
StimParamNeg.A2 = stim.current_uA;
StimParamNeg.W1 = stim.halftime_us;
StimParamNeg.W2 = stim.halftime_us;
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


try

    % If no hardware.plexon_monitor_channel is selected, just fail silently and let the user figure
    % out what's going on :)
    if hardware.plexon_monitor_channel > 0 & hardware.plexon_monitor_channel <= 16
        err = PS_SetMonitorChannel(hardware.plexon_id, hardware.plexon_monitor_channel);
        if err
            ME = MException('plexon:monitor', 'Could not set monitor channel to %d', hardware.plexon_monitor_channel);
            throw(ME);
        end
    end
    
    %disp('stimulating on channels:');
    %stim
    for channel = find(stim.active_channels)
        err = PS_SetPatternType(hardware.plexon_id, channel, 1);
        if err
            ME = MException('plexon:pattern', 'Could not set pattern type on channel %d', channel);
            throw(ME);
        end

        if negfirst(channel)
            err = PS_LoadArbPattern(hardware.plexon_id, channel, filenameNeg);
        else
            err = PS_LoadArbPattern(hardware.plexon_id, channel, filenamePos);
        end
        if err
            ME = MException('plexon:pattern', 'Could not set pattern parameters on channel %d, because %d (%s)', ...
                channel, err, PS_GetExtendedErrorInfo(err));
            throw(ME);
        end
 
        if arbitrary_pattern
            global axes3yy;
            np = PS_GetNPointsArbPattern(hardware.plexon_id, channel);
            pat = [];
            pat(1,:) = PS_GetArbPatternPointsX(hardware.plexon_id, channel);
            pat(2,:) = PS_GetArbPatternPointsY(hardware.plexon_id, channel);
            pat = [[0; 0] pat [pat(1,end); 0]]; % Add zeros for cleaner look
            if ~isempty(axes3yy) & isvalid(axes3yy)
                hold(axes3yy(2), 'on');
                plot(axes3yy(2), pat(1,:)/1e6, pat(2,:)/1e3, 'g');
                hold(axes3yy(2), 'off');
                legend(axes3, 'Voltage', 'Current', 'Next i');
            end
        end
        
        switch stim_trigger
            case 'master8'
                err = PS_SetRepetitions(hardware.plexon_id, channel, 1);
            case 'arduino'
                err = PS_SetRepetitions(hardware.plexon_id, channel, 1);
            case 'ni'
                err = PS_SetRepetitions(hardware.plexon_id, channel, stim.n_repetitions);
            case 'plexon'
                err = PS_SetRepetitions(hardware.plexon_id, channel, stim.n_repetitions);
            otherwise
                disp(sprintf('You must set a valid value for stim_trigger. ''%s'' is invalid.', stim_trigger));
        end       
        if err
            ME = MException('plexon:pattern', 'Could not set repetitions on channel %d', channel);
            throw(ME);
        end
        
        err = PS_SetRate(hardware.plexon_id, channel, repetition_Hz);
        if err
            ME = MException('plexon:pattern', 'Could not set repetition rate on channel %d', channel);
            throw(ME);
        end

        [v, err] = PS_IsWaveformBalanced(hardware.plexon_id, channel);
        if err
            ME = MException('plexon:stimulate', 'Bad parameter for stimbox %d channel %d', hardware.plexon_id, channel);
            throw(ME);
        end
        if ~v
            ME = MException('plexon:stimulate:unbalanced', 'Waveform is not balanced for stimbox %d channel %d', hardware.plexon_id, channel);
            throw(ME);
        end


        err = PS_LoadChannel(hardware.plexon_id, channel);
        if err
            ME = MException('plexon:stimulate', 'Could not stimulate on box %d channel %d: %s', hardware.plexon_id, channel, PS_GetExtendedErrorInfo(err));    
            throw(ME);
        end
    end
    
    switch stim_trigger
        case 'master8'
            err = PS_SetTriggerMode(hardware.plexon_id, 1);
        case 'arduino'
            err = PS_SetTriggerMode(hardware.plexon_id, 1);
        case 'ni'
            err = PS_SetTriggerMode(hardware.plexon_id, 1);
        case 'plexon'
            err = PS_SetTriggerMode(hardware.plexon_id, 0);
    end
    if err
        ME = MException('plexon:trigger', 'Could not set trigger mode on channel %d', channel);
        throw(ME);
    end
                
    
    if isfield(hardware, 'tdt') & ~isempty(hardware.tdt)
        hardware.tdt.SetTagVal('mon_gain', round(audio_monitor_gain/5));
    end
    

    switch stim_trigger
        case 'master8'
            hardware.NIsession.startForeground;
        case 'arduino'
            hardware.NIsession.startForeground;
        case 'ni'
            hardware.NIsession.startForeground;
        case 'plexon'
            hardware.NIsession.startBackground;
            err = PS_StartStimAllChannels(hardware.plexon_id);
            if err
                hardware.NIsession.stop;
                ME = MException('plexon:stimulate', 'Could not stimulate on box %d: %s', hardware.plexon_id, PS_GetExtendedErrorInfo(err));
                throw(ME);
            end
            hardware.NIsession.wait;  % This callback needs to be interruptible!  Apparently it is??
    end
    
    
    if isfield(hardware, 'tdt') & ~isempty(hardware.tdt)
        hardware.tdt.SetTagVal('mon_gain', audio_monitor_gain);
    end
    
    

catch ME
    
    errordlg(ME.message, 'Error', 'modal');
    disp(sprintf('Caught the error %s (%s).  Shutting down...', ME.identifier, ME.message));
    report = getReport(ME)
    rethrow(ME);
end

% guidata(hObject, handles) does no good here!!!
  guidata(hObject, handles);


