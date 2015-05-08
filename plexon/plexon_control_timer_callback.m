function plexon_control_timer_callback(obj, event, hObject, handles)


global CURRENT_uAMPS;
set(handles.currentcurrent, 'String', sprintf('%.2f', CURRENT_uAMPS));
CURRENT_uAMPS = min(handles.MAX_uAMPS, CURRENT_uAMPS * handles.change);



try

    box = 1;

    [nchan, err] = PS_GetNChannels(box);
    if err
        ME = MException('plexon:init', 'Plexon: invalid stimulator number "%d".', box);
    else
        disp(sprintf('Plexon device %d has %d channels.', box, nchan));
    end


    err = PS_SetTriggerMode(box, 0);
    if err
        ME = MException('plexon:stimulate', 'Could not set trigger mode on stimbox %d', box);
    end


    % Is this the easiest way to define this?  Use GUI soon.  Meanwhile, A is
    % amplitude, W is width, Delay is interphase delay.
    if handles.NEGFIRST
            StimParam.A1 = -handles.CURRENT_uAMPS;
            StimParam.A2 = handles.CURRENT_uAMPS;
    else
            StimParam.A1 = handles.CURRENT_uAMPS;
            StimParam.A2 = -handles.CURRENT_uAMPS;
    end
    StimParam.W1 = handles.HALF_TIME_uS;
    StimParam.W2 = handles.HALF_TIME_uS;
    StimParam.Delay = 0;

    channel = str2num(get(handles.String));
    % If no channel is selected, just fail silently and let the user figure
    % out what's going on :)
    if channel > 0 & channel <= nchan
        err = PS_SetMonitorChannel(box, channel);
        if err
            ME = MException('plexon:monitor', 'Could not set monitor channel to %d', channel);
            throw(ME);
        end
        err = PS_SetPatternType(box, channel, 0);
        if err
            ME = MException('plexon:pattern', 'Could not set pattern type on channel %d', channel);
            throw(ME);
        end


        err = PS_SetRectParam2(box, channel, StimParam);
        if err
            ME = MException('plexon:pattern', 'Could not set pattern parameters on channel %d', channel);
            throw(ME);
        else
            disp(sprintf('Pattern on channel %02d will be [ %d uA for %d usec, delay %d usec, %d uA for %d usec ].', ...
                channel, StimParam.A1, StimParam.W1, StimParam.Delay, StimParam.A2, StimParam.W2));
        end

        err = PS_SetRepetitions(1, channel, 1);
        if err
            ME = MException('plexon:pattern', 'Could not set repetition on channel %d', channel);
            throw(ME);
        end

        [v, err] = PS_IsWaveformBalanced(box, channel);
        if err
            ME = MException('plexon:stimulate', 'Bad parameter for stimbox %d channel %d', box, channel);
            throw(ME);
        end
        if ~v
            ME = MException('plexon:stimulate:unbalanced', 'Waveform is not balanced for stimbox %d channel %d', box, channel);
            throw(ME);
        end

        err = PS_LoadChannel(box, channel);
        if err
            ME = MException('plexon:stimulate', 'Could not stimulate on box %d channel %d: %s', box, channel, PS_GetExtendedErrorInfo(err));    
            throw(ME);
        end

        err = PS_StartStimChannel(box, channel);
        if err
            ME = MException('plexon:stimulate', 'Could not stimulate on box %d channel %d: %s', box, channel, PS_GetExtendedErrorInfo(err));    
            throw(ME);
        end

    end

catch ME
    disp(sprintf('Caught error %s (%s).  Shutting down...', ME.identifier, ME.message));
    err = PS_CloseAllStim;
    rethrow(ME);
end


guidata(hObject, handles);
