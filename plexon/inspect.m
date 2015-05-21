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

% Last Modified by GUIDE v2.5 20-May-2015 12:57:13

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

global responses;

files = dir('stim*');

[sorted_names, sorted_index] = sortrows({files.name}');
handles.files = sorted_names;
handles.sorted_index = sorted_index;
set(handles.listbox1,'String',handles.files,'Value',1)


guidata(hObject, handles);




function varargout = inspect_OutputFcn(hObject, eventdata, handles) 
varargout{1} = handles.output;


% --- Executes on selection change in listbox1.
function listbox1_Callback(hObject, eventdata, handles)
file = handles.sorted_index(get(hObject,'Value'));
do_file(hObject, eventdata, handles, file);
guidata(hObject, handles);


function do_file(hObject, eventdata, handles, file);
global responses;

load(handles.files{file});

tabledata{1,1} = sprintf('%d ', data.stim_electrodes);
tabledata{2,1} = sprintf('%.3g uA', data.current);
if isfield(data, 'halftime')
    tabledata{3,1} = sprintf('%d', round(data.halftime));
else
    tabledata{3,1} = '?';
end
if isfield(data, 'negfirst')
    if data.negfirst
        tabledata{4,1} = 'y';
    else
        tabledata{4,1} = '';
    end
else
    tabledata{4,1} = '?'; % negative pulse first
end
tabledata{5,1} = sprintf('%d', data.monitor_electrode);
set(handles.table1, 'Data', tabledata);

triggerchannel = 3;
triggerthreshold = 0.1;
aftertrigger = 0.009;

triggertime = find(abs(data.data(:,triggerchannel)) > triggerthreshold);
if isempty(triggertime)
    triggertime = 0;
else
    triggertime = (triggertime(1) / data.fs);
end
beforetrigger = max(0, triggertime - 0.001);

%disp('Bandpass-filtering the data...');
[B A] = butter(4, 0.6, 'low');
data.data = filter(B, A, data.data);

if ~isfield(data, 'halftime') % old format does not scale saved data
        scalefactor_V = 1/0.25;
        scalefactor_i = 400;
        data.data(:,1) = data.data(:,1) * scalefactor_V;
        data.data(:,2) = data.data(:,2) * scalefactor_i;
end
times = (data.time - triggertime) * 1000; % milliseconds
u = find(data.time > beforetrigger & data.time < triggertime + aftertrigger);
yy = plotyy(handles.axes2, times(u), data.data(u,1), ...
    times(u), data.data(u,2));
legend(handles.axes2, data.names{1:2});
xlabel(handles.axes2, 'ms');
set(get(yy(1),'Ylabel'),'String','V')
set(get(yy(2),'Ylabel'),'String','\mu A')

plot(handles.axes1, times(u), data.data(u,3));
set(handles.axes1, 'YLim', [-0.1 0.1]);
legend(handles.axes1, data.names{3});
ylabel(handles.axes1, data.names{3});

roi = round([ triggertime + 0.002  triggertime + 0.006 ] * data.fs);

len = roi(2)-roi(1)+1;
if isempty(responses)
        responses = zeros(len, handles.files);
end
responses(1:len,file) = data.data(roi(1):roi(2), 3);
if file > 1 & file < length(handles.files)
        lastxc = [xcorr2(responses(:, file-1), responses(:, file))'
                  xcorr2(responses(:, file+1), responses(:, file))']';
        %lastxc = xcorr(responses(:, file-1:file+1));
        plot(handles.axes3, lastxc);
end

guidata(hObject, handles);


% --- Executes during object creation, after setting all properties.
function listbox1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to listbox1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in next1.
function next1_Callback(hObject, eventdata, handles)
% hObject    handle to next1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in previous.
function previous_Callback(hObject, eventdata, handles)
% hObject    handle to previous (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in next10.
function next10_Callback(hObject, eventdata, handles)
% hObject    handle to next10 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in previous10.
function previous10_Callback(hObject, eventdata, handles)
% hObject    handle to previous10 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in previous100.
function previous100_Callback(hObject, eventdata, handles)
% hObject    handle to previous100 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in next100.
function next100_Callback(hObject, eventdata, handles)
% hObject    handle to next100 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
