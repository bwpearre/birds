function varargout = inspect(varargin)
% INSPECT MATLAB code for inspect.fig
%      INSPECT, by itself, creates a new INSPECT or raises the existing
%      singleton*.
%
%      H = INSPECT returns the handle to a new INSPECT or the handle to
%      the existing singleton*.
%
%      INSPECT('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in INSPECT.M with the given input arguments.
%
%      INSPECT('Property','Value',...) creates a new INSPECT or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before inspect_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to inspect_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help inspect

% Last Modified by GUIDE v2.5 10-Nov-2015 11:48:05

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @inspect_OpeningFcn, ...
                   'gui_OutputFcn',  @inspect_OutputFcn, ...
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


% --- Executes just before inspect is made visible.
function inspect_OpeningFcn(hObject, eventdata, handles, varargin)
handles.output = hObject;

scriptpath = fileparts(mfilename('fullpath'));
path(sprintf('%s/../lib', scriptpath), path);


global responses_detrended;
global wait_bar;
global tdt_show_now tdt_show_data tdt_show_data_last tdt_show_last_chosen;
global detrend_param;


clear detrend_param;

tdt_show_now = zeros(1, 16);
tdt_show_last_chosen = ones(1, 16);
tdt_show_data = zeros(1, 16);
tdt_show_data_last = zeros(1, 16);

clear nnsetX;

files = dir('stim*');

[sorted_names, sorted_index] = sortrows({files.name}');
handles.files = sorted_names;
handles.sorted_index = sorted_index;
set(handles.listbox1,'String',handles.files,'Value',1);

responses_detrended = [];
if ~isempty(wait_bar)
        close(wait_bar);
        wait_bar = [];
end

% Which channels to show?
for i = 1:16
    handles.tdt_show_buttons{i} = uicontrol('Style','checkbox','String', sprintf('%d', i), ...
                       'Value',0,'Position', [920 570-22*(i-1) 50 20], ...
                        'Callback',{@tdt_show_channel_Callback});
end


guidata(hObject, handles);



function tdt_show_channel_Callback(hObject, eventData, handles)
global tdt_show_now tdt_show_last_chosen tdt_show_data tdt_show_data_last;
global file;
tdt_show_now(str2double(get(hObject, 'String'))) = get(hObject, 'Value');
tdt_show_last_chosen = tdt_show_now;
handles = guidata(hObject);
if ~isempty(file)
    do_file(hObject, handles, file, true);
end


% If I choose what channels to show, but loading a file with a different
% set of channels tosses my chosen result, pressing this button will
% restore my chosen ones.
function restore_show_Callback(hObject, eventdata, handles)
global tdt_show_now tdt_show_last_chosen tdt_show_data tdt_show_data_last;
global file;
tdt_show_now = tdt_show_last_chosen;
for i = 1:16
    set(handles.tdt_show{i}, 'Value', tdt_show_now(i));
end
if ~isempty(file)
    do_file(hObject, handles, file, true);
end


function varargout = inspect_OutputFcn(hObject, ~, handles) 
varargout{1} = handles.output;


% --- Executes on selection change in listbox1.
function listbox1_Callback(hObject, ~, handles)
global file;

file = handles.sorted_index(get(hObject,'Value'));
do_file(hObject, handles, file, true);



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% This is the main function!
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function do_file(hObject, handles, file, doplot)
global tdt_show_now tdt_show_data tdt_show_data_last;
global detrend_param;

%set(handles.listbox1, 'Enable', 'inactive');
drawnow;

load(handles.files{file});
data = update_data_struct(data, detrend_param, handles);

devices = {};
devices_perhaps = {'tdt', 'ni'};
for i = devices_perhaps
    if isfield(data, i)
        devices(end+1) = i;
    end
end
set(handles.show_device, 'String', devices);


if data.version >= 12
    tdt_show_data = zeros(1, 16);
    tdt_show_data(data.tdt.index_recording(data.tdt.show)) = ones(1, length(data.tdt.show));
    if any(tdt_show_data ~= tdt_show_data_last)
        tdt_show_now = tdt_show_data;
        for i = 1:16
            set(handles.tdt_show_buttons{i}, 'Value', tdt_show_now(i));
        end
        tdt_show_data_last = tdt_show_data;
    end
end


% If we've made changes through the GUI, re-detrend.
if isempty(detrend_param)
    detrend_param = data.detrend_param;
end



if ~isequal(detrend_param, data.detrend_param)
    %data.detrend_param = detrend_param;
    if isfield(data, 'tdt')
        [ data.tdt.response_detrended data.tdt.response_trend data.detrend_param ] ...
            = detrend_response(data.tdt, data, detrend_param);
        [ data.tdt.spikes data.tdt.spikes_r ]= look_for_spikes_xcorr(data.tdt, ...
            data, detrend_param, [], handles);
    else
        [ data.ni.response_detrended data.ni.response_trend data.detrend_param ] ...
            = detrend_response(data.ni, data, detrend_param);
        [ data.ni.spikes data.ni.spikes_r ]= look_for_spikes_xcorr(data.ni, ...
            data, detrend_param, [], handles);
    end
end



set(handles.detrend_model, 'String', detrend_param.model);
set(handles.fit0, 'String', sprintf('%g', detrend_param.range(1)*1000));
set(handles.fit1, 'String', sprintf('%g', detrend_param.range(2)*1000));
set(handles.roi0, 'String', sprintf('%g', detrend_param.response_roi(1)*1000));
set(handles.roi1, 'String', sprintf('%g', detrend_param.response_roi(2)*1000));
set(handles.baseline0, 'String', sprintf('%g', detrend_param.response_baseline(1)*1000));
set(handles.baseline1, 'String', sprintf('%g', detrend_param.response_baseline(2)*1000));
set(handles.response_detection_threshold, 'String', sprintf('%g', ...
    detrend_param.response_detection_threshold));
if isfield(data, 'tdt')
    for i = 1:16
        if any(data.tdt.index_recording == i)
            foo = 'on';
        else
            foo = 'off';
        end
        set(handles.tdt_show_buttons{i}, 'Enable', foo);
    end
end
            





if doplot
        if data.version >= 6
            tabledata{1,1} = data.bird;
        end
        tabledata{2,1} = sprintf('%d ', data.stim.active_electrodes);
        tabledata{3,1} = sprintf('%.3g uA', data.stim.current_uA);
        if isfield(data.stim, 'halftime_us')
            tabledata{4,1} = sprintf('%d us', round(data.halftime_s)*1e6);
        else
            tabledata{4,1} = '?';
        end
        
        if isfield(data.stim, 'negativefirst')
            tabledata{5,1} = sprintf('%d ', data.stim.negativefirst);
        else
            tabledata{5,1} = '?'; % negative pulse first
        end
        tabledata{6,1} = sprintf('%d', data.stim.plexon_monitor_electrode);
        if isfield(data, 'comments')
            set(handles.comments, 'String', data.comments);
        end
        
        
        set(handles.table1, 'Data', tabledata);
end

data.tdt.show_now = find(tdt_show_now(data.tdt.index_recording));

plot_stimulation(data, handles);


set(handles.listbox1, 'Enable', 'on');

guidata(hObject, handles);







function listbox1_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end




function load_all_Callback(hObject, eventdata, handles)
global wait_bar;
global knowngood;
global net;
global nnsetX;

set(handles.load_all, 'Enable', 'off');


clear nnsetX;
clear net;

if isempty(wait_bar)
        wait_bar = waitbar(0, 'Loading...');
end

nfiles = length(handles.files);
for file = 1:nfiles
        waitbar(file / nfiles);
        do_file(hObject, handles, file, false);
end


close(wait_bar);
wait_bar = [];
train_net(hObject, handles);
set(handles.load_all, 'Enable', 'on');




% --- Executes on button press in response1.
function response1_Callback(hObject, eventdata, handles)
% hObject    handle to response1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of response1


% --- Executes on button press in response2.
function response2_Callback(hObject, eventdata, handles)
% Should never be called: it's an indicator!

function train_net(hObject, handles)
global nnsetX;
global knowngood;
global net;
global train_record;
net = feedforwardnet([10 5]);

net.trainParam.max_fail = 5;
net.trainParam.showWindow = false;
[net, train_record] = train(net, nnsetX, knowngood(1:size(nnsetX, 2)));
%train_record
do_roc(hObject, handles);



function do_roc(hObject, handles)
global net knowngood nnsetX;

netresponses = sim(net, nnsetX);

thresholds = -1:0.01:2;
for i = 1:length(thresholds)
        tpr(i) = sum(netresponses > thresholds(i) & knowngood) ...
                / sum(knowngood);
        fp(i) = sum(netresponses > thresholds(i) & ~knowngood);
        fpr(i) = fp(i) / sum(~knowngood);
end
roc_integral = -((fpr(2:end)-fpr(1:end-1)) * ((tpr(1:end-1)+tpr(2:end))/2)');
plot(handles.axes4, fpr, tpr);
xlabel(handles.axes4, 'False Positive Rate')
ylabel(handles.axes4, 'True Positive Rate');
title(handles.axes4, sprintf('ROC integral: %.4f', roc_integral));
set(handles.axes4, 'XLim', [0 1], 'YLim', [0 1]);




% --- Executes on button press in train.
function train_Callback(hObject, eventdata, handles)

set(handles.train, 'Enable', 'off');

train_net(hObject, handles);

set(handles.train, 'Enable', 'on');



% --- Executes on slider movement.
function xscale_Callback(hObject, eventdata, handles)
last_xlim = get(handles.axes1, 'XLim');
set(handles.axes1, 'XLim', get(handles.xscale, 'Value') * [-4 30] / 1e3);
set(handles.axes2, 'XLim', get(handles.xscale, 'Value') * [-4 30] / 1e3);
new_xlim = get(handles.axes1, 'XLim');
% It seems that the whole graph isn't drawn--expanding the view region
% results in blank areas. In this case, replot.
if new_xlim(2) > last_xlim(2)
    plot_stimulation([], handles, 1);
end


% --- Executes on slider movement.
function yscale_Callback(hObject, eventdata, handles)
set(handles.axes1, 'YLim', (2^(get(handles.yscale, 'Value')))*[-0.3 0.3]/1e3);
set(handles.axes2, 'YLim', (2^(get(handles.yscale, 'Value')))*[-0.3 0.3]/1e3);


% --- Executes during object creation, after setting all properties.
function yscale_CreateFcn(hObject, eventdata, handles)
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


function comments_Callback(hObject, eventdata, handles)

% --- Executes during object creation, after setting all properties.
function comments_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in response_show_avg.
function response_show_avg_Callback(hObject, eventdata, handles)
if get(hObject, 'Value')
    set(handles.response_show_all, 'Value', 0);
end
listbox1_Callback(handles.listbox1, eventdata, handles);

% --- Executes on button press in response_show_trend.
function response_show_trend_Callback(hObject, eventdata, handles)
listbox1_Callback(handles.listbox1, eventdata, handles);


% --- Executes on button press in response_show_detrend_paramed.
function response_show_detrended_Callback(hObject, eventdata, handles)
listbox1_Callback(handles.listbox1, eventdata, handles);


% --- Executes on button press in response_filter.
function response_filter_Callback(hObject, eventdata, handles)
listbox1_Callback(handles.listbox1, eventdata, handles);


% --- Executes on button press in response_show_all.
function response_show_all_Callback(hObject, eventdata, handles)
if get(hObject, 'Value')
    set(handles.response_show_avg, 'Value', 0);
end
listbox1_Callback(handles.listbox1, eventdata, handles);




% --- Executes on selection change in show_device.
function show_device_Callback(hObject, eventdata, handles)
global show_device;
foo = cellstr(get(hObject, 'String'));
show_device = foo{get(hObject, 'Value')};
listbox1_Callback(handles.listbox1, eventdata, handles);


% --- Executes during object creation, after setting all properties.
function show_device_CreateFcn(hObject, eventdata, handles)
global show_device;
set(hObject, 'String', {'TDT', 'NI'});
foo = cellstr(get(hObject, 'String'));
show_device = foo{get(hObject, 'Value')};

if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



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





function xscale_CreateFcn(hObject, eventdata, handles)
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end
