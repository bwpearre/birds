clear;

files = dir('stim*.mat');
[~, sorted_index] = sortrows({files.date}');
files = files(sorted_index);

detrend_param.model = 'fourier8';
detrend_param.range = [0.002 0.025];
detrend_param.response_roi = [0.0025 0.008];
detrend_param.response_baseline = [0.012 0.025];
detrend_param.response_sigma = 5;
detrend_param.response_prob = NaN;
detrend_param.response_detection_threshold = Inf;


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
    
    pattern = 2.^[0:15] * data.stim.negativefirst' + 1;
    pp = unique([pp pattern]);
    pattern_string{pattern} = sprintf('%d', data.stim.negativefirst(find(data.stim.active_electrodes)));

    if pattern > length(current)
        current{pattern} = [];
        prob{pattern} = [];
        voltage{pattern} = [];
        monitor{pattern} = [];
    end
    [~, p] = look_for_spikes_peaks(d, data, detrend_param, d.response_detrended);
    current{pattern} = [current{pattern} data.stim.current_uA];
    voltage{pattern} = [voltage{pattern} data.voltage];
    monitor{pattern} = [monitor{pattern} data.stim.plexon_monitor_electrode];
    foo = zeros(16,1);
    foo(d.index_recording) = p;
    if isempty(prob{pattern})
        prob{pattern} = foo;
    else
        prob{pattern} = [prob{pattern} foo];
    end
end

tansig = @(a, mu, x) 0.5 + 0.5*tanh(a*(x-mu));

if true
    show = 'V';
else
    show = '?A';
end


if strcmp(show, 'V')
    % The voltage should be the maximum voltage across any channel at a given current.  I need to do
    % something drastic and throw out all samples for which I don't know the maximum voltage.
    
    % Voltage sweeps are indexed as:
    %    i = find(diff(monitor{pp(p)}) > 0) % (and one more on either side?)
    %    j = find(diff([Inf i]) ~= 1)
    %    k = diff([j length(i)+1]);
    %    ind(s) = i(j(s)):i(j(s))+k(s)
    %  current{pp(p)}(i(j(s)):i(j(s))+k(s)) % should all be the same

sp1 = ceil(sqrt(length(pp)));
for p = 1:length(pp)
    clear indices j V;

    if strcmp(show, 'V')
        [xData, yData] = prepareCurveData(voltage{pp(p)}, prob{pp(p)}(3,:));
        
        i = find(diff(monitor{pp(p)}) > 0);
        j = find(diff([Inf i]) ~= 1);
        k = diff([j length(i)+1]);
        for s = 1:length(j)
            indices{s} = i(j(s)):i(j(s))+k(s);
            if length(unique(current{pp(p)}(indices{s}))) ~= 1
                disp('Different values for current in a sweep!');
            end
            V{s} = max(voltage{pp(p)}(indices{s})) * ones(1, k(s)+1);
        end
        xData = [];
        yData = [];
        for s = 1:length(j)
            xData = [xData V{s}];
            yData = [yData prob{pp(p)}(3,indices{s})];
        end
        [xData, yData] = prepareCurveData(xData, yData);

    else
        [xData, yData] = prepareCurveData(current{pp(p)}, prob{pp(p)}(3,:));
    end
    
    if length(xData) < 5
        continue;
    end

    % Set up fittype and options.
    ft = fittype( tansig, 'independent', 'x', 'dependent', 'y' );
    opts = fitoptions( 'Method', 'NonlinearLeastSquares' );
    opts.Display = 'Off';
    opts.Lower = [0 -Inf];
    opts.StartPoint = [0.1 0];
    opts.Upper      = [Inf Inf];

    % Fit model to data.
    fits{p} = fit( xData, yData, ft, opts );
    
    
    %% Draw stuff...
    figure(1);
    subplot(sp1, sp1, p);
    cla;
    hold on;
    scatter(xData, yData, 5, 'b', 'filled');
    %set(gca, 'XLim', [0 60]);
    xlabel(show);
    ylabel('Pr(r)');
    title(sprintf('%s: %s %s', pattern_string{pp(p)}, sigfig(fits{p}.mu), show));
    set(gca, 'YLim', [0 1]);
    scatter(fits{p}.mu, 0.5, 20, [1 0 0], '+');
    
    % plot fit
    domain = get(gca, 'xlim');
    fitx = linspace(domain(1), domain(2), 50);
    plot(fitx, tansig(fits{p}.a, fits{p}.mu, fitx));
    %scatter(current{pp(p)}, prob{pp(p)}(8,:), 5, 'r', 'filled');
    hold off;
end

