function [ goodchannels, locs ] = findspikes(stuff, channels, threshold);

amplifier_data = stuff.amplifier_data;
frequency_parameters = stuff.frequency_parameters;

[nchannels npoints] = size(amplifier_data);
fs = frequency_parameters.amplifier_sample_rate;


ad = (amplifier_data')/1e3;


[B A] = ellip(2, .000001, 30, [10 3000]/(fs/2));
for channel = 1:nchannels
    %ad(:,i) = filtfilt(B, A, ad(:,i));
    ad(:,channel) = ad(:,channel)-mean(ad(:,channel));
end


adz = zscore(ad);

    
if length(channels) == 16
    
    goodchannels = [];    
    
    
    nchannels = length(channels);
    for channelnum = 1:nchannels
        channel = channels(channelnum);
        
        [ pks, locs ] = findpeaks(-adz(:, channel), 'MinPeakHeight', threshold, 'MinPeakDistance', 0.01*fs);
        alllocs{channelnum} = locs;
        
        if length(locs) > 5
            goodchannels(end+1) = channel;
            
            for j = 1:length(locs)
                try
                    indices = locs(j)+window(1)*fs : locs(j)+window(2)*fs;
                catch ME
                end
            end
        end
    end
else
    goodchannels = channels;
end

