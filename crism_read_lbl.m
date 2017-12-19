%
% File to read a CRISM .lbl file.
%
function label = crism_read_lbl(filepath)

% Check number and type of arguments
if nargin < 1
  error('Function requires one input argument');
elseif ~ischar(filepath)
  error('Input must be a string representing a filename');
end


% Open the file for reading.
fid = fopen(filepath, 'r');


% While it's not yet the end of the file.
while ~feof(fid)

    % Read a line from the file.
    in = fgetl(fid);

    % If the line is not null, whitespace or a comment.
    if ~isempty(strtrim(in)) && (isempty(strfind(in, '/*')) && isempty(strfind(in, '*/'))) 

        % If the line has an '=' in it, then we need to make a new field
        % out of the keyword.
        if findstr(in, '=')
            [param, value] = strtok(in, '=');

            param = strtrim(param);
            value = strtok(value, '=');

            % Replace illegal characters in variable name with null
            if strfind(param, ':')
                param = strrep(param, ':', '');
            end
            if strfind(param, '^')
                param = strrep(param, '^', '');
            end
            
            % Make the new parameter equal to the new value.
            eval(['label.', param, '=','''', value, ''';']);

            % If the value has a '{' at it's beginning and does not
            % have a corressponding '}' on this line, then we must read
            % lines until we find a closing curly brace.
            if findstr(value, '{')
                flag = 1;
            end

        else
            % This line must be part of a large field that spans
            % several lines, so we add it to the parameter.. % Add a
            % § character after each one.
            eval(['label.', param, '=', '[label.', param, ',''§'',in];']);
            if findstr(in, '}')
                flag = 0;
            end
        end
    end
end