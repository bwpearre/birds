function [] = transition_probabilities(data, ntimes_of_interest);


remove_diagonal = true;



datas = data;

foo = floor(datas(:,1) * 24);
hours = mod(foo, 24);
hoursu = unique(hours);
days = floor(datas(:,1));
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
        trans_by_hour(houri, datas(i-1, 5), datas(i, 5)) = trans_by_hour(houri, datas(i-1, 5), datas(i, 5)) + 1;
    end
    if remove_diagonal
        for i = 1:ntimes_of_interest
            trans_by_hour(houri, i, i) = 0;
        end
    end
    subplot(length(daysu)+1, length(hoursu), houri);
    imagesc(squeeze((trans_by_hour(houri,:,:))+eps));
    axis xy;
    title(sprintf('%d:00 (n=%d)', hoursu(houri), length(di)+1));
    if houri == 1
        ylabel('All days');
    end
    axis square;
    drawnow;
end

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
            trans_by_day(dayi, houri, datas(i-1, 5), datas(i, 5)) = trans_by_day(dayi, houri, datas(i-1, 5), datas(i, 5)) + 1;
        end
        if remove_diagonal
            for i = 1:ntimes_of_interest
                trans_by_day(dayi, houri, i, i) = 0;
            end
        end

        subplot(length(daysu)+1, length(hoursu), houri+(dayi * length(hoursu)));
        imagesc(squeeze((trans_by_day(dayi, houri, :, :)+eps)));
        axis xy;
        title(sprintf('%d:00 (n=%d)', hoursu(houri), length(di)+1));
        if houri == 1
            ylabel(sprintf('Day %d', dayi));
        end
        axis square;
    end
end

colormap gray;

foo = zeros(ntimes_of_interest);
subplot(length(daysu)+1, length(hoursu), prod([length(daysu)+1 length(hoursu)]));
for i = 2:ntimes_of_interest
    foo(i-1, i) = 1;
end
imagesc(foo);
axis xy;
title('Expected:');
axis square;