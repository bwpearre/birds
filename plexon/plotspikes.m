function [] = plotspikes(sessions, goodsessions, channels, n_min, window, colours);

nchannels = length(channels);
nsessions = length(find(goodsessions));

sessioncounter = 0;
xlims = [];
ylims = [];
figure(1);
clf;

for session = find(goodsessions)
    sessioncounter = sessioncounter+1;
    fs = sessions{session}.data.frequency_parameters.amplifier_sample_rate;

    for channelnum = 1:nchannels
        
        channel = channels(channelnum);

        if isempty(find(sessions{session}.recording_channels == channel, 1))
            continue;
        end
        
        
        subplot(nchannels, nsessions, nsessions*(channelnum-1)+sessioncounter);
        %subplot(nchannels, 1, channelnum);
        cla;
        
        ad = sessions{session}.data.amplifier_data;
        locs = sessions{session}.peaklocs{channel};        
        spikeset = zeros(length([window(1):1/fs:window(2)]), length(locs));
        
        %disp(sprintf('rms = %s', sigfig(rms(ad(channel)))));
        for j = 1:length(locs)
            try
                indices = locs(j)+window(1)*fs : locs(j)+window(2)*fs;
                spikeset(:, j) = ad(channel, indices);
            catch ME
            end
        end
        
        n = length(locs);
        mu = nanmean(spikeset, 2);
        sigma = nanstd(spikeset, 0, 2);
        ste = sigma / sqrt(n);
        ste95 = ste * 1.96;
        
        if n >= n_min
            if true
                shadedErrorBar([window(1):1/fs:window(2)]*1e3, ...
                    mu, ...
                    sigma, ...
                    {'color', [0 0 0]});
                hold on;
                shadedErrorBar([window(1):1/fs:window(2)]*1e3, ...
                    mu, ...
                    ste95, ...
                    {'color', colours(channelnum,:)});
                hold off;
            else
                plot([window(1):1/fs:window(2)]*1e3, ...
                    spikeset, ...
                    'color', colours(channelnum,:));
            end
        end
        grid on;
        axis tight;
        ylims = [ylims; get(gca, 'YLim')];
        %legend(sprintf('n=%d', length(locs)), 'Location', 'SouthEast');
        text(0.95, 0, sprintf('%ds\nn=%d\n%s/s', ...
            round(sessions{session}.data.t_total_s), ...
            length(locs), ...
            sigfig(length(locs)/sessions{session}.data.t_total_s)), ...
            'Units', 'normalized', 'HorizontalAlignment', 'right', ...
            'VerticalAlignment', 'bottom', 'FontSize', 8);
        
        if channelnum == 1
            title(sprintf('day %d', round(sessions{session}.experiment_day)));
        end
        
        if channelnum == nchannels
            %xlabel('milliseconds');
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

axfoo = axes('Position', [0 0 1 1], 'Visible', 'off');
axes(axfoo);
mstext = text(0.5, 0.05, 'milliseconds', 'HorizontalAlignment', 'center');
