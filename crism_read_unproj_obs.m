function [cube, cubeinfo, aux] = crism_read_unproj_obs(obsid)
%
% Function to load a CRISM cube defined by it's observation ID, load the
% accompanying data in the ddr and parameter files and pass it back.
%
% For this function to propery operate it needs to exist:
%
% The CRISM .img (long wavelength) file and its ENVI header, ending in:
%   corr_destripe_despike.img
%   corr_destripe_despike.img.hdr
%
% The accompanying ddr file for long wavelength image file and its label 
% file, ending in:
%   l_ddr1.img
%   l_ddr1.lbl
%
% The .img file containing the spectral summary parameters and its ENVI header
% file, ending in:
%   corr_destripe_despike_params.img
%   corr_destripe_despike_params.img.hdr
%
% All the files must be present in the same directory, with the name of the
% CRISM observation. This directory should be at the end of the path
% returned by: crism_getdatadir().
%
% The processes that must be applied to the original CRISM TRDR data file
% to produce this are: Atmospheric correction (adds _corr to the filename)
%                      Spectral cleaning, via CIRRUS (adds _destripe_despike to the filename)
% 
% Elliot Sefton-Nash 26/08/2011
%

% Look for the observation in the crism data directory.
datadir = crism_getdatadir();

% Look for the observation folder
obsdir = [datadir, obsid];
if ~exist(obsdir, 'dir')
    error(['Observation directory ''', obsdir, ''' does not exist.']);
end

% If the directory does exist, get it's contents:
tmp = dir(obsdir);
numfiles = numel(tmp);

% Set up 6 filename endings that should uniquely represent the files we need in the directory:
fpends = {'corr_destripe_despike.img'; 'corr_destripe_despike.img.hdr';... % Cube
	'l_ddr1.img'; 'l_ddr1.lbl';...											% DDR
    'corr_destripe_despike_params.img';'corr_destripe_despike_params.img.hdr'}; % specsum params

% Contains the variable names that will be used to store each files stuff.
fvars = {'fpimg'; 'fpimghdr'; 'fpddr'; 'fpddrlbl'; 'fpimgprm'; 'fpimgprmhdr'};

numends = numel(fpends);

for i = 1:numfiles

    s = tmp(i).name; 
    
    % Check each file in this directory to see if it has the obsid in it:
    if findstr(s, obsid)
    	% Check through endings
    	for ie = 1:numends	
    		
    		% For testing if the filename is a long wavelength one.
    		flag = 0;
    		
  		  	% If the path is longer than the files' ending.
  		  	if numel(s) > numel(fpends{ie})+1	
  		  	
				% if the ending is the right one
				if strcmpi(fpends{ie}, s(numel(s)-numel(fpends{ie})+1:end))
					
					% If this is a long-wavelength file:
					if ie == 1 || ie == 2 || ie == 5 || ie == 6 % For the img and params
						% character 21 of the filename should be 'l'
						if numel(s) >= 21
							if strcmpi(s(21), 'l')
								flag = 1;
							end
						end	
					else
						flag = 1; % If we're looking for the ddr files.
					end
					
					if flag
						% A match. Assuming there's only one match, store it in the appropriate variable name.
						thisfullpath = [obsdir, '/',s];
						eval([ fvars{ie}, '=thisfullpath;']);
                        disp( ['Found: ', thisfullpath] );
					end
				end
    		end
    	end
    end
end	

% Now all the paths are stored, load and consolidate this junk.

% Check all files have been found:
for i = 1:numel(fvars)
    if ~exist(fvars{i}, 'var');
        error(['Variable ''', fvars{i}, ''' does not exist. File with suffix ''', fpends{i}, ''' not found in directory ''', obsdir, '''.'])
    end
end

% Load the ddr and its label, note that the label path is determined automatically
[aux.lat, aux.lon, aux.zm, aux.slp, aux.az, aux.ti, aux.alb] = crism_ddr_extractquans(fpddr);

% Load the spectral summary parameters and its header
[specsum,~,~,specsuminfo] = crism_read_envi_img(fpimgprm, fpimgprmhdr);

% Load the image and its header:
[cube,~,~,cubeinfo] = crism_read_envi_img(fpimg, fpimghdr);

% Check that the specsum and ddr are the same size
planesizespecsum = size(specsum);
planesizespecsum = planesizespecsum(1:2); % First 2 elements, not number of bands.
if size(aux.zm) ~= planesizespecsum
	error('Data in DDR file is not same number of lines and samples as data in spectral summary bands. Check for map-projection');
end

% Combine specsum and ddr into same aux structure
for i=1:specsuminfo.bands
	eval(['aux.', specsuminfo.band_names{i}, '=specsum(:,:,i);']);
end
    
end