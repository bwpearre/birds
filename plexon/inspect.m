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

% Last Modified by GUIDE v2.5 23-Jun-2015 12:59:49

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

global responses_detrended;
global wait_bar;
global knowngood;
global heur;
global nnsetX;

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


guidata(hObject, handles);




function varargout = inspect_OutputFcn(hObject, eventdata, handles) 
varargout{1} = handles.output;


% --- Executes on selection change in listbox1.
function listbox1_Callback(hObject, eventdata, handles)
file = handles.sorted_index(get(hObject,'Value'));
do_file(hObject, eventdata, handles, file, true);


function do_file(hObject, eventdata, handles, file, doplot);
global responses_detrended;
persistent corr_range;
global heur;
global knowngood;
global nnsetX;
global net;
if isempty(corr_range)
        corr_range = [0 eps];
end

load(handles.files{file});

if doplot
        data
        tabledata{1,1} = sprintf('%d ', data.stim_electrodes);
        tabledata{2,1} = sprintf('%.3g uA', data.current);
        if isfield(data, 'halftime_us')
                tabledata{3,1} = sprintf('%d us', round(data.halftime_us));
        else
                tabledata{3,1} = '?';
        end
        if isfield(data, 'negativefirst')
                if data.negativefirst
                        tabledata{4,1} = 'y';
                else
                        tabledata{4,1} = '';
                end
        else
                tabledata{4,1} = '?'; % negative pulse first
        end
        tabledata{5,1} = sprintf('%d', data.monitor_electrode);
        if isfield(data, 'comments')
            set(handles.comments, 'String', data.comments);
        end
        
        
        set(handles.table1, 'Data', tabledata);
end

knowngood(file) = sum(data.stim_electrodes) == 16 && data.current >= 2;
set(handles.response1, 'Value', knowngood(file));        

aftertrigger = 0.016;
beforetrigger = -0.002;

if ~isfield(data, 'version') % old format does not scale saved data
        scalefactor_V = 1/0.25;
        scalefactor_i = 400;
        data.data(:,1) = data.data(:,1) * scalefactor_V;
        data.data(:,2) = data.data(:,2) * scalefactor_i;
end
edata = data.data;
halftime_us = data.halftime_us;
interpulse_s = data.interpulse_s;
times_aligned = data.times_aligned;
beforetrigger = max(times_aligned(1), beforetrigger);
aftertrigger = min(times_aligned(end), aftertrigger);

% u: indices into times_aligned that we want to show, aligned and shit.
u = find(times_aligned > beforetrigger & times_aligned < aftertrigger);
% v is the times to show for the pulse
v = find(times_aligned >= -0.001 & times_aligned < 0.001 + 2 * halftime_us/1e6 + interpulse_s);

if doplot
        
        plot(handles.axes1, times_aligned(u), edata(u,3));
        xl = get(handles.axes1, 'XLim');
        xl(1) = beforetrigger;
        set(handles.axes1, ...
            'XLim', [beforetrigger aftertrigger], ...
            'YLim', (2^(get(handles.yscale, 'Value')))*[-0.3 0.3]/515/2);
        legend(handles.axes1, data.names{3});
        ylabel(handles.axes1, data.names{3});
        grid(handles.axes1, 'on');
       
        yy = plotyy(handles.axes2, times_aligned(v), edata(v,1), ...
                times_aligned(v), edata(v,2));
        legend(handles.axes2, data.names{1:2});
        xlabel(handles.axes2, 'ms');
        set(get(yy(1),'Ylabel'),'String','V')
        set(get(yy(2),'Ylabel'),'String','\mu A')
end




% Exponential curve-fit: use a slightly longer time period for better
% results:
roifit = [ 0.003  0.016 ];
roiifit = find(times_aligned >= roifit(1) & times_aligned < roifit(2));
roitimesfit = times_aligned(roiifit);
lenfit = length(roitimesfit);
weightsfit = linspace(1, 0, lenfit);
weightsfit = ones(1, lenfit);
f = fit(roitimesfit, edata(roiifit, 3), 'exp2', ...
        'Weight', weightsfit, 'StartPoint', [1 -3000 1 -30], ...
        'Upper', [Inf -0.01 Inf -0.01], 'TolX', 1e-15, 'TolFun', 1e-15);
roitrend = f.a .* exp(f.b * times_aligned) + f.c .* exp(f.d * times_aligned);
len = length(times_aligned);
detrended = edata(:, 3) - roitrend;

roi = [0.003 0.008 ];
roii = find(times_aligned >= roi(1) & times_aligned <= roi(2));
roiiplus = find(times_aligned > roi(2) & times_aligned <= roifit(2));
roitimes = times_aligned(roii);
roitimesplus = times_aligned(roiiplus);

if doplot
        hold(handles.axes1, 'on');
        plot(handles.axes1, roitimesfit, roitrend(roiifit), 'g');
        plot(handles.axes1, roitimes, detrended(roii), 'r');
        plot(handles.axes1, roitimesplus, detrended(roiiplus), 'k');
        hold(handles.axes1, 'off');
end




% Store de-trended data in the ROI (smaller than the detrending fit
% region):
responses_detrended(1:len, file) = detrended;


% Let's try a high-pass filter, shall we?
%disp('Bandpass-filtering the data...');
%[B A] = butter(2, 0.07, 'high');
if false
    [B A] = ellip(6, .2, 60, 500/(data.fs/2), 'high');
    data2 = filtfilt(B, A, edata(roiifit,3));
    if doplot
        hold(handles.axes1, 'on');
        plot(handles.axes1, times_aligned(roiifit), data2 - 5e-5, 'm');
        plot(handles.axes1, times_aligned(roiifit), data2 - responses_detrended(1:length(roiifit), file) - 1e-4, 'k');
        hold(handles.axes1, 'off');
    end
    %data.data = filter(B, A, data.data);
end


% Kludge so we can ask for the next one for xcorr below
if size(responses_detrended, 2) == file
    responses_detrended(len, file+1) = 0;
end
%responses_detrended(1:len,file) = data.data(roi(1):roi(2), 3) - roitrend;


if file > 1 & file < length(handles.files)
        lastxc = [xcorr(responses_detrended(roii, file-1), responses_detrended(roii, file), 'coeff')'
                  xcorr(responses_detrended(roii, file+1), responses_detrended(roii, file), 'coeff')']';
        %lastxc = xcorr(responses_detrended(:, file-1:file+1));
        corr_range = [min(corr_range(1), min(min(lastxc))) ...
                max(corr_range(2), max(max(lastxc)))];
        if doplot
                plot(handles.axes3, lastxc);
                set(handles.axes3, 'XLim', [0 2*length(roii)], 'YLim', corr_range);
                legend(handles.axes3, 'Prev', 'Next');
                
                if 0
                        plot(handles.axes4, roitimes, responses_detrended(:,file), 'b', ...
                                roitimes, data.data(roi(1):roi(2), 3), 'r');
                end
        end
        range = 250:350;
        
        if 1
                % FFT the xcorr just for good measure
                FFT_SIZE = 256;
                freqs = [300:100:2000];
                window = hamming(FFT_SIZE);
                [speck freqs times] = spectrogram(lastxc(:,1), window, [], freqs, data.fs);
                %[speck freqs times] = spectrogram(responses_detrended(:,file), window, [], freqs, data.fs);
                [nfreqs, ntimes] = size(speck);
                speck = speck + eps;
                if doplot & false
                        plot(handles.axes4, freqs, abs(speck));
                        %imagesc(log(abs(speck)), 'Parent', handles.axes4);
                        %axis(handles.axes4, 'xy');
                        %colorbar('peer', handles.axes4);
                end
        end

        
        
        [val, pos] = max(lastxc(:, 1));
        nnsetX(:,file) = [max(lastxc(range,1)) - min(lastxc(range,1)); ...
                abs(pos-len); ...
                abs(speck(:,2))];
elseif file > 1
        nnsetX(:,file) = NaN * nnsetX(:,file-1);
end

if ~isempty(net)
        set(handles.response2, 'Value', sim(net, nnsetX(:,file)) > 0.5);
end

if doplot
    w = find(times_aligned > halftime_us/1e6 & times_aligned < halftime_us/1e6 + interpulse_s);
    w = w(1:end-1);
    min_interpulse_volts = min(abs(edata(w,1)))
    plot(handles.axes4, times_aligned(w)*1000, edata(w,1));
    grid(handles.axes4, 'on');
    xlabel(handles.axes4, 'ms');
    ylabel(handles.axes4, 'V');
end
%set(handles.response2, 'Value', heur(file));

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




% --- Executes on button press in load_all.
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
        do_file(hObject, eventdata, handles, file, false);
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
function yscale_Callback(hObject, eventdata, handles)
set(handles.axes1, 'YLim', (2^(get(handles.yscale, 'Value')))*[-0.3 0.3]/515/2);



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


