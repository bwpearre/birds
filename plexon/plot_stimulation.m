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
global show_device;
global axes1 axes2 axes3 axes4;
if isempty(corr_range)
        corr_range = [0 eps];
end
if isempty(show_device)
    show_device = 'tdt';
end

% Repair my stupidity -- version 12 has unscaled data.
if data.version == 12
    data.ni.stim(:,:,1) = data.ni.stim(:,:,1) * 4;
    data.ni.stim(:,:,2) = data.ni.stim(:,:,2) * 400;
end

% If plot_stimulation is called from a timer or DAQ callback, the axes are
% not present in the handles structure.  You may need a beer for this
% one...
%if isfield(handles, 'startcurrent')
for i = 1:4
    j = sprintf('axes%d', i);
    if ~isfield(handles, j)
        eval(sprintf('handles.%s = %s;', j, j));
    end
end

if isempty(axes4)
    axes1 = handles.axes1;
    axes2 = handles.axes2;
    axes3 = handles.axes3;
    axes4 = handles.axes4;
end


persistent responses_detrended_prev;


if data.version <= 15
    data.ni.times_aligned = data.ni.times_aligned';
end

if isfield(data, 'tdt')
    eval(sprintf('d = data.%s;', lower(show_device)));
else
    d = data.ni;
end
nchannels = size(d.response, 3);

n_repetitions = d.n_repetitions;
aftertrigger = 25e-3;
beforetrigger = -3e-3;


colours = distinguishable_colors(nchannels);

% Generate stimulation alignment information
if data.version <= 15 | ~isfield(d, 'stim_active_indices')
    data.stim_duration = 2*data.halftime_us/1e6+data.interpulse_s;
    d.stim_active_indices = find(d.times_aligned >= 0 ...
        & d.times_aligned <= data.stim_duration);
    d.stim_active = 0 * d.response(1, :, 1);    
    d.stim_active(d.stim_active_indices) = ones(1, length(d.stim_active_indices));
else
    d.stim_active = d.stim_active(1:size(d.response, 2));
end
stim_times = d.times_aligned(d.stim_active_indices);



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

sz = size(d.response);

% Shall we compute the average of time-aligned responses?
response_avg = mean(d.response, 1);
%foo = size(response_avg);
%if length(foo) == 3
%    response_avg = reshape(response_avg, foo(2:3));
%end

if get(handles.response_show_avg, 'Value')
    response_plot = response_avg;
else
    response_plot = d.response;
end


if data.version >= 17
    detrend_toi = data.detrend_toi;
else
    detrend_toi = [ 0.002 0.025 ];
end
if get(handles.response_show_detrended, 'Value') | get(handles.response_show_trend, 'Value')
    [ detrended trend ] = detrend_response(response_avg, d, data, detrend_toi, 'fourier8');
end
    
response_toi = [0.003 0.008];
response_baseline = [0.012 Inf];

tic
[ detrended_all trend_all ] = detrend_response(d.response, d, data, detrend_toi, 'fourier8');
disp(sprintf('Detrending all took %s seconds.', sigfig(toc, 3)));
tic
[spikes r] = look_for_spikes(detrended_all, data, d, response_toi, response_baseline, 'fourier8');
disp(sprintf('Finding spikes took %s seconds.', sigfig(toc, 3)));

linewidths = 0.3*ones(1, nchannels);
linewidths(find(spikes)) = ones(1, length(linewidths(find(spikes)))) * 3;


% get(handles.response_show_all, 'Value')

% Let's try a filter, shall we?  This used to filter the raw data, but I
% think I should not filter until after detrending, if at all.
%disp('Bandpass-filtering the data...');
%[B A] = butter(2, 0.07, 'high');
if get(handles.response_filter, 'Value')
    [B A] = ellip(2, .000001, 30, [100]/(d.fs/2), 'high');
    for i = 1:size(response_plot, 1)
        response_plot(i,:,:) = filtfilt(B, A, squeeze(response_plot(i,:,:)));
    end
end




%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Plot axes1
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

roii = find(d.times_aligned >= detrend_toi(1) & d.times_aligned < detrend_toi(2));
roitimes = d.times_aligned(roii);



cla(handles.axes1);
hold(handles.axes1, 'on');
legend_handles = [];
legend_names = {};
for channel = union(d.show, find(spikes))
    
    % Raw (or filtered) response
    foo = plot(handles.axes1, ...
        times_aligned(u), ...
        reshape(response_plot(:,u,channel), [size(response_plot, 1) length(u)])', ...
        'Color', colours(channel, :), 'LineWidth', linewidths(channel));
    
    % Detrended
    if get(handles.response_show_detrended, 'Value')
        plot(handles.axes1, roitimes, detrended(1, roii, channel), ...
            'Color', colours(channel, :), 'LineStyle', '--');
    end
    if get(handles.response_show_trend, 'Value')
        plot(handles.axes1, roitimes, trend(1, roii, channel), ...
            'Color', colours(channel,:), 'LineStyle', ':');
        axes1legend{end+1} = 'Trend';
    end

    
    legend_handles(end+1) = foo(1);
    legend_names(end+1) = strcat(d.names(channel), '..... ', sigfig(r(channel), 2));
end
hold(handles.axes1, 'off');
%legend_names = d.names(d.show);
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



v = find(data.ni.times_aligned >= -0.0002 ...
    & data.ni.times_aligned < 0.0002 + 2 * halftime_us/1e6 + interpulse_s);
if isempty(v)
    disp('No data to plot here... quitting...');
    return;
end
global axes3yy;
axes3yy = plotyy(handles.axes3, data.ni.times_aligned(v), squeeze(mean(data.ni.stim(:, v, 1), 1)), ...
    data.ni.times_aligned(v), squeeze(mean(data.ni.stim(:, v, 2), 1)));
set(axes3yy(1), 'XLim', data.ni.times_aligned(v([1 end])));
set(axes3yy(2), 'XLim', data.ni.times_aligned(v([1 end])));
legend(handles.axes3, data.ni.names{1:2});
xlabel(handles.axes3, 'ms');
set(get(axes3yy(1),'Ylabel'),'String','V')
set(get(axes3yy(2),'Ylabel'),'String','\mu A')

xtick = get(handles.axes1, 'XTick');
set(handles.axes1, 'XTick', xtick(1):0.001:aftertrigger);
%figure(1);
%plot(times_aligned(u), reshape(data.data_aligned(:,u,data.channels_out), [ length(u) length(data.channels_out)])');





%if ~isempty(net)
%        set(handles.response2, 'Value', sim(net, nnsetX(:,file)) > 0.5);
%end

if false
    % Plot a close-up of the interpulse interval
    w = find(times_aligned >= halftime_us/1e6 - 0.00003 ...
        & times_aligned < halftime_us/1e6 + interpulse_s + 0.00001);
    %w = w(1:end-1);
    stim_avg = mean(data.ni.stim, 1);
    min_interpulse_volts = min(abs(stim_avg(1, w, 1)));
    plot(handles.axes4, times_aligned(w)*1000, squeeze(stim_avg(1, w, 1)));
    grid(handles.axes4, 'on');
    xlabel(handles.axes4, 'ms');
    ylabel(handles.axes4, 'V');
end

responses_detrended_prev = responses_detrended;
