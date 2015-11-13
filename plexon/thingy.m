load current_thresholds;

plotpos = 0;


[~, sort_indices] = sort(current_thresholds(1, 1, 1:length(polarities)));
polarities_sorted = polarities(sort_indices);


frequencies = frequencies(1:2)

for frequency = 1:length(frequencies)
    stim.repetition_Hz = frequencies(frequency);

    for dur = 1:length(durations)
        stim.halftime_s = durations(dur);
        
        plotpos = plotpos + 1;
        figure(1);
        subplot(length(frequencies), length(durations), plotpos);
        plot(squeeze(current_thresholds(frequency, dur, sort_indices)));
        title(sprintf('Freq %s, Half-dur %s', ...
            sigfig(frequencies(frequency), 3), ...
            sigfig(durations(dur), 3)));
        for p = 1:length(polarities)
            labels{p} = dec2bin(polarities_sorted(p), log2(max(polarities)));
        end
        set(gca, 'XTick', 1:length(polarities), 'XTickLabel', labels);
        xticklabel_rotate;
        ylabel('Min current');

        if false
            figure(2);
            subplot(length(frequencies), length(durations), plotpos);
            plot(squeeze(current_threshold_voltages(frequency, dur, 1:length(polarities))));
            title(sprintf('Freq %s, Half-dur %s', ...
                sigfig(frequencies(frequency), 3), ...
                sigfig(durations(dur), 3)));
            xlabel('Arbitrary polarity label');
            ylabel('Min current');
        end
    end
end
