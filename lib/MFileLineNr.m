function LineNr = MFileLineNr()
% MFILELINENR returns the current linenumber
    Stack  = dbstack;
    LineNr = Stack(2).line;   % the line number of the calling function
end
