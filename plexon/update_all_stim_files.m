files = dir('*.mat');
mkdir('updated');

for i=1:length(files)
  load(files(i).name)
  data = update_for_win(data);
  save(fullfile('updated', strcat(files(i).name(1:end-4), 'v73')), 'data', '-v7.3');
end
