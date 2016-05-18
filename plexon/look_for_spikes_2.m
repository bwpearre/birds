function [ spikes r ] = look_for_spikes_xcorr(d, data, detrend_param, response_detrended, handles);


[ nstims nsamples nchannels ] = size(d.response_detrended);
times = d.times_aligned;

if ~isfield(d, 'response_detrended') & prod(size(response_detrended)) == 0
    spikes = [];
    r = NaN * zeros(1, nchannels);
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
%validi = find(times > roi(1) & times < baseline(2));



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
    response_detrended = detrend_response(d, data, detrend_param);
else
    response_detrended = d.response_detrended;
end


[B A] = ellip(2, .5, 40, [500 1000]/((d.fs))/2);
parfor channel = 1:nchannels
    for stim = 1:nstims
%        response_detrended(stim, :, channel) = filtfilt(B, A, squeeze(response_detrended(stim, :, channel)));
    end
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

RESPONSE_DETECTION_THRESHOLD = 4;

% Find the std dev of the non-roi.  BASERMS is indexed in matrix indices [1 2 3...]
peaks{1} = [];
peaks{2} = [];
kclusts = [];
probs = zeros(1, nchannels, 2);
min_peaks = 3;
g = {};

for channel = 1:nchannels
    basestd(channel) = std(reshape(response_detrended(:, baselinei, channel), 1, []));
    for stim = 1:nstims
        [ ~, x ] = findpeaks(response_detrended(stim, roii, channel), times(roii), ...
            'MinPeakHeight', RESPONSE_DETECTION_THRESHOLD*basestd(channel), ...
            'MinPeakDistance', 0.001);
        peaks{1} = [peaks{1} x];
        [ ~, x ] = findpeaks(-response_detrended(stim, roii, channel), times(roii), ...
            'MinPeakHeight', RESPONSE_DETECTION_THRESHOLD*basestd(channel), ...
            'MinPeakDistance', 0.001);
        peaks{2} = [peaks{2} x];
    end

    
    for posneg = [1 2]
        clust_k = [2:10]; % Try these k-cluster values
        if length(peaks{posneg}) >= min_peaks
            for k = clust_k
                try
                    g{k} = fitgmdist(peaks{posneg}', k);
                    aic(k) = g{k}.AIC;
                    if k > 1 & aic(k) > aic(k-1)
                        break;
                    end
                catch ME
                    break;
                end
            end
            [~, kclusts(posneg)] = min(aic);
        
            
            gmm_final{posneg} = g{kclusts(posneg)};
            clust = cluster(gmm_final{posneg}, peaks{posneg}');
            % For each cluster with sigma < 100 us, how many members does the cluster have?
            for c = 1:kclusts(posneg)
                gmm_counts{posneg}(c) = sum(abs(peaks{posneg}(find(clust==c)) - gmm_final{posneg}.mu(c)) < 0.0002);
                
                probs(c, channel, posneg) = sum(abs(peaks{posneg} - gmm_final{posneg}.mu(c)) < 0.0001);
            end
        end
    end
end

if isempty(g)
    r = zeros(1, nchannels);
    spikes = zeros(1, nchannels);
    return;
end

probs = probs / nstims;
% Find most probable cluster
for channel = 1:nchannels
    for posneg = 1:2
        r(channel) = max(max(probs(:,channel,:)));
    end
end
spikes = r > 0.3;


% Draw some stuff?
channel = 1;
posneg = 2;
if exist('handles')
    v = gmm_final{posneg}.pdf(times(roii)');
    v = v / max(v);
    
    axes(handles.axes2);
    cla;
    hold on;
    %histogram(positives,50);
    h = histogram(peaks{posneg}*1000, 30);
    plot(times(roii)*1000, v*max(h.Values));
    hold off;
    title(handles.axes2, sprintf('Spikes on channel %d', channel));
    xlabel('ms');
end

a=1;

