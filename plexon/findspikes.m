function [ goodchannels, alllocs ] = findspikes(stuff, channels, threshold);

amplifier_data = stuff.amplifier_data;
frequency_parameters = stuff.frequency_parameters;

[nchannels npoints] = size(amplifier_data);
fs = frequency_parameters.amplifier_sample_rate;




%[B A] = ellip(2, .000001, 30, [10 3000]/(fs/2));
%for channel = 1:nchannels
    %ad(:,i) = filtfilt(B, A, ad(:,i));
%    ad(:,channel) = ad(:,channel)-mean(ad(:,channel));
%end

% This is zscore, since the data are already zero-mean.  This is faster:
adz = bsxfun(@rdivide, stuff.amplifier_data, std(stuff.amplifier_data, 0, 2));


goodchannels = [];
alllocs = {};

nchannels = length(channels);
for channelnum = 1:nchannels
    channel = channels(channelnum);
    locs = [];
    
    if ~isempty(adz)
        [ pks, locs ] = findpeaks(-adz(channel, :), ...
            'MinPeakHeight', threshold, ...
            'MinPeakDistance', 0.003*fs);
        alllocs{channel} = locs;
    end
    
    if length(locs) >= 1
        goodchannels(end+1) = channel;
    end
end
