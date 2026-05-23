function [sides] = sideEdgeSelection(start_edge,allEdges,points,epsilon, loops, boundaryEdges, t)
%   (a) Side edge definition =================================================
%       i) using an existing edge in the background mesh
%       ii) swapping the diagonal of adjacent triangles
%       iii) splitting triangles to create a new edge

switch start_edge(3)
    case 1
        % S11 - don't need more side edges
        sides = [e1,e2]; % add both sides to it
    case 2
        % S10 - need a right side edge
        rightSide = generateSideEdge(start_edge(1),allEdges(start_edge(1),2),allEdges,points,epsilon, loops);
        sides = [e1, rightSide];
    case 3
        % S01 - need a left side edge
        leftSide = generateSideEdge(start_edge(1),allEdges(start_edge(1),1),allEdges,points,epsilon, loops);
        sides = [leftSide, e2];
    case 4
        % S00 - need both side edges
        rightSide = generateSideEdge(start_edge(1),allEdges(start_edge(1),2),allEdges,points,epsilon, loops);
        leftSide = generateSideEdge(start_edge(1),allEdges(start_edge(1),1),allEdges,points,epsilon, loops);
        sides = [leftSide, rightSide];
end
end % end main function



% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function selectedEdge = generateSideEdge(start_edge_ID,Nk,allEdges,points,epsilon, loops,t )
    selectedEdge = struct(); 
    
    % Find adjacent edges
    start_edge = allEdges(start_edge_ID,:);
    
    % grab the before and after
    [prev_edge_ix, next_edge_ix] = findAdjacentEdges(start_edge_ID, loops);
    
    prev_node_ix = 0;
    next_node_ix = 0;

    if ~isempty(find(allEdges(prev_edge_ix)==Nk,1))
        % see if Nk is on previous
        prev_node_ix = allEdges(prev_edge_ix,1);
        next_node_ix = start_edge(2);

    else
        prev_node_ix = start_edge(1);
        next_node_ix = allEdges(next_edge_ix,2);
    end

    % now gotta actually do edge stuffs
    % figure out which of three options
    % build ideal vector Vk
    center_pt = points(Nk,:);
    e1_pt = points(prev_node_ix,:);
    e2_pt = points(next_node_ix,:);

    e1_pt = e1_pt - center_pt;
    e2_pt = e2_pt - center_pt;

    dirs(1,:) = e1_pt / norm(e1_pt);
    dirs(2,:) = e2_pt / norm(e2_pt);
    
    tol = 1e-6;
    Vk = dirs(1,:) + dirs(2,:);
    if norm(Vk) < tol
        % fallback logic
        % if parallel and opposing direction, jsut be 90 deg inwards
        prev_pt = points(prev_node_ix,:);
        next_pt = points(next_node_ix,:);
        t = next_pt - prev_pt;
        t = t/norm(t); 
        Vk = [-t(2), t(1)]; % point 90 CCW from next, ie. inwards
        Vk = Vk / norm(Vk);
    else
        Vk = dirs(1,:) + dirs(2,:);
        Vk = Vk / norm(Vk);
    end
   
    % Find all edges connected to Nk
    % Find candidate angles for all edges conneted to nk
    [candidateEdges, ~] = find(allEdges==Nk);

    % Check cases for dudes
    
    % CASE 1: Use existing edge =====================================
    
    % Vk = [Vk+center_pt;center_pt]; % put back on center point
    % candidateEdges_notNk = find(ed)
    thetas = Vk_angle(candidateEdges,Vk,Nk,points, allEdges); %angle btwn Vk and candidate edges 
    [best_theta,best_theta_ix] = min(abs(thetas));
    if best_theta<epsilon
        % CASE 1 applies
        % selectedEdge = candidateEdges(best_theta_ix);
        selectedEdge.type = "existing";
        selectedEdge.edgeID = candidateEdges(best_theta_ix);
        selectedEdge.Nk = Nk;
        return;
    end
    % CASE 2: Edge swap =====================================
    % Incomplete
    edgeID = start_edge_ID;
    edgeNodes = allEdges(edgeID,:);

    % CASE 3: Edge split ==============================================
    % Incomplete
    

end % main function end

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [prev_edge_ix, next_edge_ix] = findAdjacentEdges(start_edge_ix, loops)
    for k = 1:length(loops)
        loop = loops{k};
        if isempty(find(loops{k}==start_edge_ix,1))
            continue; % doesn't belong to this loop
        end
        % does belong to this loop
        loop_edge_ix = find(loops{k}==start_edge_ix,1);
        prev_loop_edge_ix = mod(loop_edge_ix-2,length(loops{k}))+1;
        next_loop_edge_ix = mod(loop_edge_ix,length(loops{k}))+1;

        prev_edge_ix = loops{k}(prev_loop_edge_ix);
        next_edge_ix = loops{k}(next_loop_edge_ix);
        break;
    end
    % prev_edge_ix = mod(start_edge_ix-1,length(allEdges)) + 1;
    % next_edge_ix = mod(start_edge_ix-1,length(allEdges)) + 1;
end

function alphas = Vk_angle(candidateEdges, Vk, Nk, points, edges)
% Returns angle between two lines, handles vectors of lines
% angle is in radians
    % P1 = points(e1(:,1),:);
    % V = points(center,:);
    % P2 = points(e2(:,2),:);
    % 
    % % shift to start at origin
    % A = P1 - V;
    % B = P2 - V;
    a = edges(candidateEdges,:) == Nk; % get mapping of same
    candidateNodes = edges(candidateEdges,:);
    candidateNodes = sum(candidateNodes.*~a,2);
    candidatePoints = points(candidateNodes,:);

    V = points(Nk,:);

    % shift to start at origin
    A = candidatePoints - V;
    B = Vk ;

    anglesA = atan2(A(:,2), A(:,1));
    angleB  = atan2(B(2), B(1));
    
    % Find the difference
    angles_rad = anglesA - angleB;
        % Keep results between -pi and pi

    alphas = atan2(sin(angles_rad), cos(angles_rad));
end

