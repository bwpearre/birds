clear;

cd lw95rhp-2015-11-23;

read_Intan_RHD2000_file;

plot(t_amplifier*1e3, amplifier_data(15, :)'/1e3);
title('Spontaneous activity in Area X, EIROF array, +197 days');
xlabel('milliseconds');
ylabel('millivolts');
legend('1','2','3','4','5','6','7','8','9','10','11','12','13','14','15','16')
%set(gca, 'XLim', [0 400]);

set(gcf,'PaperPositionMode','auto'); 
saveas(gcf, 'spiketrain.png');
saveas(gcf, 'spiketrain.eps', 'epsc');
saveas(gcf, 'spiketrain.fig');
