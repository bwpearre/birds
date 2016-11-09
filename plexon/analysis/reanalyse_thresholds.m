clear;

global showP;


files = dir('stim*.mat');
[~, sorted_index] = sortrows({files.date}');
files = files(sorted_index);

detrend_param.model = 'fourier8';
detrend_param.range = [0.0025 0.025];
detrend_param.response_roi = [0.003 0.008];
detrend_param.response_baseline = [0.012 0.025];
detrend_param.response_sigma = 3;
detrend_param.response_prob = NaN;
detrend_param.response_detection_threshold = Inf;

warning('off', 'curvefit:fit:invalidStartPoint');
warning('off', 'signal:findpeaks:largeMinPeakHeight');
warning('off', 'stats:gmdistribution:FailedToConverge');

current = {};
voltage = {};
monitor = {};
active_electrodes = {};
prob = {};
polarity_string = {};
pp = [];
%look_for_spikes = @look_for_spikes_xcorr

nfiles = length(files);

if exist('wbar', 'var') & ishandle(wbar) & isvalid(wbar)
    close(wbar);
    waitbar(0, wbar);
else
    wbar = waitbar(0, sprintf('Loading %d files...', nfiles));
end

for f = 1:nfiles
    load(files(f).name);
    data = update_data_struct(data, detrend_param, []);
    if isfield(data, 'tdt')
        d = data.tdt;
    else
        d = data.ni;
    end
    
    act = find(data.stim.active_electrodes);
    
    % This relies on negativefirst for binning, and can't use current_scale.
    % The +1 at the end is for indexing:
    polarity = 2.^[0:sum(data.stim.active_electrodes)-1] * data.stim.negativefirst(act)' + 1;
    pp = unique([pp polarity]);
    polarity_for_bar{polarity} = polarity - 1;
    % Reverse order of polarity_string for consistency with plot_max_voltage_bar.m
    polarity_string{polarity} = dec2bin(polarity_for_bar{polarity}, sum(data.stim.active_electrodes)); %sprintf('%d', data.stim.negativefirst(act(end:-1:1)));

    if polarity > length(current)
        current{polarity} = [];
        voltage{polarity} = [];
        monitor{polarity} = [];
        active_electrodes{polarity} = [];
        probs{polarity} = [];
        prob{polarity} = [];
        response_recordings{polarity} = {};
        response_channels{polarity} = {};
        times{polarity} = {};
    end
    % Force different detrend? Redundant with passing detrend_param to update_data_struct above?
    %[~, p] = detrend_param.spike_detect(d, data, detrend_param, d.response_detrended);
    %detrend_param.response_detection_threshold = zeros(1, 16);
    %detrend_param.response_detection_threshold(11) = -8.8;
    %[~, response_probabilities] = look_for_spikes_peaks(d, data, detrend_param, d.response_detrended);
    [~, response_probabilities, response_detrended, aligning_stims] = look_for_spikes_peaks(d, data, detrend_param, d.response_detrended);
    current{polarity} = [current{polarity} data.stim.current_uA];
    voltage{polarity} = [voltage{polarity} data.voltage];
    monitor{polarity} = [monitor{polarity} data.stim.plexon_monitor_electrode];
    active_electrodes{polarity} = [active_electrodes{polarity}; data.stim.active_electrodes];
    foo = zeros(16, 1);
    foo(data.tdt.index_recording) = response_probabilities;
    probs{polarity} = [probs{polarity} foo];
    prob{polarity} = [prob{polarity} max(response_probabilities)]; % FIXME ANALYSE_REC_CH ?
    times{polarity}{end+1} = d.times_aligned;
    
    % If we're seeing a good response, then add the response to a collection for plotting:
    for rec_ch = data.tdt.index_recording
        rec_ch_i = find(data.tdt.index_recording == rec_ch);

        if isempty(response_recordings{polarity}) | length(response_recordings{polarity}) < rec_ch
            response_recordings{polarity}{rec_ch} = {};
            response_channels{polarity}{rec_ch} = {};
        end
        
        if response_probabilities(rec_ch_i) >= 0.5
            response_recordings{polarity}{rec_ch}{end+1} = response_detrended(aligning_stims{rec_ch_i},:);
            response_channels{polarity}{rec_ch}{end+1} = data.tdt.index_recording(rec_ch_i);
        end
    end
    waitbar(f/nfiles, wbar);
end
close(wbar);

mytansig = @(a, mu, x) 0.5 + 0.5*tanh(a*(x-mu));

if true
    show = 'V';
else
    show = '?A';
end


% Find all monitor-channel sweeps for each CSC polarity p in pp, and add them to xData and yData.
% Even if we don't do fits with this (they're not very good), we need these in order to compute the
% ratio of voltages per electrode.
goodP = [];
sortable = [];
xlimhigh = -Inf;
clear xData yData;
for p = 1:length(pp) % p is the index into the CSC names; pp is the list of polaritys
    clear indices j V;

    if strcmp(show, 'V')
        i = find(diff(monitor{pp(p)}) > 0);
        j = find(diff([Inf i]) ~= 1);
        k = diff([j length(i)+1]);
        
        valid_sweep_i = find(k == max(k));
        if length(valid_sweep_i) ~= length(k)
            disp(sprintf('Config %s: sweep counts are %s; deleting low-count sweeps.', ...
                polarity_string{pp(p)}, ...
                sprintf(' %d', k)));
        end
        k = k(valid_sweep_i);
        j = j(valid_sweep_i);
        
        if length(j) == 0
            disp(sprintf('No sweeps found in config %s', polarity_string{pp(p)}));
            continue;
        elseif length(j) == 1
            disp(sprintf('Only one sweep found in   %s', polarity_string{pp(p)}));
            continue;
        else
            disp(sprintf('Found %d sweeps in config  %s', length(j), polarity_string{pp(p)}));
        end
        
        for s = 1:length(j)
            % s is the sweep number
            indices{s} = i(j(s)):i(j(s))+k(s);
            
            % Going to reverse-fudge other voltage data.  Store extra data as well
            %indices_presweep{s} = 1:i(j(s))-1;
            
            
            if length(unique(current{pp(p)}(indices{s}))) ~= 1
                error('Different values for current in a sweep.');
            end
            % Maximum monitor voltage over the monitor electrodes:
            
            V{s} = max(voltage{pp(p)}(indices{s})) * ones(1, k(s)+1);
            
            cur_s{p}(s) = current{pp(p)}(indices{s}(1));
            vol_s{p}(s,:) = voltage{pp(p)}(indices{s});
            
        end
        
        
        % The goal here is to get a bunch of indices into stimulation runs
        % with corresponding maximum voltages, so we can get the
        % probability of response for a maximum stimulation voltage
        xData{p} = []; % Maximum voltage over sweep
        yData{p} = []; % Probability of response over all stimulations in the sweep
        for s = 1:length(j)
            xData{p} = [xData{p} V{s}];
            yData{p} = [yData{p} prob{pp(p)}(indices{s})];
        end
        
        [xData{p}, yData{p}] = prepareCurveData(xData{p}, yData{p});
    else
        [xData{p}, yData{p}] = prepareCurveData(current{pp(p)}, prob{pp(p)});
    end
    
    if length(xData{p}) < 5
        continue;
    end

    goodP = [goodP p];
    
    % Set up fittype and options.
    ft = fittype( mytansig, 'independent', 'x', 'dependent', 'y' );
    opts = fitoptions( 'Method', 'NonlinearLeastSquares' );
    opts.Display = 'Off';
    opts.StartPoint = [1 1];
    opts.Lower = [0 -Inf];
    opts.Upper = [Inf Inf];

    % Fit model to data.
    fits{p} = fit( xData{p}, yData{p}, ft, opts );
    foo = confint(fits{p});
    reanalysed_thresholds(p,:) = [ polarity_for_bar{pp(p)} fits{p}.mu fits{p}.a foo(:,2)'];
    sortable(p) = fits{p}.mu;
end

colours = distinguishable_colors(length(goodP));


%% Plot responses to the different CSCs...
% What's the best bet for a channel for the response graphs?
figure(4);
showP = goodP;

showP = goodP(1);

global checkboxes;
% Delete old checkboxes and re-create them:
if exist('checkboxes', 'var')
    for i = 1:length(checkboxes)
        delete(checkboxes{i});
    end
    checkboxes = {};
end
pi = 1;
for i = 1:length(goodP)
    value = length(intersect(showP, goodP(i)));
    checkboxes{i} = uicontrol('Style', 'checkbox',...
        'String', polarity_string{pp(goodP(i))}, ...
        'Tag', sprintf('%d', goodP(i)), ...
        'Position', [1 20*pi 130 17], ...
        'Value', value, ...
        'ForegroundColor', colours(pi,:), ...
        'Callback', @plotwhich);
    pi = pi + 1;
end

ANALYSE_REC_CH = 11;

clear all_res response_means response_stds response_stes;
for p = goodP
    all_res{p} = [];
    [~, best_response_channel{pp(p)}] = max(mean(probs{pp(p)}, 2), [], 1);
    best_response_channel{pp(p)} = ANALYSE_REC_CH; % Detect, or choose?  FIXME
    % Accumulate all the response recordings for the best channel:
    for i = 1:length(response_recordings{pp(p)}{ANALYSE_REC_CH})
        %response_recording_ind = find(response_channels{pp(p)}{ANALYSE_REC_CH}{i} == best_response_channel{pp(p)});
        all_res{p} = [all_res{p}; response_recordings{pp(p)}{ANALYSE_REC_CH}{i}];
    end
    try
        response_means(p,:) = mean(all_res{p}, 1);
        response_stds(p,:) = std(all_res{p}, 0, 1);
        response_ste95(p,:) = 1.96 * response_stds(p,:) / sqrt(size(all_res{p}, 1));
    catch ME
        showP = showP(find(showP ~= p));
        set(checkboxes{p}, 'Value', 0, 'Enable', 'off');
        disp(sprintf('No robust responses found for CSC %d', p));
    end
end
roii = find(times{pp(p)}{1} >= detrend_param.response_roi(1) & times{pp(p)}{1} <= detrend_param.response_roi(2));
roitimes = times{pp(p)}{1}(roii);
% Plot the mean+std on top, and the mean+ste underneath:
plot_wiggles(goodP, colours, roitimes, roii, all_res, response_means, response_stds, response_ste95);


%[~, order] = sort(sortable);
order = 1:length(pp);

%order = order(2:17)
sp1 = ceil(sqrt(length(goodP)));

figure(1);
plotind = 1;
for p = goodP
    %% Draw stuff...
    if isempty(xData{order(p)})
        disp(sprintf('Could not get data for p=%d', p));
        continue;
    end
    subplot(sp1, sp1, plotind);
    plotind = plotind + 1;
    
    cla;
    hold on;
    scatter(xData{order(p)}+random('unif', -0.01, 0.01, size(yData{order(p)})), ...
        yData{order(p)}+random('unif', -0.01, 0.01, size(yData{order(p)})), ...
        20, 1:length(xData{order(p)}), 'filled');
    xlimhigh = max(xlimhigh, max(xData{order(p)}));
    xlabel(show);
    ylabel('Pr(r)');
    title(sprintf('%s: %s %s', polarity_string{pp(order(p))}, sigfig(fits{order(p)}.mu), show));
    set(gca, 'YLim', [0 1]);
    scatter(fits{order(p)}.mu, 0.5, 20, [1 0 0], '+');
    
    %scatter(current{pp(p)}, prob{pp(p)}(8,:), 5, 'r', 'filled');
    hold off;
    drawnow;
end


% Plot the fits
plotind = 1;
for p = goodP
    if isempty(fits{order(p)})
        continue;
    end
    subplot(sp1, sp1, plotind);
    plotind = plotind + 1;
    set(gca, 'xlim', [0 xlimhigh]);
    
    % plot fit
    hold on;
    domain = get(gca, 'xlim');
    fitx = linspace(domain(1), domain(2), 50);
    plot(fitx, mytansig(fits{order(p)}.a, fits{order(p)}.mu, fitx));
    hold off;
end



% Plot the relative voltage of each electrode.  This is a visual sanity
% check for extrapolating max voltages for the non-sweep data.
if true
    figure(11);
    plotind = 1;
    
    for p = goodP
        if isempty(xData{order(p)})
            continue;
        end
        subplot(sp1, sp1, plotind);
        plotind = plotind + 1;
        plot(vol_s{order(p)}');
        title(sprintf('%s: %s %s', polarity_string{pp(order(p))}, sigfig(fits{order(p)}.mu), show));
    end
end    

% Go through all data and add all stimulations for fitting with the synthesised (estimated) voltage
% data:
figure(1);
plotind = 1;
Vest = {};
Pest = {};
for p = goodP
    
    % Position in vol_s that contains the maximum voltage over an average of the sweeps:
    voltage_s = mean(vol_s{p})/max(mean(vol_s{p}));
    [~,pos] = max(voltage_s); % Find average maximum-voltage electrode
    for i = 1:size(vol_s{p}, 1) % Normalise all rows by the average maximum-voltage electrode
        voltage_s(i,:) = vol_s{p}(i,:) / vol_s{p}(i,pos);
    end
    voltage_s = mean(voltage_s, 1); % Average of per-run scaling factors
    voltage_scale{p} = zeros(1, 16); % Align by active_electrodes
    voltage_scale{p}(find(active_electrodes{polarity}(1,:))) = voltage_s;
    % FIXME Convert that to the index index that includes all electrodes?

    for i = 1:length(current{pp(p)})
        Vest{p}(i) = voltage{pp(p)}(i) / voltage_scale{p}(monitor{pp(p)}(i));
        Pest{p}(i) = prob{pp(p)}(i);
    end
    
    % Every time there is no detection, add that v
    for i = 1:0
        Vest{p}(end+1) = 0;
        Pest{p}(end+1) = 0;
    end
    
    [xData2{p}, yData2{p}] = prepareCurveData(Vest{p}, Pest{p});
    
    % Set up fittype and options.
    ft = fittype( mytansig, 'independent', 'x', 'dependent', 'y' );
    opts = fitoptions( 'Method', 'NonlinearLeastSquares' );
    opts.Display = 'Off';
    opts.StartPoint = [1 1];
    opts.Lower = [0 -Inf];
    opts.Upper = [Inf Inf];

    % Fit model to data.
    fits{p} = fit(xData2{p}, yData2{p}, ft, opts );
    conf_ints = confint(fits{p});
    reanalysed_thresholds(p,:) = [ polarity_for_bar{pp(p)} fits{p}.mu fits{p}.a conf_ints(:,2)'];
   
    
    % Scatterplot the new data
    subplot(sp1, sp1, plotind);
    plotind = plotind + 1;
    
    cla;
    hold on;
    scatter(xData2{order(p)}+random('unif', -0.01, 0.01, size(yData2{order(p)})), ...
        yData2{order(p)}+random('unif', -0.01, 0.01, size(yData2{order(p)})), ...
        20, 1:length(xData2{order(p)}), 'filled');
    %xlimhigh = max(xlimhigh, max(xData{order(p)}));
    xlabel(show);
    ylabel('Pr(r)');
    title(sprintf('%s: %s %s', polarity_string{pp(order(p))}, sigfig(fits{order(p)}.mu), show));
    set(gca, 'XLim', domain, 'YLim', [0 1]);
    scatter(fits{order(p)}.mu, 0.5, 20, [1 0 0], '+');
    

    hold on;
    domain = get(gca, 'xlim');
    fitx = linspace(domain(1), domain(2), 50);
    plot(fitx, mytansig(fits{order(p)}.a, fits{order(p)}.mu, fitx), 'r');
    hold off;

end

save('reanalysed_thresholds.mat', 'reanalysed_thresholds');



