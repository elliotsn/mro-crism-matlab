function [ddr, banddesc] = crism_read_ddr(ddrfp)
%
%  Function to read the ancilliary information from a CRISM DDR file
%  addressed using the path ddrfp.
%
%  Elliot Sefton-Nash 19/08/2011
%
% Get name of label file and load it.
lenddrfp = numel(ddrfp);
lblfp = [ddrfp(1:lenddrfp-3), 'LBL'];
lbl = crism_read_lbl(lblfp);

% Now find the crucial details of the bands held in this file.
recordbytes = str2num(lbl.RECORD_BYTES);
filerecords = str2num(lbl.FILE_RECORDS);
lines = str2num(lbl.LINES);
samples = str2num(lbl.LINE_SAMPLES);

sampletype = strtrim(lbl.SAMPLE_TYPE);
samplebits = strtrim(lbl.SAMPLE_BITS);
% Get precision and endian based on these above two

[endian] = get_endian(sampletype);
[precision, pixel_bytes] = get_precision(samplebits);

numbands = str2num(lbl.BANDS);

% N.B. Currently only supports band sequential

% Extract band names from string, look for all the newline characters, they
% should separate each name.
notdone = 1;
i = 0;
remain = lbl.BAND_NAME;
if numel(remain) >= 2
    while notdone
        i = i + 1;
        if i > numbands
            notdone = 0;
        end
        
        % Get this chunk
        [thispiece, remain]  =  strtok(remain, '§');
        thispiece = strrep(thispiece, '§', '');
        % Trim it and rid it of junk.
        thispiece = strrep(thispiece, '"', '');
        thispiece = strrep(thispiece, ',', '');
        thispiece = strrep(thispiece, '(', '');
        thispiece = strrep(thispiece, ')', '');
        banddesc{i} = strtrim(thispiece);
       
    end    
else
    error('No band descriptions');
end
    
% There may be 15 band labels, but one is probably empty.


% Make data structure.
ddr = zeros(lines, samples, numbands);

% Now load the data from the binary ddr.
fid = fopen(ddrfp, 'r', endian);
% Skip header
fseek(fid, 1, 'bof');

% Loop over the bands
for i = 1:numbands
    tmp = fread(fid, [samples, lines], precision);
    ddr(:,:,i) = tmp';
end
 
% Read image data (fread fills column-wise, so must transpose. 
fclose(fid);

end
