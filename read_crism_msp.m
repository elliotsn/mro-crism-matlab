%
% File to read the files that comprise a CRISM MSP observation.
%
% Elliot Sefton-Nash 22/05/2012
%
% Passed:
%
%   imgpath - the path to the .img file, which contains the data. It is
%   assumed that the corressponding .lbl file is in the same directory.
%   
%   trdrhkfmtpath - the path to the file trdrhk.fmt, which tells us what
%   format an msp observations housekeeping file is in and allows us to
%   read it. On the PDS this file is kept in some top level directory for
%   each release. If it's passed as a null string this function can be set
%   to assume a default local path.
%
% Returned:
%   
%   cube            Spectral cube: lines x samples x bands
%   label           Structure containing the label information for this
%                   observation
%   wa              Centre wavelength as a function of band and sample
%                   (there is a spectral smile effect). Dimensions are
%                   lines x samples x bands to match the spectral cube, but
%                   lines always == 1. Units are nm.
%   rownum_table    The list of band rownumbers, which bands were used for
%                   this observation
%   hktab           Structure containing the housekeeping table
%
%   idx             Structure containing the observations entry in the 
%                   index, assuming the index directory is stored as it is 
%                   on the PDS.
%
% Invoke by:      
% 
%   [cube, label, wa, rownum_table, hktab, idx] = ...
%       read_crism_msp(imgpath, trdrhkfmtpath)
%
function [cube, label, wa, rownum_table, hktab, idx] = read_crism_msp(imgpath, trdrhkfmtpath)

	% By default, set the outputs to -1, guilty until proven innocent.
	cube = -1;
	wa = -1;
   	rownum_table = -1;
	hktab = -1;
	idx = -1;

    %% DEBUG
    if isempty(imgpath)
        imgpath = '/Volumes/resource/data/crism/mro/mro-m-crism-3-rdr-targeted-v1/mrocr_2101/trdr/2007/2007_137/msp00005b9c/msp00005b9c_05_if214l_trr3.img';
    end

    %% Path to the format file that describes what is stored in the
    % housekeeping files for each observation (*.TAB)
    if isempty(trdrhkfmtpath)
        trdrhkfmtpath = '/Volumes/resource/data/crism/mro/mro-m-crism-3-rdr-targeted-v1/mrocr_2101/label/trdrhk.fmt';
    end
        
    %% Check number and type of arguments
    if nargin < 1
      error('Function requires one input argument');
    elseif ~ischar(imgpath)
      error('Input must be a string representing a filename');
    end
    
    nullvalue = 65535;
    
    % Get the data directory:
    [fname, remain] = strtok(reverse(imgpath), '/');
    datadir = reverse(remain);
    
    % Read the label file.
    lblpath = [imgpath(1:end-3), 'lbl'];
    label = read_pds_lbl(lblpath);
    
    if isstruct(label)
        fname = reverse(fname);
	fprintf('%s\n', [fname, ': label']);

        % In the structure that's returned, label.file1 is the .img, while
        % label.file2 is the .tab file. 

        %% Get required info regarding the image
        img_lines = str2double(label.file1.image.lines);
        img_samples = str2double(label.file1.image.line_samples);
        img_endian = get_endian(label.file1.image.sample_type);
        img_precision = get_precision(label.file1.image.sample_bits);
        img_bands = str2double(label.file1.image.bands);
        img_samplebytes = str2double(label.file1.image.sample_bits)/8;

        % Determine the interleave type and set the parameter ready to pass to
        % 'multibandread'.
        switch label.file1.image.band_storage_type
            case 'LINE_INTERLEAVED'
                img_interleave = 'bil';
            case 'BAND_INTERLEAVED'
                img_interleave = 'bsq';
            case 'SAMPLE_INTERLEAVED'
                img_interleave = 'bip';
        end

        % Read the image
        cube = multibandread(imgpath, [img_lines,img_samples,img_bands],...
            img_precision, 0, img_interleave, img_endian);
        
	if max(size(cube)) > 1
	
		 % Zero all the null values
        	 cube(cube == nullvalue) = 0;

        	 %% Read row number table.
        	 %rn_rowbytes = str2double(label.file1.rownum_table.row_bytes);
        	 rn_rows = str2double(label.file1.rownum_table.rows);
        	 rn_columns = str2double(label.file1.rownum_table.columns);
        	 rn_endian = get_endian(label.file1.rownum_table.column1.data_type);
        	 rn_precision = get_precision(label.file1.rownum_table.row_bytes);

        	 % Calculate where the rownum table begins.
        	 rn_startbyte = (img_lines * img_samples * img_bands * img_samplebytes);

        	 % Read the rownumber table.
        	 rownum_table = multibandread(imgpath, [rn_columns , rn_rows, 1], rn_precision, rn_startbyte, 'bsq', rn_endian);

        	 fprintf('%s\n', [fname, ': cube']);

        	 %% Check that the tab file for this observation exists
        	 hktabpath = getFileExist([datadir, str_remove_quotes(label.file2.hat_trdr_hk_table)]);

        	 %% Need to read all the housekeeping info from this msp's tab file into variables,
        	 % They're stored according to trdrhk.fmt

        	 % So read trdrhk.fmt
        	 trdrhk = read_pds_lbl(trdrhkfmtpath);

        	 % Read the housekeeping .TAB file according to the structure held in
        	 % trdrhk.
        	 formatstring = getFormatString(trdrhk, 'column');

        	 % Open and read the housekeeping table
        	 fid = fopen(hktabpath, 'r');
        	 % Read columns into cell array
        	 C = textscan(fid, formatstring, 'Delimiter', ',');
        	 fclose(fid);

        	 % Now format the housekeeping table to send it back with the observation.
        	 hktab = formatPDSTableWithLabel(C, trdrhk, 'column');

        	 fprintf('%s\n', [fname, ': housekeeping table']);

        	 %% To get the absolute wavelengths of each band we need to read the
        	 % defined CDR, something like:
        	 %
        	 %   CDR450924300802_WA0300010S_2.IMG
        	 %
        	 % They are all held on the PDS in the directory:
        	 %  
        	 %   /mro/mro-m-crism-2-edr-v1/mrocr_0001/cdr/wa/
        	 %
        	 % Which should be stored locally and read as needed.
        	 %
        	 % 
        	 cdrwadir = [imgpath(1:strfind(imgpath, '/mro/')), 'mro/mro-m-crism-2-edr-v1/mrocr_0001/cdr/wa/'];

        	 % Check the file exists
        	 cdrwapath = getFileExist([cdrwadir, lower(str_remove_quotes(label.mro_wavelength_file_name))]);

			 if ischar(cdrwapath)
        		 % Check it's label exists
        		 cdrwalblpath = getFileExist(getLabelPath(cdrwapath));

				 % If it also exists, read the label:
				 if ischar(cdrwalblpath)
					 cdrwalbl = read_pds_lbl(cdrwalblpath);

					 % Get info regarding the table of wavelengths:
					 wa_lines = str2double(cdrwalbl.file1.image.lines);
					 wa_samples = str2double(cdrwalbl.file1.image.line_samples);
					 wa_endian = get_endian(cdrwalbl.file1.image.sample_type);
					 wa_precision = get_precision(cdrwalbl.file1.image.sample_bits);
					 wa_bands = str2double(cdrwalbl.file1.image.bands);
					 wa_samplebytes = str2double(cdrwalbl.file1.image.sample_bits)/8;
					 switch cdrwalbl.file1.image.band_storage_type
						 case 'LINE_INTERLEAVED'
							 wa_interleave = 'bil';
						 case 'BAND_INTERLEAVED'
							 wa_interleave = 'bsq';
						 case 'SAMPLE_INTERLEAVED'
							 wa_interleave = 'bip';
					 end
					 % Read the wavelength table.
					 wa = multibandread(cdrwapath, [wa_lines,wa_samples,wa_bands],...
						 wa_precision, 0, wa_interleave, wa_endian);

					 % Now read the rownumber table.
					 % Get info regarding the table of wavelengths:
					 rncdr_rows = str2double(cdrwalbl.file1.rownum_table.rows);
					 rncdr_columns = str2double(cdrwalbl.file1.rownum_table.columns);
					 rncdr_endian = get_endian(cdrwalbl.file1.rownum_table.column1.data_type);
					 rncdr_precision = get_precision(cdrwalbl.file1.rownum_table.row_bytes);

					 % Calculate where the rownum table begins.
					 rncdr_startbyte = (wa_lines * wa_samples * wa_bands * wa_samplebytes);

					 % Read the rownumber table.
					 rownum_table_cdr = multibandread(cdrwapath, [rncdr_columns , rncdr_rows, 1], rncdr_precision, rncdr_startbyte, 'bsq', rncdr_endian);

					 % Check this rownumber table matches the one in the observation file,
					 % if not there's a problem.
					 if rownum_table_cdr ~= rownum_table
						 error(['Rownumber table in ', imgpath, ' does not match that in ', cdrwapath]);
					 end
					 % Make the null values equal to 0;
					 wa(wa == nullvalue) = 0;

					 fprintf('%s\n', [fname, ': wavelength table']);

					 %% Now get the entries for the observation in the index for this volume
					 % Have a guess at the path to the index directory in the PDS, given the 
					 % path to the image...
					 idxpath = [imgpath(1:strfind(imgpath, '/trdr/')), 'index'];
					 [~, result] = unix(['grep ', str_remove_quotes(label.product_id), ' ', idxpath, '/*.tab']);
					 [idxpath, record] = strtok(result, ':');

					 % Now the index entry is stored in record. Get the structure from the
					 % label file.

					 % Check the label file exists: 
					 idxlblpath = getFileExist(getLabelPath(idxpath));

					 % Read it:
					 idxlabel = read_pds_lbl(idxlblpath);
					 % Make the format string.
					 formatstring = getFormatString(idxlabel.index_table, 'column');
					 % Read the string into a cell array
					 C = textscan(record(2:end), formatstring, 'Delimiter', ',');

					 % Now format the cell array to send it back with the observation as the
					 % structure idx.
					 idx = formatPDSTableWithLabel(C, idxlabel.index_table, 'column');

					 fprintf('%s\n', [fname, ': index entry']);
				 end
			 end
	     end
	end
end
