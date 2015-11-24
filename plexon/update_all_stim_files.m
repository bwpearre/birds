files = dir('*.mat')

for i=1:length(files)
  load(files(i).name)
  data = update_for_win(data);
  save(files(i).name, 'data', '-v7.3');
end
