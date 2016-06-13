function [] = plot_transition_probabilities(data, active_syllable, ntimes_of_interest);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Configure %%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
show_expected = false;
remove_diagonal = false;
remove_off_diagonal = false;
squash = @log; % Squash the colormap
squash = @(x) x;  % Don't squash

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% End configure %%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

foo = floor(data(:,1) * 24);
hours = mod(foo, 24);
hoursu = unique(hours);
days = floor(data(:,1));
days = days - min(days);
daysu = unique(days);

trans_by_hour = zeros(length(hoursu), ntimes_of_interest, ntimes_of_interest);

figure(51);
clf;
for houri = 1:length(hoursu)
    di = find(hours == hoursu(houri));
    dil(houri) = length(di);
    
    di(1) = []; % Eliminate first one so we can look at di(1)-1
    for i = di'
        trans_by_hour(houri, active_syllable(i-1), active_syllable(i)) ...
            = trans_by_hour(houri, active_syllable(i-1), active_syllable(i)) + 1;
    end
    if remove_diagonal
        for i = 1:ntimes_of_interest
            trans_by_hour(houri, i, i) = 0;
        end
    end
    if remove_off_diagonal
        for i = 1:ntimes_of_interest-1
            trans_by_hour(houri, i, i+1) = 0;
        end
        trans_by_hour(houri, ntimes_of_interest, 1) = 0;
    end
    
    ee(houri) = entropy(trans_by_hour(houri,:,:));
    
    subplot(length(daysu)+1, length(hoursu), houri);
    imagesc(squeeze(squash(trans_by_hour(houri,:,:))+eps));
    axis xy;
    title(sprintf('%d:00 (n=%d) (S=%s)', hoursu(houri), length(di)+1, sigfig(ee(houri))));
    if houri == 1
        ylabel('All days');
    end
    axis square;
    drawnow;
end

figure(13);
plot(ee);

figure(51);

trans_by_day = zeros(length(daysu), length(hoursu), ntimes_of_interest, ntimes_of_interest);

for dayi = 1:length(daysu)
    for houri = 1:length(hoursu)
        di = find(hours == hoursu(houri) & days == daysu(dayi));
        dil(houri) = length(di);
        
        if length(di) <= 1
            continue;
        end
        di(1) = []; % Eliminate first one so we can look at di(1)-1
        for i = di'
            trans_by_day(dayi, houri, active_syllable(i-1), active_syllable(i)) ...
                = trans_by_day(dayi, houri, active_syllable(i-1), active_syllable(i)) + 1;
        end
        if remove_diagonal
            for i = 1:ntimes_of_interest
                trans_by_day(dayi, houri, i, i) = 0;
            end
        end
        if remove_off_diagonal
            for i = 1:ntimes_of_interest-1
                trans_by_day(dayi, houri, i, i+1) = 0;
            end
            trans_by_day(dayi, houri, ntimes_of_interest, 1) = 0;
        end

        subplot(length(daysu)+1, length(hoursu), houri+(dayi * length(hoursu)));
        imagesc(squeeze(squash(trans_by_day(dayi, houri, :, :)+eps)));
        axis xy;
        title(sprintf('%d:00 (n=%d)', hoursu(houri), length(di)+1));
        if houri == 1
            ylabel(sprintf('Day %d', dayi));
        end
        axis square;
    end
end

colormap gray;

if show_expected
    foo = zeros(ntimes_of_interest);
    subplot(length(daysu)+1, length(hoursu), prod([length(daysu)+1 length(hoursu)]));
    for i = 2:ntimes_of_interest
        foo(i-1, i) = 1;
    end
    foo(ntimes_of_interest, 1) = 1;
    imagesc(foo);
    axis xy;
    title('Expected:');
    axis square;
end