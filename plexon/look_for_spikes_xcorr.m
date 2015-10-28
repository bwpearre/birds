function [ spikes r ] = look_for_spikes_xcorr(d, data, detrend_param, response_detrended, handles);

% If detrend_param != d.detrend_param
%    if response_detrended == [] {
%        re-detrend using detrend_param
%    }
%    use response_detrended
% } else {
%    use d.response_detrended
% }

    
[ nstims nsamples nchannels ] = size(d.response_detrended);
times = d.times_aligned;

minstarttime = 0.001 + times(d.stim_active_indices(end));
maxendtime = -0.0005 + 1/data.repetition_Hz;
maxendtime = min(maxendtime, d.times_aligned(nsamples));

if ~exist('detrend_param') | isempty(detrend_param)
    detrend_param = data.detrend_param;
end

roi = detrend_param.response_roi;
baseline = detrend_param.response_baseline;
roi(1) = max(roi(1), minstarttime);
baseline(2) = min(baseline(2), maxendtime);

roii = find(times > roi(1) & times < roi(2));
baselinei = find(times > baseline(1) & times < baseline(2));
validi = find(times > roi(1) & times < baseline(2));



disp(sprintf('Look for spikes: toi [%g %g] ms, baseline [%g %g] ms', ...
    roi(1)*1000, roi(2)*1000, baseline(1)*1000, baseline(2)*1000));
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

%[B A] = ellip(2, .5, 40, [300 10000]/((d.fs))/2));
%[B A]= ellip(2, .5, 40, 300/(d.fs/2), 'high');
%for i = 1:nchannels
%    d.response_detrended(:, i) = filtfilt(B, A, squeeze(d.response_detrended(:, i)));
%end

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
    foo(channel,:,:) = xcorr(response_detrended(:, roii, channel)', xcorr_nsamples, 'coeff');
    cow(channel,:,:) = xcorr(response_detrended(:, baselinei, channel)', xcorr_nsamples, 'coeff');
end

%% Remove the autocorrelation of each to self
a = 1:nstims+1:nstims^2;
foo(:, :, a) = zeros(nchannels, size(foo,2), nstims);
cow(:, :, a) = zeros(nchannels, size(cow,2), nstims);
if exist('handles')
    imagesc(squeeze(foo(4,:,:)), 'Parent', handles.axes2);
    imagesc(squeeze(cow(4,:,:)), 'Parent', handles.axes4);
    colorbar('Peer', handles.axes2);
    colorbar('Peer', handles.axes4);
end

xcfoo = max(foo, [], 2);
xccow = max(cow, [], 2);
%mean(xcfoo, 3)
%mean(xccow, 3)

%r = (mean(xcfoo, 3) ./ mean(xccow, 3))';
%spikes = r > 2;

r = mean(xcfoo, 3)';
spikes = r > 10;