function plexon_control_timer_callback(obj, event, hObject, handles)

disp('%%%%%%%%%%%%%%%%%%%%% DISABLED %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%');

return;



global CURRENT_uAMPS;
global change;
global NEGFIRST;
global VOLTAGE_RANGE_LAST_STIM;

set(handles.currentcurrent, 'String', sprintf('%.2f', CURRENT_uAMPS));
CURRENT_uAMPS = min(handles.MAX_uAMPS, CURRENT_uAMPS * change);

if 0
    %% Emergency shutdown: move mouse out of window!
    oldUnits = get(0,'units');
    set(0,'units','pixels');
    % Get the figure beneath the mouse pointer & mouse pointer pos
    try
       fig = matlab.ui.internal.getPointerWindow;  % HG2: R2014b or newer
    catch
       fig = get(0,'PointerWindow');  % HG1: R2014a or older
    end
    p = get(0,'PointerLocation');
    set(0,'units',oldUnits);

    % Look for quick exit (if mouse pointer is not over any figure)
    if fig==0
        disp('Pausing stimulation until mouse returns to window...');
        return;
    end
end

try

    % Is this the easiest way to define this?  Use GUI soon.  Meanwhile, A is
    % amplitude, W is width, Delay is interphase delay.
    if NEGFIRST
            StimParam.A1 = -CURRENT_uAMPS;
            StimParam.A2 = CURRENT_uAMPS;
    else
            StimParam.A1 = CURRENT_uAMPS;
            StimParam.A2 = -CURRENT_uAMPS;
    end
    StimParam.W1 = handles.HALF_TIME_uS;
    StimParam.W2 = handles.HALF_TIME_uS;
    StimParam.Delay = 0;
    
    NullPattern.W1 = 0;
    NullPattern.W2 = 0;
    NullPattern.A1 = 0;
    NullPattern.A2 = 0;
    NullPattern.Delay = 0;

    which_valid_electrode = get(handles.monitor_electrode_control, 'Value');
    valid_electrode_strings = get(handles.monitor_electrode_control, 'String');
    channel = str2num(valid_electrode_strings{which_valid_electrode});
    % If no channel is selected, just fail silently and let the user figure
    % out what's going on :)
    if channel > 0 & channel <= 16
        err = PS_SetMonitorChannel(handles.box, channel);
        if err
            ME = MException('plexon:monitor', 'Could not set monitor channel to %d', channel);
            throw(ME);
        end
    end
    
    for channel = find(handles.stim)
        err = PS_SetPatternType(handles.box, channel, 0);
        if err
            ME = MException('plexon:pattern', 'Could not set pattern type on channel %d', channel);
            throw(ME);
        end

        err = PS_SetRectParam2(handles.box, channel, StimParam);
        if err
                ME = MException('plexon:pattern', 'Could not set pattern parameters on channel %d', channel);
                throw(ME);
        end
                

        err = PS_SetRepetitions(1, channel, 1);
        if err
            ME = MException('plexon:pattern', 'Could not set repetition on channel %d', channel);
            throw(ME);
        end

        [v, err] = PS_IsWaveformBalanced(handles.box, channel);
        if err
            ME = MException('plexon:stimulate', 'Bad parameter for stimbox %d channel %d', handles.box, channel);
            throw(ME);
        end
        if ~v
            ME = MException('plexon:stimulate:unbalanced', 'Waveform is not balanced for stimbox %d channel %d', handles.box, channel);
            throw(ME);
        end

        err = PS_LoadChannel(handles.box, channel);
        if err
            ME = MException('plexon:stimulate', 'Could not stimulate on box %d channel %d: %s', handles.box, channel, PS_GetExtendedErrorInfo(err));    
            throw(ME);
        end
    end
    
    % Start it!
    handles.NIsession.startBackground;
    err = PS_StartStimAllChannels(handles.box);
    if err
        handles.NIsession.stop;
        ME = MException('plexon:stimulate', 'Could not stimulate on box %d: %s', handles.box, PS_GetExtendedErrorInfo(err));
        throw(ME);
    end
    handles.NIsession.wait;  % This callback needs to be interruptible!  Apparently it is??
    if max(abs(VOLTAGE_RANGE_LAST_STIM)) > handles.VoltageLimit
        ME = MException('plexon:stimulate:brokenElectrode', 'Channel %d may be broken!!', channel);    
        throw(ME);
    end
    

catch ME
    errordlg(ME.message, 'Error', 'modal');
    disp(sprintf('Caught the error %s (%s).  Shutting down...', ME.identifier, ME.message));
    report = getReport(ME)
    PS_StopStimAllChannels(handles.box);
    handles.NIsession.stop;
    handles.running = false;
    guidata(hObject, handles);
    rethrow(ME);
end


guidata(hObject, handles);

