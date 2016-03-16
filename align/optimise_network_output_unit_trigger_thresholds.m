function [ optimal_thresholds optimal_thresholds_c ] = optimise_network_output_unit_trigger_thresholds(...
        testout, ...
        nwindows_per_song, ...
        FALSE_POSITIVE_COST, ...
        times_of_interest, ...
        tstep_of_interest, ...
        MATCH_PLUSMINUS, ...
        timestep, ...
        time_window_steps, ...
        songs_with_hits, ...
        continuous);

global Y_NEGATIVE;

Y_NEGATIVE = -1;

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

figure(113);
cla;
hold on;
colours = distinguishable_colors(length(tstep_of_interest));

for i = 1:length(tstep_of_interest)
    responses = squeeze(testout(i, :, :))';
    positive_interval = tstep_of_interest_shifted(i)-ACTIVE_TIMESTEPS_BEFORE:...
        tstep_of_interest_shifted(i)+ACTIVE_TIMESTEPS_AFTER;
    positive_interval = positive_interval(find(positive_interval > 0 & positive_interval <= nwindows_per_song));
    
    fc = @(threshold)trigger_threshold_cost_continuous(threshold, ...
        responses, ...
        tstep_of_interest_shifted, ...
        positive_interval, ...
        FALSE_POSITIVE_COST, ...
        songs_with_hits);
    
    f = @(threshold)trigger_threshold_cost(threshold, ...
        responses, ...
        positive_interval, ...
        FALSE_POSITIVE_COST, ...
        songs_with_hits);
    
    % Find optimal threshold on the interval [0.001 1]
    % optimal_thresholds = fminbnd(f, 0.001, 1);
    %% Actually, fminbnd is useless at jumping out of local minima, but brute-forcing the search is quick.
    best = Inf;
    testpts = linspace(Y_NEGATIVE, 1, ntestpts);
    trueposrate = zeros(1, length(tstep_of_interest));
    falseposrate = zeros(1, length(tstep_of_interest));
    for j = 1:ntestpts
        [ outval_c trueposrate_c(j) falseposrate_c(j) ] = fc(testpts(j));
        [ outval trueposrate(j) falseposrate(j) ] = f(testpts(j));
        outvals(j) = outval;
        outvals_c(j) = outval_c;
        if outval < best
            best = outval;           % cost value
            bestparam = testpts(j);  % ...at this threshold
            bestperf = [trueposrate(j) falseposrate(j)];
        end
    end
    
    figure(113);
    plot(testpts, 1+outvals, 'Color', colours(i,:));
    plot(testpts, 1+outvals_c, 'Color', 'r');
    % I've been running into a problem because with near-perfect detection over a large variety of
    % thresholds, the first one was chosen, but then with a large number of test songs, noise threw
    % one or two of them over the threshold.  So if there are several values for the threshold that
    % all produce identical accuracy, take the average, not the lowest.
    [val pos] = find(outvals==best);
    
    % TOTAL KLUDGE: if the cost for a slightly larger of the threshold is the same, use that
    % instead.
    if 0
        if pos(2) == pos(1) + 1
            opt_index = pos(2);
        else
            opt_index = pos(1);
        end
        % Look for the first sequence of consecutive positions:
        if false
            a = diff(pos);
            b = find([a Inf] > 1);
            c = diff([0 b]);
            opt_index = floor(mean(pos(1:c(1))));
        end
        
        if exist('midpoint', 'var') & midpoint
            optimal_thresholds(i) = testpts(opt_index);
        else
            optimal_thresholds(i) = bestparam;
        end
    end
    optimal_thresholds(i) = bestparam;
    [best_c pos] = min(outvals_c);
    bestparam_c = testpts(pos);
    optimal_thresholds_c(i) =     bestparam_c;
    scatter(bestparam_c, 1+best_c, 100, colours(i,:), 'o');
    scatter(bestparam, 1+best, 100, colours(i,:), '^');

    %% Plot the ROC curve.  It's, frankly, not very exciting.
    if false
        % ROC should probably use the test set...
        ROCintegral = trueposrate(1:end-1) * (falseposrate(1:end-1)-falseposrate(2:end))';
        subplot(1, nsubfigs, i);
        plot(falseposrate, trueposrate);
        xlabel('false positives');
        ylabel('true positives');
        title(sprintf('ROC at %g ms; integral = %.3g', times_of_interest(i)*1000, ROCintegral));
        axis square;
    end
end
hold off;
title('Cost vs threshold');
xlabel('threshold');
ylabel('cost+1');
set(gca, 'YScale', 'log');
