function [ detrended detrendotron ] = detrend_resposne(response, d, data, toi, handles);
    
fittype = 'fourier8';


nchannels = size(d.response, 3);
s = size(response);
if length(s) == 3
    response = reshape(response, s(2:3)); % must already be mean(response, 1)
end

colours = distinguishable_colors(nchannels);
% Try:
% Fourier, 8 terms
% Polynomial, degree 8
% Smoothing spline with specify 0.9999999999? Hmmm...


% Curve-fit: use a slightly longer time period
%roifit = [ stim_duration + 100e-6 0.008 ];
roii = find(d.times_aligned >= toi(1) & d.times_aligned < toi(2));
roitimes = d.times_aligned(roii);


len = length(d.times_aligned);
lenfit = length(roitimes);



opts = fitoptions;
opts.Normalize = 'on';

if false
    % Blank the data during stimulation.  FIT can't handle NaN, so just set the
    % fit weights to 0 for that period.
    weights_blanking = roiifit;
    weights_blanking(d.stim_active_indices(1)-roii(1)+1 : d.stim_active_indices(end)-roii(1)+1) = ...
        zeros(1, length(d.stim_active_indices));
    weights_blanking = double(weights_blanking ~= 0);
    %opts.Weights = weights;
end

detrended = zeros(length(d.times_aligned), nchannels);

for channel = 1:nchannels
    f = fit(roitimes', squeeze(response(roii, channel)), ...
        fittype, opts);
    roitrend(:, channel) = f(d.times_aligned);
    detrended(:, channel) = squeeze(response(:, channel)) - roitrend(:, channel);
    detrendotron{channel} = f;
end


%% Stanza for inside per-channel plotting loop...
%    if get(handles.response_show_trend, 'Value')
%        plot(handles.axes1, roitimes, roitrend(roii, channel), ...
%            'Color', colours(channel,:), 'LineStyle', ':');
%        axes1legend{end+1} = 'Trend';
%    end
