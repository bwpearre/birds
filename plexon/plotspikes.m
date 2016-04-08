channels = goodchannels;
nchannels = length(channels);
colours = distinguishable_colors(nchannels);
for channelnum = 1:nchannels
    channel = channels(channelnum);
    
    
    if 1
        [ pks, locs ] = findpeaks(-adz(:, channel), 'MinPeakHeight', threshold, 'MinPeakDistance', 0.01*fs);
        figure(1);
        %subplot(nchannels, 3, 3*channelnum);
        subplot(nchannels, subplotx, subplotx*(channelnum-1)+[subplotx]);
        %subplot(nchannels, 1, channelnum);
        cla;
        
        set = zeros(length([window(1):1/fs:window(2)]), length(locs));
        for j = 1:length(locs)<
            try
                indices = locs(j)+window(1)*fs : locs(j)+window(2)*fs;
%                 plot([window(1):1/fs:window(2)]*1e3, ...
%                     ad(indices, channel), ...
%                     'color', colours(channelnum,:));
                set(:, j) = ad(indices, channel);
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
        
        %set(gca, 'YLim', [-0.2 0.2]);
    
            
        if channelnum == 1
            title(experiment_desc);
        end
        if channelnum == nchannels
            xlabel('milliseconds');
        end
        %ylabel('millivolts');
        legend(sprintf('%d', channel));
        
    end
    
    
    
    
    
    figure(1);
    subplot(nchannels, subplotx, subplotx*(channelnum-1)+[1:subplotx-1]);
    %subplot(nchannels, 1, channelnum);
    plot(t_amplifier*1e3, ad(:,channel), 'color', colours(channelnum,:));
    axis tight;
    if channelnum == 1
        title(experiment_desc);
    end
    if channelnum == nchannels
        xlabel('milliseconds');
    end
    ylabel('millivolts');
    legend(sprintf('%d', channel));    
    
end

