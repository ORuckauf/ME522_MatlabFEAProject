function [totalLength, elementEdgeNodePairs] = getEdgeLengths(model, bcEntry, displayUnits)
% GETEDGELENGTHS  Compute the total length of a boundary edge and the
%                 ordered node pairs along it.
%
% INPUTS
%   model        - model struct from the GUI (needs model.mesh.xcoords/ycoords)
%   bcEntry      - one entry from model.constraints or model.loads
%                  (needs bcEntry.affected_nodes)
%   displayUnits - (optional) 'm' | 'cm' | 'mm' | 'in'  (default: 'm')
%                  NOTE: always use 'm' inside the solver.
%
% OUTPUTS
%   totalLength          - total arc length of the edge in requested units
%   elementEdgeNodePairs - [k-1 x 2] ordered node index pairs [nodeA, nodeB]

if nargin < 3 || isempty(displayUnits), displayUnits = 'm'; end
switch lower(displayUnits)
    case 'm',   scale = 1;
    case 'cm',  scale = 100;
    case 'mm',  scale = 1000;
    case 'in',  scale = 39.3701;
    otherwise,  warning('getEdgeLengths: unknown unit "%s", using metres.', displayUnits); scale = 1;
end

if ~isstruct(model) || ~isfield(model,'mesh') || isempty(model.mesh)
    error('getEdgeLengths: model.mesh is empty.'); end
if ~isstruct(bcEntry) || ~isfield(bcEntry,'affected_nodes')
    error('getEdgeLengths: bcEntry must have affected_nodes.'); end

x = model.mesh.xcoords(:);
y = model.mesh.ycoords(:);
nodes = bcEntry.affected_nodes(:)';

if numel(nodes) <= 1
    totalLength = 0; elementEdgeNodePairs = zeros(0,2); return;
end

nodes = orderNodesAlongEdge(nodes, x, y);

nSeg = numel(nodes) - 1;
elementEdgeNodePairs = zeros(nSeg, 2);
totalLength = 0;
for s = 1:nSeg
    nA = nodes(s); nB = nodes(s+1);
    totalLength = totalLength + hypot(x(nB)-x(nA), y(nB)-y(nA)) * scale;
    elementEdgeNodePairs(s,:) = [nA, nB];
end

end

function orderedNodes = orderNodesAlongEdge(nodes, x, y)
    if numel(nodes) <= 2, orderedNodes = nodes; return; end
    [~, startIdx] = sortrows([x(nodes(:)), y(nodes(:))], [1 2]);
    ordered   = nodes(startIdx);
    current   = ordered(1);
    remaining = ordered(2:end);
    orderedNodes = current;
    while ~isempty(remaining)
        dists = hypot(x(remaining)-x(current), y(remaining)-y(current));
        [~, nextIdx] = min(dists);
        current = remaining(nextIdx);
        remaining(nextIdx) = [];
        orderedNodes(end+1) = current; %#ok<AGROW>
    end
end