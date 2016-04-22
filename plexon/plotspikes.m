function [] = plotspikes(sessions, goodsessions, channels, window);

nchannels = length(channels);
colours = distinguishable_colors(nchannels);
nsessions = length(find(goodsessions));

sessioncounter = 0;
xlims = [];
ylims = [];
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
        locs = sessions{session}.peaklocs{channelnum};        
        spikeset = zeros(length([window(1):1/fs:window(2)]), length(locs));
        for j = 1:length(locs)
            try
                indices = locs(j)+window(1)*fs : locs(j)+window(2)*fs;
                spikeset(:, j) = ad(channel, indices);
            catch ME
            end
        end
        
        n = length(locs);
        mu = mean(spikeset, 2);
        sigma = std(spikeset, 0, 2);
        ste = sigma / sqrt(n);
        ste95 = ste * 1.96;
        
        if n > 10
            if true
                shadedErrorBar([window(1):1/fs:window(2)]*1e3, ...
                    mu, ...
                    ste95, ...
                    {'color', colours(channelnum,:)}, 1);
            else
                plot([window(1):1/fs:window(2)]*1e3, ...
                    spikeset, ...
                    'color', colours(channelnum,:));
            end
        end
        grid on;
        axis tight;
        ylims = [ylims; get(gca, 'YLim')];
        legend(sprintf('n=%d', length(locs)), 'Location', 'SouthEast');        
        
        if channelnum == 1
            title(strcat(sessions{session}.experiment_desc, ...
                sprintf(' (%d s)', round(sessions{session}.data.t_total_s))));
        end
        
        if channelnum == nchannels
            xlabel('milliseconds');
        else
            set(gca, 'XTickLabel', []);
        end
        if sessioncounter == 1
            ylabel(sprintf('ch %d, \\mu V', channel));
        end
        if mod(sessioncounter-1, nsessions)
            set(gca, 'YTickLabel', []);
        end
        %ylabel('millivolts');
        %legend(sprintf('%d', channel));
        
    end
end

ylims = [min(ylims(:,1))-eps max(ylims(:,2))+eps];
%ylims = [-150 100];
sessioncounter = 0;
for session = find(goodsessions)
    sessioncounter = sessioncounter+1;
    for channelnum = 1:nchannels
        channel = channels(channelnum);
        subplot(nchannels, nsessions, nsessions*(channelnum-1)+sessioncounter);
        set(gca, 'YLim', ylims);
    end
end
