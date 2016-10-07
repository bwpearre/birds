function plotwhich(source, event)
global showP;
global checkboxes;



for i = 1:length(checkboxes)
    whichone = str2double(checkboxes{i}.Tag);
    v = checkboxes{i}.Value;
    if v
        showP = sort(union(showP, whichone));
    else
        showP = showP(find(showP ~= whichone));
    end

end
plot_wiggles();
