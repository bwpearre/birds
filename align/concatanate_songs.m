clear;


bird = 'lblk121rr'
loc = '/Volumes/disk2/winData';

l = dir(sprintf('%s/%s', loc, bird));

massosongs = [];

for i = 1:30
        if ~strncmp(l(i).name(end:-1:1), 'vaw.', 4)
                continue;
        end
        fprintf('reading ''%s''\n', l(i).name);
        [foo, fs] = audioread(sprintf('%s/%s/%s', loc, bird, l(i).name));
        % downsample
        if fs > 30000
                foo = foo(2:2:end);
                fs = fs / 2;
        end
        massosongs = [massosongs; foo];
end

audiowrite(sprintf('massosongs_%s.wav', bird), massosongs, round(fs));
