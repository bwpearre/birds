clear;

files = dir('stim*.mat');
[~, sorted_index] = sortrows({files.date}');
files = files(sorted_index);

detrend_param.model = 'fourier8';
detrend_param.range = [0.002 0.025];
detrend_param.response_roi = [0.003 0.008];
detrend_param.response_baseline = [0.012 0.025];
detrend_param.response_sigma = 2;
detrend_param.response_prob = NaN;
detrend_param.response_detection_threshold = Inf;

ELECTRODE = 11; % Not sure what this is.  HVC electrode on which we may see responses?

warning('off', 'curvefit:fit:invalidStartPoint');
warning('off', 'signal:findpeaks:largeMinPeakHeight');
warning('off', 'stats:gmdistribution:FailedToConverge');

current = {};
voltage = {};
monitor = {};
prob = {};
pattern_string = {};
pp = [];

for f = 1:length(files)
    load(files(f).name);
    data = update_data_struct(data, detrend_param, []);
    if isfield(data, 'tdt')
        d = data.tdt;
    else
        d = data.ni;
    end
    
    % This relies on negativefirst for binning, and can't use current_scale.
    pattern = 2.^[0:15] * data.stim.negativefirst' + 1;
    pp = unique([pp pattern]);
    act = find(data.stim.active_electrodes);
    pattern_for_bar{pattern} = bin2dec(sprintf('%d', data.stim.negativefirst(act(end:-1:1))));
    % Reverse order of pattern_string for consistency with plot_max_voltage_bar.m
    pattern_string{pattern} = sprintf('%d', data.stim.negativefirst(act(end:-1:1)));

    if pattern > length(current)
        current{pattern} = [];
        prob{pattern} = [];
        voltage{pattern} = [];
        monitor{pattern} = [];
    end
    %[~, p] = detrend_param.spike_detect(d, data, detrend_param, d.response_detrended);
    [~, p] = look_for_spikes_peaks(d, data, detrend_param, d.response_detrended);
    current{pattern} = [current{pattern} data.stim.current_uA];
    voltage{pattern} = [voltage{pattern} data.voltage];
    monitor{pattern} = [monitor{pattern} data.stim.plexon_monitor_electrode];
    foo = zeros(16,1);
    foo(d.index_recording) = p;
    prob{pattern} = [prob{pattern} foo];
end

mytansig = @(a, mu, x) 0.5 + 0.5*tanh(a*(x-mu));

if true
    show = 'V';
else
    show = '?A';
end

GoodP = [];

sortable = [];
xlimhigh = -Inf;
clear xData yData;
for p = 1:length(pp) % p is the index into the CSC names
    clear indices j V;

    if strcmp(show, 'V')
        i = find(diff(monitor{pp(p)}) > 0);
        j = find(diff([Inf i]) ~= 1);
        k = diff([j length(i)+1]);
        if length(j) == 0
            disp(sprintf('No sweeps found in config %s', pattern_string{pp(p)}));
            continue;
        elseif length(j) == 1
            disp(sprintf('Only one sweep found in   %s', pattern_string{pp(p)}));
            continue;
        else
            disp(sprintf('Found %d sweeps in config  %s', length(j), pattern_string{pp(p)}));
        end
        for s = 1:length(j)
            % s is the sweep number
            indices{s} = i(j(s)):i(j(s))+k(s);
            if length(unique(current{pp(p)}(indices{s}))) ~= 1
                disp('Different values for current in a sweep!');
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
            yData{p} = [yData{p} prob{pp(p)}(ELECTRODE,indices{s})];
        end
        
        [xData{p}, yData{p}] = prepareCurveData(xData{p}, yData{p});
    else
        [xData{p}, yData{p}] = prepareCurveData(current{pp(p)}, prob{pp(p)}(ELECTRODE,:));
    end
    
    if length(xData{p}) < 5
        continue;
    end

    GoodP = [GoodP p];
    
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
    reanalysed_thresholds(p,:) = [ pattern_for_bar{pp(p)} fits{p}.mu fits{p}.a foo(:,2)'];
    sortable(p) = fits{p}.mu;
end


save('reanalysed_thresholds.mat', 'reanalysed_thresholds');

[~, order] = sort(sortable);
order = 1:length(pp)

%order = order(2:17)
sp1 = ceil(sqrt(length(GoodP)));

figure(1);
plotind = 1;
for p = GoodP
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
    title(sprintf('%s: %s %s', pattern_string{pp(order(p))}, sigfig(fits{order(p)}.mu), show));
    set(gca, 'YLim', [0 1]);
    scatter(fits{order(p)}.mu, 0.5, 20, [1 0 0], '+');
    
    %scatter(current{pp(p)}, prob{pp(p)}(8,:), 5, 'r', 'filled');
    hold off;
    drawnow;
end

plotind = 1;
for p = GoodP
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
figure(11);
plotind = 1;
for p = GoodP
    if isempty(xData{order(p)})
        continue;
    end
    subplot(sp1, sp1, plotind);
    plotind = plotind + 1;
    plot(vol_s{order(p)}');
    title(sprintf('%s: %s %s', pattern_string{pp(order(p))}, sigfig(fits{order(p)}.mu), show));
    
    [~, max_vol_s_i{p}] = max(mean(vol_s{p}));
    
end
