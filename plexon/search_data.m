clear;

files = dir;

for i = randperm(length(files))
    if ~strncmp(files(i).name, 'stim', 4)
        continue;
    end
    
    
    load(files(i).name);
    if sum(data.stim_electrodes) == 16
        files(i).name
        break;
    end
    pause(0.001);
end
