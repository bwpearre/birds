function varargout = plexme(varargin)
% PLEXME MATLAB code for plexme.fig
%      PLEXME, by itself, creates a new PLEXME or raises the existing
%      singleton*.
%
%      H = PLEXME returns the handle to a new PLEXME or the handle to
%      the existing singleton*.
%
%      PLEXME('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in PLEXME.M with the given input arguments.
%
%      PLEXME('Property','Value',...) creates a new PLEXME or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before plexme_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to plexme_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help plexme

% Last Modified by GUIDE v2.5 15-Sep-2016 16:24:58

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @plexme_OpeningFcn, ...
                   'gui_OutputFcn',  @plexme_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT






% --- Executes just before plexme is made visible.
function plexme_OpeningFcn(hObject, ~, handles, varargin)

global scriptdir;
scriptdir = fileparts(mfilename('fullpath'));

libdirs = {'/tdt/lib64', ...
    'C:\opt\PlexonSDKs\MATLAB SDK for PlexStim 2.0 - 64 bit'};



% Choose default command line output for plexme
handles.output = hObject;

global bird;

global offsiteTest;
global in_stim_loop;

global hardware stim;
global safeParams;
global smoothnessParams;

global homedir data_basedir datadir intandir;
global change;
global axes1;
global axes1_yscale;
global axes2;
global axes3;
global axes4;
global vvsi;
global comments;
global electrode_last_stim;
% global max_current;
global default_halftime_s;
global increase_type;
global max_halftime;
global saving_stimulations;
global recording_amplifier_gain;
global ni_recording_channel_ranges;
global valid_electrodes; % which electrodes seem valid for stimulation?
global ni_response_channels;
global currently_reconfiguring;
global start_uAmps min_uAmps max_uAmps increase_step;
global inter_trial_s;
global disable_safety_checks;

% Offsite testing? (Cannot use the DAQ boards or other hardware)
offsiteTest = false;

currently_reconfiguring = true;

in_stim_loop = false;

max_uAmps = 100;
min_uAmps = 0.05;
increase_step = 1.1;
start_uAmps = 15;
stim.current_uA = start_uAmps;
inter_trial_s = 0.01; % Additional time between sets; not really used.
hardware.plexon.id = 1;   % Assume (hardcode) 1 Plexon box
hardware.plexon.open = false;
change = increase_step;
smoothnessParams.ampStep = .1;
smoothnessParams.pauseStep = 50;
smoothnessParams.ampNumSteps = 10;
smoothnessParams.pauseNumSteps = 10;

stim.n_repetitions = 20;
stim.repetition_Hz = 27;


% NI control rubbish
hardware.ni.session = [];

valid_electrodes = ones(1, 16);
%valid_electrodes(12:15) = ones(1,4);
stim.active_electrodes = zeros(1, 16);

disable_safety_checks = false;

if ispc
    homedir = getenv('USERPROFILE');
else
    homedir = getenv('HOME');
end

% Who controls pulses?  Three functional paradigms, and one special case:
% ACQUISITION-INITIATED, EACH PULSE EXTERNALLY TRIGGERED:
%    "master8": trigger pulses or pulse trains using Master8 (and 3 pulse
%               generators).  Also, print out programming instructions for
%               Master8.
%    "arduino": trigger pulses or pulse trains with an arduino (not yet
%               implemented)
% ACQUISITION-INITIATED, FIRST PULSE IN TRAIN EXTERNALLY TRIGGERED,
% SUBSEQUENT PULSES INITIATED INTERNALLY BY STIMULATOR (Plexon):
%    "ni":      first pulse triggered by NI acquisition, probably sent to a
%               pulse generator so a baseline can be found before
%               stimulating; any subsequent pulses come from multipulse
%               sequences programmed into plexon.  That may make amplifier
%               blanking difficult to synchronise for more than a single pulse.
% SOFTWARE-INITIATED, ALL PULSES IN TRAIN INITIATED INTERNALLY BY STIMULATOR:
%    "plexon:   pulses come from Plexon--and cannot trigger amp blanking,
%               nor can acquisition begin before the Plexon stimulates.
%               Use this for external trigger.

hardware.stim_trigger = 'ni';


switch hardware.stim_trigger
    case 'master8'
        disp('Program the Master-8 thusly:');
        disp('           OFF, All, All, All, Enter         # reset all');
        disp('           TRIG, 1, Enter                    # channel 1 in trigger mode');
        disp('           DURA, 1, 1, Enter, 4, Enter       # duration of trigger pulse');
        disp('           TRAIN, 1, Enter                   # channel 1 in pulsetrain mode');
        disp(sprintf('           INTER, 1, %d, Enter, 3, Enter    # interpulse interval', 1e3/stim.repetition_Hz));
        disp(sprintf('           M, 1, %d, Enter, 0, Enter          # channel 1 train has m pulses', stim.n_repetitions));
    case 'arduino'
        disp('Arduino triggering is not yet supported.  TO DO: write code');
        disp('  to generate/upload/run Arduino pulse-train-generating code.');
        a(0);
    case 'ni'
        disp('Using NI to trigger first pulse.  Clock drift will kill amplifier blanking.');
    case { 'plexon' }
        disp('Using Plexon to generate pulse trains.  Amplifier blanking WON''T WORK.');
    case 'external'
        disp('Using an external trigger to initiate single pulses.');
        stim.n_repetitions = 1;
        set(handles.n_repetitions_box, 'Enable', 'off', 'String', sprintf('%d', stim.n_repetitions));
        set(handles.n_repetitions_hz_box, 'Enable', 'off');
    otherwise
        error('Invalid multipulse hardware.stim_trigger keyword');
end


bird = 'noname';

data_basedir = strcat(homedir, filesep, 'Data', filesep, 'plexon');
datadir = strcat(data_basedir, filesep, bird, '-', datestr(now, 'yyyy-mm-dd'));
increase_type = 'current'; % or 'time'
default_halftime_s = 200e-6;
stim.halftime_s = default_halftime_s;
stim.interpulse_s = 0;
stim.prepulse_us = zeros(1,16); % Number of microseconds that this electrode's pulse will be delayed
stim.current_scale = ones(1,16); % Factor to multiply current_uA with to get this electrode's stimulation current
stim.plexon_monitor_electrode = 1;
safeParams.max_current = 150; % Maximum (or negative of minimum) allowed current
safeParams.max_prepulse_us = 200; % Maximum allowed prepulse pause
electrode_last_stim = 0;
% max_current = 0 * ones(1, 16);
max_halftime = NaN * ones(1, 16);
hardware.intan.gain = 515;
recording_amplifier_gain = 1; % For display only!
saving_stimulations = true;
handles.TerminalConfig = {'SingleEndedNonReferenced'};
%handles.TerminalConfig = {'SingleEndedNonReferenced', 'SingleEndedNonReferenced', 'SingleEndedNonReferenced'};
%handles.TerminalConfig = {'SingleEnded', 'SingleEnded', 'SingleEnded'};
intandir = 'C:\Users\gardnerlab\Desktop\RHD2000interface_compiled_v1_5\';
ni_response_channels = [ 0 0 0 0 0 0 0 ];

%handles.TerminalConfig = 'SingleEnded';
vvsi = [];
comments = '';

ni_recording_channel_ranges = 2 * [ 1 1 1 1 1 1 1 1 ];

%% ROWS:
% (1) Pins on the Plexon
% (2) Pins on the Intan.
% (3) Pins on TDT ZIFclip if my guess about their value of "the connector" is right
handles.PIN_NAMES = [ 1  2  3  4  5  6  7  8  9  10  11  12  13  14  15  16 ; ...
                     19 18 17 16 15 14 13 12 20  21  22  23   8   9  10  11 ; ...
                     15 13 11  9  7  5  3  1 16  14  12  10   8   6   4   2];

%for i = 1:16
%    eval(sprintf('set(handles.negfirst%d, ''String'', ''%s'');', ...
%        i,...
%        sprintf('%d', handles.PIN_NAMES(3,i))));
%end

for i = 1:16
    handles.prepulse_us{i} = uicontrol('Style', 'edit', ...
        'String', '', ...
        'Tag', sprintf('%d', i), ...
        'Position', [588 764-22*(i-1) 40 20], ...
        'Callback',{@prepulse_us_Callback}, ...
        'Enable', 'off', ...
        'Visible', 'off');
end

offcolour = [0.9 0.9 1];
set(handles.halftime, 'BackgroundColor', offcolour);
set(handles.delaytime, 'BackgroundColor', offcolour);
set(handles.n_repetitions_box, 'BackgroundColor', offcolour);
set(handles.n_repetitions_hz_box, 'BackgroundColor', offcolour);
set(handles.apply_params, 'BackgroundColor', [1 0 0], 'Visible', 'off');

handles.disable_on_run = { handles.currentcurrent, ...
    handles.maxcurrent, handles.increasefactor, handles.halftime, handles.delaytime, ...
    handles.voltage_limit, ...
    handles.full_threshold_scan, handles.presets};

if ~strcmp(hardware.stim_trigger, 'external')
    handles.disable_on_run{end+1} = handles.n_repetitions_box;
    handles.disable_on_run{end+1} = handles.n_repetitions_hz_box;
end

for i = 1:16
    eval(sprintf('handles.disable_on_run{end+1} = handles.electrode%d;', i));
    eval(sprintf('handles.disable_on_run{end+1} = handles.stim%d;', i));
end
for i = 2:7
    eval(sprintf('handles.disable_on_run{end+1} = handles.hvc%d;', i));
end

handles.disable_on_reconfigure = { handles.increase handles.decrease handles.hold ...
    handles.full_threshold_scan handles.smoothness_scan};


axes1 = handles.axes1;
axes1_yscale = handles.yscale;
axes2 = handles.axes2;
axes4 = handles.axes4;
axes3 = handles.axes3;



demo = false;
if ispc
    demofile = 'c:/Users/gardnerlab/Data/plexon/lw95rhp-2015-08-05/stim_20150805_183907.299.mat';
else
    demofile = '/Volumes/Data/plexon/lw95rhp-2015-08-05/stim_20150805_183907.299.mat';
end
if demo
    offsiteTest = true;
    load(demofile);
    data = update_data_struct(data, [], handles);
    global detrend_param;
    detrend_param = data.detrend_param;
    devices = {};
    devices_perhaps = {'tdt', 'ni'};
    for i = devices_perhaps
        if isfield(data, i)
            devices(end+1) = i;
        end
    end
    set(handles.show_device, 'String', devices);

    plot_stimulation(data, handles);
end


set(hObject, 'CloseRequestFcn', {@gui_close_callback, handles});
if (~offsiteTest)
    for i = 1:length(libdirs)
        if ~exist(libdirs{i}, 'dir')
            error('The library directory "%s" does not exist.', libdirs{i});
        else
            addpath(libdirs{i});
        end
    end
    addpath(sprintf('%s/../lib', scriptdir));

    
    handles = configure_acquisition_devices(hObject, handles);
    
    if isfield(hardware, 'tdt')
        % This should not be in the TDT init code, as that may be called on
        % reconfiguration and this should only appear once.
        for i = 1:16
            eval(sprintf('handles.disable_on_run{end+1} = handles.tdt_valid_buttons{%d};', i));
        end
    end
else
    handles = configure_acquisition_devices_OFFSITE(hObject, handles);
end

if demo
    hardware = [];
end

% We don't need to know when there are no spikes.
warning('off', 'signal:findpeaks:largeMinPeakHeight');
warning('off', 'stats:gmdistribution:FailedToConverge');

presets_Callback(handles.presets, [], handles);

update_gui_values(hObject, handles);

guidata(hObject, handles);





function [handles] = configure_acquisition_devices_OFFSITE(hObject, handles);
global hardware;

% TDT fake initializations
hardware.tdt.device = []; % Set empty so that parts of the code are skipped over






function [handles] = configure_acquisition_devices(hObject, handles);
global currently_reconfiguring;
global offsiteTest;

tic

currently_reconfiguring = true;


disp('Opening NI session...');
init_ni(hObject, handles);
disp('...done.');
disp('Opening TDT session...');
handles = init_tdt(hObject, handles);
disp('...done.');
disp('Opening Plexon session...');
init_plexon(hObject, handles);
disp('...done');

currently_reconfiguring = false;

guidata(hObject, handles);

disp(sprintf('Reconfiguring finished.  Elapsed time %s s.', sigfig(toc)));



function [] = init_plexon(hObject, handles)
global hardware;
global plexon_newly_initialised;
% Open the stimulator

PS_CloseAllStim;
if hardware.plexon.open
    hardware.plexon.open = false;
end

err = PS_InitAllStim;
switch err
    case 1
        msgbox({'Error: Could not open the Plexon box.', ' ', 'POSSIBLE CAUSES:', '* Device is not attached', '* Device is not turned on', '* Another program is using the device', ...
            '* Device needs rebooting', '', 'TO REBOOT:', '1. DISCONNECT THE BIRD!!!', '2. Power cycle', '3. Reconnect bird.'});
        error('plexon:init', 'Plexon initialisation error: %s', PS_GetExtendedErrorInfo(err));
    case 2
        msgbox({'Error: Could not open the Plexon box.', ' ', 'POSSIBLE CAUSES:', '* Device is not attached', '* Device is not turned on', '* Another program is using the device', ...
            '* Device needs rebooting', '', 'TO REBOOT:', '1. DISCONNECT THE BIRD!!!', '2. Power cycle', '3. Reconnect bird.'});
        error('plexon:init', 'Plexon: no devices available.  Is the blue box on?  Is other software accessing it?');
    otherwise
        hardware.plexon.open = true;
end


nstim = PS_GetNStim;
if nstim > 1
    err = PS_CloseAllStim;
    hardware.plexon.open = false;
    error('plexon:init', 'Plexon: %d devices available, but that dolt Ben assumed only 1!', nstim);
    return;
end


%    err = PS_SetDigitalOutputMode(hardware.plexon.id, 0); % Keep digital
%    out HIGH in interpulse BUT this seems to break everything...?!?!?!
%    if err
%        ME = MException('plexon:init', 'Plexon: digital output on "%d".', hardware.plexon.id);
%        throw(ME);
%    end

[nchan, err] = PS_GetNChannels(hardware.plexon.id);
if err
    ME = MException('plexon:init', 'Plexon: invalid stimulator number "%d".', hardware.plexon.id);
    throw(ME);
else
    disp(sprintf('Plexon show_device %d has %d channels.', hardware.plexon.id, nchan));
end
if nchan ~= 16
    ME = MException('plexon:init', 'Ben assumed that there would always be 16 channels, but there are in fact %d', nchan);
    throw(ME);
end


err = PS_SetTriggerMode(hardware.plexon.id, 0);
if err
    ME = MException('plexon:stimulate', 'Could not set trigger mode on stimbox %d', hardware.plexon.id);
    throw(ME);
end

plexon_newly_initialised = true;

guidata(hObject, handles);






function [handles] = init_ni(hObject, handles);

global hardware stim;
global ni_response_channels;
global ni_trigger_index;
global recording_time;


if ~isempty(hardware.ni.session)
    stop(hardware.ni.session);
    release(hardware.ni.session);
    hardware.ni.session = [];
end


%% Open NI acquisition board
dev='Dev1'; % location of input device
ni_plexon_monitor_channels = [0 1];
hardware.ni.recording_channel_indices = length(ni_plexon_monitor_channels)+1 : length(ni_plexon_monitor_channels) + length(find(ni_response_channels));
ni_channels = [ ni_plexon_monitor_channels find(ni_response_channels)]; % kludge; the latter pretends to be 0-indexed
channel_labels = {'Voltage', 'Current'}; % labels for INCHANNELS
for i = find(ni_response_channels)
    channel_labels{end+1} = sprintf('Response %d', i);
end
channel_labels{end+1} = 'Trigger';

hardware.ni.channel_labels = channel_labels;

% daq.reset;
hardware.ni.session = daq.createSession('ni');
hardware.ni.session.Rate = 100000;
hardware.ni.session.IsContinuous = 0;
recording_time = 1/stim.repetition_Hz * stim.n_repetitions + 0.05;
hardware.ni.session.DurationInSeconds = recording_time;
global ni_recording_channel_ranges;
% FIXME Add TTL-triggered acquisition?
%addTriggerConnection(hardware.ni.session,'External','Dev1/PFI0','StartTrigger');
% FIXME Slew rate


for i = 1:length(ni_channels)
    addAnalogInputChannel(hardware.ni.session, dev, sprintf('ai%d', ni_channels(i)), 'voltage');
    param_names = fieldnames(hardware.ni.session.Channels(i));
	hardware.ni.session.Channels(i).Name = channel_labels{i};
	%hardware.ni.session.Channels(i).Coupling = 'AC';
    hardware.ni.session.Channels(i).Range = [-1 1] * ni_recording_channel_ranges(i);
    if length(handles.TerminalConfig) == length(ni_channels)
        foo = i;
    else
        foo = 1;
    end
 	if any(strcmp(param_names,'TerminalConfig'))
 		hardware.ni.session.Channels(i).TerminalConfig = handles.TerminalConfig{foo};
 	elseif any(strcmp(param_names,'InputType'))
 		hardware.ni.session.Channels(i).InputType = handles.TerminalConfig{foo};
 	else
 		error('Could not set NiDaq input type');
    end
end

addDigitalChannel(hardware.ni.session, dev, 'Port0/Line0', 'InputOnly');
ni_trigger_index = size(hardware.ni.session.Channels, 2);
hardware.ni.session.Channels(ni_trigger_index).Name = channel_labels{ni_trigger_index};
nscans = round(hardware.ni.session.Rate * hardware.ni.session.DurationInSeconds);
tc = addTriggerConnection(hardware.ni.session, sprintf('%s/PFI0', dev), 'external', 'StartTrigger');

%ch = hardware.ni.session.addDigitalChannel(dev, 'Port0/Line1', 'OutputOnly');
%ch = hardware.ni.session.addCounterOutputChannel(dev, 'ctr0', 'PulseGeneration');
%disp(sprintf('Output trigger channel is ctr0 = %s', ch.Terminal));
%ch.Frequency = 0.1;
%ch.InitialDelay = 0;
%ch.DutyCycle = 0.01;

%pulseme = zeros(nscans, 1);
%pulseme(1:1000) = ones(1000, 1);
%hardware.ni.session.queueOutputData(pulseme);
if false
    % Generate a test signal for dac0 output
    global outputSignal;

    foo = addAnalogOutputChannel(hardware.ni.session, dev, 'ao0', 'Voltage');
    outputSignalLength = recording_time * hardware.ni.session.Rate;
    outputSignal = (sin((1:outputSignalLength)/(30*2*pi))') * 1e-3;
    outputSignal(end) = 0;
    hardware.ni.session.Channels(end).Range = [-1 1] * 5;
    queueOutputData(hardware.ni.session, outputSignal);
end

if isfield(hardware, 'ni') & isfield(hardware.ni, 'listeners')
    delete(hardware.ni.listeners{1});
end

% When stim_trigger is 'plexon', stimulate() uses startBackground, so we need
% the callback. Otherwise, we use startForeground().
switch hardware.stim_trigger 
    case { 'plexon', 'external' }
        hardware.ni.listeners{1} = addlistener(hardware.ni.session, 'DataAvailable',...
            @(obj,event) NIsession_callback(obj, event, handles));
        hardware.ni.session.NotifyWhenDataAvailableExceeds = nscans;
    case { 'master8', 'arduino', 'ni' }
        % No listener/callback
    otherwise
        disp(sprintf('You must set a valid value for hardware.stim_trigger. ''%s'' is invalid.', hardware.stim_trigger));
end

prepare(hardware.ni.session);






function [handles] = init_tdt(hObject, handles)
global hardware stim;
global scriptdir;
global recording_time;
global stim_timer;


if ~isfield(handles, 'tdt_valid_buttons')
    % If this is the first time, initialise stuff and create GUI elements.
    
    hardware.tdt.audio_monitor_gain = 200; % For TDT audio monitor output

    stim.tdt_valid = ones(1, 16);
    stim.tdt_show = ones(1, 16);

    for i = 1:16
        hardware.tdt.channel_labels{i} = sprintf('%d', i);
        handles.tdt_valid_buttons{i} = uicontrol('Style','checkbox','String', sprintf('%d', i), ...
            'Value',stim.tdt_valid(i),'Position', [750 764-22*(i-1) 50 20], ...
            'Callback',{@tdt_valid_channel_Callback});
        handles.tdt_show_buttons{i} = uicontrol('Style','checkbox','String', sprintf('%d', i), ...
            'Value',stim.tdt_show(i),'Position', [810 764-22*(i-1) 50 20], ...
            'Callback',{@tdt_show_channel_Callback});
    end
end



tdtprogram = strrep(strcat(scriptdir, '/TDT_triggered_recorder_m.rcx'), ...
    '/', ...
    filesep);

hardware.tdt.device = actxcontrol('RPco.X', [5 5 5 5]);
if ~hardware.tdt.device.ConnectRZ5('GB', 1)
    disp('Could not connect to RZ5');
    return;
end

if ~hardware.tdt.device.ClearCOF
    error('Can''t clear TDT');
end

if ~hardware.tdt.device.LoadCOFsf(tdtprogram, 2)
    error('Can''t load TDT program ''%s''', tdtprogram);
end
hardware.tdt.samplerate = hardware.tdt.device.GetSFreq;
hardware.tdt.nsamples = ceil(hardware.tdt.samplerate * recording_time) + 1;



if ~hardware.tdt.device.Run
    error('tdt:start', 'Can''t start TDT program.');
elseif ~hardware.tdt.device.SetTagVal('record_time', recording_time * 1e3)
    error('tdt:start', 'Can''t set TDT recording time');
elseif ~hardware.tdt.device.SetTagVal('down_time', recording_time * 1e3 / 100)
    error('tdt:start', 'Can''t set TDT schmitt down time');
%elseif ~hardware.tdt.device.SetTagVal('buffer_size', ceil(16 * hardware.tdt.nsamples * 1.1));
     %% The buffer size cannot be set.  It appears to work (returns success, and if you ask it the buffer size it tells you it's correct) but it only actually uses the amount that's hardcoded in their gui.
%    error('tdt:start', 'Can''t set TDT data buffer size to %d words', ...
%        ceil(16 * hardware.tdt.nsamples * 1.1));
%elseif ~hardware.tdt.device.SetTagVal('dbuffer_size', ceil(hardware.tdt.nsamples * 1.1))
%    error('tdt:start', 'Can''t set TDT digital buffer size.');
end

hardware.tdt.device.SetTagVal('mon_gain', round(hardware.tdt.audio_monitor_gain));
set(handles.audio_monitor_gain, 'String', sprintf('%d', round(hardware.tdt.device.GetTagVal('mon_gain'))));

%disp(sprintf('TDT buffer %d, need %d', tdt.GetTagVal('dbuffer_size'), hardware.tdt.nsamples));
tdt_dbuffer_size = hardware.tdt.device.GetTagVal('dbuffer_size');

if ceil(hardware.tdt.nsamples*1.1) > tdt_dbuffer_size
    if ~isempty(stim_timer)
        if isvalid(stim_timer)
            %if timer_running(stim_timer)
            disp('Stopping timer from tdt_configure...');
            stop(stim_timer); % this also stops and closes the Plexon box
            %end
        else
            disp('*** The timer was invalid!');
        end
    end
    
    uiwait(msgbox({'The TDT buffer is too small for your chosen recording duration.  Increase Averaging Hz or decrease Averaging Pulses.', ...
        '', sprintf('Maximum recording duration is %g s.', tdt_dbuffer_size/1.1/hardware.tdt.samplerate)}, 'modal'));
    
end




guidata(hObject, handles);









%% Called by NI data acquisition process at end of acquisition
function NIsession_callback(obj, event, handlefigure)
global stim hardware detrend_param;
disp('Called the callback...');
organise_data(stim, hardware, detrend_param, obj, event, handlefigure);






function tdt_valid_channel_Callback(hObject, eventData)
global stim;

handles = guidata(hObject);

foo = get(hObject, 'Value');
n = str2double(get(hObject, 'String'));
stim.tdt_valid(n) = foo;
stim.tdt_show(n) = foo;
if foo
    cow = 'on';
else
    cow = 'off';
end
set(handles.tdt_show_buttons{n}, 'Enable', cow, 'Value', foo);
guidata(hObject, handles);


function tdt_show_channel_Callback(hObject, eventData)
global stim;

stim.tdt_show(str2double(get(hObject, 'String'))) = get(hObject, 'Value');




function gui_close_callback(hObject, callbackdata, handles)
global hardware stim;
global vvsi;
global datadir;
global stim_timer;

disp('Shutting down...');

stop_everything(handles);

disp('Shutting down NI session...');
if isfield(hardware, 'ni') & ~isempty(hardware.ni.session)
    stop(hardware.ni.session);
    release(hardware.ni.session);
    hardware.ni.session = [];
end
disp('...done.');

disp('Shutting down Plexon session... NOT closing Plexon box!');
if isfield(hardware, 'plexon') & hardware.plexon.open & false
    err = PS_CloseAllStim;
    if err
        msgbox({'ERROR CLOSING STIMULATOR', 'Could not contact Plexon stimulator for shutdown!'});
    else
        hardware.plexon.open = false;
    end
end
disp('...done.');


if false
    file_format = 'yyyymmdd_HHMMSS.FFF';
    file_basename = 'vvsi';
    datafile_name = [ file_basename '_' datestr(now, file_format) '.mat' ];
    mkdir_p(datadir);
    
    save(fullfile(datadir, datafile_name), 'vvsi', '-v7.3');
end

disp('Shutting down TDT session...');
if isfield(hardware, 'tdt') & ~isempty(hardware.tdt.device)
    try
        hardware.tdt.device.Halt;
    catch
        disp('Caught TDT-is-stupid error #2589723. Moving on.');
    end
end
disp('...done.');

delete(hObject);


% UIWAIT makes plexme wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = plexme_OutputFcn(hObject, eventdata, handles) 
varargout{1} = handles.output;


function [ intan_pin] = map_plexon_pin_to_intan(plexon_pin, handles)
intan_pin = handles.PIN_NAMES(2, find(handles.PIN_NAMES(1,:) == plexon_pin));


function [ plexon_pin] = map_intan_pin_to_plexon(intan_pin, handles)
plexon_pin = handles.PIN_NAMES(1, find(handles.PIN_NAMES(2,:) == intan_pin));




function startcurrent_Callback(hObject, eventdata, handles)
global start_uAmps;
start_uAmps = str2double(get(hObject,'String'));


% --- Executes during object creation, after setting all properties.
function startcurrent_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function maxcurrent_Callback(hObject, eventdata, handles)
global max_uAmps;
max_uAmps = str2double(get(hObject,'String'));

% --- Executes during object creation, after setting all properties.
function maxcurrent_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end




function increasefactor_Callback(hObject, eventdata, handles)
global increase_step;
increase_step = str2double(get(hObject,'String'));

% --- Executes during object creation, after setting all properties.
function increasefactor_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function halftime_Callback(hObject, eventdata, handles)
set(hObject, 'BackgroundColor', [1 0 0]);
set(handles.apply_params, 'Visible', 'on');


function halftime_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function delaytime_Callback(hObject, eventdata, handles)
set(hObject, 'BackgroundColor', [1 0 0]);
set(handles.apply_params, 'Visible', 'on');



function delaytime_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function n_repetitions_box_Callback(hObject, eventdata, handles)
set(hObject, 'BackgroundColor', [1 0 0]);
set(handles.apply_params, 'Visible', 'on');


function n_repetitions_box_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function n_repetitions_hz_box_Callback(hObject, eventdata, handles)
set(hObject, 'BackgroundColor', [1 0 0]);
set(handles.apply_params, 'Visible', 'on');

% --- Executes during object creation, after setting all properties.
function n_repetitions_hz_box_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function apply_params_Callback(hObject, eventdata, handles)
global hardware stim;
global default_halftime_s;

for i = 1:length(handles.disable_on_reconfigure)
    set(handles.disable_on_reconfigure{i}, 'Enable', 'off');
end

default_halftime_s = str2double(get(handles.halftime, 'String')) / 1e6;
stim.halftime_s = default_halftime_s;
stim.interpulse_s = str2double(get(handles.delaytime, 'String'))/1e6;
stim.n_repetitions = str2double(get(handles.n_repetitions_box, 'String'));
stim.repetition_Hz = str2double(get(handles.n_repetitions_hz_box, 'String'));
if stim.repetition_Hz > 40
    stim.repetition_Hz = 40;
    set(hObject, 'String', sigfig(stim.repetition_Hz, 3));
end

offcolour = [0.9 0.9 1];
set(handles.halftime, 'BackgroundColor', offcolour);
set(handles.delaytime, 'BackgroundColor', offcolour);
set(handles.n_repetitions_box, 'BackgroundColor', offcolour);
set(handles.n_repetitions_hz_box, 'BackgroundColor', offcolour);
set(hObject, 'BackgroundColor', offcolour, 'Visible', 'off');

handles = configure_acquisition_devices(hObject, handles);

for i = 1:length(handles.disable_on_reconfigure)
    set(handles.disable_on_reconfigure{i}, 'Enable', 'on');
end

guidata(hObject, handles);






function electrode_universal_callback(hObject, eventdata, handles)
global valid_electrodes stim;

whichone = str2num(hObject.String);
value = get(hObject, 'Value');
valid_electrodes(whichone) = value;
if valid_electrodes(whichone)
        newstate = 'on';
else
        newstate = 'off';
end
% "stimulate this electrode" should be enabled or disabled according to the
% state of this button
stim.active_electrodes(whichone) = 0;
eval(sprintf('set(handles.stim%d, ''Enable'', ''%s'');', whichone, newstate));
eval(sprintf('set(handles.stimscale%d, ''Enable'', ''%s'', ''Visible'', ''%s'');', ...
    whichone, newstate, newstate));
% "stimulate this electrode" should default to 0...
eval(sprintf('set(handles.stim%d, ''Value'', 0);', whichone));
stim_scale_set(handles, 0, whichone);
update_monitor_electrodes(hObject, handles);
stim_scale_update_gui(handles);
prepulse_us_update_gui(handles);
guidata(hObject, handles);


% --- Executes on button press in electrode1.
function electrode1_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);

function electrode2_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);

function electrode3_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);

function electrode4_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);

function electrode5_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);

function electrode6_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);

function electrode7_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);

function electrode8_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);

function electrode9_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);

function electrode10_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);

function electrode11_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);

function electrode12_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);

function electrode13_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);

function electrode14_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);

function electrode15_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);

function electrode16_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);



% --- Executes on selection change in electrode.
function monitor_electrode_control_Callback(hObject, eventdata, handles)
global hardware stim;
which_valid_electrode = get(handles.monitor_electrode_control, 'Value');
valid_electrode_strings = get(handles.monitor_electrode_control, 'String');
stim.plexon_monitor_electrode = str2num(valid_electrode_strings{which_valid_electrode});

%handles.monitor_electrode = get(hObject, 'Value'); % Only works because all 16 are present! v(5)=5
update_monitor_electrodes(hObject, handles);
guidata(hObject, handles);

% --- Executes during object creation, after setting all properties.
function monitor_electrode_control_CreateFcn(hObject, eventdata, handles)
set(hObject, 'BackgroundColor', [0.8 0.2 0.1]);



function start_timer(hObject, handles)
global stim_timer inter_trial_s;

% Clean up any stopped timers
if isempty(stim_timer)
    stim_timer = timer('Period', inter_trial_s, 'ExecutionMode', 'fixedSpacing');
    stim_timer.TimerFcn = {@plexon_control_timer_callback_2, hObject, handles};
    stim_timer.StartFcn = {@plexon_start_timer_callback, hObject, handles};
    stim_timer.StopFcn = {@plexon_stop_timer_callback, hObject, handles};
    stim_timer.ErrorFcn = {@plexon_error_timer_callback, hObject, handles};
else
    stim_timer.Period = inter_trial_s;
end

if ~timer_running(stim_timer)
    disable_controls(hObject, handles);
    start(stim_timer);
end
guidata(hObject, handles);



% Stupid fucking matlab uses a string, not a boolean
function s = timer_running(t)
s = strcmp(t.running, 'on');

function ready = sufficient_active_electrodes
global stim
ready = true;

if ~(sum(stim.active_electrodes) > 0)
    disp('No active electrode selected');
    ready = false;
    return;
end

if stim.active_electrodes(stim.plexon_monitor_electrode) == 0
    disp('Monitoring electrode not active');
    ready = false;
    return;
end


function stim_loop(hObject, handles)
global stop_button_pressed;
global in_stim_loop;

if in_stim_loop
    disp('stim_loop: already in stim_loop.  Press "STOP" if necessary.');
    return;
end

if ~sufficient_active_electrodes
    disp('stim_loop: insufficient active electrodes.');
    return;
end

disable_controls(hObject, handles);

in_stim_loop = true;
plexon_start_timer_callback([], [], hObject, handles);

if stop_button_pressed
    disp('stim_loop: stop_button was pressed and not reset.');
end

while in_stim_loop & ~stop_button_pressed
    plexon_control_timer_callback_2([], [], hObject, handles)
end

stop_button_pressed = false;
in_stim_loop = false;
enable_controls(handles);


% --- Executes on button press in increase.
function increase_Callback(hObject, eventdata, handles)
global change;
global increase_type increase_step;
global stim;
global default_halftime_s;
global stop_button_pressed;

stop_button_pressed = false;

stim.halftime_s = default_halftime_s;
increase_type = 'current';
change = increase_step;
% start_timer(hObject, handles);
stim_loop(hObject, handles);

guidata(hObject, handles);


% --- Executes on button press in decrease.
function decrease_Callback(hObject, eventdata, handles)
global change increase_step;
global increase_type;
global stim;
global default_halftime_s;
global stop_button_pressed;

stop_button_pressed = false;

stim.halftime_s = default_halftime_s;
increase_type = 'current';
change = 1/increase_step;
% start_timer(hObject, handles);
stim_loop(hObject, handles);

guidata(hObject, handles);


% --- Executes on button press in hold.
function hold_Callback(hObject, eventdata, handles)
global change;
global increase_type;
global stim;
global default_halftime_s;
global stop_button_pressed;

stop_button_pressed = false;

stim.halftime_s = default_halftime_s;
increase_type = 'current';
change = 1;
% start_timer(hObject, handles);
stim_loop(hObject, handles);
% disp('Stim_loop done')


% --- Executes on button press in stop.
function stop_Callback(hObject, eventdata, handles)
global stop_button_pressed;

stop_button_pressed = true; % Used to abort long sequences...

stop_everything(handles);


function stop_everything(handles);
global thewaitbar;
global stop_button_pressed;
global in_stim_loop;
global paused;

if ~isempty(thewaitbar)
    delete(thewaitbar);
    thewaitbar = [];
end

%PS_StopStimAllChannels(hardware.plexon.id);

disp('Stopping everything...');

enable_controls(handles);

global paused;

if ~exist('paused', 'var')
    paused = false;
    set(handles.pause, 'BackgroundColor', [1 1 1]*0.94, 'String', 'Pause');
end

in_stim_loop = false;


function currentcurrent_Callback(hObject, eventdata, handles)
global stim;
global max_uAmps min_uAmps;

newcurrent = str2double(get(hObject, 'String'));
if isnan(newcurrent)
        set(hObject, 'String', sigfig(stim.current_uA, 3));
elseif newcurrent < min_uAmps
        stim.current_uA = min_uAmps;
elseif newcurrent > max_uAmps
        stim.current_uA = max_uAmps;
else
        stim.current_uA = newcurrent;
end
set(hObject, 'String', sigfig(stim.current_uA, 3));


% --- Executes during object creation, after setting all properties.
function currentcurrent_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function disable_controls(hObject, handles)

for i = 1:length(handles.disable_on_run)
    set(handles.disable_on_run{i}, 'Enable', 'off');
end



function enable_controls(handles);
global valid_electrodes;

for i = 1:length(handles.disable_on_run)
    set(handles.disable_on_run{i}, 'Enable', 'on');
end
% Yeah, but we don't want to enable all the "stim" checkboxes, but rather
% only the valid ones.  They get disabled with the rest of the
% interface on start-stim, and re-enabled on stop-stim, so now let's update
% them as a special case.
for i = 1:16
    if valid_electrodes(i)
            status = 'on';
    else
            status = 'off';
    end
    eval(sprintf('set(handles.stim%d, ''Enable'', ''%s'');', i, status));
end


% When any of the "start sequence" buttons is pressed, open the Plexon box
% and do some basic error checking.  Set all channels to nil.
function plexon_start_timer_callback(obj, event, hObject, handles)
global hardware stim;
global stim_timer;

save_globals;

%try
    NullPattern.W1 = 0;
    NullPattern.W2 = 0;
    NullPattern.A1 = 0;
    NullPattern.A2 = 0;
    NullPattern.Delay = 0;

    % Set up all non-stimulating channels to nil
    for channel = find(~stim.active_electrodes)
        % We will be using the rectangular pattern
        err = PS_SetPatternType(hardware.plexon.id, channel, 0);
        if err
            ME = MException('plexon:pattern', 'Could not set pattern type on channel %d', channel);
            throw(ME);
        end

        % Set these channels to nothing.
        err = PS_SetRectParam2(hardware.plexon.id, channel, NullPattern);
        if err
                ME = MException('plexon:pattern', 'Could not set NULL pattern parameters on channel %d', channel);
                throw(ME);
        end

        err = PS_SetRepetitions(hardware.plexon.id, channel, 1);
        if err
            ME = MException('plexon:pattern', 'Could not set repetition on channel %d', channel);
            throw(ME);
        end

        err = PS_LoadChannel(hardware.plexon.id, channel);
        if err
            ME = MException('plexon:stimulate', 'Could not stimulate on box %d channel %d: %s', hardware.plexon.id, channel, PS_GetExtendedErrorInfo(err));    
            throw(ME);
        end
    end
%catch ME
%    if timer_running(stim_timer)
%        stop(stim_timer);
%    end
%    disp(sprintf('Caught the error %s (%s).  Shutting down...', ME.identifier, ME.message));
%    report = getReport(ME)
%    PS_StopStimAllChannels(hardware.plexon.id);
%    guidata(hObject, handles);
%    rethrow(ME);
%end

guidata(hObject, handles);


function plexon_stop_timer_callback(obj, event, hObject, handles)
enable_controls(handles);
save_globals;

function plexon_error_timer_callback(obj, event, hObject, handles)
stop_everything(handles);
save_globals;

function stim_universal_callback(hObject, eventdata, handles)
global hardware stim;

whichone = str2num(hObject.String);
newval = get(hObject, 'Value');
stim.active_electrodes(whichone) = newval;

if stim.active_electrodes(whichone)
    stim.plexon_monitor_electrode = whichone;
    stim_scale_set(handles, 1, whichone);
    prepulse_us_set(handles, 0, whichone);
else
    stim_scale_set(handles, 0, whichone);
    prepulse_us_set(handles, 0, whichone);
end
update_monitor_electrodes(hObject, handles);
guidata(hObject, handles);



function update_monitor_electrodes(hObject, handles)
global stim;

changed = false;
if ~stim.active_electrodes(stim.plexon_monitor_electrode)
    stim.plexon_monitor_electrode = find(stim.active_electrodes, 1);
    if isempty(stim.plexon_monitor_electrode)
        stim.plexon_monitor_electrode = 1;
    end
    changed = true;
end
set(handles.monitor_electrode_control, 'Value', stim.plexon_monitor_electrode);
if stim.active_electrodes(stim.plexon_monitor_electrode)
    if changed
        set(handles.monitor_electrode_control, 'BackgroundColor', [1 1 0]);
    else
        set(handles.monitor_electrode_control, 'BackgroundColor', [0.1 0.8 0.1]);
    end
else
    set(handles.monitor_electrode_control, 'BackgroundColor', [0.8 0.2 0.1]);
end
drawnow;


% --- Executes on button press in stim1.
function stim1_Callback(hObject, eventdata, handles)
stim_universal_callback(hObject, eventdata, handles);

% --- Executes on button press in stim2.
function stim2_Callback(hObject, eventdata, handles)
stim_universal_callback(hObject, eventdata, handles);

% --- Executes on button press in stim3.
function stim3_Callback(hObject, eventdata, handles)
stim_universal_callback(hObject, eventdata, handles);

function stim4_Callback(hObject, eventdata, handles)
stim_universal_callback(hObject, eventdata, handles);

% --- Executes on button press in stim5.
function stim5_Callback(hObject, eventdata, handles)
stim_universal_callback(hObject, eventdata, handles);

% --- Executes on button press in stim6.
function stim6_Callback(hObject, eventdata, handles)
stim_universal_callback(hObject, eventdata, handles)

% --- Executes on button press in stim7.
function stim7_Callback(hObject, eventdata, handles)
stim_universal_callback(hObject, eventdata, handles)

% --- Executes on button press in stim8.
function stim8_Callback(hObject, eventdata, handles)
stim_universal_callback(hObject, eventdata, handles)

% --- Executes on button press in stim9.
function stim9_Callback(hObject, eventdata, handles)
stim_universal_callback(hObject, eventdata, handles)

% --- Executes on button press in stim10.
function stim10_Callback(hObject, eventdata, handles)
stim_universal_callback(hObject, eventdata, handles)

% --- Executes on button press in stim11.
function stim11_Callback(hObject, eventdata, handles)
stim_universal_callback(hObject, eventdata, handles)

% --- Executes on button press in stim15.
function stim15_Callback(hObject, eventdata, handles)
stim_universal_callback(hObject, eventdata, handles)

% --- Executes on button press in stim16.
function stim16_Callback(hObject, eventdata, handles)
stim_universal_callback(hObject, eventdata, handles)

% --- Executes on button press in stim14.
function stim14_Callback(hObject, eventdata, handles)
stim_universal_callback(hObject, eventdata, handles)

% --- Executes on button press in stim12.
function stim12_Callback(hObject, eventdata, handles)
stim_universal_callback(hObject, eventdata, handles)

% --- Executes on button press in stim13.
function stim13_Callback(hObject, eventdata, handles)
stim_universal_callback(hObject, eventdata, handles)

% --- Executes on button press in stim_all.
function select_all_valid_Callback(hObject, eventdata, handles)
global valid_electrodes stim;

for i = find(valid_electrodes)
    if ~stim.active_electrodes(i)
        stim.active_electrodes(i) = 1;
        eval(sprintf('set(handles.stim%d, ''Value'', 1);', i));
        stim_scale_set(handles, 1, i);
        prepulse_us_set(handles, 0, i);
    end
end
update_monitor_electrodes(hObject, handles);








function stim = safety_check(stim,safeParams)
% Check magnitude of current delivered
for i = 1:16
    stim.current_scale(i) = check_current_magnitude(stim.current_scale(i), stim.current_uA, safeParams);
    stim.current_scale(i) = check_pause_magnitude(stim.prepulse_us(i), safeParams);
end

function newPause = check_pause_magnitude(pause, safeParams)
newPause = pause;
if (newPause > safeParams.max_prepulse_us)
    % Pause is too high, bring it back down to max value
    newPause = safeParams.max_prepulse_us;
end

function newScale = check_current_magnitude(scale, current_uA, safeParams)
newScale = scale;
if (newScale*current_uA > safeParams.max_current)
    % Stim current is too high, bring it back down to max value
    newScale = safeParams.max_current/current_uA;
elseif (newScale*current_uA < -safeParams.max_current)
    % Stim current is too far negative, bring it back up to min value
    newScale = -safeParams.max_current/current_uA;
end

function plexon_control_timer_callback_2(obj, event, hObject, handles)
global hardware stim;
global safeParams;
global detrend_param;
global increase_type;
global max_uAmps min_uAmps;
global default_halftime_s;
% global max_current;
global max_halftime;
global change;
global voltage_range_last_stim;
global electrode_last_stim;
global stim_timer;

switch increase_type
    case 'current'
        stim.current_uA = min(max_uAmps, stim.current_uA * change);
        stim.current_uA = max(min_uAmps, stim.current_uA * change);
        set(handles.currentcurrent, 'String', sigfig(stim.current_uA, 3));
    case 'time'
        stim.halftime_s = min(default_halftime_s, stim.halftime_s * change);
        set(handles.halftime, 'String', sigfig(stim.halftime_s * 1e6, 3));
end
       


if false
    % Re-load output signal (for debugging; this must also be enabled where
    % the NI show_device is initialised)
    
    global outputSignal;
    queueOutputData(hardware.ni.session, outputSignal);
end

%stim = safety_check(stim, safeParams); % Check stimulation for being safe
[ data, response_detected, voltage ] = stimulate_wrapper(stim, hardware, detrend_param, handles);
if isempty(data)
    disp('timer callback: stimulate() did not capture any data.');
    return;
end


  




% --- Executes on button press in mark_all.
function mark_all_Callback(hObject, eventdata, handles)
global valid_electrodes;

valid_electrodes = ones(1, 16);
update_valid_checkboxes(hObject, handles);


function update_valid_checkboxes(hObject, handles)
global valid_electrodes;

for whichone = find(valid_electrodes)
    newstate = 'on';
    % "stimulate this electrode" should be enabled or disabled according to the
    % state of this button
    eval(sprintf('set(handles.electrode%d, ''Value'', 1);', whichone));
    eval(sprintf('set(handles.stim%d, ''Enable'', ''%s'');', whichone, newstate));
    %eval(sprintf('set(handles.negfirst%d, ''Enable'', ''%s'');', whichone, newstate));
end
update_monitor_electrodes(hObject, handles);

guidata(hObject, handles);




% --- Executes on button press in saving.
function saving_Callback(hObject, eventdata, handles)
global saving_stimulations;
saving_stimulations = get(hObject, 'Value');



function birdname_Callback(hObject, eventdata, handles)
global scriptdir data_basedir datadir;
global bird;

bird = get(hObject,'String');
datadir = strcat(data_basedir, filesep, bird, '-', datestr(now, 'yyyy-mm-dd'));
mkdir_p(datadir);
set(handles.datadir_box, 'String', datadir);

set(hObject, 'BackgroundColor', [0 0.8 0]);


function birdname_CreateFcn(hObject, eventdata, handles)
set(hObject, 'String', 'noname');
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function comments_Callback(hObject, eventdata, handles)
global comments;

comments = get(hObject, 'String');


% --- Executes during object creation, after setting all properties.
function comments_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes on slider movement. DUPLICATED in inspect.m
function xscale_Callback(hObject, eventdata, handles)
axes2_tracks_axes1 = false; % kludge
last_xlim = get(handles.axes1, 'XLim');
set(handles.axes1, 'XLim', get(handles.xscale, 'Value') * [-4 30]);
if axes2_tracks_axes1
    set(handles.axes2, 'XLim', get(handles.xscale, 'Value') * [-4 30]);
end
new_xlim = get(handles.axes1, 'XLim');


% --- Executes on slider movement. DUPLICATED in inspect.m
function yscale_Callback(hObject, eventdata, handles)
%set(handles.axes1, 'YLim', (2^(get(handles.yscale, 'Value')))*[-0.3 0.3]/1e3);
set(handles.axes1, 'YLim', (2^(get(handles.yscale, 'Value')))*[-1 1]*1e3*0.3);
%plot_stimulation([], handles, 1);


% --- Executes during object creation, after setting all properties.
function yscale_CreateFcn(hObject, eventdata, handles)
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


function response_show_avg_Callback(hObject, eventdata, handles)
if get(hObject, 'Value')
    set(handles.response_show_all, 'Value', 0);
end
plot_stimulation([], handles, true);

function response_show_all_Callback(hObject, eventdata, handles)
if get(hObject, 'Value')
    set(handles.response_show_avg, 'Value', 0);
end
plot_stimulation([], handles, true);

function response_show_raw_Callback(hObject, eventdata, handles)
plot_stimulation([], handles, true);

function response_show_trend_Callback(hObject, eventdata, handles)
plot_stimulation([], handles, true);

function response_show_detrended_Callback(hObject, eventdata, handles)
plot_stimulation([], handles, true);

function response_filter_Callback(hObject, eventdata, handles)
plot_stimulation([], handles, true);




% --- Executes on button press in load_impedances.
function load_impedances_Callback(hObject, eventdata, handles)
global intandir;
global datadir;
global impedances_x;
global valid_electrodes;
global bird;


mkdir_p(datadir);

%% Try to grab any Intan impedance files that may be
%% lying about... if they were created within the last 30 minutes.
intanfilespec = strcat(intandir, '*.csv')
csvs = dir(intanfilespec);
for i = 1:length(csvs)
    % datenum's unit is days, so 1/48 of a day is 30 minutes
    if datenum(now) - csvs(i).datenum <= 1/48
        %disp('Warning: copying x.csv, not moving it as god intended');
        copyfile(strcat(intandir, csvs(i).name), strcat(datadir, filesep, 'impedances-', csvs(i).name));
        disp(sprintf('Copied %s to %s', ...
            strcat(intandir, csvs(i).name), ...
            strcat(datadir, filesep, 'impedances-', csvs(i).name)));
    end
end

%% Also copy any RECENT (half hour) recordings named 'bird*.rhd' into the data dir
intanfilespec = strcat(intandir, bird, '*.rhd')
csvs = dir(intanfilespec);
for i = 1:length(csvs)
    % datenum's unit is days, so 1/48 of a day is 30 minutes
    if datenum(now) - csvs(i).datenum <= 1/48
        %disp('Warning: copying x.csv, not moving it as god intended');
        copyfile(strcat(intandir, csvs(i).name), strcat(datadir, filesep, 'intan-recordings-', csvs(i).name));
        disp(sprintf('Copied %s to %s', ...
            strcat(intandir, csvs(i).name), ...
            strcat(datadir, filesep, 'intan-recordings-', csvs(i).name)));
    end
end
if exist(strcat(intandir, 'plexon-compatible.isf'), 'file')
    copyfile(strcat(intandir, 'plexon-compatible.isf'), datadir);
end

%% If the Area X file exists, display its contents:
if exist(strcat(datadir, filesep, 'impedances-x.csv'), 'file')
    fid = fopen(strcat(datadir, filesep, 'impedances-x.csv'));
    a = textscan(fid, '%s', 8, 'Delimiter', ',');
    b = textscan(fid, '%s%s%s%d%f%f%f%f', 'Delimiter', ',');
    fclose(fid);
    
    impedances_x = NaN * ones(1, 16);
    
    c = char(b{2});
    for i = find(b{4})'
        if ~strcmp(c(i,1:7), 'plexon-')
            disp(sprintf('Warning: active channel name ''%s'' is not ''plexon-xx''', c(i,:)));
            continue;
        end
        pchan = str2double(c(i,8:end));
        impedances_x(pchan) = b{5}(i);
        h = eval(sprintf('handles.maxi%d', pchan));
        set(h, 'String', sprintf('%g', impedances_x(pchan)/1e6));
        valid_electrodes(pchan) = impedances_x(pchan)/1e6 >= 0.1 & impedances_x(pchan)/1e6 <= 5;
    end
    
    update_valid_checkboxes(handles.mark_all, handles);
end


guidata(hObject, handles);


    
function stimscale_reset_all_Callback(hObject, eventdata, handles)
stim_scale_set(handles, ones(1,16));


function stimscaling_universal_callback(hObject, handles)
global stim safeParams;
% Go through each electrode and check value (allows function to be called
% anywhere, not just as a callback)

n = get(hObject, 'Tag');
i = str2double(n(10:end));

newVal = str2double(get(hObject, 'String'));
   
% Make sure it's a number
if isnan(newVal)
    % If it is not a number, replace the editbox's contents with its old
    % value (taken from stim.current_scale)
    newVal = stim.current_scale(i);
end
   
stim_scale_set(handles, newVal, i);


% I could set the callback in each of the GUI elements to
% *_universal_callback, but all that clicking in guide would kill me.  I
% could do it programmatically (at the risk of confusing guide in the
% future), but apparently writing this comment is marginally easier...
function stimscale1_Callback(hObject, eventdata, handles)
stimscaling_universal_callback(hObject, handles)

function stimscale2_Callback(hObject, eventdata, handles)
stimscaling_universal_callback(hObject, handles)

function stimscale3_Callback(hObject, eventdata, handles)
stimscaling_universal_callback(hObject, handles)

function stimscale4_Callback(hObject, eventdata, handles)
stimscaling_universal_callback(hObject, handles)

function stimscale5_Callback(hObject, eventdata, handles)
stimscaling_universal_callback(hObject, handles)

function stimscale6_Callback(hObject, eventdata, handles)
stimscaling_universal_callback(hObject, handles)

function stimscale7_Callback(hObject, eventdata, handles)
stimscaling_universal_callback(hObject, handles)

function stimscale8_Callback(hObject, eventdata, handles)
stimscaling_universal_callback(hObject, handles)

function stimscale9_Callback(hObject, eventdata, handles)
stimscaling_universal_callback(hObject, handles)

function stimscale10_Callback(hObject, eventdata, handles)
stimscaling_universal_callback(hObject, handles)

function stimscale11_Callback(hObject, eventdata, handles)
stimscaling_universal_callback(hObject, handles)

function stimscale12_Callback(hObject, eventdata, handles)
stimscaling_universal_callback(hObject, handles)

function stimscale13_Callback(hObject, eventdata, handles)
stimscaling_universal_callback(hObject, handles)

function stimscale14_Callback(hObject, eventdata, handles)
stimscaling_universal_callback(hObject, handles)

function stimscale15_Callback(hObject, eventdata, handles)
stimscaling_universal_callback(hObject, handles)

function stimscale16_Callback(hObject, eventdata, handles)
stimscaling_universal_callback(hObject, handles)




function debug_Callback(hObject, eventdata, handles)
globalVars = who('global');
for iVar = 1:numel(globalVars)
  eval(sprintf('global %s', globalVars{iVar}));  % [EDITED]
end
disp('Made all vars global.  Not throwing an error.  Edit plexme.m if you want that.');



%% Controls which NI channels are used for recording.
function hvc_Callback(hObject, eventdata, handles)
global ni_response_channels;

% There's an offset here, but that's okay because we are reserving
% channels 0 and 1 for Plexon self-monitoring, so we never need 0.
whichone = str2double(get(hObject, 'String'));
ni_response_channels(whichone) = get(hObject, 'Value');

handles = configure_acquisition_devices(hObject, handles);
guidata(hObject, handles);





function tdt_monitor_channel_Callback(hObject, eventdata, handles)
global hardware stim;
hardware.tdt.audio_monitor_channel = get(hObject, 'Value');
if ~hardware.tdt.device.SetTagVal('mon_channel', hardware.tdt.audio_monitor_channel)
    disp(sprintf('Can''t change TDT audio monitor'));
end


function tdt_monitor_channel_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function audio_monitor_gain_Callback(hObject, eventdata, handles)
global hardware stim;
hardware.tdt.audio_monitor_gain = round(str2double(get(hObject, 'String')));

if ~hardware.tdt.device.SetTagVal('mon_gain', hardware.tdt.audio_monitor_gain)
    disp(sprintf('Can''t change TDT audio monitor gain'));
end



function audio_monitor_gain_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function tdt_valid_Callback(hObject, eventdata, handles)
global stim;

persistent last_valid_state last_show_state;
if ~exist('last_valid_state', 'var') | isempty(last_valid_state)
    last_valid_state = stim.tdt_valid;
    last_show_state = stim.tdt_show;
end

if all(stim.tdt_valid)
    % If all on --> all off
    stim.tdt_valid = zeros(1, 16);
    stim.tdt_show = zeros(1, 16); % can't show these if invalid
elseif ~any(stim.tdt_valid)
    % if all off --> last remembered
    stim.tdt_valid = last_valid_state;
    stim.tdt_show = last_show_state;
else
    % if some mix --> (1) save state, (2) all on
    last_valid_state = stim.tdt_valid;
    last_show_state = stim.tdt_show;

    stim.tdt_valid = ones(1, 16);
end

% Update checkboxes
for i = 1:16
    if stim.tdt_valid(i)
        foo = 'on';
    else
        foo = 'off';
    end
    set(handles.tdt_valid_buttons{i}, 'Value', stim.tdt_valid(i));
    set(handles.tdt_show_buttons{i}, 'Value', stim.tdt_show(i), 'Enable', foo);
end
guidata(hObject, handles);



function tdt_show_all_Callback(hObject, eventdata, handles)
global stim;

persistent last_show_state;
if ~exist('last_show_state', 'var') | isempty(last_show_state)
    last_show_state = stim.tdt_show;
end

if all(stim.tdt_show(find(stim.tdt_valid))) 
    % If all valid ones are on --> all off
    stim.tdt_show = zeros(1, 16); % can't show these if invalid
elseif ~any(stim.tdt_show)
    % if all off --> last remembered
    stim.tdt_show = last_show_state & stim.tdt_valid;
else
    % if some mix --> (1) save state, (2) all on
    last_show_state = stim.tdt_show;

    stim.tdt_show = stim.tdt_valid;
end

% Update checkboxes
for i = 1:16
    if stim.tdt_valid(i)
        foo = 'on';
    else
        foo = 'off';
    end
    set(handles.tdt_valid_buttons{i}, 'Value', stim.tdt_valid(i));
    set(handles.tdt_show_buttons{i}, 'Value', stim.tdt_show(i), 'Enable', foo);
end

guidata(hObject, handles);



function show_device_Callback(hObject, eventdata, handles)
global show_device;
foo = cellstr(get(hObject, 'String'));
show_device = foo{get(hObject, 'Value')};


function show_device_CreateFcn(hObject, eventdata, handles)
global show_device;

set(hObject, 'String', {'TDT', 'NI'});
foo = cellstr(get(hObject, 'String'));
show_device = foo{get(hObject, 'Value')};

if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function [] = save_globals;
[save_vars savename] = get_save_vars();

for i = save_vars
    eval(sprintf('global %s;', char(i)));
    eval(sprintf('saved.%s = %s;', char(i), char(i)));
end

save(savename, 'saved', '-v7.3');



function restore_globals_Callback(hObject, eventdata, handles)
[save_vars savename] = get_save_vars();
global data_basedir datadir scriptdir;

load(savename);

for i = save_vars
    j = char(i);
    %disp(sprintf('restoring %s', j));
    eval(sprintf('global %s;', j));
    eval(sprintf('%s = saved.%s;', j, j));
end
datadir = strcat(data_basedir, filesep, bird, '-', datestr(now, 'yyyy-mm-dd'));
update_gui_values(hObject, handles);
handles = configure_acquisition_devices(hObject, handles);

guidata(hObject, handles);




function [save_vars savename] = get_save_vars();
global scriptdir;
save_vars = {'stim', 'bird', 'comments', ...
    'increase_step', ...
    'max_uAmps', 'min_uAmps', ...
    'show_device', ...
    'start_uAmps', 'valid_electrodes', ...
    'ni_response_channels', 'voltage_limit', ...
    'detrend_param'};
% Which ones are in the list but don't have GUI elements (yet?)?
unused = {'min_uAmps', ...
     'show_device'};
savename = strcat(scriptdir, '/saved.mat');







function update_gui_values(hObject, handles);
global hardware;
global data_basedir;

save_vars = get_save_vars(); % Just for the list of variables.  Does not affect values.

for i = save_vars
    eval(sprintf('global %s;', char(i)));
end


%%%%% Initialise some elements %%%%%
set(handles.select_all_valid, 'Enable', 'on');
newvals = {};
for i = 1:16
    newvals{end+1} = sprintf('%d', i);
end
set(handles.monitor_electrode_control, 'String', newvals);
set(handles.tdt_monitor_channel, 'String', newvals);
datadir = strcat(data_basedir, filesep, bird, '-', datestr(now, 'yyyy-mm-dd'));


%%%%% From save_vars %%%%%

set(handles.datadir_box, 'String', datadir);
set(handles.startcurrent, 'String', sprintf('%d', round(start_uAmps)));
set(handles.currentcurrent, 'String', sigfig(stim.current_uA, 3));
set(handles.maxcurrent, 'String', sprintf('%d', round(max_uAmps)));
set(handles.increasefactor, 'String', sprintf('%g', increase_step));
set(handles.halftime, 'String', sigfig(stim.halftime_s*1e6, 3));
set(handles.delaytime, 'String', sigfig(stim.interpulse_s*1e6, 3));
set(handles.n_repetitions_box, 'String', sprintf('%d', stim.n_repetitions));
set(handles.n_repetitions_hz_box, 'String', sigfig(stim.repetition_Hz, 3));
set(handles.comments, 'String', comments);
set(handles.detrend_model, 'String', detrend_param.model);
set(handles.fit0, 'String', sprintf('%g', detrend_param.range(1)*1000));
set(handles.fit1, 'String', sprintf('%g', detrend_param.range(2)*1000));
set(handles.roi0, 'String', sprintf('%g', detrend_param.response_roi(1)*1000));
set(handles.roi1, 'String', sprintf('%g', detrend_param.response_roi(2)*1000));
set(handles.baseline0, 'String', sprintf('%g', detrend_param.response_baseline(1)*1000));
set(handles.baseline1, 'String', sprintf('%g', detrend_param.response_baseline(2)*1000));
%set(handles.response_detection_threshold, 'String', sprintf('%g', ...
%    detrend_param.response_detection_threshold));
set(handles.response_sigma, 'String', sprintf('%g', ...
    detrend_param.response_sigma));
set(handles.response_prob, 'String', sprintf('%g', ...
    detrend_param.response_prob));

set(handles.voltage_limit, 'String', sigfig(voltage_limit, 2));
for i = 2:length(ni_response_channels)
    eval(sprintf('set(handles.hvc%d, ''Value'', %d);', i, ni_response_channels(i)));
end
for i = 1:16
    if valid_electrodes(i)
        foo = 'on';
    else
        foo = 'off';
    end
    eval(sprintf('set(handles.electrode%d, ''Value'', %d);', i, valid_electrodes(i)));
    eval(sprintf('set(handles.stim%d, ''Enable'', ''%s'');', i, foo));
    eval(sprintf('set(handles.stim%d, ''Value'', %d);', i, stim.active_electrodes(i)));
end
stim_scale_update_gui(handles);
prepulse_us_update_gui(handles);
set(handles.datadir_box, 'String', datadir);
set(handles.birdname, 'String', bird, 'BackgroundColor', [0 0.8 0]);
update_monitor_electrodes(hObject, handles);
devices = {};
devices_perhaps = {'tdt', 'ni'};
for i = devices_perhaps
    if isfield(hardware, i)
        devices(end+1) = i;
    end
end
set(handles.show_device, 'String', devices);

if isfield(hardware, 'tdt') & ~isempty(hardware.tdt.device)
    for i = 1:16
        if stim.tdt_valid(i)
            foo = 'on';
        else
            foo = 'off';
        end
        set(handles.tdt_valid_buttons{i}, 'Value', stim.tdt_valid(i));
        set(handles.tdt_show_buttons{i}, 'Enable', foo, 'Value', stim.tdt_show(i));
    end
    %tdt.SetTagVal('mon_gain', round(hardware.tdt.audio_monitor_gain));
    %set(handles.audio_monitor_gain, 'String', sprintf('%d', round(tdt.GetTagVal('mon_gain'))));
end
%%%%% From hardware %%%%%
%if ~isempty(tdt)
%    set(handles.audio_monitor_gain, 'String', sprintf('%d', round(tdt.GetTagVal('mon_gain'))));
%end



%%%%% From handles or hardcoded; currently not saved. %%%%%
%set(handles.terminalconfigbox, 'String', handles.TerminalConfig);



mkdir_p(datadir);

guidata(hObject, handles);



function fit0_Callback(hObject, eventdata, handles)
global detrend_param;
detrend_param.range(1) = str2double(get(hObject,'String'))/1000;

function fit0_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function fit1_Callback(hObject, eventdata, handles)
global detrend_param;
detrend_param.range(2) = str2double(get(hObject,'String'))/1000;


function fit1_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function roi0_Callback(hObject, eventdata, handles)
global detrend_param;
detrend_param.response_roi(1) = str2double(get(hObject,'String'))/1000;


% --- Executes during object creation, after setting all properties.
function roi0_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function roi1_Callback(hObject, eventdata, handles)
global detrend_param;
detrend_param.response_roi(2) = str2double(get(hObject,'String'))/1000;


% --- Executes during object creation, after setting all properties.
function roi1_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function baseline0_Callback(hObject, eventdata, handles)
global detrend_param;
detrend_param.response_baseline(1) = str2double(get(hObject,'String'))/1000;


% --- Executes during object creation, after setting all properties.
function baseline0_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function baseline1_Callback(hObject, eventdata, handles)
global detrend_param;
detrend_param.response_baseline(2) = str2double(get(hObject,'String'))/1000;


% --- Executes during object creation, after setting all properties.
function baseline1_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function detrend_model_Callback(hObject, eventdata, handles)
global detrend_param;
detrend_param.model = get(hObject, 'String');


function detrend_model_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function response_indicator_Callback(hObject, eventdata, handles)




function response_detection_threshold_Callback(hObject, eventdata, handles)
global detrend_param;
detrend_param.response_detection_threshold = str2double(get(hObject,'String'));

function response_detection_threshold_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end






function [ out errors ] = find_threshold(hObject, handles)
global stim hardware detrend_param;
global start_uAmps min_uAmps max_uAmps voltage_limit;
global stop_button_pressed;
global increase_step;


factor = increase_step;
final_factor = 1.02;
out.best_current = Inf;
out.best_current_voltage = Inf;
out.stim_filename = {};
stim.current_uA = start_uAmps;

out.all_resp = [];
out.all_resp_filenames = {};

done = false;
found_lower_limit = false;
    
while ~done
    
    while get(handles.pause, 'Value')
        pause(1);
    end
    
    update_gui_values(hObject, handles);
    drawnow;
    
    if stop_button_pressed
        return;
    end
    
    data = [];
    
    errorcounter = 0;

    while isempty(data)
        [ data, response, voltage, errors ] = stimulate_wrapper(stim, hardware, detrend_param, handles);
        errorcounter = errorcounter + 1;
        if errorcounter > 5
            a(0)
        end
        if exist('errors', 'var') & isfield(errors, 'val') & bitand(errors.val, 256)
            return;
        end
    end
    


    switch response
        case 1
            % Response seen: (0) record it, (1) reduce current, (2)
            % decrease search step size, (3) check termination conditions
            % Best stim so far? If so, save it.
            
            % (0) record it
            if stim.current_uA < out.best_current
                out.best_current = stim.current_uA;
                out.best_current_voltage = voltage;
                out.stim_filename = cellstr(data.filename);
            end
            
            out.all_resp(:, end+1) = [ stim.current_uA; voltage ];
            out.all_resp_filenames(end+1) = cellstr(data.filename);

            % (1, 2)
            stim.current_uA = stim.current_uA / factor;
            if found_lower_limit
                factor = factor ^ (1/1.5);
                if factor < final_factor
                    done = true;
                end
            end
            
            % (3)
            if stim.current_uA < min_uAmps
                %disp(sprintf('Current is %s < %s, but saw response so continuing lower anyway!', ...
                %    sigfig(stim.current_uA, 3), sigfig(min_uAmps, 3)));
                stim.current_uA = min_uAmps;
                done = true;
            end
            
            
            % This results in a decrease of current, so let's skip the
            % error check...
        case 0
            % No response: (1) increase current, (2) check termination
            % conditions
            found_lower_limit = true;
            
            if stim.current_uA >= max_uAmps
                done = true;
            end
            
            stim.current_uA = stim.current_uA * factor;
            
            % If we don't have a best-case stim filename, save something
            % anyway. This will be the largest stim current used.
            if isempty(out.stim_filename)
                out.stim_filename = cellstr(data.filename);
            end
            

        otherwise
            % That quirk in which the first stim sometimes doesn't register
            % on the NI will result in NaN. Do nothing; await the next
            % stim.
    end
    
end

if isinf(out.best_current)
    out.voltages = NaN * zeros(size(stim.active_electrodes));
else
    disp(sprintf('Best so far: %s. Mean: %s.', sigfig(out.best_current, 3), ...
        sigfig(mean(out.all_resp(1, :)), 3)));
    stim.current_uA = mean(out.all_resp(1, :));
    out.voltages = check_all_stim_voltages(hObject, handles);
end




%% Given a stimulation pattern, don't change anything except the plexon monitor channel, and monitor the delivere
function [ voltages ] = check_all_stim_voltages(hObject, handles, test_current);
% Find voltage on each active electrode for a given current.
% Leave the monitor electrode set to that which sees the highest voltage.
global stop_button_pressed;
global stim hardware detrend_param;
%one_pulse = false;

stim_orig = stim;

if exist('test_current', 'var')
    stim.current_uA = test_current;
end

voltages = NaN * zeros(size(stim.active_electrodes));

% For a voltage scan we can speed things up by only doing one pulse per
% channel.  BUT I've been using the data from the voltage scans, so this is
% actually quite a bad idea, generally.  Keeping it here in case it is
% useful at some point...
%if sum(stim.active_electrodes) >= 4
%    stim.n_repetitions = 1;
%    set(handles.n_repetitions_box, 'String', '1');
%    handles = configure_acquisition_devices(hObject, handles);
%    guidata(hObject, handles);
%    one_pulse = true;
%    % Also, turn off de-trending etc. on the response recording end!
%end

for i = find(stim.active_electrodes)
    
    while get(handles.pause, 'Value')
        pause(1);
    end

    stim.plexon_monitor_electrode = i;
    update_monitor_electrodes(hObject, handles);
    
    if stop_button_pressed
        disp('stop button pressed');
        stop_button_pressed = false;
        stim = stim_orig;
        update_monitor_electrodes(hObject, handles);
        break;
    end
    
    [ ~, ~, voltages(i)] = stimulate_wrapper(stim, hardware, detrend_param, handles);
end

% Don't reset--leave it at the highest voltage found so far?
stim = stim_orig;
voltages
[~, pos] = max(voltages);
stim.plexon_monitor_electrode = pos(1)
set(handles.monitor_electrode_auto, 'BackgroundColor', 0.94 * [1 1 1]);

%if one_pulse
%    handles = configure_acquisition_devices(hObject, handles);    
%    guidata(hObject, handles);
%end

update_monitor_electrodes(hObject, handles);





function full_threshold_scan_Callback(hObject, eventdata, handles)
global stim hardware detrend_param;
global stop_button_pressed;
global response_thresholds;
global datadir;
global thewaitbar;
global scriptdir data_basedir;
global paused;

if ~exist('pause', 'var')
    paused = false;
end

disable_controls(hObject, handles);
stop_button_pressed = false;



%%% Repeat a previous experiment, as given in this threshold scan file and
%%% this stimulation file:
%repeat_experiment = strcat(scriptdir, '/lw95rhp-2015-11-19/current_thresholds_8.mat');
%repeat_stim_file = strcat(scriptdir, '/lw95rhp-2015-11-19/stim_20151119_175100.405.mat');

%% WIN

if exist('repeat_experiment', 'var')
    if ~exist(repeat_experiment, 'file') | ~exist(repeat_stim_file, 'file')
        error('continue:wrongfiles', 'You are trying to continue an experiment, but the files are not found.');
    end
    repeatme = load(repeat_experiment);
    repeat = load(repeat_stim_file);
    
    disp(sprintf('*** Continuing the experiment from %s...', repeat_experiment));

    frequencies = repeatme.frequencies;
    durations = repeatme.durations;
    detrend_param = repeatme.detrend_param;
    polarities = repeatme.polarities;
    
    % This copies across frequency, repetitions, active electrodes, pulse
    % width, choice of TDT channels... the other stuff will be overwritten
    % as necessary.
    disp(sprintf('    Using hardware configuration recorded in %s:', repeat_stim_file));
    stim = repeat.data.stim

    update_gui_values(hObject, handles);
    handles = configure_acquisition_devices(hObject, handles);
elseif true
    NPOLARITIES = 16; % Perfect squares are easiest to subplot...
    
    frequencies = [ 27 27 27 27 27 27 27 ]
    durations = [200e-6]
    polarities = randperm(2^sum(stim.active_electrodes) - 2); % Will add 000 and 111 manually
    polarities = polarities(1:min([length(polarities) NPOLARITIES-2]));
    % Always test non-current-steering configurations!
    polarities = [ polarities,  0,   2^sum(stim.active_electrodes) - 1 ]
    
    if true
        old_experiment_file = strcat(data_basedir, '/lr7-2016-09-29/experiment.mat');
        warning('Using polarities from past experiment %s', old_experiment_file);
        old_experiment = load(old_experiment_file);
        polarities = old_experiment.polarities;
        polarity_strings = old_experiment.polarity_strings;
        i_want_these_polarities = [1:7 9:11 13:18];
        polarities = polarities(i_want_these_polarities)
        polarity_strings = polarity_strings(i_want_these_polarities)
    end
end


mkdir_p(datadir);

if exist(fullfile(datadir, 'current_thresholds.mat', 'file'))
    error('duplicatefile:warning', 'Error: ''%s'' already exists. Rename or delete.', ...
        fullfile(datadir, 'current_thresholds.mat'));
end

response_thresholds = {};

detrend_param

% Track progress...
nsearches = length(frequencies) * length(durations) * length(polarities);
nsearches_done = 0;
start_time = tic;
start_datetime = datenum(datetime('now'));
if isempty(thewaitbar)
    thewaitbar = waitbar(0, 'Time remaining: hundreds of years');
else
    waitbar(0, thewaitbar, 'Time remaining: hundreds of years');
end

warning('Test the thing that says TESTME');

disp(sprintf('Doing %d threshold searches.', nsearches));

freqs_completed = 0;

for frequency = 1:length(frequencies)
    % Go through different repitition frequencies
    stim.repetition_Hz = frequencies(frequency);

    for dur = 1:length(durations)
        % Go through different durations
        stim.halftime_s = durations(dur);
        
        handles = configure_acquisition_devices(hObject, handles);
 
        for polarity = randperm(length(polarities))
            
            while get(handles.pause, 'Value')
                pause(1);
            end
            
            if stop_button_pressed
                stop_button_pressed = false;
                return;
            end
            electrode_bit = 0; % run over all stim polarities...
            for electrode = find(stim.active_electrodes)
                electrode_bit = electrode_bit + 1;
                if bitget(polarities(polarity), electrode_bit)
                    % This seems backwards... I think it is...
                    stim_scaling_set(handles, 1, electrode);
                else
                    stim_scaling_set(handles, -1, electrode);
                end
            end
            
            
            [response_thresholds{frequency, dur, polarity}, errors] = find_threshold(hObject, handles);
            
            if exist('errors', 'var') & isfield(errors, 'val') & bitand(errors.val, 256)
                return;
            end

            
            if stop_button_pressed
                % Should there be a "stop_button_pressed = false" here?
                return;
            end
            
            
            elapsed_time = toc(start_time);
            nsearches_done = nsearches_done + 1;
            total_expected_time = elapsed_time * nsearches / nsearches_done;
            expected_finish_time = start_datetime + (total_expected_time / (24*3600));
            if ishandle(thewaitbar)
                waitbar(elapsed_time / total_expected_time, ...
                    thewaitbar, ...
                    sprintf('Expected finish time: %s', datestr(expected_finish_time, 'dddd HH:MM:SS')));
            end
            
            
        end
    end
    
    save(fullfile(datadir, 'response_thresholds'), ...
        'response_thresholds', ...
        'frequencies', 'durations', ...
        'polarities', 'detrend_param', '-v7.3');
    % Let's see what we've got:
    
    for f = 1:frequency
        for d = 1:length(durations)
            for p = 1:length(polarities)
                v(f,d,p,:) = response_thresholds{f,d,p}.voltages;
            end
        end
    end
    
    % Probably want max per channel, actually...
    channel_voltage_means = squeeze(mean(mean(max(v, [], 4), 1), 2))
    channel_voltage_stds = squeeze(std(max(v(:, 1, :, :), [], 4), 0, 1)) % TESTME
    
                
    %squeeze(response_thresholds.best_current_voltages(:,1,:))'
    disp(sprintf('Completed experiment %d of %d...', frequency, length(frequencies)));
end

delete(thewaitbar);
thewaitbar = [];

enable_controls(handles);





function stim_scaling_set(handles, scaling, electrode)
global stim;

stim.current_scale(electrode) = scaling;




% --- Executes on button press in stim_voltage_scan.
function stim_voltage_scan_Callback(hObject, eventdata, handles)
voltages = check_all_stim_voltages(hObject, handles);


%polarity_string = '';
%for i = find(stim.active_electrodes)
%    polarity_string = strcat(polarity_string, sigfig(stim.stim_current(i)));
%end
%save(fullfile(datadir, sprintf('voltages_%s.mat', polarity_string)), ...
%    'stim', 'voltages', '-v7.3');





function voltage_limit_Callback(hObject, eventdata, handles)
global voltage_limit;
voltage_limit = str2double(get(hObject, 'String'));


function voltage_limit_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end




function xscale_CreateFcn(hObject, eventdata, handles)
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end




% --- Executes on button press in pause.
function pause_Callback(hObject, eventdata, handles)
global paused;

if ~exist('paused', 'var')
    paused = true;
end


if paused
    paused = false;
    set(handles.pause, 'BackgroundColor', [1 1 1]*0.94, 'String', 'Pause');
else
    paused = true;
    set(handles.pause, 'BackgroundColor', [1 0 0], 'String', 'Resume');
end




function xcorr_threshold_auto_Callback(hObject, eventdata, handles)
global stim hardware detrend_param;
global datadir;
global cow ste wayout;
global stop_button_pressed;

% Set stim to the minimum (30 nA),  stimulate a bunch of times, and get a
% range of xcorrelation values, per valid recording channel. How many

stim.current_uA = 500;
stim.tdt_valid = ones(1, 16);
stim.tdt_show = stim.tdt_valid;
detrend_param.response_detection_threshold = zeros(size(stim.tdt_valid));
detrend_param.response_sigma = 3;
detrend_param.response_prob = 0.5;

nactive = sum(stim.tdt_valid);

colours = distinguishable_colors(nactive);
tdt_valid_mapping = find(stim.tdt_valid);

xcorr_min_threshold = -10.1; % Is this even reasonable?

% One goes first. Given the way for loops work, this is easiest.
data = stimulate_wrapper(stim, hardware, detrend_param, handles);
clear cow ste wayout;
for i = 1:20
    if stop_button_pressed
        stop_button_pressed = false;
        break;
    end
    
    data = stimulate_wrapper(stim, hardware, detrend_param, handles);

    cow(i,:) = data.tdt.spikes_r;
    if i > 1
        m = mean(cow);
        wayout(i,:) = m + 3*std(cow);
        ste95 = std(cow) * 1.96 / sqrt(i);
        
        m(find(m <= xcorr_min_threshold)) = Inf;
        
        % This just lets us monitor progress: shouldn't see pinkness by end
        detrend_param.response_detection_threshold = m + ste95 + 3*std(cow);

        for j = 1:size(wayout, 2)
            pchan = tdt_valid_mapping(j);
            h = eval(sprintf('handles.maxi%d', pchan));
            set(h, 'String', sprintf('%s', sigfig(wayout(i,j), 4)));
        end
        
        %axes(handles.axes2);
        cla(handles.axes2);
        hold(handles.axes2, 'on');
        for j = 1:nactive
            scatter(handles.axes2, repmat(j, 1, i), cow(:,j), 5, colours(j,:));
            scatter(handles.axes2, j, m(j), 10, colours(j,:), '+');
            % Plot the 95%-confidence estimate of the mean:
            %shadedErrorBar(1:i, ste(1:i, j), ...
            %    ste(1:i, j), ...
            %    {'color', colours(j,:)}, 1);
            % Plot the best guess for the 3*sigma threshold:
            %plot(handles.axes2, 1:i, wayout(1:i,j), 'Color', colours(j,:));
            xlabel(handles.axes2, 'trial');
            ylabel(handles.axes2, 'xcorr');
            title(handles.axes2, 'Channel response thresholds');
            set(handles.axes2, 'YLim', [-11 -9]);
        end
        hold(handles.axes2, 'off');
        set(handles.axes2, 'XLim', [0 j+1]);

    end
end

m = mean(cow);
stim.tdt_valid = m > xcorr_min_threshold;
stim.tdt_show = stim.tdt_valid;

detrend_param.response_detection_threshold ...
    = m(find(stim.tdt_valid)) + ste95(find(stim.tdt_valid)) + 3*std(cow(find(stim.tdt_valid)));

for j = 1:size(wayout, 2)
    pchan = tdt_valid_mapping(j);
    h = eval(sprintf('handles.maxi%d', pchan));
    set(h, 'String', sprintf('%s', sigfig(wayout(i,j), 4)));
end

for i = 1:16
    if stim.tdt_valid(i)
        foo = 'on';
    else
        foo = 'off';
    end
    set(handles.tdt_valid_buttons{i}, 'Value', stim.tdt_valid(i));
    set(handles.tdt_show_buttons{i}, 'Value', stim.tdt_show(i), 'Enable', foo);
end

datafile_name = sprintf('corr_thresholds_%suA.mat', sigfig(stim.current_uA));
save(fullfile(datadir, datafile_name), 'cow', '-v7.3');


%% Since Matlab can't call subfunctions across files, and stimulate() is in
%% its own file, I have to jump through some hoop to handle errors in a
%% unified way.  I choose this way.
function [ data, response_detected, voltage, errors] = stimulate_wrapper(stim, hardware, detrend_param, handles)
global disable_safety_checks;

[ data, response_detected, voltage, errors] = stimulate(stim, hardware, detrend_param, handles);

if ~isempty(errors) & errors.val ~= 0
    for i = 1:length(errors.name)
        disp(errors.name{i});
    end
    
    if disable_safety_checks
        for i = 1:5
            set(handles.disable_safety_checks, 'BackgroundColor', 0.94*[1 1 1]);
            pause(0.03);
            set(handles.disable_safety_checks, 'BackgroundColor', [1 0.3 0]);
            pause(0.03);
        end
    elseif nargout < 4 % If "errors" isn't asked for by the caller
        stop_everything(handles);
    end
end


% --- Executes on button press in smoothness_scan.
function smoothness_scan_Callback(hObject, eventdata, handles)
global stim hardware detrend_param safeParams;
global stop_button_pressed;
global response_thresholds;
global datadir;
global thewaitbar;
global scriptdir;
global paused;

expName = 'smoothness_scan'; % Experiment name

if ~exist('pause', 'var')
    paused = false;
end

disable_controls(hObject, handles);
stop_button_pressed = false;



% Repeat experiment put on hold until the continuous experiment has been
% developed

% %%% Repeat a previous experiment, as given in this threshold scan file and
% %%% this stimulation file:
% %repeat_experiment = strcat(scriptdir, '/lw95rhp-2015-11-19/current_thresholds_8.mat');
% %repeat_stim_file = strcat(scriptdir, '/lw95rhp-2015-11-19/stim_20151119_175100.405.mat');
% 
% 
% if exist('repeat_experiment', 'var')
%     if ~exist(repeat_experiment, 'file') | ~exist(repeat_stim_file, 'file')
%         error('continue:wrongfiles', 'You are trying to continue an experiment, but the files are not found.');
%     end
%     repeatme = load(repeat_experiment);
%     repeat = load(repeat_stim_file);
%     
%     disp(sprintf('*** Continuing the experiment from %s...', repeat_experiment));
% 
%     frequencies = repeatme.frequencies;
%     durations = repeatme.durations;
%     detrend_param = repeatme.detrend_param;
%     polarities = repeatme.polarities;
%     
%     % This copies across frequency, repetitions, active electrodes, pulse
%     % width, choice of TDT channels... the other stuff will be overwritten
%     % as necessary.
%     disp(sprintf('    Using hardware configuration recorded in %s:', repeat_stim_file));
%     stim = repeat.data.stim
% 
%     update_gui_values(hObject, handles);
%     handles = configure_acquisition_devices(hObject, handles);
% elseif false
%     NPOLARITIES = 6;
%     
%     frequencies = [ 20 20 20 ]
%     durations = [200e-6]
%     polarities = randperm(2^sum(stim.active_electrodes)) - 1;
%     polarities = polarities(1:min([length(polarities) NPOLARITIES]));
%     % Always test non-current-steering configurations!
%     polarities = [ polarities,  0,   2^sum(stim.active_electrodes) - 1 ]
% else
%     NPOLARITIES = 6;
%     
%     frequencies = [ 27 27 27 27 27 ]
%     durations = [150 200 300]*1e-6;
%     polarities = randperm(2^sum(stim.active_electrodes)) - 1;
%     polarities = polarities(1:min([length(polarities) NPOLARITIES]));
%     % Always test non-current-steering configurations!
%     polarities = [ polarities,  0,   2^sum(stim.active_electrodes) - 1 ]
% end

%% Save file

if ~exist(datadir, 'dir')
    mkdir(datadir);
end

if exist(fullfile(datadir, [expName '.mat']), 'file')
    error('duplicatefile:warning', 'Error: ''%s'' already exists. Rename or delete.', ...
        fullfile(datadir, [expName '.mat']));
end

response_thresholds = {};

% detrend_param

% disp(sprintf('Doing %d threshold searches.', nsearches));

%% Do a smoothness check on some random permutation of active electrodes
% (Can make current steering choice more exact later if needed)

% Test if user has changed stimulation scales on any active electrodes
% (indicating that they probably want a certain current steering condition)
% If they have not changed the stim scale, select a random permutation of
% electrodes to have negative current
if all(stim.current_scale(stim.active_electrodes) == 1)
    % Make a random perturbation of electrodes to test
    numActiveElectrodes = sum(stim.active_electrodes); % Number of active electrodes
    negElectrodes = logical(de2bi(randi([0 2^(numActiveElectrodes) - 1]), numActiveElectrodes)); % For each active electrode, binary to indicate neg-first
    
    % Make a negative amplitude scale for each of the randomly chosen
    % electrodes
    stim.current_scale(negElectrodes) = -stim.current_scale(negElectrodes);
end

% Determine the spaces over which amplitude and pre-stim pause will be
% tested, as well as which electrode will be tested
% Currently just goes between the current stimulation parameters
% and the largest allowable stimulation parameters
ampStepSize = min([smoothnessParams.ampNumSteps ceil((safeParams.max_current - stim.current_uA)/(stim.current_uA*smoothnessParams.ampStep))]); % Find the minimum number of amplitude steps (which are given by either smoothnessParams.ampNumSteps or smoothnessParams.ampStepS
pauseStepSize = min([ceil(safeParams.max_prepulse_us/smoothnessParams.pauseStep) smoothnessParams.pauseNumSteps]); % Find the minimum number of amplitude steps (which are given by either smoothnessParams.ampNumSteps or smoothnessParams.ampStepS

amplitudeScales = linspace(stim.current_uA,safeParams.max_current,ampStepSize)/stim.current_uA; % All amplitudes that will be checked (in the form of scaling factors)
pauses = linspace(0,safeParams.max_prepulse_us,pauseStepSize); % All pause valuse that will be checked

% Select the electrode to test on
% activeElectrodeInds = find(stim.active_electrodes);
% testedElectrode = stim.active_electrodes(activeElectrodeInds(randi(size(activeElectrodeInds,2)))); % Determine the index of the active electrode randomly
% while stim.plexon_test_electrode == stim.plexon_monitor_electrode
%     stim.plexon_test_electrode = stim.plexon_test_electrode + 1;
%     if stim.plexon_test_electrode > 16
%        stim.plexon_test_electrode = stim.plexon_test_electrode - 16; % Make sure that test electrode is not above 16
%     end
% end
% 
% testedElectrode = stim.plexon_test_electrode; % Test on the electrode selected by the user
testedElectrode = stim.plexon_monitor_electrode; % Use the monitor electrode as the electrode which is changed

%% Track progress...
nsearches = length(amplitudeScales) * length(pauses);
nsearches_done = 0;
start_time = tic;
if isempty(thewaitbar)
    thewaitbar = waitbar(0, 'Time remaining: hundreds of years');
else
    waitbar(0, thewaitbar, 'Time remaining: hundreds of years');
end

warning('Test the thing that says TESTME');

%% Do space search
% Loop through regions of stimulation amplitude and pre-stim pause on the
% chosen active electrode, and determine what the minimum stimulation
% current is for each parameter pair to get a voltage response

response_results = zeros(size(amplitudeScales,2),size(pauses,2)); % Matrix to hold the response detected results of the experiment
voltage_results = nan(size(response_results)); % Matrix to hold the voltage results of the experiment
errorFlag = false;
for ampInd = 1:size(amplitudeScales,2)
    % For each amplitude
    stimAmpScale = amplitudeScales(ampInd); % Extract the current stimulation amlpitude scale
    
    for pauseInd = 1:size(pauses,2)
        % For each pre-pulse pause duration
        stimPause = pauses(pauseInd); % Extract the current pre-pulse pause duration
        
        %% Set up the stimulation parameters
        % Set the parameters for the testing electrode
        stim.current_scale(testedElectrode) = stimAmpScale;
        stim.prepulse_us(testedElectrode) = stimPause;
        
        % Test the values, so that they are safe (redudant, but fast and
        % safe)
        stim = safety_check(stim, safeParams);
        
        %% Send stimulations
        [data, response_detected, voltage ] = stimulate_wrapper(stim, hardware, detrend_param, handles);
        if isempty(data)
            disp('smoothness check: stimulate() did not capture any data.');
            return;
        end
                
        % Record result
        response_results(ampInd, pauseInd) = response_detected; % Record whether or not a response was seen at this voltage
        voltage_results(ampInd, pauseInd) = voltage; % Record the voltage measured
        
        %% Update user
        elapsed_time = toc(start_time);
        nsearches_done = nsearches_done + 1;
        total_expected_time = elapsed_time * nsearches / nsearches_done;
        expected_remaining_time = (elapsed_time / nsearches_done) * (nsearches - nsearches_done);
        if ishandle(thewaitbar)
            waitbar(elapsed_time / total_expected_time, ...
                thewaitbar, ...
                sprintf('Expected remaining time: %s', expected_remaining_time));
        end
        
    end
    if errorFlag
        break;
    end
end

%% Plot results
if ~errorFlag
    figure;
    mesh(amplitudeScales*stim.current_uA, pauses*1e6, response_results);
    ylabel('Amplitude (uA)');
    xlabel('Pre-pulse pause duration (us)');
    zlabe('Response');
    title('Neural response as a function of amplitude and pre-pulse pause duration');
    
    figure;
    mesh(amplitudeScales*stim.current_uA, pauses*1e6, voltage_results);
    ylabel('Amplitude (uA)');
    xlabel('Pre-pulse pause duration (us)');
    zlabe('Response');
    title('Stimulation voltage as a function of amplitude and pre-pulse pause duration');
end
delete(thewaitbar);
thewaitbar = [];

enable_controls(handles);

function optimize_over_stim_parameters(handles, policyFunction, optimizationFunction, finishingConds)
% optimize_over_stim_parameters(handles, policyFunction, minimizationFunction, finishingConds)
% 
% This function will minimize the minimizationFunction by changing the
% electrode parameters using the policyFunction.
%
% policyFunction must have the contract:
% [newAmplitudes newPauseDurations newFunctionMemory] = policyFunction(currentAmplitudes, currentPauseDurations, lastFunctionResult, lastfunctionMemory)
% where:
% newAmplitudes are the previous amplitude for each electrode,
% newPauseDurations are the previous pause durations for each electrode,
% newFunctionMemory is data that policyFunction may generate that will be
% passed back to it during the next iteration,
% currentAmplitudes are the new amplitudes for each electrode,
% currentPauseDurations are the new pause durations for each electrode,
% lastFunctionResult is the output of the last call to
% optimizationFunction, and
% lastFunctionMemory is the newFunctionMemory generated by the previous
% call to policyFunction (this variable will be initialized to NaN)
%
% optimizationFunction must have the contract:
% result = optimizationFunction(stimData)
% where:
% result is a scalar to be optimized, and
% stimData is the data output from stimulate()
% If there is an error (no stimulation, etc.), optimizationFunction would
% return NaN.  This can be handled by policyFunction.
%
% finishingConds is a structure that has the following fields
% (= default value if field does not exist):
% finishingConds.maxSteps (=10000) determines the maximum number of steps
% the optimization can make
% finishingConds.ampThresh (= 1) determines the threshold for the minimum
% adjustment, in uA, that the policyFunction will make before finishing
% (the largest step distance across all electrodes must be smaller than
% this value)
% finishingConds.pauseThresh (= 1) determines the threshold for the minimum
% adjustment, in uS, that the policyFunction will make before finishing
% (the largest step distance across all electrodes must be smaller than
% this value)

global stim hardware detrend_param safeParams;
global stop_button_pressed;
global response_thresholds;
global datadir;
global thewaitbar;
global scriptdir;
global paused;

%% Fill in default finishingConds values
if ~isfield(finishingConds, 'maxSteps')
    finishingConds.maxSteps = 10000;
end

if ~isfield(finishingConds, 'ampThresh')
    finishingConds.ampThresh = 1;
end

if ~isfield(finishingConds, 'pauseThresh')
    finishingConds.pauseThresh = 1;
end

%% Save file
expName = 'optimization'; % Experiment name

if ~exist(datadir, 'dir')
    mkdir(datadir);
end

if exist(fullfile(datadir, [expName '.mat']), 'file')
    error('duplicatefile:warning', 'Error: ''%s'' already exists. Rename or delete.', ...
        fullfile(datadir, [expName '.mat']));
end

%% Prepare GUI
if ~exist('pause', 'var')
    paused = false;
end

disable_controls(hObject, handles);
stop_button_pressed = false;

%% Track progress...
% nsearches = 10;
% nsearches_done = 0;
% start_time = tic;
% if isempty(thewaitbar)
%     thewaitbar = waitbar(0, 'Time remaining: hundreds of years');
% else
%     waitbar(0, thewaitbar, 'Time remaining: hundreds of years');
% end

%% Do space search
% Initialize matrices to record all amplitudes, pauseDurations, and results
numRows = finishingConds.maxSteps + 1;
amplitudes = zeros(numRows, size(stim.current_scale, 2));
pauseDurations = zeros(numRows, size(stim.prepulse_us, 2));
results = zeros(numRows, 1);

% Initialize electrode parameters
lastAmplitudes = stim.current_scale.*stim.current_uA;
lastPauseDurations = stim.prepulse_us;
amplitudes(1,:) = lastAmplitudes;
pauseDurations(1,:) = lastPauseDurations;

% Stimulate once to get initial result from optimization function
stimData = stimulate_wrapper(stim, hardware, detrend_param, handles);
if isempty(stimData)
    disp('Initial conditions for optimization did not produce response.  Stopping optimization.');
    return;
end


% Get initial result from optimization function
lastFunctionResult = feval(optimizationFunction, stimData);
results(1) = lastFunctionResult;

% Initialize loop parameters
policyMemory = NaN;
currentLoop = 1;
isDone = false;

% Start optimization
while ~isDone
    %% Get new values from the policy
    % Acquire new values
    [newAmplitudes, newPauseDurations, policyMemory] = feval(policyFunction, lastAmplitudes, lastPauseDurations, lastFunctionResult, policyMemory);
    
    % Save new values from policy
    amplitudes(currentLoop + 1,:) = newAmplitudes;
    pauseDurations(currentLoop + 1,:) = newPauseDurations;
    
    % Convert the amplitude values to scale
    newAmplitudeScales = newAmplitudes/stim.current_uA;
    
    % Assign the new values to the stim struct
    stim_scale_set(handles, newAmplitudeScales);
    stim.prepulse_us = newPauseDurations;
    
    %% Check the new values
    % Check for safety
    stim = safety_check(stim,safeParams);
    
    % Save values from safety check  if needed (SHOULD be the same as from
    % the policyFunction, but may have been changed if they were unsafe)
    if any(stim.current_scale ~= newAmplitudeScales) || any(stim.prepulse_us ~= newPauseDurations)
        disp('Safety Check: Policy produced unsafe parameters.  Parameters have been changed.');
        amplitudes(currentLoop + 1,:) = stim.current_scale*stim.current_uA;
        pauseDurations(currentLoop + 1,:) = stim.prepulse_us;
    end
    
    % Check if optimization is done
    dAmplitudes = abs(newAmplitudes - lastAmplitudes);
    dPauseDurations = abs(newPauseDurations - lastPauseDurations);
    if (all(dAmplitudes < finishingConds.ampThresh) || all(dPauseDurations*1e6 < finishingConds.pauseThresh))
       isDone = true;
    end
    
    %% Save the old values
    lastAmplitudes = newAmplitudes;
    lastPauseDurations = newPauseDurations;
    
    %% Stimulate
    [stimData ] = stimulate_wrapper(stim, hardware, detrend_param, handles);
    if isempty(data)
        disp('optimization: stimulate() did not capture any data.');
        return;
    end
    
    if errors.val ~= 0
        for i = 1:length(errors.name)
            disp(errors.name{i});
        end
        isDone = true;
    end
    
    %% Find value of optimizationFunction
    lastFunctionResult = feval(optimizationFunction, stimData);
    results(currentLoop + 1) = lastFunctionResult;
    
    
    %% Iterate counter for next loop
    currentLoop = currentLoop + 1;
    
    %% Check if max number of steps has been reached
    if (currentLoop > finishingConds.maxSteps)
       isDone = true; 
    end
end

%% Save all data
save(fullfile(datadir, [expName '.mat']),'amplitudes', 'pauseDurations',...
    'results', '-v7.3');

% delete(thewaitbar);
% thewaitbar = [];

enable_controls(handles);


function ampStep_Callback(hObject, eventdata, handles)
% hObject    handle to ampStep (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global smoothnessParams;

% Get the value
newVal = str2double(get(hObject, 'String'));

% Make sure it's a number
if isnan(newVal)
    % If it is not a number, replace the editbox's contents with its old
    % value (taken from stim.current_scale)
    newVal = smoothnessParams.ampStep;
end

% Make sure it's valid
if newVal <= 0
   newVal = smoothnessParams.ampStep;
end


% Set this (potentially changed) value back to the edit box, and save it
% to stim
set(hObject, 'String', num2str(newVal));
smoothnessParams.ampStep = newVal;
   


function stim_scale_set(handles, val, electrodes)
% If electrodes is not given:
%    Set all electrodes to 'newscale'
%        (will error if not 16)
% else
%    set whatever electrodes are named to the values in newscale
% end
% renormalise over the active electrodes
% update GUI

global stim;

if ~exist('electrodes', 'var')
    stim.current_scale = val;
elseif length(electrodes) == length(val)
    stim.current_scale(electrodes) = val;
end

stim_scale_renormalise(handles);

% This probably obsoletes monitor electrode autoset, so alert the user:
set(handles.monitor_electrode_auto, 'BackgroundColor', [0.8 0.4 0]);



function stim_scale_renormalise(handles);
global stim;

i = find(stim.active_electrodes);
if length(i) < 1
    return
end
stim.current_scale(i) = stim.current_scale(i) / max(abs(stim.current_scale(i)));
stim.current_scale(find(~stim.active_electrodes)) = 0;

stim_scale_update_gui(handles);



function stim_scale_update_gui(handles)
global stim;

for i = 1:16
   tag = ['stimscale' num2str(i)];
   if stim.active_electrodes(i)
       if stim.current_scale(i) > 0
           set(handles.(tag), 'String', sigfig(stim.current_scale(i)), ...
               'Enable', 'on', ...
               'ForegroundColor', [0 0 0], ...
               'BackgroundColor', [1 1 1] * (stim.current_scale(i)+1)/2, ...
               'Visible', 'on');
       else
           set(handles.(tag), 'String', sigfig(stim.current_scale(i)), ...
               'Enable', 'on', ...
               'ForegroundColor', [1 1 1], ...
               'BackgroundColor', [1 1 1] * (stim.current_scale(i)+1)/2, ...
               'Visible', 'on');
       end
   else
       set(handles.(tag), 'String', '', 'Enable', 'off', 'Visible', 'off');
   end
end


function prepulse_us_Callback(hObject, eventdata)
handles = guidata(hObject);

whichone = str2double(get(hObject, 'Tag'));
val = str2double(get(hObject, 'String'));
prepulse_us_set(handles, val, whichone);


function prepulse_us_set(handles, val, electrodes)
% If electrodes is not given:
%    Set all electrodes to 'newscale'
%        (will error if not 16)
% else
%    set whatever electrodes are named to the values in newscale
% end
% renormalise over the active electrodes
% update GUI

global stim;

if ~exist('electrodes', 'var')
    stim.prepulse_us = val;
elseif length(electrodes) == length(val)
    stim.prepulse_us(electrodes) = val;
end

prepulse_us_renormalise(handles);


function prepulse_us_renormalise(handles)
% Min delay should be 0
global stim;

active = find(stim.active_electrodes);
mindelay = min(stim.prepulse_us(active));
if mindelay
    stim.prepulse_us(active) = stim.prepulse_us(active) - mindelay;
end
prepulse_us_update_gui(handles);



function prepulse_us_update_gui(handles)
global stim;

for i = 1:16
   if stim.active_electrodes(i)
       set(handles.prepulse_us{i}, 'String', sprintf('%d', stim.prepulse_us(i)), ...
           'Enable', 'on', ...
           'ForegroundColor', [0 0 0], ...
           'BackgroundColor', [1 1 1] * 1/(stim.prepulse_us(i)/20+1), ...
               'Visible', 'on');
       if stim.prepulse_us(i) > 20
           set(handles.prepulse_us{i}, 'ForegroundColor', [1 1 1], ...
               'Visible', 'on');
       end
   else
       set(handles.prepulse_us{i}, 'String', '', 'Enable', 'off', ...
               'Visible', 'off');
   end
end


function pauseStep_Callback(hObject, eventdata, handles)
% hObject    handle to pauseStep (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global smoothnessParams;

% Get the value
newVal = str2double(get(hObject, 'String'));

% Make sure it's a number
if isnan(newVal)
    % If it is not a number, replace the editbox's contents with its old
    % value (taken from stim.current_scale)
    newVal = smoothnessParams.pauseStep;
end

% Make sure it's valid
if newVal <= 0
   newVal = smoothnessParams.pauseStep;
end

% Set this (potentially changed) value back to the edit box, and save it
% to stim
set(hObject, 'String', num2str(newVal));
smoothnessParams.pauseStep = newVal;
  
function pauseStep_CreateFcn(a, b, c)

function ampStep_CreateFcn(a, b, c)



function response_sigma_Callback(hObject, eventdata, handles)
global detrend_param;
detrend_param.response_sigma = str2double(get(hObject,'String'));


function response_sigma_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function response_prob_Callback(hObject, eventdata, handles)
global detrend_param;
detrend_param.response_prob = str2double(get(hObject,'String'));
if isnan(detrend_param.response_prob)
    set(handles.response_prob, 'BackgroundColor', [1 0 0]);
else
    set(handles.response_prob, 'BackgroundColor', 0.94 * [1 1 1]);
end


function response_prob_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end




function monitor_electrode_auto_Callback(hObject, eventdata, handles)
% The "1" is the optional test_current argument to the function.
check_all_stim_voltages(hObject, handles, 1);


function presets_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

set(hObject, 'String', {'CNS', 'Peripheral'});

function presets_Callback(hObject, eventdata, handles)
global detrend_param voltage_limit;
contents = cellstr(get(hObject,'String'));
val = contents{get(hObject,'Value')};
%% Defaults cater to my experiment. Should add controls for multiple defaults...
if strcmp(val, 'CNS') % For my X--HVC experiment
    detrend_param.model = 'fourier8';
    detrend_param.range = [0.0025 0.025];
    detrend_param.response_roi = [0.003 0.008];
    detrend_param.response_baseline = [0.012 0.025];
    detrend_param.response_detection_threshold = 0.5;
    detrend_param.spike_detect = @look_for_spikes_peaks;
    detrend_param.response_sigma = 3;
    detrend_param.response_prob = 0.5;
    voltage_limit = 4;
elseif strcmp(val, 'Peripheral')
    detrend_param.model = 'fourier3'; % For Win's peripheral nerve experiment
    detrend_param.range = [0.0007 0.02];
    detrend_param.response_roi = [0.0007 0.002];
    detrend_param.response_baseline = [0.005 0.02];
    detrend_param.response_detection_threshold = 0.5;
    detrend_param.spike_detect = @look_for_spikes_peaks;
    detrend_param.response_sigma = 5;
    detrend_param.response_prob = 0.5;
    voltage_limit = 7;
else
    error('Invalid choice "%s"', val);
end
update_gui_values(hObject, handles);


function disable_safety_checks_Callback(hObject, eventdata, handles)
global disable_safety_checks;
disable_safety_checks = get(hObject, 'Value');
if disable_safety_checks
    set(hObject, 'BackgroundColor', [1 0 0]);
else
    set(hObject, 'BackgroundColor', 0.94*[1 1 1]);
end

