%
% Function to read ENVI header files, which are a list of parameter =
% value pairs. Headed by the string 'ENVI'.
%
% Elliot Sefton-Nash 24/08/2011
%
function header = crism_read_envi_hdr(filepath)

    % Check number and type of arguments
    if nargin < 1
      error('Function requires one input argument');
    elseif ~ischar(filepath)
      error('Input must be a string representing a filename');
    end

    % Open the file for reading.
    fid = fopen(filepath, 'r');

    % While it's not yet the end of the file.
    flag = 0;
    while ~feof(fid)

        % Read a line from the file.
        in = fgetl(fid);

        % If the line is not null or whitespace
        if ~isempty(strtrim(in))

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
                
                % Replace whitespace with underscores
                if strfind(param, ' ')
                    param = strrep(param, ' ', '_');
                end
                
                % Null any open curly braces
                if strfind(value, '{')
                    value = strrep(value, '{', '');
                end
                
                % Make the new parameter equal to the new value.
                eval(['header.', param, '=''', value, ''';']);

                % If the value has a '{' at it's beginning and does not
                % have a corressponding '}' on this line, then we must read
                % lines until we find a closing curly brace.

            else
                % If it's not the first line, which denotes an ENVI file.
                if ~strcmpi(strtrim(in), 'ENVI'); 
                    % This line must be part of a large field that spans
                    % several lines, so we add it to the parameter after
                    % removing any close curly braces.
                    in = strrep(in, '}', '');
                    eval(['header.', param, '=', '[header.', param, ',in];']);
                end
            end
        end
    end
end