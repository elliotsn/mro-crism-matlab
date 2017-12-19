%
% Count the number of numbered fields in a structure that have a known character
% prefix.
%
function fields = getNNumberedFields(structure, prefix)

    fields = 1;
    while isfield(structure, [prefix, num2str(fields)])
         fields = fields + 1; 
    end
    fields = fields - 1; % Overshoots by 1 because needs to test the one after the maximum to find out it's not a field in order to exit the while loop.
end