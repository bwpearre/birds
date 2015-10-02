function plot_stimulation(data, handles);

if data.version < 12
    plot_stimulation_pre12(data, handles);
    return;
end

global responses_detrended;
persistent corr_range;
global heur;
global knowngood;
global nnsetX;
global net;
global axes1 axes2 axes3 axes4;
if isempty(corr_range)
        corr_range = [0 eps];
end

% If plot_stimulation is called from a timer or DAQ callback, the axes are
% not present in the handles structure.  You may need a beer for this
% one...
if isfield(handles, 'startcurrent')
    handles.axes1 = axes1;
    handles.axes2 = axes2;
    handles.axes3 = axes3;
    handles.axes4 = axes4;
end

colours = repmat(get(handles.axes1, 'ColorOrder'), 3, 1);

persistent responses_detrended_prev;



if isfield(data, 'tdt')
    d = data.tdt;
else
    d = data.ni;
end

n_repetitions = d.n_repetitions;
aftertrigger = 12e-3;
beforetrigger = -3e-3;


halftime_us = data.halftime_us;
interpulse_s = data.interpulse_s;
times_aligned = d.times_aligned;
beforetrigger = max(times_aligned(1), beforetrigger);
aftertrigger = min(times_aligned(end), aftertrigger);

% u: indices into times_aligned that we want to show, aligned and shit.
u = find(times_aligned > beforetrigger & times_aligned < aftertrigger);
w = find(times_aligned >= 0.003 & times_aligned < 0.008);

if isempty(u) | length(u) < 5
    disp(sprintf('WARNING: time alignment problem.  Is triggering working?'));
    return;
end

axes1legend = {};

response = d.response;
sz = size(response);

response_avg = mean(response, 1);

if get(handles.response_show_avg, 'Value')
    response = response_avg;
end

foo = size(response_avg);
if length(foo) == 3
    response_avg = reshape(response_avg, foo(2:3));
end

% get(handles.response_show_all, 'Value')
    
cla(handles.axes1);
colour_index = 1;
legend_handles = [];
hold(handles.axes1, 'on');
for i = d.show
    foo = plot(handles.axes1, ...
        times_aligned(u), ...
        reshape(response(:,u,i), [size(response, 1) length(u)])', ...
        'Color', colours(colour_index, :));
    colour_index = colour_index + 1;
    legend_handles(end+1) = foo(1);
end
hold(handles.axes1, 'off');
legend_names = d.names{d.show};
legend(handles.axes1, legend_handles, legend_names);
    

% How about the derivative of the data?
%deriv = diff(data.data_aligned(:,:,3), 1, 2);
%[B A] = ellip(2, .5, 40, [300 3000]/(data.fs/2));
%deriv2 = filtfilt(B, A, deriv);
%plot(handles.axes2, times_aligned(u), deriv2(:, u));
%set(handles.axes2, 'YLim', [-1 1] * max(max(abs(deriv2(:, w)))));
    
title(handles.axes1, 'Response');
xl = get(handles.axes1, 'XLim');
xl(1) = beforetrigger;
set(handles.axes1, ...
    'XLim', [beforetrigger aftertrigger], ...
    'YLim', (2^(get(handles.yscale, 'Value')))*[-0.3 0.3]/515/2);
ylabel(handles.axes1, 'volts');
grid(handles.axes1, 'on');



v = find(data.ni.times_aligned >= -0.001 ...
    & data.ni.times_aligned < 0.001 + 2 * halftime_us/1e6 + interpulse_s);
if isempty(v)
    disp('No data to plot here... quitting...');
    return;
end
yy = plotyy(handles.axes3, data.ni.times_aligned(v), squeeze(mean(data.ni.stim(:, v, 1), 1)), ...
    data.ni.times_aligned(v), squeeze(mean(data.ni.stim(:, v, 2), 1)));
legend(handles.axes3, data.ni.names{1:2});
xlabel(handles.axes3, 'ms');
set(get(yy(1),'Ylabel'),'String','V')
set(get(yy(2),'Ylabel'),'String','\mu A')

xtick = get(handles.axes1, 'XTick');
set(handles.axes1, 'XTick', xtick(1):0.001:xtick(end));
%figure(1);
%plot(times_aligned(u), reshape(data.data_aligned(:,u,data.channels_out), [ length(u) length(data.channels_out)])');

% Try:
% Fourier, 8 terms
% Polynomial, degree 8
% Smoothing spline with specify 0.9999999999? Hmmm...


% Curve-fit: use a slightly longer time period
roifit = [ 2*data.halftime_us/1e6+data.interpulse_s+100e-6  0.016 ];
roiifit = find(times_aligned >= roifit(1) & times_aligned < roifit(2));
roitimesfit = times_aligned(roiifit);
len = length(times_aligned);
lenfit = length(roitimesfit);
weightsfit = linspace(1, 0, lenfit);
weightsfit = ones(1, lenfit);

fittype = 'fourier8';
opts = fitoptions;
opts.Normalize = 'on';

switch fittype
    case 'exp2'
        opts = fitoptions(opts, 'StartPoint', [1 -3000 1 -30], ...
                'Upper', [Inf -0.01 Inf -0.01] );
    case 'fourier8'
    case 'poly8'
    otherwise
end

response_avg_avg = mean(response_avg, 2);

f = fit(roitimesfit', response_avg_avg(roiifit), fittype, opts);
roitrend = f(times_aligned);
responses_detrended = response_avg_avg - roitrend;

if false
    f = fit(roitimesfit,  responses_detrended(roiifit), fittype, opts);
    roitrend = f(times_aligned);
    responses_detrended = responses_detrended - roitrend;
end

%cftool(roitimesfit,response_avg(roiifit,3))

roi = [500e-6 0.008 ];
roii = find(times_aligned >= roi(1) & times_aligned <= roi(2));
roiiplus = find(times_aligned > roi(2) & times_aligned <= roifit(2));
roitimes = times_aligned(roii);
roitimesplus = times_aligned(roiiplus);

hold(handles.axes1, 'on');
if get(handles.response_show_trend, 'Value')
    plot(handles.axes1, roitimesfit, roitrend(roiifit), 'g');
    axes1legend{end+1} = 'Trend';
end
if get(handles.response_show_detrended, 'Value')
    plot(handles.axes1, roitimes, responses_detrended(roii), 'r', 'LineWidth', 2);
    plot(handles.axes1, roitimesplus, responses_detrended(roiiplus), 'k', 'LineWidth', 2);
    axes1legend{end+1} = 'Detrended';
end
hold(handles.axes1, 'off');
if ~isempty(axes1legend) & false
    legend(handles.axes1, axes1legend);
end



% Let's try a filter, shall we?  This used to filter the raw data, but I
% think I should not filter until after detrending, if at all.
%disp('Bandpass-filtering the data...');
%[B A] = butter(2, 0.07, 'high');
if get(handles.response_filter, 'Value')
    [B A] = ellip(2, .5, 40, [300 9000]/(data.fs/2));

    
    %response_avg(:,3) = filtfilt(B, A, response_avg(:,3));
    %if data.version >= 8
    %    data.data_aligned(:,:,3) = filtfilt(B, A, data.data_aligned(:,:,3));
    %else
    %    data.data_raw(:,3) = filtfilt(B, A, data.data_raw(:,3));
    %end
end



if ~isempty(responses_detrended_prev)
        lastxc = [xcorr(responses_detrended_prev(roii), responses_detrended(roii), 'coeff')']';

        corr_range = [min(corr_range(1), min(min(lastxc))) ...
                max(corr_range(2), max(max(lastxc)))];
        if false
                plot(handles.axes2, lastxc);
                set(handles.axes2, 'XLim', [0 2*length(roii)], 'YLim', corr_range);
                legend(handles.axes2, 'Prev');
                
                if 0
                        plot(handles.axes4, roitimes, responses_detrended, 'b', ...
                                roitimes, data.data(roi(1):roi(2), 3), 'r');
                end
        end
        
        range = 250:350;
        
        if 1
                % FFT the xcorr just for good measure
                FFT_SIZE = 256;
                freqs = [300:100:2000];
                window = hamming(FFT_SIZE);
                [speck freqs times] = spectrogram(lastxc(:,1), window, [], freqs, d.fs);
                %[speck freqs times] = spectrogram(responses_detrended, window, [], freqs, data.fs);
                [nfreqs, ntimes] = size(speck);
                speck = speck + eps;
                if false
                        plot(handles.axes4, freqs, abs(speck));
                        %imagesc(log(abs(speck)), 'Parent', handles.axes4);
                        %axis(handles.axes4, 'xy');
                        %colorbar('peer', handles.axes4);
                end
        end

        
        
        [val, pos] = max(lastxc(:, 1));
        %nnsetX(:,file) = [max(lastxc(range,1)) - min(lastxc(range,1)); ...
        %        abs(pos-len); ...
        %        abs(speck(:,2))];
end

%if ~isempty(net)
%        set(handles.response2, 'Value', sim(net, nnsetX(:,file)) > 0.5);
%end

w = find(times_aligned >= halftime_us/1e6 - 0.00003 ...
    & times_aligned < halftime_us/1e6 + interpulse_s + 0.00001);
%w = w(1:end-1);
min_interpulse_volts = min(abs(response_avg(w,1)));
plot(handles.axes4, times_aligned(w)*1000, response_avg(w,1));
grid(handles.axes4, 'on');
xlabel(handles.axes4, 'ms');
ylabel(handles.axes4, 'V');

responses_detrended_prev = responses_detrended;
