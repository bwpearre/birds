clear;

%cd lw95rhp-2015-11-23;

[a,experiment,c] = fileparts(pwd);
e1 = strsplit(experiment, '-');
bird = e1{1};
if strcmp(bird, 'lw85ry')
    implant_date = datenum([ 2015 04 27 0 0 0 ]);
elseif strcmp(bird, 'lw95rhp')
    implant_date = datenum([ 2015 05 04 0 0 0 ]);
else
    implant_date = datenum([ 0 0 0 0 0 0 ]);
end
experiment_date = datenum([ str2double(e1{2}) str2double(e1{3}) str2double(e1{4}) 0 0 0]);

%experiment_desc = sprintf('Bird %s, Area X, %d days post-surgery', e1{1}, experiment_date-implant_date);
experiment_desc = sprintf('%s, day %d', e1{1}, experiment_date-implant_date);

read_Intan_RHD2000_file;


[nchannels npoints] = size(amplifier_data);
fs = frequency_parameters.amplifier_sample_rate;


ad = (amplifier_data')/1e3;

[B A] = ellip(2, .000001, 30, [10 3000]/(fs/2));
for channel = 1:nchannels
%    ad(:,i) = filtfilt(B, A, ad(:,i));
end


channels = 1:nchannels;
channels = [2 5 7 15];
subplotx = 7;

nchannels = length(channels);
colours = distinguishable_colors(nchannels);
for channelnum = 1:nchannels
    channel = channels(channelnum);
    figure(1);
    %subplot(nchannels, subplotx, subplotx*(channelnum-1)+[1:subplotx-1]);
    subplot(nchannels, 1, channelnum);
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
    %legend('1','2','3','4','5','6','7','8','9','10','11','12','13','14','15','16');
    %saveas(gcf, strcat('spiketrain-', experiment, '.fig'));
    
    threshold = 8;
    window = [-0.001 0.002];
    adz = zscore(ad);

    if 0
        [ pks, locs ] = findpeaks(adz(:, channel), 'MinPeakHeight', threshold);
        subplot(nchannels, 1, channelnum);
        cla;
        hold on;
        
        for j = 1:length(locs)
            try
                indices = locs(j)+window(1)*fs : locs(j)+window(2)*fs;
                plot([window(1):1/fs:window(2)]*1e3, ...
                    ad(indices, channel), ...
                    'color', colours(channelnum,:));
                axis tight;
                
            catch ME
            end
        end
        hold off;
    end
    
    if 1
        [ pks, locs ] = findpeaks(-adz(:, channel), 'MinPeakHeight', threshold, 'MinPeakDistance', 0.01*fs);
        figure(2);
        subplot(nchannels, 3, 3*channelnum);
        %subplot(nchannels, subplotx, subplotx*(channelnum-1)+[subplotx]);
        
        cla;
        hold on;
        
        for j = 1:length(locs)
            try
                indices = locs(j)+window(1)*fs : locs(j)+window(2)*fs;
                plot([window(1):1/fs:window(2)]*1e3, ...
                    ad(indices, channel), ...
                    'color', colours(channelnum,:));
                axis tight;
                %set(gca, 'YLim', [-0.2 0.2]);
            catch ME
            end
        end
        hold off;
        if channelnum == 1
            title(experiment_desc);
        end
        if channelnum == nchannels
            xlabel('milliseconds');
        end
        %ylabel('millivolts');
        legend(sprintf('%d', channel));
        
        %title(sprintf('%s, Area X, channel %d', experiment_desc, channel));
        %xlabel('milliseconds');
        %ylabel('millivolts');

    end
end

