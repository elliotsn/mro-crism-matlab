%
% Function to build a formatstring for use by textscan based on the
% information held in a structure representative of a PDS label file with
% data objects with the name held in 'prefix'. The name is usually
% 'column'.
%
%   Elliot Sefton-Nash 23/05/2012
%
function formatstring = getFormatString(structure, prefix)

    % Get the number of columns in this structure
    ncol = getNNumberedFields(structure, prefix);

    % Define vars
    startbyte = zeros(1, ncol);
    bytes = zeros(1, ncol);
    name = cell(1, ncol);
    
    formatstring = '';
    % Read info from each column structure.
    for icol = 1:ncol
        % For ease of addressing.
        eval(['thiscol = structure.', prefix, num2str(icol), ';']);

        startbyte(icol) = str2double(thiscol.start_byte);
        bytes(icol) = str2double(thiscol.bytes);
        name{icol} = thiscol.name;
        
        % Build the format string that we use to read the tab file.
        switch thiscol.data_type
            case 'ASCII_REAL'
                piece = '%f ';    
            case 'ASCII_INTEGER'
                % Special case for CRISM, for some reason hashes are
                % included in an integer field.
                if icol==14
                    if strcmpi(thiscol.name, 'MRO:OBSERVATION_NUMBER')
                        piece = '%s ';
                    end
                else
                    piece = '%d ';
                end
            case 'CHARACTER' % char array
                piece = '%s ';
        end
        formatstring = [formatstring, piece];    
    end
    % Trim off the last space.
    formatstring = strtrim(formatstring);
end
