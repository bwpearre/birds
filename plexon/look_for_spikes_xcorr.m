function [ spikes r ] = look_for_spikes_xcorr(d, data, detrend_param, response_detrended, handles);


if ~isfield(d, response_detrended) & prod(size(response_detrended)) == 0
    spikes = [];
    r = NaN;
    return;
end

[ nstims nsamples nchannels ] = size(d.response_detrended);
times = d.times_aligned;

minstarttime = data.goodtimes(1);
maxendtime = data.goodtimes(2);

if ~exist('detrend_param', 'var') | isempty(detrend_param)
    detrend_param = data.detrend_param;
end

roi = detrend_param.response_roi;
baseline = detrend_param.response_baseline;
roi(1) = max(roi(1), minstarttime);
baseline(2) = min(baseline(2), maxendtime);

roii = find(times > roi(1) & times < roi(2));
baselinei = find(times > baseline(1) & times < baseline(2));
validi = find(times > roi(1) & times < baseline(2));



%disp(sprintf('Look for spikes: toi [%g %g] ms, baseline [%g %g] ms', ...
%    roi(1)*1000, roi(2)*1000, baseline(1)*1000, baseline(2)*1000));
if length(baselinei) < 10
    disp('   ...the baseline region is too short!');
    r = zeros(1, nchannels);
    spikes = zeros(1, nchannels);
    return;
end    
if length(roii) < 10
    disp('   ...the ROI region is too short!');
    r = zeros(1, nchannels);
    spikes = zeros(1, nchannels);
    return;
end

if ~isfield(d, 'response_detrended') ...
        | (exist('detrend_param') & ~isempty(detrend_param) ...
           & ~isequal(detrend_param, data.detrend_param) ...
           & isempty(response_detrended))
    disp('look_for_spikes_xcorr: re-detrending as follows:');
    detrend_param
    response_detrended = detrend_response([], d, data, detrend_param);
else
    response_detrended = d.response_detrended;
end


%[B A] = ellip(2, .5, 40, [300 2000]/((d.fs))/2);
%[B A]= ellip(2, .5, 40, 300/(d.fs/2), 'high');
%parfor channel = 1:nchannels
%    for stim = 1:nstims
%        response_detrended(stim, :, channel) = filtfilt(B, A, squeeze(response_detrended(stim, :, channel)));
%    end
%end


if exist('handles') & false
    set(handles.axes2, 'ColorOrder', distinguishable_colors(nchannels));
    cla(handles.axes2);
    hold(handles.axes2, 'on');
    for i = 1:nchannels
        plot(handles.axes2, ...
            times, ...
            response_detrended(:, i));
    end
    set(handles.axes2, 'XLim', get(handles.axes1, 'XLim'));
    hold(handles.axes2, 'off');
end


xcorr_nsamples = round(0.001 * d.fs);
parfor channel = 1:nchannels
    % foo dimensions: [ channel time_offset stimXstim ]
    foo(channel,:,:) = xcorr(response_detrended(:, roii, channel)', xcorr_nsamples, 'unbiased');
    cow(channel,:,:) = xcorr(response_detrended(:, baselinei, channel)', xcorr_nsamples, 'unbiased');
    %foo(channel,:,:) = cov(response_detrended(:, roii, channel)');
    %cow(channel,:,:) = cov(response_detrended(:, baselinei, channel)');
end


%% Remove the autocorrelation of each to self: that is the signal's power--useful?
if 1
    a = 1:nstims+1:nstims^2;
    foo(:, :, a) = zeros(nchannels, size(foo,2), nstims);
    cow(:, :, a) = zeros(nchannels, size(cow,2), nstims);
end

% Draw some stuff?
channel = 1;
if exist('handles') & false
    %imagesc(squeeze(foo(channel,:,:)), 'Parent', handles.axes2);
    %imagesc(squeeze(cow(channel,:,:)), 'Parent', handles.axes4);
    colorbar('Peer', handles.axes2);
    colorbar('Peer', handles.axes4);
    title(handles.axes2, sprintf('Cross-correlation for channel %d', channel));
end

% For each stimXstim pair, find maximum xcorrelation over the time interval xcorr_nsamples
xcfoo = max(foo, [], 2);
xccow = max(cow, [], 2);

% Average over stimXstim pairs
%mean(xcfoo, 3)
%mean(xccow, 3)

%r = (mean(xcfoo, 3) ./ mean(xccow, 3))';
r = mean(xcfoo, 3)';
spikes = r >= detrend_param.response_detection_threshold;
