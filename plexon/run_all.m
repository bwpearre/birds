function varargout = run_all(varargin)
% RUN_ALL MATLAB code for run_all.fig
%      RUN_ALL, by itself, creates a new RUN_ALL or raises the existing
%      singleton*.
%
%      H = RUN_ALL returns the handle to a new RUN_ALL or the handle to
%      the existing singleton*.
%
%      RUN_ALL('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in RUN_ALL.M with the given input arguments.
%
%      RUN_ALL('Property','Value',...) creates a new RUN_ALL or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before run_all_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to run_all_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help run_all

% Last Modified by GUIDE v2.5 06-May-2015 20:02:07

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @run_all_OpeningFcn, ...
                   'gui_OutputFcn',  @run_all_OutputFcn, ...
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


% --- Executes just before run_all is made visible.
function run_all_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to run_all (see VARARGIN)

% Choose default command line output for run_all
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes run_all wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = run_all_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;



function input_duration_Callback(hObject, eventdata, handles)
% hObject    handle to input_duration (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of input_duration as text
%        str2double(get(hObject,'String')) returns contents of input_duration as a double


% --- Executes during object creation, after setting all properties.
function input_duration_CreateFcn(hObject, eventdata, handles)
% hObject    handle to input_duration (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function input_amplitude_Callback(hObject, eventdata, handles)
% hObject    handle to input_amplitude (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of input_amplitude as text
%        str2double(get(hObject,'String')) returns contents of input_amplitude as a double


% --- Executes during object creation, after setting all properties.
function input_amplitude_CreateFcn(hObject, eventdata, handles)
% hObject    handle to input_amplitude (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbutton_load.
function pushbutton_load_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_load (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in pushbutton_run.
function pushbutton_run_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_run (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



function input_delay_Callback(hObject, eventdata, handles)
% hObject    handle to input_delay (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of input_delay as text
%        str2double(get(hObject,'String')) returns contents of input_delay as a double


% --- Executes during object creation, after setting all properties.
function input_delay_CreateFcn(hObject, eventdata, handles)
% hObject    handle to input_delay (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
