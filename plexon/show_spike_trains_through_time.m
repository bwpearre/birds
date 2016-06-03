clear;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%

bird = 'lw94rhp'                    % Which bird to look at?

%channels = [1 8 16];               % Speed up reading by only looking for spikes here
%channels_show = [1 8 16];
threshold = 5;                      % Spike threshold in std.dev.
window = [-0.001 0.002];            % Time window to plot around spikes

%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%

implant_date = get_implant_date(bird);

d = dir(sprintf('%s*', bird));
has_x_recordings = zeros(1,length(d));

goodsessions = [];
goodchannels = zeros(1, 16);

if ~exist('channels', 'var')
    channels = 1:16;
end

for i = 1:length(d)
    sessions{i}.data = read_lots_of_intan_files(d(i).name);

    if isempty(sessions{i}.data) | ~isfield(sessions{i}.data, 'amplifier_data')
        continue;
    end
    sessions{i}.bird = bird;
    sessions{i}.experiment_day = sessions{i}.data.experiment_date - implant_date;
    [ sessions{i}.goodchannels, sessions{i}.peaklocs ] = findspikes(sessions{i}.data, channels, threshold);
    goodsessions(i) = 1;
    goodchannels_ind = zeros(1, 16);
    goodchannels_ind(sessions{i}.goodchannels) = 1;
    goodchannels = or(goodchannels, goodchannels_ind);
    session_days(i) = sessions{i}.data.experiment_date - implant_date;
    if ~isempty(sessions{i}.data.impedances.x)
        session_impedances_x(i,:) = sessions{i}.data.impedances.x;
    end
end



if ~exist('channels_show', 'var')
    channels_show = channels;
end

plotchannels = intersect(channels_show, find(goodchannels));
colours = distinguishable_colors(length(plotchannels));

plotspikes(sessions, goodsessions, plotchannels, window, colours);


figure(101);
h = semilogy(session_days, session_impedances_x(:,plotchannels));

for i = 1:length(h)
    h(i).Color = colours(i,:);
end

legendnames = {};
for i = plotchannels
    legendnames{end+1} = sprintf('%d', i);
end
legend(legendnames, 'Location', 'NorthWest');
xlabel('Days post-implant');
set(gca, 'XTick', session_days(find(session_days > 0)));
ylabel('Impedance at 1 kHz (\Omega)');
title('Impedances');
