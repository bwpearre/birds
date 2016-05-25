function [ ] = show_confusion(...
        testout, ...
        nwindows_per_song, ...
        FALSE_POSITIVE_COST, ...
        times_of_interest, ...
        tstep_of_interest, ...
        MATCH_PLUSMINUS, ...
        timestep, ...
        time_window_steps, ...
        songs_with_hits, ...
        trigger_thresholds, ...
        train_record);

% Search for optimal thresholds given false-positive vs
% false-negagive weights (the latter := 1).

% The onset has to be no more than ACTIVE_TIME_BEFORE before the baseline
% training signal, and the 

% A positive that happens within ACTIVE_TIME of the event does not count as a
% false positive.  This is in seconds, and allows for some jitter.

ACTIVE_TIMESTEPS_BEFORE = floor(MATCH_PLUSMINUS / timestep);
ACTIVE_TIMESTEPS_AFTER = floor(MATCH_PLUSMINUS / timestep);

% The timesteps of interest are with reference to the start of the song.
% Responses have been trimmed to start at the start of recognition given
% the time window.  So we need to align those:
tstep_of_interest_shifted = tstep_of_interest - time_window_steps + 1;

%figure(7);
%nsubfigs = size(testout, 1);

ntestpts = 1000;

for i = 1:length(tstep_of_interest)
    responses = squeeze(testout(i, :, :))';
    positive_interval = tstep_of_interest_shifted(i)-ACTIVE_TIMESTEPS_BEFORE:...
        tstep_of_interest_shifted(i)+ACTIVE_TIMESTEPS_AFTER;
    positive_interval = positive_interval(find(positive_interval > 0 & positive_interval <= nwindows_per_song));
    
    f = @(threshold)trigger_threshold_cost(threshold, ...
        responses, ...
        positive_interval, ...
        FALSE_POSITIVE_COST, ...
        songs_with_hits);
    
    % Find optimal threshold on the interval [0.001 1]
    % optimal_thresholds = fminbnd(f, 0.001, 1);
    %% Actually, fminbnd is useless at jumping out of local minima, but brute-forcing the search is quick.
    best = Inf;
    testpts = linspace(0, 1, ntestpts);
    trueposrate = zeros(1, length(tstep_of_interest));
    falseposrate = zeros(1, length(tstep_of_interest));
    [ outval trueposrate falseposrate ] = f(trigger_thresholds(i));
    
    tpfp = [times_of_interest trueposrate falseposrate train_record.best_tperf];

    if true
        fprintf('At %d ms:        True positive    negative\n', times_of_interest(i) * 1000);
        fprintf('     output pos      %.5f%%     %s%%\n', trueposrate*100, sigfig(falseposrate*100));
        fprintf('            neg       %s%%       %.5f%%\n', sigfig((1-trueposrate)*100), (1-falseposrate)*100);
        if exist('confusion_log_perf.txt', 'file')
            save('confusion_log_perf.txt', 'tpfp', '-append', '-ascii');
        else
            save('confusion_log_perf.txt', 'tpfp', '-ascii');
        end
    else
        fprintf('\\vspace{8pt}\\par\\noindent\n\\begin{tabular}{r|cc}\n  {\\bf At %d ms} & \\multicolumn{2}{c}{True} \\\\ \n  & pos & neg \\\\ \n  \\hline  Detected pos & %.5f\\%% & %.5f\\%%\\\\ \n  neg & %.5f\\%% & %.5f\\%%\\\\ \n\\end{tabular}\n', ...
            times_of_interest(i) * 1000, trueposrate*100, falseposrate*100, (1-trueposrate)*100, (1-falseposrate)*100);
    end
end

