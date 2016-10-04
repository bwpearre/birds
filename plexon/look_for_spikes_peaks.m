function [ spikes response probability ] = look_for_spikes_peaks(d, data, detrend_param, response_detrended, handles);

MAX_JITTER = 0.0002; % seconds.  Projectors should be synchronous to within 50 us, while intraneurons might be 200 us.

[ nstims nsamples nchannels ] = size(d.response_detrended);
times = d.times_aligned;

if ~isfield(d, 'response_detrended') & prod(size(response_detrended)) == 0
    spikes = [];
    response = NaN * zeros(1, nchannels);
    return;
end

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
%if max(baselinei) > size(response_detrended, 2)
%    baselinei = baselinei(find(baselinei <= size(response_detrended, 2)));
%    disp('Shortening baselinei');
%end
%validi = find(times > roi(1) & times < baseline(2));



%disp(sprintf('Look for spikes: toi [%g %g] ms, baseline [%g %g] ms', ...
%    roi(1)*1000, roi(2)*1000, baseline(1)*1000, baseline(2)*1000));
if length(baselinei) < 10
    warning('   ...the baseline region is too short!: %d', length(baselinei));
    response = zeros(1, nchannels);
    spikes = zeros(1, nchannels);
    return;
end    
if length(roii) < 10
    warning('   ...the ROI region is too short!');
    response = zeros(1, nchannels);
    spikes = zeros(1, nchannels);
    return;
end

if ~isfield(d, 'response_detrended') ...
        | (exist('detrend_param') & ~isempty(detrend_param) ...
           & ~isequal(detrend_param, data.detrend_param) ...
           & isempty(response_detrended))
    disp('look_for_spikes_peaks: re-detrending as follows:');
    detrend_param
    response_detrended = detrend_response(d, data, detrend_param);
else
    response_detrended = d.response_detrended;
end


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

% Find the std dev of the non-roi.  BASERMS is indexed in matrix indices [1 2 3...]

pp = zeros(2, nchannels); % Counts of peaks that line up.
ppos = NaN * zeros(2, nchannels);
for channel = 1:nchannels
    peaks{1,channel} = [];
    peaks{2,channel} = [];
    basestd(channel) = std(reshape(response_detrended(:, baselinei, channel), 1, []));

    % Find peaks, but they must be separated from each other by at least MinPeakDistance
    for stim = 1:nstims
        [ ~, x ] = findpeaks(response_detrended(stim, roii, channel), times(roii), ...
            'MinPeakHeight', detrend_param.response_sigma*basestd(channel), ...
            'MinPeakDistance', 0.0005);
        peaks{1,channel} = [peaks{1,channel} x];
        [ ~, x ] = findpeaks(-response_detrended(stim, roii, channel), times(roii), ...
            'MinPeakHeight', detrend_param.response_sigma*basestd(channel), ...
            'MinPeakDistance', 0.0005);
        peaks{2,channel} = [peaks{2,channel} x];
    end

    
    for posneg = [1 2]
        % How big is each group of spikes within 100us of each other?
        dists = squareform(pdist(peaks{posneg,channel}'));
        counts{posneg,channel} = sum(dists <= MAX_JITTER);
        if max(counts{posneg,channel}) > 0
            [pp(posneg,channel) ppos(posneg,channel)] = max(counts{posneg,channel});
        end
    end
end

% If fewer than 2 peaks line up, toss the singletons:
pp(find(pp < 2)) = 0;
pp = pp / nstims;
response = max(pp);
spikes = response >= detrend_param.response_prob;
probability = max(response);

% Plot curves and detected spikes on channel 'channel'
if exist('handles')
    channel = 1;
    axes(handles.axes4);
    cla;
    hold on;
    plot(times(roii)*1e3, squeeze(response_detrended(:,roii,channel))*1e3);
    line((1e3*[1;1]*[times(roii(1)) times(roii(end))])', ...
        (1e3*[1 1; -1 -1]*detrend_param.response_sigma*basestd(channel))');
    if pp(1,channel) >= detrend_param.response_prob
        scatter(peaks{1,channel}(ppos(1,channel))*1e3, ...
            0, ...
            200, [1 0 0], '^', 'filled');
    end
    if pp(2,channel) >= detrend_param.response_prob
        scatter(peaks{2,channel}(ppos(2,channel))*1e3, ...
            0, ...
            200, [1 0 0], 'v', 'filled');
    end
    
    hold off;
    ylabel('\mu V');
    xlabel('ms');
end
