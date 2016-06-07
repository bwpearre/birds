function [] = transition_probabilities(data, ntimes_of_interest);

foo = round(data(:,1) * 24);

data(:,1) = foo-min(foo);
hours = unique(data(:,1));

trans_by_hour = zeros(length(hours), ntimes_of_interest, ntimes_of_interest);

figure(51);
for houri = 1:length(hours)
    di = find(data(:,1) == hours(houri));
    dil(houri) = length(di);
    
    di(1) = []; % Eliminate first one so we can look at di(1)-1
    for i = di'
        trans_by_hour(houri, data(i-1, 5), data(i, 5)) = trans_by_hour(houri, data(i-1, 5), data(i, 5)) + 1;
    end
    subplot(1, length(hours), houri);
    imagesc(squeeze(trans_by_hour(houri,:,:)));
end
