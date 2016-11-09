function plot_stimulation(data, handles, use_cached);

global axes1 axes2 axes3 axes4;
global detrend_param;

% A bunch of GUI-changing functions want to be able to call
% plot_stimulation but because they're called through the GUI they don't
% have access to 'data'. So if plot_stimulation([], handles), use the last
% data plotted.
persistent cached_data;
if isempty(data) & ~exist('use_cached', 'var')
    return;
elseif exist('use_cached', 'var') & use_cached
    data = cached_data;
else
    if isempty(data)
        a(0)
    end
    cached_data = data;
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




index_selected = get(handles.show_device, 'Value');
list = get(handles.show_device, 'String');
eval(sprintf('d = data.%s;', char(list(index_selected))));

nchannels = size(d.response, 3);
n_repetitions = d.n_repetitions;

% For the graph
xscale = get(handles.xscale, 'Value');
beforetrigger = -4 * 1e-3 * xscale;
aftertrigger = 30 * 1e-3 * xscale;

colours = distinguishable_colors(nchannels);

% Generate stimulation alignment information
%if data.version <= 15 | ~isfield(d, 'stim_active_indices')
%    data.stim_duration_s = 2*data.stim.halftime_s + data.stim.interpulse_s;
%    d.stim_active_indices = find(d.times_aligned >= 0 ...
%        & d.times_aligned <= data.stim_duration_s);
%    d.stim_active = 0 * d.response(1, :, 1);    
%    d.stim_active(d.stim_active_indices) = ones(1, length(d.stim_active_indices));
%else
d.stim_active = d.stim_active(1:size(d.response, 2));
%end
stim_times = d.times_aligned(d.stim_active_indices);



times_aligned = d.times_aligned;
beforetrigger = max(times_aligned(1), beforetrigger);
aftertrigger = min(times_aligned(end), aftertrigger);


% u: indices into times_aligned that we want to show, aligned and shit.
u = find(times_aligned > beforetrigger & times_aligned < aftertrigger);
%w = find(times_aligned >= 0.003 & times_aligned < 0.008);

if isempty(u) | length(u) < 5
    disp(sprintf('WARNING: time alignment problem.  Is triggering working?'));
    return;
end

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

    

linewidths = 0.3*ones(1, nchannels);
%linewidths(find(d.spikes)) = ones(1, length(linewidths(find(d.spikes))));


% get(handles.response_show_all, 'Value')

if get(handles.response_filter, 'Value')
    [B A] = ellip(2, .001, 30, [300 3000]/(d.fs/2));
    for i = 1:size(response_plot, 1)
        response_plot(i,:,:) = filtfilt(B, A, squeeze(response_plot(i,:,:)));
    end
end




%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Plot axes1
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

roi = [ max(detrend_param.range(1), data.goodtimes(1)) ...
    min(detrend_param.range(2), data.goodtimes(2))];
roii = find(d.times_aligned >= roi(1) & d.times_aligned < roi(2));
roitimes = d.times_aligned(roii);

cla(handles.axes1);
hold(handles.axes1, 'on');
legend_handles = [];
legend_names = {};

if any(d.spikes)
    set(handles.response_indicator, 'BackgroundColor', [ 1 0 1 ], 'String', 'Response!');
else
    set(handles.response_indicator, 'BackgroundColor', 0.94 * [1 1 1], 'String', 'Response?');
end

if isfield(data, 'tdt')
    for ch = 1:length(d.index_recording)
        chr = d.index_recording(ch);
        if d.spikes(ch)
            set(handles.tdt_show_buttons{chr}, 'BackgroundColor', [1 0 1]);
        else
            set(handles.tdt_show_buttons{chr}, 'BackgroundColor', 0.94 * [1 1 1]);
        end
    end
end

if isfield(d, 'show_now')
    show_channels = d.show_now;
else
    show_channels = d.show;
end

% These need to be cached so we don't get inconsistent legends halfway
% through.
show_avg = get(handles.response_show_avg, 'Value');
show_all = get(handles.response_show_all, 'Value');

show_raw = get(handles.response_show_raw, 'Value');
show_trend = get(handles.response_show_trend, 'Value');
show_detrended = get(handles.response_show_detrended, 'Value');

if ~(show_raw | show_trend | show_detrended)
    set(handles.response_show_raw, 'Value', 1);
    show_raw = true;
end


clear h; % Handles for plot -- if empty, there will be no legend, title, etc 
for channel = show_channels
    
    % Raw (or filtered) response
    if show_raw
        h = plot(handles.axes1, ...
            1e3*times_aligned(u), ...
            1e6*reshape(response_plot(:,u,channel), [size(response_plot, 1) length(u)])', ...
            'Color', colours(channel, :), 'LineWidth', linewidths(channel));
    end
    
    
    % Trend
    if show_trend
        if show_avg
            h = plot(handles.axes1, 1e3*roitimes, ...
                1e6*reshape(mean(d.response_trend(:, roii, channel), 1), [1 length(roii)])', ...
                'Color', colours(channel, :));
        else
            h = plot(handles.axes1, 1e3*roitimes, ...
                1e6*reshape(d.response_trend(:, roii, channel), [size(d.response_detrended, 1) length(roii)])', ...
                'Color', colours(channel, :));
        end
    end

    % Detrended
    if show_detrended
        if show_avg
            h = plot(handles.axes1, 1e3*roitimes, ...
                1e6*reshape(mean(d.response_detrended(:, roii, channel), 1), [1 length(roii)])', ...
                'Color', colours(channel, :), 'LineWidth', 2);
        else
            h = plot(handles.axes1, 1e3*roitimes, ...
                1e6*reshape(d.response_detrended(:, roii, channel), [size(d.response_detrended, 1) length(roii)])', ...
                'Color', colours(channel, :), 'LineWidth', linewidths(channel));
        end
    end
    
    % Add whatever we've got to the legend bookkeeper
    if exist('h', 'var')
        legend_handles(end+1) = h(1);
        legend_names(end+1) = strcat(d.names(channel), ' (', sigfig(d.spikes_r(channel), 4), ')');
    end
    
end
hold(handles.axes1, 'off');
%legend(handles.axes1, legendhandles, {'Raw', 'Trend', 'Detrended'});
%legend_names = d.names(d.show);
if exist('h', 'var')
    try
        legend(handles.axes1, legend_handles, legend_names);
    catch ME
        disp('Legend error: inconsistent legend state.');
    end

    title(handles.axes1, 'Response');
    xl = get(handles.axes1, 'XLim');
    xl(1) = beforetrigger;
    set(handles.axes1, ...
        'XLim', 1e3*[beforetrigger aftertrigger], ...
        'YLim', (2^(get(handles.yscale, 'Value')))*[-0.3 0.3]*1e3);
    ylabel(handles.axes1, 'voltage (\mu V)');
    xlabel(handles.axes1, 'time (ms)');
    grid(handles.axes1, 'on');
end


v = find(data.ni.times_aligned >= -0.0002 ...
    & data.ni.times_aligned < 0.0002 + 2 * data.stim.halftime_s + data.stim.interpulse_s);
if isempty(v)
    disp('No data to plot here... quitting...');
    return;
end
%axes3yy = plotyy(handles.axes3, data.ni.times_aligned(v), squeeze(mean(data.ni.stim(:, v, 1), 1)), ...
[axes3yy h1 h2] = plotyy(handles.axes3, data.ni.times_aligned(v)*1e3, squeeze(data.ni.stim(:, v, 1)), ...
    data.ni.times_aligned(v)*1e3, squeeze((data.ni.stim(:, v, 2))));
set(axes3yy(1), 'XLim', data.ni.times_aligned(v([1 end]))*1e3, 'YColor', 'b');
set(axes3yy(2), 'XLim', data.ni.times_aligned(v([1 end]))*1e3, 'YColor', 'r');
for i = 1:length(h1)
    set(h1(i), 'Color', 'b');
    set(h2(i), 'Color', 'r');
end

hold(axes3yy(2), 'on');
h3 = plot(axes3yy(2), data.stim.target_current(1,:)*1e3, data.stim.target_current(2,:), 'Color', [0 1 0]);

%%%%%%%% Plot lines showing the detected range of voltages
%line(data.ni.times_aligned(v([1 end])) * 1e3, data.voltage_range([1 1]));
%line(data.ni.times_aligned(v([1 end])) * 1e3, data.voltage_range([2 2]));
%%%%%%%

hold(axes3yy(2), 'off');

legend_handles = [h1(1) h2(1) h3];
legend_names = {'V', 'i', 'i*'};
legend(handles.axes3, legend_handles, legend_names);

xlabel(handles.axes3, 'ms');
set(get(axes3yy(1),'Ylabel'),'String','V')
set(get(axes3yy(2),'Ylabel'),'String','\mu A')
title(handles.axes3, sprintf('Stimulation (%sV, %snC)', sigfig(data.voltage, 3), ...
    sigfig(data.stim.current_uA * data.stim.halftime_s * 1e3, 3)));


xtick = get(handles.axes1, 'XTick');
set(handles.axes1, 'XTick', xtick(1):aftertrigger*1e3);
%figure(1);
%plot(times_aligned(u), reshape(data.data_aligned(:,u,data.channels_out), [ length(u) length(data.channels_out)])');




%if ~isempty(net)
%        set(handles.response2, 'Value', sim(net, nnsetX(:,file)) > 0.5);
%end

if false
    % Plot a close-up of the interpulse interval
    w = find(times_aligned >= data.stim.halftime_s - 0.00003 ...
        & times_aligned < data.stim.halftime_s + data.stim.interpulse_s + 0.00001);
    %w = w(1:end-1);
    stim_avg = mean(data.ni.stim, 1);
    min_interpulse_volts = min(abs(stim_avg(1, w, 1)));
    plot(handles.axes4, times_aligned(w)*1000, squeeze(stim_avg(1, w, 1)));
    grid(handles.axes4, 'on');
    xlabel(handles.axes4, 'ms');
    ylabel(handles.axes4, 'V');
end


drawnow;
