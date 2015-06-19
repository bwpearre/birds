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

% Last Modified by GUIDE v2.5 19-Jun-2015 14:18:18

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




function [ intan_pin] = map_plexon_pin_to_intan(plexon_pin, handles)
intan_pin = handles.PIN_NAMES(2, find(handles.PIN_NAMES(1,:) == plexon_pin));


function [ plexon_pin] = map_intan_pin_to_plexon(intan_pin, handles)
plexon_pin = handles.PIN_NAMES(1, find(handles.PIN_NAMES(2,:) == intan_pin));



% --- Executes just before plexme is made visible.
function plexme_OpeningFcn(hObject, ~, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to plexme (see VARARGIN)


% Choose default command line output for plexme
handles.output = hObject;

handles.START_uAMPS = 1; % Stimulating at this current will not yield enough voltage to cause injury even with a bad electrode.
handles.MAX_uAMPS = 150;
handles.INCREASE_STEP = 1.1;
handles.INTERSPIKE_S = 0.1;
handles.VoltageLimit = 3.5;
handles.valid = zeros(1, 16);
handles.stim = zeros(1, 16);  % Stimulate these electrodes
handles.timer = [];
handles.box = 1;   % Assume (hardcode) 1 Plexon box
handles.open = false;

% NI control rubbish
handles.NIsession = [];

global CURRENT_uAMPS;
CURRENT_uAMPS = handles.START_uAMPS;
global change;
change = handles.INCREASE_STEP;
global NEGFIRST;
NEGFIRST = false;
global axes_top;
global axes_bottom;
global axes4;
global axes5;
global rmsbox;
global vvsi;
global comments;
global timer_sequence_running;
global monitor_electrode;
global electrode_last_stim;
global max_current;
global default_halftime_us;
global halftime_us;
global interpulse_s;
global increase_type;
global max_halftime;
global known_invalid;
global current_amplification;
global saving_stimulations;
global intan_voltage_amplification;
global channel_ranges;
global datadir;
global channels;

datadir = 'noname';
increase_type = 'current'; % or 'time'
default_halftime_us = 400;
halftime_us = default_halftime_us;
interpulse_s = 100e-6;
monitor_electrode = 1;
electrode_last_stim = 0;
max_current = NaN * ones(1, 16);
max_halftime = NaN * ones(1, 16);
known_invalid = zeros(1, 16);
intan_voltage_amplification = 515;
current_amplification = 1;
saving_stimulations = false;
handles.TerminalConfig = {'SingleEndedNonReferenced', 'SingleEndedNonReferenced', 'SingleEndedNonReferenced'};
%handles.TerminalConfig = {'SingleEnded', 'SingleEnded', 'SingleEnded'};

%handles.TerminalConfig = 'SingleEnded';
vvsi = [];
comments = '';


channel_ranges = 1 * [ 1 1 1 ];


% Top row is the names of pins on the Plexon.  Bottom row is corresponding
% pins on the Intan.
handles.PIN_NAMES = [ 1  2  3  4  5  6  7  8  9  10  11  12  13  14  15  16 ; ...
                     19 18 17 16 15 14 13 12 20  21  22  23   8   9  10  11 ];


set(handles.startcurrent, 'String', sprintf('%d', round(handles.START_uAMPS)));
set(handles.currentcurrent, 'String', sprintf('%.2g', CURRENT_uAMPS));
set(handles.maxcurrent, 'String', sprintf('%d', round(handles.MAX_uAMPS)));
set(handles.increasefactor, 'String', sprintf('%g', handles.INCREASE_STEP));
set(handles.halftime, 'String', sprintf('%d', round(halftime_us)));
set(handles.delaytime, 'String', sprintf('%g', handles.INTERSPIKE_S));
set(handles.negativefirst, 'Value', NEGFIRST);
set(handles.select_all_valid, 'Enable', 'off');
set(handles.i_amplification, 'String', sprintf('%g', current_amplification));
set(handles.terminalconfigbox, 'String', handles.TerminalConfig);

newvals = {};
for i = 1:16
    newvals{end+1} = sprintf('%d', i);
end
set(handles.monitor_electrode_control, 'String', newvals);
% Also make sure that the monitor spinbox is the right colour


handles.disable_on_run = { handles.currentcurrent, handles.startcurrent, ...
        handles.maxcurrent, handles.increasefactor, handles.halftime, handles.delaytime, ...
        handles.vvsi_auto_safe};
for i = 1:16
    cmd = sprintf('handles.disable_on_run{end+1} = handles.electrode%d;', i);
    eval(cmd);
    cmd = sprintf('handles.disable_on_run{end+1} = handles.stim%d;', i);
    eval(cmd);
end

for i = 1:16
    cmd = sprintf('set(handles.electrode%d, ''Value'', 0);', i);
    eval(cmd);
    cmd = sprintf('set(handles.stim%d, ''Enable'', ''off'');', i);
    eval(cmd);
    cmd = sprintf('set(handles.stim%d, ''Value'', false);', i);
    eval(cmd);
end

% Open the stimulator

PS_CloseAllStim; % Clean up from last time?  Does no harm...

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
        handles.open = true;
end

nstim = PS_GetNStim;
if nstim > 1
    PS_CloseAllStim;
    error('plexon:init', 'Plexon: %d devices available, but Ben assumed only 1!', nstim);
    return;
end


try
    [nchan, err] = PS_GetNChannels(handles.box);
    if err
        ME = MException('plexon:init', 'Plexon: invalid stimulator number "%d".', handles.box);
        throw(ME);
    else
        disp(sprintf('Plexon device %d has %d channels.', handles.box, nchan));
    end
    if nchan ~= 16
        ME = MException('plexon:init', 'Ben assumed that there would always be 16 channels, but there are in fact %d', nchan);
        throw(ME);
    end


    err = PS_SetTriggerMode(handles.box, 0);
    if err
        ME = MException('plexon:stimulate', 'Could not set trigger mode on stimbox %d', handles.box);
        throw(ME);
    end

catch ME
    disp(sprintf('Caught initialisation error %s (%s).  Shutting down...', ME.identifier, ME.message));
    report = getReport(ME);
    err = PS_CloseAllStim;
    handles.open = false;
    rethrow(ME);
end

set(hObject, 'CloseRequestFcn', {@gui_close_callback, handles});
              


%% Open NI acquisition board
dev='Dev2'; % location of input device
channels = [0 1 7];
channel_labels = {'Voltage', 'Current', 'Response', 'error23842'}; % labels for INCHANNELS
daq.reset;
handles.NIsession = daq.createSession('ni');
handles.NIsession.Rate = 100000;
handles.NIsession.IsContinuous = 0;
handles.NIsession.DurationInSeconds = 0.025;
global channel_ranges;
% FIXME Add TTL-triggered acquisition?
%addTriggerConnection(handles.NIsession,'External','Dev1/PFI0','StartTrigger');
% FIXME Slew rate


for i = 1:length(channels)
    addAnalogInputChannel(handles.NIsession, dev, sprintf('ai%d', channels(i)), 'voltage');
    param_names = fieldnames(handles.NIsession.Channels(i));
	handles.NIsession.Channels(i).Name = channel_labels{i};
	%handles.NIsession.Channels(i).Coupling = 'AC';
    handles.NIsession.Channels(i).Range = [-1 1] * channel_ranges(i);
    if length(handles.TerminalConfig) == length(channels)
        foo = i;
    else
        foo = 1;
    end
 	if any(strcmp(param_names,'TerminalConfig'))
 		handles.NIsession.Channels(i).TerminalConfig = handles.TerminalConfig{foo};
 	elseif any(strcmp(param_names,'InputType'))
 		handles.NIsession.Channels(i).InputType = handles.TerminalConfig{foo};
 	else
 		error('Could not set NiDaq input type');
    end
end
addDigitalChannel(handles.NIsession, dev, 'Port0/Line0:1', 'InputOnly');

handles.NI.listeners{1}=addlistener(handles.NIsession, 'DataAvailable',...
	@(obj,event) NIsession_callback(obj, event));
handles.NIsession.NotifyWhenDataAvailableExceeds=round(handles.NIsession.Rate*handles.NIsession.DurationInSeconds);
prepare(handles.NIsession);

axes_top = handles.axes_top;
axes_bottom = handles.axes_bottom;
axes4 = handles.axes4;
axes5 = handles.axes5;

timer_sequence_running = false;

guidata(hObject, handles);





%% Called by NI data acquisition background process at end of acquisition
function NIsession_callback(obj, event)
global VOLTAGE_RANGE_LAST_STIM;
global electrode_last_stim;
global CURRENT_uAMPS;
global stim_electrodes;
global monitor_electrode;
global axes_bottom;
global axes_top;
global axes4;
global axes5;
global rmsbox;
global current_amplification;
global channel_ranges;
global intan_voltage_amplification;
global saving_stimulations;
global halftime_us;
global interpulse_s;
global datadir;
global channels;
global comments;
persistent rmshist;

if isempty(datadir)
    datadir = 'null';
end

% Just to be confusing, the Plexon's voltage monitor channel scales its
% output because, um, TEXAS!
scalefactor_V = 1/PS_GetVmonScaling(1); % V/V !!!!!!!!!!!!!!!!!!!!!!!
scalefactor_i = 400; % uA/mV, always!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
edata = event.Data;
for i = 1:length(channels)
    disp(sprintf('Channel %d (%g V)', ...
                i, max(abs(edata(i,:)))));
    if any(abs(edata(i,:)) > channel_ranges(i))
        disp(sprintf('WARNING: Channel %d (%g V) exceeds expected max voltage %g', ...
                i, max(abs(edata(i,:))), channel_ranges(i)));
    end
end
edata(:,1) = event.Data(:,1) * scalefactor_V;
edata(:,2) = event.Data(:,2) * scalefactor_i / current_amplification;
edata(:,3) = event.Data(:,3) / intan_voltage_amplification;

% FIXME change data.data to edata

data.time = event.TimeStamps;
data.fs = obj.Rate;

triggerchannel = 4;
triggerthreshold = 0.5;

triggertime = event.TimeStamps(find(event.Data(:,triggerchannel) >= triggerthreshold, 1));
if isempty(triggertime)
    disp('No trigger!');
    return;
end    

% times_aligned is data.time aligned so spike=0
times_aligned = event.TimeStamps - triggertime;
beforetrigger = max(times_aligned(1), -0.002);
aftertrigger = min(times_aligned(end), 0.020);

% u: indices into times_aligned that we want to show, aligned and shit.
u = find(times_aligned > beforetrigger & times_aligned < aftertrigger);
% v is the times to show for the pulse
v = find(times_aligned >= -0.001 & times_aligned < 0.001 + 2 * halftime_us/1e6 + interpulse_s);


% Fit the ROI for de-trending.
roifit = [ 0.0015  aftertrigger ];
%roifit = [max(1, roifit(1)) min(length(times), roifit(2))];
roiifit = find(times_aligned >= roifit(1) & times_aligned <= roifit(2));
roitimesfit = times_aligned(roiifit);
lenfit = length(roitimesfit);
weightsfit = linspace(1, 0, lenfit);
%weightsfit = ones(1, lenfit);
f = fit(roitimesfit, edata(roiifit, 3), 'exp1', ...
        'Weight', weightsfit, 'StartPoint', [0 0]);
ff = f.a .* exp(f.b * roitimesfit); % + f.c .* exp(f.d * roitimesfit);

roi = [0.002  0.01];
%roi = [max(1, roi(1)) min(length(times), roi(2))];

roii = find(times_aligned >= roi(1) & times_aligned <= roi(2));
roitimes = times_aligned(roii);
len = length(roitimes);
roitrend = f.a .* exp(f.b * roitimes);% + f.c .* exp(f.d * roitimes);

responses_detrended = edata(roii, 3) - roitrend;



%[B A] = butter(4, 0.1, 'low');

yy = plotyy(axes_bottom, times_aligned(v)*1000, edata(v,1), ...
    times_aligned(v)*1000, edata(v,2));
legend(axes_bottom, {obj.Channels(1).Name obj.Channels(2).Name});
xlabel(axes_bottom, 'ms');
set(get(yy(1),'Ylabel'),'String','V');
set(get(yy(2),'Ylabel'),'String','\mu A');
%set(get(yy(2),'YLim'), [-1 1] * CURRENT_uAMPS * 1.5);
VOLTAGE_RANGE_LAST_STIM = [ max(edata(:,1)) min(edata(:,1))];
electrode_last_stim = monitor_electrode;

plot(axes_top, times_aligned(u)*1000, edata(u,3)*1000);
hold(axes_top, 'on');
plot(axes_top, roitimes*1000, responses_detrended*1000, 'r');
hold(axes_top, 'off');
legend(axes_top, obj.Channels(3).Name, 'Detrended');
ylabel(axes_top, strcat(obj.Channels(3).Name, ' (mV)'));
set(axes_top, 'XLim', [-2 20], 'YLim', [-0.1 0.1]*1000/intan_voltage_amplification);
grid(axes_top, 'on');

%% Blow up the interpulse region--can we align this well?
% What is the max voltage for the first millisecond of acquisition?  This
% is before the pulse, I assume...(?)
beforepulse = find(times_aligned < 0);
beforepulse = beforepulse(1:end-1);
Real_Voltage_RMS = rms(event.Data(beforepulse,1:length(channels)));

if isempty(rmshist)
    rmshist = zeros(50, length(Real_Voltage_RMS));
end

rmshist = [rmshist(2:end, :); Real_Voltage_RMS];
%set(rmsbox, 'String', sprintf('[%s ] uV', ...
%    sprintf('  %.3g', Real_Voltage_RMS * 1e6)));
semilogy(axes5, rmshist);
axis(axes5, 'tight');

interpulse_at = triggertime + halftime_us/1e6;

w = find(times_aligned > halftime_us/1e6 & times_aligned < halftime_us/1e6 + interpulse_s);
w = w(1:end-1);
min_interpulse_volts = min(abs(edata(w,1)))

plot(axes4, times_aligned(w)*1000, edata(w,1));
foo = get(axes4, 'YLim');
%line([1 1] * halftime_us / 1e3, foo, 'Parent', axes4, 'Color', [1 0 0]);

%%% Save for posterity!
file_basename = 'stim';
file_format = 'yyyymmdd_HHMMSS.FFF';
nchannels = length(obj.Channels);

data.current = CURRENT_uAMPS;
data.data = edata;
data.time = event.TimeStamps;
data.times_aligned = times_aligned;
data.stim_electrodes = stim_electrodes;
data.monitor_electrode = monitor_electrode;
data.fs = obj.Rate;
data.labels = {};
data.names = {};
data.triggertime = triggertime;
data.parameters.sensor_range = {};
data.comments = comments;

for i=1:nchannels
	data.labels{i} = obj.Channels(i).ID;
	data.names{i} = obj.Channels(i).Name;
	%data.parameters.sensor_range{i} = obj.Channels(i).Range;
end

if saving_stimulations
    datafile_name = [ file_basename '_' datestr(now, file_format) '.mat' ];
    if ~exist(datadir, 'dir')
        mkdir(datadir);
    end

    save(fullfile(datadir, datafile_name), 'data');
end





function gui_close_callback(hObject, callbackdata, handles)

global vvsi;
global timer_sequence_running;
global datadir;

disp('Shutting down...');
handles.timer = clear_timer(handles.timer);
if ~isempty(handles.NIsession)
    stop(handles.NIsession);
    release(handles.NIsession);
    handles.NIsession = [];
end
if handles.open
    err = PS_CloseAllStim;
    if err
        msgbox({'ERROR CLOSING STIMULATOR', 'Could not contact Plexon stimulator for shutdown!'});
    end
else
     msgbox({'ERROR CLOSING STIMULATOR', 'Could not contact Plexon stimulator for shutdown!'});
end

timer_sequence_running = false;

file_format = 'yyyymmdd_HHMMSS.FFF';
file_basename = 'vvsi';
datafile_name = [ file_basename '_' datestr(now, file_format) '.mat' ];
if ~exist(datadir, 'dir')
	mkdir(datadir);
end
save(fullfile(datadir, datafile_name), 'vvsi');
delete(hObject);


% UIWAIT makes plexme wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = plexme_OutputFcn(hObject, eventdata, handles) 
varargout{1} = handles.output;




% --- Executes on button press in negativefirst.
function negativefirst_Callback(hObject, eventdata, handles)
global NEGFIRST;
NEGFIRST = get(hObject, 'Value');
global CURRENT_uAMPS;
CURRENT_uAMPS = handles.START_uAMPS;
set(handles.currentcurrent, 'String', sprintf('%.2g', CURRENT_uAMPS));
guidata(hObject, handles);



function startcurrent_Callback(hObject, eventdata, handles)
handles.START_uAMPS = str2double(get(hObject,'String'));
guidata(hObject, handles);


% --- Executes during object creation, after setting all properties.
function startcurrent_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function maxcurrent_Callback(hObject, eventdata, handles)
handles.MAX_uAMPS = str2double(get(hObject,'String'));
guidata(hObject, handles);


% --- Executes during object creation, after setting all properties.
function maxcurrent_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end




function increasefactor_Callback(hObject, eventdata, handles)
handles.INCREASE_STEP = str2double(get(hObject,'String'));
guidata(hObject, handles);


% --- Executes during object creation, after setting all properties.
function increasefactor_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function halftime_Callback(hObject, eventdata, handles)
global default_halftime_us;
global halftime_us;
default_halftime_us = str2double(get(hObject,'String'));
halftime_us = default_halftime_us;
guidata(hObject, handles);


% --- Executes during object creation, after setting all properties.
function halftime_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function delaytime_Callback(hObject, eventdata, handles)
handles.INTERSPIKE_S = str2double(get(hObject,'String'));
guidata(hObject, handles);


% --- Executes during object creation, after setting all properties.
function delaytime_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function electrode_universal_callback(hObject, eventdata, handles)
whichone = str2num(hObject.String);
value = get(hObject, 'Value');
handles.valid(whichone) = value;
if handles.valid(whichone)
        newstate = 'on';
else
        newstate = 'off';
end
% "stimulate this electrode" should be enabled or disabled according to the
% state of this button
cmd = sprintf('set(handles.stim%d, ''Enable'', ''%s'');', whichone, newstate);
eval(cmd);
% "stimulate this electrode" should default to 0...
cmd = sprintf('set(handles.stim%d, ''Value'', 0);', whichone);
eval(cmd);
handles.stim(whichone) = 0;
if 0 % This was for when stimAll was a persistent variable.
    % ...unless...
    if handles.stimAll
        % Set the "stimulate this electrode" value to match
        cmd = sprintf('prev = get(handles.stim%d, ''Value'');', whichone);
        eval(cmd);
        cmd = sprintf('set(handles.stim%d, ''Value'', %d);', whichone, value);
        eval(cmd);
        % Set the bookkeeping structure
        handles.stim(whichone) = value;
        if prev ~= value
            global CURRENT_uAMPS;
            CURRENT_uAMPS = handles.START_uAMPS;
            set(handles.currentcurrent, 'String', sprintf('%.2g', CURRENT_uAMPS));
        end
    end
end
update_monitor_electrodes(hObject, eventdata, handles);
guidata(hObject, handles);



% --- Executes on button press in electrode1.
function electrode1_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);

function electrode2_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);


% --- Executes on button press in electrode3.
function electrode3_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);


% --- Executes on button press in electrode4.
function electrode4_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);


% --- Executes on button press in electrode5.
function electrode5_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);


% --- Executes on button press in electrode6.
function electrode6_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);


% --- Executes on button press in electrode7.
function electrode7_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);


% --- Executes on button press in electrode8.
function electrode8_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);


% --- Executes on button press in electrode9.
function electrode9_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);


% --- Executes on button press in electrode10.
function electrode10_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);


% --- Executes on button press in electrode11.
function electrode11_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);


% --- Executes on button press in electrode12.
function electrode12_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);


% --- Executes on button press in electrode13.
function electrode13_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);

% --- Executes on button press in electrode14.
function electrode14_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);

% --- Executes on button press in electrode15.
function electrode15_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);


% --- Executes on button press in electrode16.
function electrode16_Callback(hObject, eventdata, handles)
electrode_universal_callback(hObject, eventdata, handles);



% --- Executes on selection change in electrode.
function monitor_electrode_control_Callback(hObject, eventdata, handles)
global monitor_electrode;
which_valid_electrode = get(handles.monitor_electrode_control, 'Value');
valid_electrode_strings = get(handles.monitor_electrode_control, 'String');
monitor_electrode = str2num(valid_electrode_strings{which_valid_electrode});

%handles.monitor_electrode = get(hObject, 'Value'); % Only works because all 16 are present! v(5)=5
update_monitor_electrodes(hObject, eventdata, handles);
guidata(hObject, handles);

% --- Executes during object creation, after setting all properties.
function monitor_electrode_control_CreateFcn(hObject, eventdata, handles)
set(hObject, 'BackgroundColor', [0.8 0.2 0.1]);



function start_timer(hObject, handles)

% Clean up any stopped timers
if ~isempty(handles.timer)
    a(0)
end

disable_controls(hObject, handles);
handles.timer = timer('Period', handles.INTERSPIKE_S, 'ExecutionMode', 'fixedSpacing');
handles.timer.TimerFcn = {@plexon_control_timer_callback_2, hObject, handles};
handles.timer.StartFcn = {@plexon_start_timer_callback, hObject, handles};
handles.timer.StopFcn = {@plexon_stop_timer_callback, hObject, handles};
handles.timer.ErrorFcn = {@plexon_error_timer_callback, hObject, handles};
start(handles.timer);
guidata(hObject, handles);



% --- Executes on button press in increase.
function increase_Callback(hObject, eventdata, handles)
global change;
global increase_type;
global halftime_us;
global default_halftime_us;

halftime_us = default_halftime_us;
increase_type = 'current';
change = handles.INCREASE_STEP;
if isempty(handles.timer)
    start_timer(hObject, handles);
end
guidata(hObject, handles);


% --- Executes on button press in decrease.
function decrease_Callback(hObject, eventdata, handles)
global change;
global increase_type;
global halftime_us;
global default_halftime_us;

halftime_us = default_halftime_us;
increase_type = 'current';
change = 1/handles.INCREASE_STEP;
if isempty(handles.timer)
    start_timer(hObject, handles);
end
guidata(hObject, handles);


% --- Executes on button press in hold.
function hold_Callback(hObject, eventdata, handles)
global change;
global increase_type;
global halftime_us;
global default_halftime_us;

halftime_us = default_halftime_us;
increase_type = 'current';
change = 1;
if isempty(handles.timer)
    start_timer(hObject, handles);
end
guidata(hObject, handles);


% --- Executes on button press in stop.
function stop_Callback(hObject, eventdata, handles)
global vvsi;
global monitor_electrode;
global axes_top;
global increase_type;

disp('Stopping everything...');

PS_StopStimAllChannels(handles.box);

if ~isempty(handles.timer)
    if isvalid(handles.timer)
        stop(handles.timer); % this also stops and closes the Plexon box
    end
    delete(handles.timer);
    handles.timer = [];
end

if ~isempty(vvsi)
    this_electrode = find(vvsi(:,1) == monitor_electrode);
    if false
        cla(axes_top);
        hold(axes_top, 'on');
        switch increase_type
            case 'current'
                abscissa = 2;
            case 'time'
                abscissa = 6;
        end
        scatter(axes_top, vvsi(this_electrode,abscissa), vvsi(this_electrode,4), 'b');
        scatter(axes_top, vvsi(this_electrode,abscissa), vvsi(this_electrode,5), 'r');
        hold(axes_top, 'off');
    end
    %set(axes_top, 'YLim', [min(vvsi(this_electrode,5)) max(vvsi(this_electrode,4))]);
end

guidata(hObject, handles);



function currentcurrent_Callback(hObject, eventdata, handles)
newcurrent = str2double(get(hObject, 'String'));
global CURRENT_uAMPS;
if isnan(newcurrent)
        set(hObject, 'String', sprintf('%.2g', CURRENT_uAMPS));
elseif newcurrent < handles.START_uAMPS
        CURRENT_uAMPS = handles.START_uAMPS;
elseif newcurrent > handles.MAX_uAMPS
        CURRENT_uAMPS = handles.MAX_uAMPS;
else
        CURRENT_uAMPS = newcurrent;
end
set(hObject, 'String', sprintf('%.2g', CURRENT_uAMPS));
guidata(hObject, handles);


% --- Executes during object creation, after setting all properties.
function currentcurrent_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function disable_controls(hObject, handles)
for i = 1:length(handles.disable_on_run)
        set(handles.disable_on_run{i}, 'Enable', 'off');
end



function enable_controls(hObject, handles)
global known_invalid;

for i = 1:length(handles.disable_on_run)
        set(handles.disable_on_run{i}, 'Enable', 'on');
end
% Yeah, but we don't want to enable all the "stim" checkboxes, but rather
% only the valid ones.  *sigh*.  They get disabled with the rest of the
% interface on start-stim, and re-enabled on stop-stim, so now let's update
% them as a special case.
for i = 1:16
    if handles.valid(i)
            status = 'on';
    else
            status = 'off';
    end
    cmd = sprintf('set(handles.stim%d, ''Enable'', ''%s'');', i, status);
    eval(cmd);
end


% When any of the "start sequence" buttons is pressed, open the Plexon box
% and do some basic error checking.  Set all channels to nil.
function plexon_start_timer_callback(obj, event, hObject, handles)

global CURRENT_uAMPS;
global change;
global NEGFIRST;

try
    NullPattern.W1 = 0;
    NullPattern.W2 = 0;
    NullPattern.A1 = 0;
    NullPattern.A2 = 0;
    NullPattern.Delay = 0;

    for channel = find(~handles.stim)
        err = PS_SetPatternType(handles.box, channel, 0);
        if err
            ME = MException('plexon:pattern', 'Could not set pattern type on channel %d', channel);
            throw(ME);
        end

        err = PS_SetRectParam2(handles.box, channel, NullPattern);
        if err
                ME = MException('plexon:pattern', 'Could not set NULL pattern parameters on channel %d', channel);
                throw(ME);
        end

        err = PS_SetRepetitions(1, channel, 1);
        if err
            ME = MException('plexon:pattern', 'Could not set repetition on channel %d', channel);
            throw(ME);
        end

        err = PS_LoadChannel(handles.box, channel);
        if err
            ME = MException('plexon:stimulate', 'Could not stimulate on box %d channel %d: %s', handles.box, channel, PS_GetExtendedErrorInfo(err));    
            throw(ME);
        end
    end
catch ME
    disp(sprintf('Caught the error %s (%s).  Shutting down...', ME.identifier, ME.message));
    report = getReport(ME)
    PS_StopStimAllChannels(handles.box);
    guidata(hObject, handles);
    rethrow(ME);
end

guidata(hObject, handles);


function plexon_stop_timer_callback(obj, event, hObject, handles)
timer_sequence_running = false;
err = PS_StopStimAllChannels(handles.box);
if err
    msgbox('ERROR stopping stimulation (@stop)!!!!');
end
enable_controls(hObject, handles);
guidata(hObject, handles);


function plexon_error_timer_callback(obj, event, hObject, handles)
disp('Caught an error in the timer callback... Stopping...');
timer_sequence_running = false;
err = PS_StopStimAllChannels(handles.box);
if err
    msgbox('ERROR stopping stimulation (@error)!!!!');
end
guidata(hObject, handles);


function stim_universal_callback(hObject, eventdata, handles)
global monitor_electrode;
whichone = str2num(hObject.String);
newval = get(hObject, 'Value');
if get(handles.stimMultiple, 'Value') == false & newval == 1 & sum(handles.stim) > 0
    for i = find(handles.stim)
        cmd = sprintf('set(handles.stim%d, ''Value'', 0);', i);
        eval(cmd);
        handles.stim(i) = 0;
    end
end
handles.stim(whichone) = newval;
global CURRENT_uAMPS;
CURRENT_uAMPS = handles.START_uAMPS;
set(handles.currentcurrent, 'String', sprintf('%.2g', CURRENT_uAMPS));
if handles.stim(whichone)
    monitor_electrode = whichone;
end
update_monitor_electrodes(hObject, eventdata, handles);
guidata(hObject, handles);


function update_monitor_electrodes(hObject, eventdata, handles)
global monitor_electrode;
set(handles.monitor_electrode_control, 'Value', monitor_electrode);
if handles.stim(monitor_electrode)  
    set(handles.monitor_electrode_control, 'BackgroundColor', [0.1 0.8 0.1]);
else
    set(handles.monitor_electrode_control, 'BackgroundColor', [0.8 0.2 0.1]);
end
guidata(hObject, handles);

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
for i = find(handles.valid)
    cmd = sprintf('set(handles.stim%d, ''Value'', 1);', i);
    eval(cmd);
    handles.stim(i) = 1;
end
update_monitor_electrodes(hObject, eventdata, handles);
guidata(hObject, handles);








function plexon_control_timer_callback_2(obj, event, hObject, handles)

global increase_type;
global CURRENT_uAMPS;
global default_halftime_us;
global halftime_us;
global interpulse_s;
global max_current;
global max_halftime;
global change;
global NEGFIRST;
global VOLTAGE_RANGE_LAST_STIM;
global electrode_last_stim;
global stim_electrodes;
global monitor_electrode;
global timer_sequence_running;

global vvsi;  % Voltages vs current for each stimulation

switch increase_type
    case 'current'
        CURRENT_uAMPS = min(handles.MAX_uAMPS, CURRENT_uAMPS * change);
        set(handles.currentcurrent, 'String', sprintf('%.3g', CURRENT_uAMPS));
    case 'time'
        halftime_us = min(default_halftime_us, halftime_us * change);
        set(handles.halftime, 'String', sprintf('%.3g', halftime_us));
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
    StimParam.W1 = halftime_us;
    StimParam.W2 = halftime_us;
    StimParam.Delay = interpulse_s * 1e6;
    
    NullPattern.W1 = 0;
    NullPattern.W2 = 0;
    NullPattern.A1 = 0;
    NullPattern.A2 = 0;
    NullPattern.Delay = 0;

    % If no monitor_electrode is selected, just fail silently and let the user figure
    % out what's going on :)
    if monitor_electrode > 0 & monitor_electrode <= 16
        err = PS_SetMonitorChannel(handles.box, monitor_electrode);
        if err
            ME = MException('plexon:monitor', 'Could not set monitor channel to %d', monitor_electrode);
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
    
    % The NI data acquisition callback can't see handles, so this is where
    % we put stuff that it needs!
    stim_electrodes = handles.stim;
    
    % Start it!
    handles.NIsession.startBackground;
    err = PS_StartStimAllChannels(handles.box);
    if err
        handles.NIsession.stop;
        ME = MException('plexon:stimulate', 'Could not stimulate on box %d: %s', handles.box, PS_GetExtendedErrorInfo(err));
        throw(ME);
    end
    handles.NIsession.wait;  % This callback needs to be interruptible!  Apparently it is??
     
    vvsi(end+1, :) = [ monitor_electrode CURRENT_uAMPS NEGFIRST VOLTAGE_RANGE_LAST_STIM halftime_us];
    if max(abs(VOLTAGE_RANGE_LAST_STIM)) < handles.VoltageLimit
        % We can safely stimulate with these parameters
        if monitor_electrode == electrode_last_stim
            max_current(monitor_electrode) = CURRENT_uAMPS;
            max_halftime(monitor_electrode) = halftime_us;
        end
    else
        % Dangerous voltage detected!
        %ME = MException('plexon:stimulate:brokenElectrode', 'Channel %d (Intan %d) is pulling [ %.2g %.2g ] volts.  Stopping.', ...
            %channel, map_plexon_pin_to_intan(channel, handles), VOLTAGE_RANGE_LAST_STIM(1), VOLTAGE_RANGE_LAST_STIM(2));    
        %throw(ME);
        disp(sprintf('WARNING: Channel %d (Intan %d) is pulling [ %.3g %.3g ] V @ %.3g uA, %dx2 us.', ...
            channel, map_plexon_pin_to_intan(channel, handles), VOLTAGE_RANGE_LAST_STIM(1), ...
            VOLTAGE_RANGE_LAST_STIM(2), CURRENT_uAMPS, round(halftime_us)));
        stop(handles.timer);
        
        % Find the maximum current at which voltage was < handles.VoltageLimit
        %handles.voltage_at_max_current(1:2, monitor_electrode) = VOLTAGE_RANGE_LAST_STIM;
        switch increase_type
            case 'current'
                if isnan(max_current(monitor_electrode))
                    maxistring = '***';
                else
                    maxistring = sprintf('%.3g uA', max_current(monitor_electrode));
                end
                eval(sprintf('set(handles.maxi%d, ''String'', ''%s'');', monitor_electrode, maxistring));
            case 'time'
                if isnan(max_halftime(monitor_electrode))
                    maxistring = '***';
                else
                    maxistring = sprintf('%.3g us', max_halftime(monitor_electrode));
                end
                eval(sprintf('set(handles.maxi%d, ''String'', ''%s'');', monitor_electrode, maxistring));
        end
                
        timer_sequence_running = false;
    end
    
    
    % We've maxed out... what to do?  We can inform the user that
    % we could perhaps go higher...

    switch increase_type
        case 'current'
            if CURRENT_uAMPS == handles.MAX_uAMPS
                stop(handles.timer);
                maxistring = sprintf('> %.3g uA', max_current(monitor_electrode));
                eval(sprintf('set(handles.maxi%d, ''String'', ''%s +'');', monitor_electrode, maxistring));
                timer_sequence_running = false;
            end
        case 'time'
            if halftime_us == default_halftime_us
                stop(handles.timer);
                maxistring = sprintf('> %.3g us', max_halftime(monitor_electrode));
                eval(sprintf('set(handles.maxi%d, ''String'', ''%s'');', monitor_electrode, maxistring));
                timer_sequence_running = false;
            end
    end

catch ME
    
    errordlg(ME.message, 'Error', 'modal');
    disp(sprintf('Caught the error %s (%s).  Shutting down...', ME.identifier, ME.message));
    report = getReport(ME)
    rethrow(ME);
end

% guidata(hObject, handles) does no good here!!!
  guidata(hObject, handles);


% --- Executes on button press in stimMultiple.
function stimMultiple_Callback(hObject, eventdata, handles)
global known_invalid;

val = get(hObject, 'Value');
if val
    set(handles.select_all_valid, 'Enable', 'on');
else
    set(handles.select_all_valid, 'Enable', 'off');
end
if ~val & sum(handles.stim) > 1
    % Turn off stimulation to all electrodes
    for i = 1:16
        cmd = sprintf('set(handles.stim%d, ''Value'', false);', i);
        eval(cmd);
    end
    handles.stim = zeros(1, 16);
    update_monitor_electrodes(hObject, eventdata, handles)
end
guidata(hObject, handles);


% --- Executes on button press in vvsi_auto_safe.
function vvsi_auto_safe_Callback(hObject, eventdata, handles)
% Set us up as if we'd reset to 1 and hit "increase"
global increase_type;
global default_halftime_us;
global halftime_us;
global CURRENT_uAMPS;
global change;
global monitor_electrode;
global timer_sequence_running;
global max_halftime;
global known_invalid;

change = 1.1;

max_halftime = NaN * ones(1, 16);

handles.INTERSPIKE_S = 0.01;

increase_type = 'time';

for i = find(handles.valid)
    halftime_us = 50;
    CURRENT_uAMPS = handles.START_uAMPS;
    handles.stim = zeros(1, 16);
    handles.stim(i) = 1;
    monitor_electrode = i;
    set(handles.monitor_electrode_control, 'Value', i);
    
    handles.timer = clear_timer(handles.timer);
    
    timer_sequence_running = true;
    start_timer(hObject, handles);
    while timer_sequence_running
        pause(0.1);
    end
end
handles.timer = clear_timer(handles.timer);

halftime_us = default_halftime_us;

known_invalid = known_invalid | (~isnan(max_halftime) & max_halftime < default_halftime_us)
for i = find(known_invalid)
    eval(sprintf('set(handles.electrode%d, ''Value'', 0, ''Enable'', ''off'');', i));
    eval(sprintf('set(handles.stim%d, ''Value'', 0, ''Enable'', ''off'');', i));
end



function empty = clear_timer(obj);
disp('Clearing timer');
if ~isempty(obj)
    disp('Timer handle exists');
    if isvalid(obj)
        disp('Timer handle is valid');
        stop(obj);
        delete(obj);
    end
    clear(obj);
    obj = [];
end
empty = [];
return;



% --- Executes on button press in mark_all.
function mark_all_Callback(hObject, eventdata, handles)
global known_invalid;

handles.valid = ones(1, 16) & ~known_invalid;
for whichone = 1:16
    handles.valid(whichone) = true;
    newstate = 'on';
    % "stimulate this electrode" should be enabled or disabled according to the
    % state of this button
    eval(sprintf('set(handles.electrode%d, ''Value'', 1);', whichone));
    eval(sprintf('set(handles.stim%d, ''Enable'', ''%s'');', whichone, newstate));
end
update_monitor_electrodes(hObject, eventdata, handles);

guidata(hObject, handles);


% --- Executes on button press in vvsi_auto_full.
function vvsi_auto_full_Callback(hObject, eventdata, handles)
% Set us up as if we'd reset to 1 and hit "increase"
global increase_type;
global default_halftime_us;
global halftime_us;
global CURRENT_uAMPS;
global change;
global monitor_electrode;
global timer_sequence_running;
global max_current;

max_current = NaN * ones(1, 16);

change = handles.INCREASE_STEP;
halftime_us = default_halftime_us;
handles.INTERSPIKE_S = 0.01;

increase_type = 'current';

for i = find(handles.valid)
    CURRENT_uAMPS = handles.START_uAMPS;
    handles.stim = zeros(1, 16);
    handles.stim(i) = 1;
    monitor_electrode = i;
    set(handles.monitor_electrode_control, 'Value', i);
    
    handles.timer = clear_timer(handles.timer);
    
    timer_sequence_running = true;
    start_timer(hObject, handles);
    while timer_sequence_running
        pause(0.1);
    end
end
handles.timer = clear_timer(handles.timer);

halftime_us = default_halftime_us;




function i_amplification_Callback(hObject, eventdata, handles)
global current_amplification;
current_amplification = str2double(get(hObject,'String'));


% --- Executes during object creation, after setting all properties.
function i_amplification_CreateFcn(hObject, eventdata, handles)
% hObject    handle to i_amplification (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end




% --- Executes on button press in saving.
function saving_Callback(hObject, eventdata, handles)
global saving_stimulations;
saving_stimulations = get(hObject, 'Value');



function birdname_Callback(hObject, eventdata, handles)
global datadir;

datadir = strcat(get(hObject,'String'), '-', datestr(now, 'yyyy-mm-dd'));
set(hObject, 'BackgroundColor', [0 0.8 0]);

% --- Executes during object creation, after setting all properties.
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
% hObject    handle to comments (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
