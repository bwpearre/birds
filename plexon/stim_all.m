clear;


err = PS_InitAllStim;
switch err
    case 1
        error('plexon:init', 'Plexon initialisation error: %s', PS_GetExtendedErrorInfo(err));
    case 2
        error('plexon:init', 'Plexon: no devices found.  Is this thing on?');
    otherwise
        disp('Initialised the Plexon box.');
end

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
    StimParam.A1 = 100;
    StimParam.A2 = -100;
    StimParam.W1 = 200;
    StimParam.W2 = 200;
    StimParam.Delay = 0;

    for channel = 1:nchan

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

        pause(0.01);
    end

catch ME
    disp(sprintf('Caught error %s (%s).  Shutting down...', ME.identifier, ME.message));
    err = PS_CloseAllStim;
    rethrow(ME);
end

err = PS_CloseAllStim;
if err
    error('plexon:shutdown', 'Plexon close error: %s', PS_GetExtendedErrorInfo(err));
end
