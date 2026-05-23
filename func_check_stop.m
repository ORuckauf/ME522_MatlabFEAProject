function func_check_stop()
%FUNC_CHECK_STOP cancellation helper for long external functions
% Call this inside long loops in generateMesh.m, func_solve.m, or any other
% external routine so the GUI Stop button can interrupt work cleanly.
%
% Example:
%   for k = 1:nElem
%       if mod(k,100)==0, func_check_stop(); end
%       ... expensive work ...
%   end

global stopRequestedG

drawnow;
if ~isempty(stopRequestedG) && stopRequestedG
    error('USER_STOPPED:ComputationStopped','Computation stopped by user.');
end
end
