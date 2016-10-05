function [] = plot_wiggles(goodP, colours, roitimes, roii, response_means, response_stds, response_ste95);

global showP;
persistent previous;


cached_inputs = {'goodP', 'colours', 'roitimes', 'roii', 'response_means', 'response_stds', 'response_ste95'};

if nargin > 0
    for i = 1:length(cached_inputs)
        eval(sprintf('previous.%s = %s;', cached_inputs{i}, cached_inputs{i}));
    end
else
    for i = 1:length(cached_inputs)
        eval(sprintf('%s = previous.%s;', cached_inputs{i}, cached_inputs{i}));
    end
end



subplot(2,1,1);
cla;
hold on;
pi = 1;
for p = goodP
    if ~isempty(find(p==showP))
        shadedErrorBar(roitimes, response_means(p, roii), response_stds(p,roii), {'color', colours(pi,:)}, 1);
    end
    pi = pi + 1;
end
hold off;
ylabel('V (\mu V)');
title('Response shapes \pm \sigma');




subplot(2,1,2);
cla;
hold on;
pi = 1;
for p = goodP
    if ~isempty(find(p==showP))
        shadedErrorBar(roitimes, response_means(p, roii), response_ste95(p,roii), {'color', colours(pi,:)}, 1);
    end
    pi = pi + 1;
end
hold off;
xlabel('Time post-stimulus (ms)');
ylabel('V (\mu V)');
title('Response shapes (95% confidence)');
