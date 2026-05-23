function [q,pq] = convertToQuadMesh(t,p)
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% unfinished function; this is incomplete
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% outputs q, connectivity map and pq, node locationss
% https://pages.cs.wisc.edu/~csverma/CS899_09/qmorph.pdf
% 
% INPUT: 
% p = node coordinates (Nx2)
% t = triangle connectivity (Mx3)
%
% nodesG = geometry nodes
% edgesG = geometry edge connectivity
% edgeTypeG = geometry edge type
% midpointsG = arc/circle extra info
% loopsG = which edges form a closed loop 
% loopTypeG = outer boundary / hole indicator
%
% OUTPUT:
% q = quad connectivity (Kx4) 
% pq = node coordinates updated 
%


% for testing
q=t;
pq=p;

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 1. Background mesh using triangular elements =================================================
% global  nodesG edgesG edgeTypeG midpointsG loopsG loopTypeG
angleTol = 3*pi/4;
epsilon = pi/6;

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 2. Front definition =================================================
% Find which edges are boundary edges
%       Make list of all edges
allEdges = [t(:,[1,2]);
            t(:,[2,3]);
            t(:,[3,1])];
% allEdgesSorted = sort(allEdges,2);
% allEdges = unique(allEdges,'rows','stable');
% allEdgesSorted = unique(allEdgesSorted,'rows'); %,'stable');
[~, unique_idx] = unique(sort(allEdges,2),'rows', 'stable');
allEdges = allEdges(unique_idx,:);

%       Make list of which edges connect which triangles

% a = [1,2,3;1,2,4;2,3,5];
% b=[1,3;1,2;1,4;2,4;2,5;2,3;3,5];
a = t;
b = allEdges;
triangleTouching = {};
boundaryEdgeIdxs = [];
boundaryEdges = [];
for i = 1:length(b)
    c = ismember(a,b(i,:));
    triangleTouching{i} = find(sum(c,2)==2)';
    
    % For edges connected to only one triangle = boundary edge
    if length(triangleTouching{i})==1
        boundaryEdgeIdxs(end+1) = i;
        boundaryEdges(end+1,:) = b(i,:);
    end
end

%       Keep track of which edges create a loop and store as such
[loops,boundaryEdges] = findLoops(boundaryEdges, boundaryEdgeIdxs,p,allEdges);
initial_front_loops = loops; % CCW for outer, CW for inner
% loops contain indicies corresponding to allEdges

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 3. Front edge classification =================================================
% For these loops, compute state and store
%       For an edge, find neighbor edges
%       Compute angle with said edges
%       store results
loops_states = {}; % where each cell is an Nx2 matrix, with each row being an edge
for k = 1:length(loops)
    edge_states = zeros(length(loops{k}),2);
   
    % if angle on either side, set it in loop_edge states
    prev_edges = [allEdges(loops{k}(end),:); allEdges(loops{k}(1:end-1),:)];
    current_edges = [allEdges(loops{k},:)];
    next_edges = [allEdges(loops{k}(2:end),:); allEdges(loops{k}(1),:)];
    left_angles = front_angle(prev_edges, current_edges, p);
    right_angles = front_angle(current_edges, next_edges, p);
    loops_states{k} = [left_angles<angleTol, right_angles<angleTol];
end

% put each edge on a priority queue 
S00 = [];
S10 = [];
S01 = [];
S11 = [];

for k=1:length(loops)
    for j = 1:length(loops{k})
        % for each edge in a loop put it on a queue
        if loops_states{k}(j,:)==[0,0]
            S00(end+1,:) = [loops{k}(j), 0];
        elseif loops_states{k}(j,:)==[1,0]
            S10(end+1,:) = [loops{k}(j), 0];
        elseif loops_states{k}(j,:)==[0,1]
            S01(end+1,:) = [loops{k}(j), 0];
        elseif loops_states{k}(j,:)==[1,1]
            S11(end+1,:) = [loops{k}(j), 0];
        end
    end
end

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 4. Front edge processing ================================================

pq = p;
while ~isempty(S00) || ~isempty(S11) || ~isempty(S01) || ~isempty(S10)
    
    % % loop through and repeat for every edge until done
    % for each one, generate the resulting side edge
   
    start_edge = getNextIx(S00,S11,S10,S01); % gives back [allEdges_idx, level, type]
    edgeID = start_edge(1);

    %   (a) Side edge definition ==============================================

    %       i) using an existing edge in the background mesh
    %       ii) swapping the diagonal of adjacent triangles
    %       iii) splitting triangles to create a new edge
    sides = sideEdgeSelection(start_edge,allEdges,pq,epsilon,loops,boundaryEdges,t);
    
    % if strcmp(sides.type, "existing")
    %     % do nothing or just accept edge
    %     continue;
    % end
    % if strcmp(sides.type, "flip")
    %     t = flipEdgeSimple(t, sides.edgeID, allEdges);
    % 
    %     % rebuild edges AFTER modification
    %     allEdges = [t(:,[1,2]);
    %                 t(:,[2,3]);
    %                 t(:,[3,1])];
    % 
    %     continue;
    % end
    % if strcmp(sides.type, "split")
    %     [pq, t, newNode] = splitEdgeSimple(pq, t, allEdges, sides.edgeID);
    % 
    %     % rebuild edges AFTER modification
    %     allEdges = [t(:,[1,2]);
    %                 t(:,[2,3]);
    %                 t(:,[3,1])];
    % 
    %     continue;
    % end
    % disp(sides.type)

    %   (b) Top edge recovery =================================================
    % topEdge = recoverTopEdge(edgeID, sides, allEdges,pq);
    
    %   (c) Quadrilateral formulation =================================================
    % quad = formQuadrilateral(edgeID, sides, topEdge, allEdges);
    % q(end+1,:) = quad;
    
    %   (d) Local smoothing  =================================================
    % pq = localSmoothQuad(pq, quad, allEdges);
    
    %   (e) Local front reclassification =================================================
    % [S00, S10 S01, S11, loops] = reclassifyFront(S00,S10,S01,S11,loops,quad,ellEdges,pq);


    % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % 5. Quadrilateral formulation =================================================

    break;
end
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 6. Topological clean-up =================================================



% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 7. Smoothing =================================================



end % end main fucntion

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Functions =====================================================

function [loops,edges] = findLoops(edges, edges_ixs,points, allEdges)
    used = zeros(size(edges,1),1);
    loops = {};
    
    for startEdge = 1:size(edges,1)
    
        if used(startEdge), continue; end
    
        loop = [];
        current_ix = startEdge;
        while ~used(current_ix) 
            used(current_ix) = 1;
            loop(end+1) = edges_ixs(current_ix);
            
            nextNode = edges(current_ix, 2);
            
            % find the next edge
            [rows, cols] = find(edges == nextNode);
            e1 = [rows(1), cols(1)]; % row index, if next is front or not
            e2 = [rows(2), cols(2)];
            nextEdge = e1;
            if nextEdge(1) == current_ix
                nextEdge = e2;
            end
    
            if nextEdge(2) == 2
                % next edge is backwards
                % (reset so tail-head, not tail-tail) 
                edges(nextEdge(1),:) = [edges(nextEdge(1),2), edges(nextEdge(1),1)];
                allcurrent_ix = edges_ixs(nextEdge(1));
                allEdges(allcurrent_ix,:) = [allEdges(allcurrent_ix,2), allEdges(allcurrent_ix,1)];
            end
            % add next edge's ix and begin again
            current_ix = nextEdge(1); 
        end      
    
        loops{end+1} = loop;
    end
    % Set exterior loop to counter clockwise, interior loop to clockwise

    % Largest magnitude area = outer boundary, put at front
    areas = [];
    for k = 1:length(loops)
        poly = loopToPolygon(points, allEdges, loops{k});
        areas(k) = polygonArea(poly);
    end

    [~, outerIdx] = max(abs(areas));
    loops = [loops(outerIdx), loops(1:outerIdx-1), loops(outerIdx+1:end)];

end % end loops function

function poly = loopToPolygon(nodes, edges, loop)
    e = edges(loop,:); % get edge indicies that make the loop
    poly = nodes(e(:,1),:); % get nodes that make the loop
end

function A = polygonArea(poly)
    x = poly(:,1);
    y = poly(:,2);

    A = 0.5 * sum(x.*circshift(y,-1) - y.*circshift(x,-1));
end

function alphas = front_angle(e1, e2, points)
% Returns angle between lines in e1 and line e2
% angle is in radians
    P1 = points(e1(:,1),:);
    V = points(e1(:,2),:);
    P2 = points(e2(:,2),:);

    % shift to start at origin
    A = P1 - V;
    B = P2 - V;

    alphas = acos(sum(A.*B,2) ./ (sqrt(sum(A.^2,2)).*sqrt(sum(B.^2,2))));
end


function nextIx = getNextIx(S00,S11,S10,S01) 
    % for every edge in the front
    % find lowest level present and start there
    priorities = [S11, ones([length(S11),1]);   ...
                  S10, 2*ones([length(S10),1]); ...
                  S01, 3*ones([length(S01),1]); ...
                  S00, 4*ones([length(S00),1])   ];
    
    % find lowest priority and lowest rank
    priorities = sortrows(priorities, [2,3]); % sort by level, then type
    nextIx = priorities(1,:); % gives back [allEdges_idx, level, type]
end

