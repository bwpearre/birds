clear;

%cd lw95rhp-2015-11-23;

e = 'lw95rhp-2015-11-19';

read_Intan_RHD2000_file;

[nchannels npoints] = size(amplifier_data);
fs = frequency_parameters.amplifier_sample_rate;

[B A] = ellip(2, .000001, 30, [10 3000]/(fs/2));

adplus = (amplifier_data')/1e3;
for i = 1:nchannels
    adplus(:,i) = filtfilt(B, A, adplus(:,i)) + i - nchannels/2;
end
plot(t_amplifier*1e3, adplus);
%set(gca, 'XLim', [400 800], 'YLim', [-1.3 0.3]);
%set(gca, 'XLim', [1000 1400], 'YLim', [-1.3 0.3]);
title('Spontaneous activity in Area X?  EIROF array, +193 days');
xlabel('milliseconds');
ylabel('millivolts');
%set(gca, 'XLim', [380 1400], 'YLim', [-1.2544 0.3491]);
%legend('1','2','3','4','5','6','7','8','9','10','11','12','13','14','15','16');
%set(gca, 'XLim', [0 400]);

set(gcf,'PaperPositionMode','auto'); 
saveas(gcf, strcat('spiketrain-', e, '.eps'), 'epsc');
saveas(gcf, strcat('spiketrain-', e, '.png'));
saveas(gcf, strcat('spiketrain-', e, '.fig'));
