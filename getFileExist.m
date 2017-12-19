% Function to check if file exists. If it does, return the path to it, 
% otherwise return -1.
function fpath = getFileExist(fpath)
    if exist(fpath, 'file') <= 0
        fpath = -1;
    end
end