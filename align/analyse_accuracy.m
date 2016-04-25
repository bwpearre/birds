clear;


files = {'confusion_log_perf_2hid.txt', 'confusion_log_perf_4hid.txt'};


figure(11);
clf;

halfwidth = 0.02;

for file = 1:length(files)
    confusion = load(files{file});

    clear dfp;
    % confusion is [ syllable# ; true positives ; false positives ; reported accuracy (useless) ]
    [sylly bini binj] = unique(confusion(:,1));
    xtickl = {};
    sylly_counts = [];
    for i = 1:length(sylly)
        xtickl{i} = sprintf('t^*_%d', i);
        sylly_counts(i) = length(find(confusion(:,1)==sylly(i)));
        dtp(:, i) = confusion(find(confusion(:,1)==sylly(i)),2);
        dfp(:, i) = confusion(find(confusion(:,1)==sylly(i)),3);
    end
        
    tpmeans(file, :) = mean(dtp);
    fpmeans(file, :) = mean(dfp);
    
    colours = distinguishable_colors(length(sylly));
    offsets = (rand(size(confusion(:,1))) - 0.5) * 2 * halfwidth;
    if size(confusion, 2) >= 4 & false
        sizes = (mapminmax(-confusion(:,4)')'+1.1)*8;
    else
        sizes = 6;
    end
    subplot(2,2,file);
    scatter(confusion(:,1)+offsets, confusion(:,2)*100, sizes, colours(binj,:), 'filled');
    xlabel('Test syllable');
    ylabel('True Positives %');
    title('Correct detections');
    if min(sylly) ~= max(sylly)
        set(gca, 'xlim', [min(sylly)-0.025 max(sylly)+0.025]);
    end
    %set(gca, 'ylim', [0 100]);
    hold on;
    for i = 1:length(sylly)
        line([-halfwidth halfwidth]+sylly(i), 100*[1 1]*tpmeans(file,i), 'color', colours(i,:));
    end
    set(gca, 'xtick', sylly, 'xticklabel', xtickl);
    hold off;

    subplot(2,2,2+file);
    scatter(confusion(:,1)+offsets, confusion(:,3)*100, sizes, colours(binj,:), 'filled');
    xlabel('Test syllable');
    ylabel('False Positives %');
    title('Incorrect detections');
    if min(sylly) ~= max(sylly)
        set(gca, 'xlim', [min(sylly)-0.025 max(sylly)+0.025]);
    end
    set(gca, 'xtick', sylly, 'xticklabel', xtickl);
    hold on;
    for i = 1:length(sylly)
        line([-halfwidth halfwidth]+sylly(i), 100*[1 1]*fpmeans(file,i), 'color', colours(i,:));
    end
    set(gca, 'xtick', sylly, 'xticklabel', xtickl);
    hold off;

end

disp('True positives: improvement 4 hidden neurons vs 2');
TPmeans = (1-tpmeans(1,:))./(1-tpmeans(2,:))
disp(sprintf('Mean: %g.  Std Dev: %g.', mean(TPmeans), std(TPmeans)));
disp('False positives: improvement 4 hidden neurons vs 2');
FPmeans = (fpmeans(1,:))./(fpmeans(2,:))
disp(sprintf('Mean: %g.  Std Dev: %g.', mean(FPmeans), std(FPmeans)));


