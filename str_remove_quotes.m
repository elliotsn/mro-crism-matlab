%
% Function to remove single or double quotes from a string.
%
function outStr = str_remove_quotes(inStr)    
    
    % If is s cell array of strings, loop over each
    if iscell(inStr)
        cellarray = cell(size(inStr));
        for i = 1:numel(inStr)
           tmpStr = strrep(inStr{i}, '"', '');
           cellarray{i} = strrep(tmpStr, '''', '');
        end
        outStr = cellarray;
    else % Otherwise just do it once
        tmpStr = strrep(inStr, '"', '');
        outStr = strrep(tmpStr, '''', '');
    end
    
end