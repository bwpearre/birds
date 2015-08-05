function plot_stimulation(data, handles);
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
if ~isfield(handles, 'axes1')
    handles.axes1 = axes1;
    handles.axes2 = axes2;
    handles.axes3 = axes3;
    handles.axes4 = axes4;
end

persistent responses_detrended_prev;

% doplot could be a parameter, and it was, but let's just hardcode it for
% now...
doplot = true;


aftertrigger = 0.016;
beforetrigger = -0.002;

if ~isfield(data, 'version') % old format does not scale saved data
        scalefactor_V = 1/0.25;
        scalefactor_i = 400;
        data.data(:,1) = data.data(:,1) * scalefactor_V;
        data.data(:,2) = data.data(:,2) * scalefactor_i;
end

edata = data.data;

% Let's try a filter, shall we?
%disp('Bandpass-filtering the data...');
%[B A] = butter(2, 0.07, 'high');
if get(handles.response_filter, 'Value')
    [B A] = ellip(2, .5, 40, [300 10000]/(data.fs/2));
    edata(:,3) = filtfilt(B, A, edata(:,3));
end


halftime_us = data.halftime_us;
interpulse_s = data.interpulse_s;
times_aligned = data.times_aligned;
beforetrigger = max(times_aligned(1), beforetrigger);
aftertrigger = min(times_aligned(end), aftertrigger);

% u: indices into times_aligned that we want to show, aligned and shit.
u = find(times_aligned > beforetrigger & times_aligned < aftertrigger);
% v is the times to show for the pulse
v = find(times_aligned >= -0.001 & times_aligned < 0.001 + 2 * halftime_us/1e6 + interpulse_s);

axes1legend = {};
if doplot
    if get(handles.response_show_raw, 'Value')
        plot(handles.axes1, times_aligned(u), edata(u,3), 'b');
        axes1legend{end+1} = 'Measured';
        hold(handles.axes1, 'on');
        plot(handles.axes1, times_aligned(u), edata(u,4), 'c');
        axes1legend{end+1} = 'trigger';
        hold(handles.axes1, 'off');
    else
        cla(handles.axes1);
    end
    title(handles.axes1, 'HVC Response');
    xl = get(handles.axes1, 'XLim');
    xl(1) = beforetrigger;
    set(handles.axes1, ...
        'XLim', [beforetrigger aftertrigger], ...
        'YLim', (2^(get(handles.yscale, 'Value')))*[-0.3 0.3]/515/2);
    ylabel(handles.axes1, 'volts');
    grid(handles.axes1, 'on');

    yy = plotyy(handles.axes3, times_aligned(v), edata(v,1), ...
            times_aligned(v), edata(v,2));
    legend(handles.axes3, data.names{1:2});
    xlabel(handles.axes3, 'ms');
    set(get(yy(1),'Ylabel'),'String','V')
    set(get(yy(2),'Ylabel'),'String','\mu A')
end


% Try:
% Fourier, 8 terms
% Polynomial, degree 8
% Smoothing spline with specify 0.9999999999? Hmmm...


% Curve-fit: use a slightly longer time period
roifit = [ 0.0027  0.016 ];
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
end

f = fit(roitimesfit, edata(roiifit, 3), fittype, opts);
roitrend = f(times_aligned);

responses_detrended = edata(:, 3) - roitrend;

%cftool(roitimesfit,edata(roiifit,3))

roi = [0.003 0.008 ];
roii = find(times_aligned >= roi(1) & times_aligned <= roi(2));
roiiplus = find(times_aligned > roi(2) & times_aligned <= roifit(2));
roitimes = times_aligned(roii);
roitimesplus = times_aligned(roiiplus);

if doplot
    hold(handles.axes1, 'on');
    if get(handles.response_show_trend, 'Value')
        plot(handles.axes1, roitimesfit, roitrend(roiifit), 'g');
        axes1legend{end+1} = 'Trend';
    end
    if get(handles.response_show_detrended, 'Value')
        plot(handles.axes1, roitimes, responses_detrended(roii), 'r');
        plot(handles.axes1, roitimesplus, responses_detrended(roiiplus), 'k');
        axes1legend{end+1} = 'Detrended';
    end
    hold(handles.axes1, 'off');
    if ~isempty(axes1legend)
        legend(handles.axes1, axes1legend);
    end
end





if ~isempty(responses_detrended_prev)
        lastxc = [xcorr(responses_detrended_prev(roii), responses_detrended(roii), 'coeff')']';

        corr_range = [min(corr_range(1), min(min(lastxc))) ...
                max(corr_range(2), max(max(lastxc)))];
        if doplot
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
                [speck freqs times] = spectrogram(lastxc(:,1), window, [], freqs, data.fs);
                %[speck freqs times] = spectrogram(responses_detrended, window, [], freqs, data.fs);
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
        %nnsetX(:,file) = [max(lastxc(range,1)) - min(lastxc(range,1)); ...
        %        abs(pos-len); ...
        %        abs(speck(:,2))];
end

%if ~isempty(net)
%        set(handles.response2, 'Value', sim(net, nnsetX(:,file)) > 0.5);
%end

if doplot
    w = find(times_aligned >= halftime_us/1e6 - 0.00003 ...
        & times_aligned < halftime_us/1e6 + interpulse_s + 0.00001);
    %w = w(1:end-1);
    min_interpulse_volts = min(abs(edata(w,1)));
    plot(handles.axes4, times_aligned(w)*1000, edata(w,1));
    grid(handles.axes4, 'on');
    xlabel(handles.axes4, 'ms');
    ylabel(handles.axes4, 'V');
end

responses_detrended_prev = responses_detrended;
