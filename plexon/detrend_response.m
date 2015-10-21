function [ detrended trend ] = detrend_resposne(response, d, data, toi);
    
fittype = 'fourier4';

persistent last_toi;
if isempty(toi)
    toi = last_toi;
end

if isempty(response)
    % Use the mean if provided; otherwise revert to detrending individuals
    response = d.response;
end

[nstims nsamples nchannels] = size(d.response);

s = size(response);
[nstims_m b c] = size(response);

if length(s) == 2
    response = reshape(response, 1, b, c);
    %response = reshape(response, [nsamples nchannels]); % must already be mean(response, 1)
end

colours = distinguishable_colors(nchannels);
% Try:
% Fourier, 8 terms
% Polynomial, degree 8
% Smoothing spline with specify 0.9999999999? Hmmm...


% Curve-fit: use a slightly longer time period
%roifit = [ stim_duration + 100e-6 0.008 ];

times = d.times_aligned;

minstarttime = 0.001 + times(d.stim_active_indices(end));
maxendtime = -0.0005 + 1/data.repetition_Hz;
maxendtime = min(maxendtime, d.times_aligned(nsamples));

toi(1) = max(toi(1), minstarttime);
toi(2) = min(toi(2), maxendtime);
disp(sprintf('detrend_response using range [%g %g]ms', toi(1)*1000, toi(2)*1000));

roii = find(d.times_aligned >= toi(1) & d.times_aligned < toi(2));
roitimes = d.times_aligned(roii);


len = length(d.times_aligned);
lenfit = length(roitimes);


opts = fitoptions(fittype);
opts.Normalize = 'on';

trend = zeros(nstims_m, nsamples, nchannels);
detrended = zeros(nstims_m, nsamples, nchannels);

for stim = 1:nstims_m
    for channel = 1:nchannels
        f = fit(roitimes', reshape(response(stim, roii, channel), [length(roii) 1]), fittype, opts);
        trend(stim, :, channel) = f(d.times_aligned);
        detrended(stim, :, channel) = squeeze(response(stim, :, channel)) - trend(stim, :, channel);
        %detrendotron{channel} = f;
    end
end

last_toi = toi;
