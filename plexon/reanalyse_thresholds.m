files = dir('stim*.mat');

detrend_param.model = 'fourier8';
detrend_param.range = [0.002 0.025];
detrend_param.response_roi = [0.0025 0.008];
detrend_param.response_baseline = [0.012 0.025];
detrend_param.response_sigma = 5;
detrend_param.response_prob = NaN;


current = {};
prob = {};

for f = 1:10
    load(files(f).name);
    data = update_data_struct(data, detrend_param, []);
    if isfield(data, 'tdt')
        d = data.tdt;
    else
        d = data.ni;
    end
    
    pattern = 2.^[0:15] * data.stim.negativefirst' + 1;
    
    if pattern > length(current)
        current{pattern} = [];
        prob{pattern} = [];
    end
    [~, p] = look_for_spikes_peaks(d, data, detrend_param, d.response_detrended);
    current{pattern} = [current{pattern} data.stim.current_uA];
    foo = zeros(16,1);
    foo(d.index_recording) = p;
    if isempty(prob{pattern})
        prob{pattern} = foo;
    else
        prob{pattern} = [prob{pattern} foo];
    end
end

