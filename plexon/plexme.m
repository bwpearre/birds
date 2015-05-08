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

% Last Modified by GUIDE v2.5 07-May-2015 18:47:27

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




function [ intan_pin] = map_plexon_pin_to_intan(plexon_pin)
intan_pin = handles.PIN_NAMES(2, find(handles.PIN_NAMES(1,:) == plexon_pin));


function [ plexon_pin] = map_intan_pin_to_plexon(intan_pin)
plexon_pin = handles.PIN_NAMES(1, find(handles.PIN_NAMES(2,:) == intan_pin));



% --- Executes just before plexme is made visible.
function plexme_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to plexme (see VARARGIN)


% Choose default command line output for plexme
handles.output = hObject;

handles.START_uAMPS = 10;
handles.MAX_uAMPS = 200;
handles.INCREASE_STEP = 1.1;
handles.change = handles.INCREASE_STEP;
handles.HALF_TIME_uS = 400;
handles.INTERSPIKE_S = 1;
handles.NEGFIRST = false;
handles.VALID_ELECTRODES = zeros(1, 16);
handles.ELECTRODE = ' ';
handles.timer = [];

global CURRENT_uAMPS;
CURRENT_uAMPS = handles.START_uAMPS;

% Top row is the names of pins on the Plexon.  Bottom row is corresponding
% pins on the Intan.
handles.PIN_NAMES = [ 1  2  3  4  5  6  7  8  9  10  11  12  13  14  15  16 ; ...
                      0  0  0  0  0  0  0  0  0   0   0   0   0   0   0   0 ];


set(handles.startcurrent, 'String', sprintf('%d', round(handles.START_uAMPS)));
set(handles.currentcurrent, 'String', sprintf('%.3g', CURRENT_uAMPS));
set(handles.maxcurrent, 'String', sprintf('%d', round(handles.MAX_uAMPS)));
set(handles.increasefactor, 'String', sprintf('%g', handles.INCREASE_STEP));
set(handles.halftime, 'String', sprintf('%d', round(handles.HALF_TIME_uS)));
set(handles.delaytime, 'String', sprintf('%g', handles.INTERSPIKE_S));
set(handles.negativefirst, 'Value', handles.NEGFIRST);

handles.disable_on_run = { handles.currentcurrent, handles.electrode, handles.startcurrent, ...
        handles.maxcurrent, handles.increasefactor, handles.halftime, handles.delaytime};
              
% Update handles structure

guidata(hObject, handles);




% UIWAIT makes plexme wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = plexme_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;




% --- Executes on button press in negativefirst.
function negativefirst_Callback(hObject, eventdata, handles)
handles.NEGFIRST = get(hObject, 'Value');
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
handles.HALF_TIME_uS = str2double(get(hObject,'String'));
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


% --- Executes on button press in electrode1.
function electrode1_Callback(hObject, eventdata, handles)
handles.valid_electrodes(str2num(hObject.String)) = get(hObject, 'Value');
newvals = {' '};
for i = find(handles.valid_electrodes)
        newvals = [newvals sprintf('%d', i)];
end
set(handles.electrode, 'String', newvals);
if get(handles.electrode, 'Value') > length(newvals)
        set(handles.electrode, 'Value', 1);
end
guidata(hObject, handles);


function electrode2_Callback(hObject, eventdata, handles)
handles.valid_electrodes(str2num(hObject.String)) = get(hObject, 'Value');
newvals = {' '};
for i = find(handles.valid_electrodes)
        newvals = [newvals sprintf('%d', i)];
end
set(handles.electrode, 'String', newvals);
if get(handles.electrode, 'Value') > length(newvals)
        set(handles.electrode, 'Value', 1);
end
guidata(hObject, handles);


% --- Executes on button press in electrode3.
function electrode3_Callback(hObject, eventdata, handles)
handles.valid_electrodes(str2num(hObject.String)) = get(hObject, 'Value');
newvals = {' '};
for i = find(handles.valid_electrodes)
        newvals = [newvals sprintf('%d', i)];
end
set(handles.electrode, 'String', newvals);
if get(handles.electrode, 'Value') > length(newvals)
        set(handles.electrode, 'Value', 1);
end
guidata(hObject, handles);


% --- Executes on button press in electrode4.
function electrode4_Callback(hObject, eventdata, handles)
handles.valid_electrodes(str2num(hObject.String)) = get(hObject, 'Value');
newvals = {' '};
for i = find(handles.valid_electrodes)
        newvals = [newvals sprintf('%d', i)];
end
set(handles.electrode, 'String', newvals);
if get(handles.electrode, 'Value') > length(newvals)
        set(handles.electrode, 'Value', 1);
end
guidata(hObject, handles);


% --- Executes on button press in electrode5.
function electrode5_Callback(hObject, eventdata, handles)
handles.valid_electrodes(str2num(hObject.String)) = get(hObject, 'Value');
newvals = {' '};
for i = find(handles.valid_electrodes)
        newvals = [newvals sprintf('%d', i)];
end
set(handles.electrode, 'String', newvals);
if get(handles.electrode, 'Value') > length(newvals)
        set(handles.electrode, 'Value', 1);
end
guidata(hObject, handles);


% --- Executes on button press in electrode6.
function electrode6_Callback(hObject, eventdata, handles)
handles.valid_electrodes(str2num(hObject.String)) = get(hObject, 'Value');
newvals = {' '};
for i = find(handles.valid_electrodes)
        newvals = [newvals sprintf('%d', i)];
end
set(handles.electrode, 'String', newvals);
if get(handles.electrode, 'Value') > length(newvals)
        set(handles.electrode, 'Value', 1);
end
guidata(hObject, handles);


% --- Executes on button press in electrode7.
function electrode7_Callback(hObject, eventdata, handles)
handles.valid_electrodes(str2num(hObject.String)) = get(hObject, 'Value');
newvals = {' '};
for i = find(handles.valid_electrodes)
        newvals = [newvals sprintf('%d', i)];
end
set(handles.electrode, 'String', newvals);
if get(handles.electrode, 'Value') > length(newvals)
        set(handles.electrode, 'Value', 1);
end
guidata(hObject, handles);


% --- Executes on button press in electrode8.
function electrode8_Callback(hObject, eventdata, handles)
handles.valid_electrodes(str2num(hObject.String)) = get(hObject, 'Value');
newvals = {' '};
for i = find(handles.valid_electrodes)
        newvals = [newvals sprintf('%d', i)];
end
set(handles.electrode, 'String', newvals);
if get(handles.electrode, 'Value') > length(newvals)
        set(handles.electrode, 'Value', 1);
end
guidata(hObject, handles);


% --- Executes on button press in electrode9.
function electrode9_Callback(hObject, eventdata, handles)
handles.valid_electrodes(str2num(hObject.String)) = get(hObject, 'Value');
handles.valid_electrodes(str2num(hObject.String)) = get(hObject, 'Value');
newvals = {' '};
for i = find(handles.valid_electrodes)
        newvals = [newvals sprintf('%d', i)];
end
set(handles.electrode, 'String', newvals);
if get(handles.electrode, 'Value') > length(newvals)
        set(handles.electrode, 'Value', 1);
end
guidata(hObject, handles);


% --- Executes on button press in electrode10.
function electrode10_Callback(hObject, eventdata, handles)
handles.valid_electrodes(str2num(hObject.String)) = get(hObject, 'Value');
handles.valid_electrodes(str2num(hObject.String)) = get(hObject, 'Value');
newvals = {' '};
for i = find(handles.valid_electrodes)
        newvals = [newvals sprintf('%d', i)];
end
set(handles.electrode, 'String', newvals);
if get(handles.electrode, 'Value') > length(newvals)
        set(handles.electrode, 'Value', 1);
end
guidata(hObject, handles);


% --- Executes on button press in electrode11.
function electrode11_Callback(hObject, eventdata, handles)
handles.valid_electrodes(str2num(hObject.String)) = get(hObject, 'Value');
newvals = {' '};
for i = find(handles.valid_electrodes)
        newvals = [newvals sprintf('%d', i)];
end
set(handles.electrode, 'String', newvals);
if get(handles.electrode, 'Value') > length(newvals)
        set(handles.electrode, 'Value', 1);
end
guidata(hObject, handles);


% --- Executes on button press in electrode15.
function electrode15_Callback(hObject, eventdata, handles)
handles.valid_electrodes(str2num(hObject.String)) = get(hObject, 'Value');
newvals = {' '};
for i = find(handles.valid_electrodes)
        newvals = [newvals sprintf('%d', i)];
end
set(handles.electrode, 'String', newvals);
if get(handles.electrode, 'Value') > length(newvals)
        set(handles.electrode, 'Value', 1);
end
guidata(hObject, handles);


% --- Executes on button press in electrode16.
function electrode16_Callback(hObject, eventdata, handles)
handles.valid_electrodes(str2num(hObject.String)) = get(hObject, 'Value');
newvals = {' '};
for i = find(handles.valid_electrodes)
        newvals = [newvals sprintf('%d', i)];
end
set(handles.electrode, 'String', newvals);
if get(handles.electrode, 'Value') > length(newvals)
        set(handles.electrode, 'Value', 1);
end
guidata(hObject, handles);


% --- Executes on button press in electrode14.
function electrode14_Callback(hObject, eventdata, handles)
handles.valid_electrodes(str2num(hObject.String)) = get(hObject, 'Value');
newvals = {' '};
for i = find(handles.valid_electrodes)
        newvals = [newvals sprintf('%d', i)];
end
set(handles.electrode, 'String', newvals);
if get(handles.electrode, 'Value') > length(newvals)
        set(handles.electrode, 'Value', 1);
end
guidata(hObject, handles);


% --- Executes on button press in electrode12.
function electrode12_Callback(hObject, eventdata, handles)
handles.valid_electrodes(str2num(hObject.String)) = get(hObject, 'Value');
newvals = {' '};
for i = find(handles.valid_electrodes)
        newvals = [newvals sprintf('%d', i)];
end
set(handles.electrode, 'String', newvals);
if get(handles.electrode, 'Value') > length(newvals)
        set(handles.electrode, 'Value', 1);
end
guidata(hObject, handles);


% --- Executes on button press in electrode13.
function electrode13_Callback(hObject, eventdata, handles)
handles.valid_electrodes(str2num(hObject.String)) = get(hObject, 'Value');
newvals = {' '};
for i = find(handles.valid_electrodes)
        newvals = [newvals sprintf('%d', i)];
end
set(handles.electrode, 'String', newvals);
if get(handles.electrode, 'Value') > length(newvals)
        set(handles.electrode, 'Value', 1);
end
guidata(hObject, handles);


% --- Executes on button press in increase.
function increase_Callback(hObject, eventdata, handles)
disable_controls(hObject, handles);
if ~isempty(handles.timer)
        stop(handles.timer);
        delete(handles.timer);
end
global CURRENT_uAMPS;
handles.change = handles.INCREASE_STEP;
handles.timer = timer('Period', handles.INTERSPIKE_S, 'ExecutionMode', 'fixedRate');
handles.timer.TimerFcn = {@plexon_control_timer_callback, hObject, handles};
handles.timer.StartFcn = {@plexon_start_timer_callback, hObject, handles};
handles.timer.StopFcn = {@plexon_stop_timer_callback, hObject, handles};
handles.timer.ErrorFcn = {@plexon_error_timer_callback, hObject, handles};
start(handles.timer);
guidata(hObject, handles);


% --- Executes on button press in decrease.
function decrease_Callback(hObject, eventdata, handles)
disable_controls(hObject, handles);
if ~isempty(handles.timer)
        stop(handles.timer);
        delete(handles.timer);
end
global CURRENT_uAMPS;
handles.change = 1/handles.INCREASE_STEP;
handles.timer = timer('Period', handles.INTERSPIKE_S, 'ExecutionMode', 'fixedRate');
handles.timer.TimerFcn = {@plexon_control_timer_callback, hObject, handles};
handles.timer.StartFcn = {@plexon_start_timer_callback, hObject, handles};
handles.timer.StopFcn = {@plexon_stop_timer_callback, hObject, handles};
handles.timer.ErrorFcn = {@plexon_error_timer_callback, hObject, handles};
start(handles.timer);
guidata(hObject, handles);


% --- Executes on button press in hold.
function hold_Callback(hObject, eventdata, handles)
disable_controls(hObject, handles);
if ~isempty(handles.timer)
        stop(handles.timer);
        delete(handles.timer);
end
global CURRENT_uAMPS;
handles.change = 1;
handles.timer = timer('Period', handles.INTERSPIKE_S, 'ExecutionMode', 'fixedRate');
handles.timer.TimerFcn = {@plexon_control_timer_callback, hObject, handles};
handles.timer.StartFcn = {@plexon_start_timer_callback, hObject, handles};
handles.timer.StopFcn = {@plexon_stop_timer_callback, hObject, handles};
handles.timer.ErrorFcn = {@plexon_error_timer_callback, hObject, handles};
start(handles.timer);
guidata(hObject, handles);


% --- Executes on button press in stop.
function stop_Callback(hObject, eventdata, handles)
% hObject    handle to stop (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
enable_controls(hObject, handles);
if ~isempty(handles.timer)
        stop(handles.timer);
        delete(handles.timer);
end
handles.timer = [];
guidata(hObject, handles);


% --- Executes on selection change in electrode.
function electrode_Callback(hObject, eventdata, handles)
handles.ELECTRODE = get(hObject, 'Value');
guidata(hObject, handles);

% --- Executes during object creation, after setting all properties.
function electrode_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function currentcurrent_Callback(hObject, eventdata, handles)
newcurrent = str2double(get(hObject, 'String'));
global CURRENT_uAMPS;
if isnan(newcurrent)
        set(hObject, 'String', sprintf('%3g', CURRENT_uAMPS));
elseif newcurrent < handles.START_uAMPS
        CURRENT_uAMPS = handles.START_uAMPS;
elseif newcurrent > handles.MAX_uAMPS
        CURRENT_uAMPS = handles.MAX_uAMPS;
else
        CURRENT_uAMPS = newcurrent;
end
set(hObject, 'String', sprintf('%.3g', CURRENT_uAMPS));
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
for i = 1:length(handles.disable_on_run)
        set(handles.disable_on_run{i}, 'Enable', 'on');
end



function plexon_start_timer_callback(obj, event, hObject, handles)
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
catch ME
    disp(sprintf('Caught error %s (%s).  Shutting down...', ME.identifier, ME.message));
    err = PS_CloseAllStim;
    rethrow(ME);
end


function plexon_stop_timer_callback(obj, event, hObject, handles)
err = PS_CloseAllStim;


function plexon_error_timer_callback(obj, event, hObject, handles)
err = PS_CloseAllStim;

