clear;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%

channels = 1:16;
%channels = [1 8 10 12 16]
subplotx = 5;
threshold = 5;
window = [-0.001 0.002];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%cd lw95rhp-2015-11-23;

[a,experiment,c] = fileparts(pwd);
e1 = strsplit(experiment, '-');
bird = e1{1};
if strcmp(bird, 'lw85ry')
    implant_date = datenum([ 2015 04 27 0 0 0 ]);
elseif strcmp(bird, 'lw95rhp')
    implant_date = datenum([ 2015 05 04 0 0 0 ]);
elseif strcmp(bird, 'lw94rhp')
    implant_date = datenum([ 2015 04 28 0 0 0 ]);
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


adz = zscore(ad);

    
if length(channels) == 16
    
    goodchannels = [];    
    
    
    nchannels = length(channels);
    for channelnum = 1:nchannels
        channel = channels(channelnum);
        
        [ pks, locs ] = findpeaks(-adz(:, channel), 'MinPeakHeight', threshold, 'MinPeakDistance', 0.01*fs);
        
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
        for j = 1:length(locs)
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
        set95 = ste * 1.96;
        
        shadedErrorBar([window(1):1/fs:window(2)]*1e3, ...
            mu, ...
            set95, ...
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

