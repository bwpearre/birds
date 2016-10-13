clear;

load current_thresholds;

v = [];
labels = {};

for i = 1:size(voltages, 3)
    if ~isempty(voltages{1,1,i})
        v(end+1, :) = voltages{1,1,i};
        m = max(v(end,:));
        labels{end+1} = sprintf('%s (%s V)', ...
            dec2bin(polarities(i), log2(max(polarities))), ...
            sigfig(m, 3));
    end
end

m = max(v, [], 2);

bar(v');
legend(labels, 'Location', 'NorthWest');
xlabel('Stimulating electrode');
ylabel('max |V|');
title('All electrode voltages for minimum stimulation current');
