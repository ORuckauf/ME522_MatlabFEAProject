function [points] = discretizeLoops(nodes, edges, edgeTypes, midpoints, loop, h)

% Walk around loop
% call helpers for each type of edge
% add to points
% check signed area to ensure counterclockwise 
% 

points = [];

for loop_idx = 1:length(loop)
    edge_idx = loop(loop_idx);
    if isnan(edge_idx)
        continue;
    end
    edgeType = edgeTypes(edge_idx);
    edgePoints = [];
    switch edgeType
        case 1, edgePoints = lineToPoints(edges(edge_idx,:), nodes, h);
        case 2, edgePoints = arcToPoints(edges(edge_idx,:), nodes,midpoints(edge_idx,:), h);
        case 3, edgePoints = circleToPoints(edges(edge_idx,1), nodes,midpoints(edge_idx,1), h);
    end
    points = [points(1:end-1,:);edgePoints]; % don't duplicate last end and now first
end
points = points(1:end-1,:); % remove duplicate last pt
tol = 1e-8;
ptsRounded = round(points/tol)*tol;
% [points, ~, ~] = unique(ptsRounded, 'rows');

end

% =========================================================================
% ===================== HELPER FUNCS ======================================
function pts = lineToPoints(edge, nodes, h)
    p1 = nodes(edge(1),:); % [x,y]
    p2 = nodes(edge(2),:); % [x,y]
    L = norm(p2 - p1); % total length
    
    % Number of segments (at least 1)
    n = max(1, ceil(L / h));
    
    % Parameter from 0 to 1
    t = linspace(0, 1, n+1)';
    pts = (1 - t) * p1 + t * p2;

end

function pts = arcToPoints(edge, nodes, midpoint, h)
% p1 : start point [x y]
% pm : midpoint/control point [x y]
% p2 : end point [x y]
% h  : desired spacing
% pts: Nx2 points along arc
pm = midpoint;
p1 = nodes(edge(1),:);
p2 = nodes(edge(2),:);

    % break up pts
    A = [p1 1;
         pm 1;
         p2 1];
     
    B = -[dot(p1,p1);
          dot(pm,pm);
          dot(p2,p2)];
      
    D = det(A);
    
    if abs(D) < 1e-12
        error('Points are collinear or nearly collinear');
    end
    
    % find radius and center using perpendicular bisector method
    a = p1; b = pm; c = p2;
    
    d = 2 * (a(1)*(b(2)-c(2)) + b(1)*(c(2)-a(2)) + c(1)*(a(2)-b(2)));
    
    ux = ((norm(a)^2)*(b(2)-c(2)) + (norm(b)^2)*(c(2)-a(2)) + (norm(c)^2)*(a(2)-b(2))) / d;
    uy = ((norm(a)^2)*(c(1)-b(1)) + (norm(b)^2)*(a(1)-c(1)) + (norm(c)^2)*(b(1)-a(1))) / d;
    
    center = [ux uy];
    R = norm(p1 - center);
    
    % find angles or start and stop
    theta1 = atan2(p1(2)-center(2), p1(1)-center(1));
    thetam = atan2(pm(2)-center(2), pm(1)-center(1));
    theta2 = atan2(p2(2)-center(2), p2(1)-center(1));
    
    % make sure CCW
    % check if midpoint lies between start and end CCW
    if mod(theta2 - theta1, 2*pi) < mod(thetam - theta1, 2*pi)
        % go the other way (CW)
        if theta2 > theta1
            theta2 = theta2 - 2*pi;
        end
    else
        % CCW
        if theta2 < theta1
            theta2 = theta2 + 2*pi;
        end
    end
    
    % split arc length into n segments with h length
    arcLength = abs(theta2 - theta1) * R;
    n = max(1, ceil(arcLength / h));
    
    theta = linspace(theta1, theta2, n+1)'; % finds lil inside thetas
    
    % use lil thetas to find x and y pts with trig
    pts = [center(1) + R*cos(theta), center(2) + R*sin(theta)];
end

function pts = circleToPoints(center_idx, nodes, radius, h)
    center = nodes(center_idx,:);
    
    % divide perim into n segemnts with h legnth
    perim = 2*pi()*radius;
    n = max(1, ceil(perim / h));
    
    theta = linspace(0, 2*pi(), n+1)'; % finds lil inside thetas
    
    % use lil thetas to find x and y pts with trig
    pts = [center(1) + radius*cos(theta), center(2) + radius*sin(theta)];
end