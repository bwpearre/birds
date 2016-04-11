function [] = plotspikes(sessions, goodsessions, channels, window);

nchannels = length(channels);
colours = distinguishable_colors(nchannels);
nsessions = length(find(goodsessions));

sessioncounter = 0;
for session = find(goodsessions)
    sessioncounter = sessioncounter+1;
    fs = sessions{session}.data.frequency_parameters.amplifier_sample_rate;

    for channelnum = 1:nchannels
        channel = channels(channelnum);
        
        figure(1);
        subplot(nchannels, nsessions, nsessions*(channelnum-1)+sessioncounter);
        %subplot(nchannels, 1, channelnum);
        cla;
        
        ad = sessions{session}.data.amplifier_data;
        locs = sessions{session}.peaklocs{channel};        
        set = zeros(length([window(1):1/fs:window(2)]), length(locs));
        for j = 1:length(locs)
            try
                indices = locs(j)+window(1)*fs : locs(j)+window(2)*fs;
                set(:, j) = ad(channel, indices);
            catch ME
            end
        end
        
        n = length(locs);
        mu = mean(set, 2);
        sigma = std(set, 0, 2);
        ste = sigma / sqrt(n);
        ste95 = ste * 1.96;
        
        shadedErrorBar([window(1):1/fs:window(2)]*1e3, ...
            mu, ...
            ste95, ...
            {'color', colours(channelnum,:)}, 1);
        grid on;
        axis tight;
        legend(sprintf('n=%d', length(locs)));
        
        %set(gca, 'YLim', [-0.2 0.2]);
        
        
        if channelnum == 1
            title(sessions{session}.experiment_desc);
        end
        
        if channelnum == nchannels
            xlabel('milliseconds');
        end
        if sessioncounter == 1
            ylabel('microvolts');
        end
        %ylabel('millivolts');
        %legend(sprintf('%d', channel));
        
    end
end