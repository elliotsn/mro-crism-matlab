%
% Function to change a cell array representing a table of ASCII parameters
% into a data structure where each subfield is a heading of a column in the
% table. The headings and column information are passed as label.
% 
% Designed to work with labels as read by read_pds_label.
%
% Elliot Sefton-Nash 23/05/2012
%
function table = formatPDSTableWithLabel(C, label, prefix)

    % Get number of columns
    ncol = getNNumberedFields(label, prefix);

    for icol = 1:ncol
        % Extract this column from the trdrhk structure.
        eval(['thiscol = label.', prefix, num2str(icol),';']);
        
        % Make a field with this name equal to the data for this parameter
        address = ['table.', strrep(str_remove_quotes(thiscol.name), ':', '_')];
        
        eval([address,'=C{icol};']);

        % If there's a description field, send this back as well.
        if isfield(thiscol, 'description')
            % Any single quotes in rhs must be replaced by ''. The
            % 'eval' command will translate this into a single quote
            if strfind(thiscol.description, '''')
                thiscol.description = strrep(thiscol.description, '''', '''''');
            end
            eval([address, '_DESCRIPTION =''', thiscol.description,''';']);
        end
        % Similarly for units.
        if isfield(thiscol, 'unit')
            eval([address, '_UNIT =''', thiscol.unit,''';']);
        end 
    end
    
end