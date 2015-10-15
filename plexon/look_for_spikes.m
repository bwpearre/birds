function [ spikes r ] = look_for_spikes(data, times, stim_active_indices);
s = size(data);
if length(s) == 3
    data = reshape(data, s(2:3));
end

starttime = 0.0005;
endtime = 0.0099;
roiregion = find(times > starttime & times < 0.002);
baseregion = find(times > 0.004 & times < endtime);
validregion = find(times > starttime & times < endtime);


%figure(1);
%plot(data(1:200,9),'b');


stim_active_indices = (0:length(stim_active_indices)+3)+stim_active_indices(1);
for i = 1:16
    data(stim_active_indices(1)-1:stim_active_indices(end)+1, i) ...
        = linspace(data(stim_active_indices(1)-1, i), data(stim_active_indices(end)+1, i), length(stim_active_indices)+2);
end

%figure(1);
%hold on;
%plot(data(1:200,9),'r');
%hold off;



[B A] = ellip(2, .5, 40, [500 5000]/((1/(times(2)-times(1)))/2));
for i = 1:size(data, 2)
    data(:, i) = filtfilt(B, A, squeeze(data(:, i)));
end


if true
    global axes2;
    set(axes2, 'ColorOrder', distinguishable_colors(16));
    cla(axes2);
    hold(axes2, 'on');
    for i = 1:16
        plot(axes2, ...
            times, ...
            data(:, i));
    end
    hold(axes2, 'off');
end



%detector = 'rms';
%detector = 'range';
%detector = 'threshold';
detector = 'convolve';

switch detector
    case 'rms'
        roirms = rms(data(roiregion, :), 1);
        baserms = rms(data(baseregion, :), 1);
        r = (roirms ./ baserms);
        spikes =  r > 2;
        
        
    case 'range'
        roipkpk = max(data(roiregion,:)) - min(data(roiregion,:));
        basepkpk = max(data(baseregion,:)) - min(data(baseregion,:));
        r = (roipkpk ./ basepkpk);
        spikes = r > 3;
        
        
    case 'threshold'
        roipkpk = (max(data(roiregion,:)) - min(data(roiregion,:)));
        basepkpk = (max(data(baseregion,:)) - min(data(baseregion,:)));
        r = (roipkpk - basepkpk);
        spikes = r > 0.00005;
        
        
    case 'convolve'
        c = load('stim_20151005_154801.070.mat');
        x = squeeze(mean(c.data.tdt.response(:,:,9)));
        x = filtfilt(B, A, x);
        y = find(c.data.tdt.times_aligned>0.0005 & c.data.tdt.times_aligned<0.002);
        b = x(y(end):-1:y(1));

        foo = zeros(length(validregion), 16);
        for i = 1:16
            foo(:,i) = conv(data(validregion,i)', b, 'same');
        end
        
        [val pos] = max(foo, [], 1);
        r = val;
        spikes = abs(val) > 1.5e-7;
        
    otherwise
        spikes = zeros(1, 16);
       
end
