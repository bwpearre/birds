clear;

cd lw95rhp-2015-11-23;

read_Intan_RHD2000_file;

plot(t_amplifier*1e3-8760, amplifier_data([1 2 4], :)');
title('Spontaneous activity in Area X, EIROF array, +197 days');
xlabel('milliseconds');
ylabel('microvolts???');
set(gca, 'XLim', [0 400]);

set(gcf,'PaperPositionMode','auto'); 
saveas(gcf, 'spiketrain.png');
saveas(gcf, 'spiketrain.eps', 'epsc');
saveas(gcf, 'spiketrain.fig');
