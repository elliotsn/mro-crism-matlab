function [varargout] = crism_read_envi_img(varargin)
%
% ENVIREAD Easily import ENVI raster files (BSQ,BIL,BIP) from header info.
%   Z = crism_read_envi_img(FILENAME); Reads an ENVI binary file (BSQ,BIL,BIP) into
%       an array using the information from the corresponding header
%       file FILENAME.hdr. The output array will be of dimensions
%       (m,n,b) where b is the number of bands.
%   Z = crism_read_envi_img(FILENAME,HEADERFILE); Uses the header information in
%       headerfile.
%   [Z,X,Y] = crism_read_envi_img(....); Returns the map coordinate vectors for geo-
%       registered data.
%   [Z,X,Y,info] = crism_read_envi_img(....); Returns the header information as a
%       structure.
%
%   NOTES:  - Requires READ_ENVIHDR to read header data.
%           - Geo-registration does not currently support rotated images.
%
% Ian M. Howat, Applied Physics Lab, University of Washington
% ihowat@apl.washington.edu
% Version 1: 11-Jul-2007 15:11:13
%
% Modified:
%
% Elliot Sefton-Nash 24/08/2011 - Now supports un-projected cubes.
%                               - If they exist, reforms the wavelength, 
%                                 bbl (bad band list) and fwhm fields of 
%                                 the header file into numeric vectors.
%                               - If bbl exists, sets to NaN all bands in
%                                 the cube that are listed as 'bad'.
%                               - If there is a data_ignore_value, sets to
%                                 NaN in the cube all values equal to this.
%
%% check for header reader
if exist('crism_read_envi_hdr.m','file') == 0
    error('This function requires crism_read_envi_hdr.m')
end

%% READ HEADER INFO
% Read Filename
file = varargin{1};
hdrfile = [file(1:end-4),'.hdr'];
if nargin == 2
    hdrfile = varargin{2};
end
% Get header file
header = crism_read_envi_hdr(hdrfile);

%% Make geo-location vectors
% If there is geographic information in the header then the image is map-projected. Make the lat and lon
% vectors.
if isfield(header, 'map_info')

    if isfield(header.map_info,'mapx') && isfield(header.map_info,'mapy')
        xi = header.map_info.image_coords(1);
        yi = header.map_info.image_coords(2);
        xm = header.map_info.mapx;
        ym = header.map_info.mapy;
        %adjust points to corner (1.5,1.5)
        if yi > 1.5 
           ym =  ym + ((yi*header.map_info.dy)-header.map_info.dy);
        end
        if xi > 1.5 
            xm = xm - ((xi*header.map_info.dy)-header.map_info.dx);
        end

        varargout{2} = xm + ((0:header.samples-1).*header.map_info.dx);
        varargout{3} = fliplr(ym - ((0:header.lines-1).*header.map_info.dy));
    end
else
    varargout{2} = -1;
    varargout{3} = -1; % If no map info, set map projection params to zero.
end


%% Set binary format parameters
switch str2double(header.byte_order)
    case {0}
        machine = 'ieee-le';
    case {1}
        machine = 'ieee-be';
    otherwise
        machine = 'n';
end
switch str2double(header.data_type)
    case {1}
        format = 'int8';
    case {2}
        format= 'int16';
    case{3}
        format= 'int32';
    case {4}
        format= 'float';
    case {5}
        format= 'double';
    case {6}
        disp('>> Sorry, Complex (2x32 bits)data currently not supported');
        disp('>> Importing as double-precision instead');
        format= 'double';
    case {9}
            error('Sorry, double-precision complex (2x64 bits) data currently not supported');
    case {12}
            format= 'uint16';
    case {13}
            format= 'uint32';
    case {14}
             format= 'int64';
    case {15}
            format= 'uint64';
    otherwise
        error(['File type number: ',num2str(dtype),' not supported']);
end
%% Read File
header.samples = str2double(header.samples);
header.lines = str2double(header.lines);
header.bands = str2double(header.bands);

Z = fread(fopen(file),header.samples*header.lines*header.bands,format,0,machine); fclose all;
tmp = zeros(header.lines, header.samples, header.bands);
switch lower(header.interleave)
    case {'bsq'}
        Z = reshape(Z,[header.samples,header.lines,header.bands]);
        for k = 1:header.bands;
            tmp(:,:,k) = rot90(Z(:,:,k));
        end
    case {'bil'}
        Z = reshape(Z,[header.samples,header.lines*header.bands]);
        for k=1:header.bands
            tmp(:,:,k) = rot90(Z(:,k:header.bands:end));
        end
    case {'bip'}
        tmp = zeros(header.lines,header.samples);
        for k=1:header.bands
            tmp1 = Z(k:header.bands:end);
            tmp(:,:,k) = rot90(reshape(tmp1,[header.samples,header.lines]));
        end
end
Z = tmp;

% Now null the bad bands and set to 0 all values equal to the data_ignore_value,
% to make plotting easier later on.
if isfield(header, 'data_ignore_value')
    header.data_ignore_value = str2double(header.data_ignore_value);
    Z(Z == header.data_ignore_value) = NaN;
end

% If the wavelength field exists, reform the character array into a vector.
if isfield(header, 'wavelength')
    tmp = header.wavelength;
    tmp(tmp == '{' | tmp == '}') = []; % Remove braces.
    header.wavelength = str2double(char(strtrim(csvstr2arr(tmp))));

    % Also, get rid of that annoying 65536 value in the first element of
    % wavelength, if it exists.
    if isfield(header, 'data_ignore_value')
         header.wavelength(header.wavelength == header.data_ignore_value) = NaN;
    end  
end

% If the bbl field exists (bad band list), reform the character array into a logical vector.
if isfield(header, 'bbl')
    tmp = header.bbl;
    tmp(tmp == '{' | tmp == '}') = []; % Remove braces.
    header.bbl = logical(str2double(char(strtrim(csvstr2arr(tmp)))));
    
    % Set to NaN those bands in the cube.
    Z(:,:,header.bbl == false) = NaN;
end

% If this is a spectral summary parameter cube, reform the band name array into
% a vector
if isfield(header, 'band_names')
    tmp = header.band_names;
    tmp(tmp == '{' | tmp == '}') = []; % Remove braces.
    header.band_names = csvstr2arr(tmp);
end

% If this is normal cube that has default bands, reform the band number array into
% a vector.
if isfield(header, 'default_bands')
    tmp = header.default_bands;
    tmp(tmp == '{' | tmp == '}') = []; % Remove braces.
    header.default_bands = str2double(char(csvstr2arr(tmp)));
end

varargout{1} = Z;
varargout{4} = header;

end