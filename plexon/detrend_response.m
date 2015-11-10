function [ detrended trend detrend_param ] = detrend_response(d, data, detrend_param);

response = d.response;

if nargin ~= 3
    dbstack
    error('args', 'Wrong number of arguments to detrend_response');
end

if prod(size(response)) == 0
    % No data. Abort.
    detrended = [];
    trend = [];
    return;
end


if isfield(data, 'detrend_param') ...
        & isequal(detrend_param.model, data.detrend_param.model) ...
        & isequal(detrend_param.range, data.detrend_param.range) ...
        & isfield(d, 'response_detrended') ...
        & all(size(response) == size(d.response))
    disp('detrend_response: Using cached detrend with the same parameters.');
    detrended = d.response_detrended;
    trend = d.response_trend;
    return;
end

%disp(sprintf('DETRENDING %d pulses per channel, %d channels...', ...
%    size(response,1), size(d.response,3)));

if isempty(response)
    % Use a processed version (e.g. mean or subset) if provided; otherwise revert to detrending individuals
    response = d.response;
end

[nstims nsamples nchannels] = size(d.response);

s = size(response);
[nstims_m b c] = size(response);

if length(s) == 2 & nstims_m ~= d.n_repetitions
    error('data:kludge_error', 'data: should see %d stims, but see %d', d.n_repetitions, nstims_m);
    %response = reshape(response, 1, b, c);
    %response = reshape(response, [nsamples nchannels]); % must already be mean(response, 1)
end

% Try:
% Fourier, 8 terms
% Polynomial, degree 8
% Smoothing spline with specify 0.9999999999? Hmmm...

times = d.times_aligned;

minstarttime = data.goodtimes(1);
maxendtime = data.goodtimes(2);
%maxendtime = min(maxendtime, d.times_aligned(nsamples));

roi(1) = max(detrend_param.range(1), minstarttime);
roi(2) = min(detrend_param.range(2), maxendtime);
%disp(sprintf('detrend_response using range [%g %g] ms', roi(1)*1000, roi(2)*1000));

roii = find(d.times_aligned >= roi(1) & d.times_aligned < roi(2));
roitimes = d.times_aligned(roii);


len = length(d.times_aligned);
lenfit = length(roitimes);

% FITOPTIONS doesn't work in a parfor!?
%opts = fitoptions(fittype, 'Normalize', 'on');

trend = zeros(nstims_m, nsamples, nchannels);
detrended = zeros(nstims_m, nsamples, nchannels);

parfor stim = 1:nstims_m
    for channel = 1:nchannels
        f = fit(reshape(roitimes, [length(roii) 1]), ...
            reshape(response(stim, roii, channel), [length(roii) 1]), ...
            detrend_param.model, 'Normalize', 'on');
        trend(stim, :, channel) = f(d.times_aligned);
        detrended(stim, :, channel) = squeeze(response(stim, :, channel)) - trend(stim, :, channel);
        %detrendotron{channel} = f;
    end
end

last_detrend = detrend_param;