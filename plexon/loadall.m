clear;

files = dir('stim*.mat');

for i = 1:length(files)
        
       load(files(i).name);
       dd{i} = data;
       
       if ~isfield(data, 'halftime') % old format does not scale saved data
               scalefactor_V = 1/0.25;
               scalefactor_i = 400;
               data.data(:,1) = data.data(:,1) * scalefactor_V;
               data.data(:,2) = data.data(:,2) * scalefactor_i;
       end

       
       triggerchannel = 3;
       triggerthreshold = 0.1;
       aftertrigger = 0.006;
       
       triggertime = find(abs(data.data(:,triggerchannel)) > triggerthreshold);
       if isempty(triggertime)
               triggertime = 0;
       else
               triggertime = (triggertime(1) / data.fs);
       end
       beforetrigger = max(0, triggertime - 0.001);
       
       %disp('Bandpass-filtering the data...');
       [B A] = butter(4, 0.6, 'low');
       d = filter(B, A, data.data);
       
       times = (data.time - triggertime) * 1000; % milliseconds
       u = find(data.time > beforetrigger & data.time < triggertime + aftertrigger);

       
       roi = round([ triggertime + 0.002  triggertime + 0.005 ] * data.fs);
       
       da(:,i) = d(roi(1):roi(2), 3);
end


times = [0:(size(da, 1)-1)] * 1000/data.fs;

x = xcorr(da);
image((da.*(da>0))*2000);
%imagesc(log(abs(x)));
