function [ optimal_thresholds ] = optimise_network_output_unit_trigger_thresholds(...
        testout, ...
        FALSE_POSITIVE_COST, ...
        tstep_of_interest_ds, ...
        MATCH_PLUSMINUS, ...
        timestep_length, ...
        time_window_ds);

% Search for optimal thresholds given false-positive vs
% false-negagive weights (the latter := 1).

% The onset has to be no more than ACTIVE_TIME_BEFORE before the baseline
% training signal, and the 

% A positive that happens within ACTIVE_TIME of the event does not count as a
% false positive.  This is in seconds, and allows for some jitter.

ACTIVE_TIMESTEPS_BEFORE = floor(MATCH_PLUSMINUS / timestep_length);
ACTIVE_TIMESTEPS_AFTER = floor(MATCH_PLUSMINUS / timestep_length);

% The timesteps of interest are with reference to the start of the song.
% Responses have been trimmed to start at the start of recognition given
% the time window.  So we need to align those:

tstep_of_interest_shifted = tstep_of_interest_ds - time_window_ds + 1;

figure(7);
nsubfigs = size(testout, 1);
ntestpts = 1000;

for i = 1:length(tstep_of_interest_ds)
        responses = squeeze(testout(i, :, :))';
        positive_interval = tstep_of_interest_shifted(i)-ACTIVE_TIMESTEPS_BEFORE:...
                tstep_of_interest_shifted(i)+ACTIVE_TIMESTEPS_AFTER;

        f = @(threshold)trigger_threshold_cost(threshold, ...
                responses, ...
                positive_interval, ...
                FALSE_POSITIVE_COST);
        
        % Find optimal threshold on the interval [0.001 1]
        % optimal_thresholds = fminbnd(f, 0.001, 1);
        %% Actually, fminbnd is useless at jumping out of local minima, and it's quick enough to brute-force it.
        best = Inf;
        testpts = linspace(0, 1, ntestpts);
        truepos = zeros(1, length(tstep_of_interest_ds));
        falsepos = zeros(1, length(tstep_of_interest_ds));
        for j = 1:ntestpts
                [ outval truepos(j) falsepos(j) ] = f(testpts(j));
                if outval < best
                        best = outval;
                        bestparam = testpts(j);
                end
        end
        optimal_thresholds(i) = bestparam;
        
        ROCintegral = truepos(1:end-1) * (falsepos(1:end-1)-falsepos(2:end))';
        subplot(1, nsubfigs, i);
        plot(falsepos, truepos);
        xlabel('false positives');
        ylabel('true positives');
        title(sprintf('ROC at %g ms; integral = %.3g', tstep_of_interest_ds(i), ROCintegral));
        axis square;
end
