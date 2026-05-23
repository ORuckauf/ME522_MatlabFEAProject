function fig = plotGeomCircle(nodes, edges, edgeType, midpoints, loops, loopType, units)
% plotGeom - Plots a 2D geometry from dxfToGeom output
%
% INPUTS:
%   nodes     : N x 2 array of coordinates
%   edges     : M x 2 connectivity array (center, NaN for circle)
%   edgeType  : M x 1 (1=line, 2=arc, 3=circle)
%   midpoints : M x 2 array (NaN, NaN for lines), (r, NaN for cirlces)
%   loops     : cell array of edge indices for each loop 
%   loopType  : +1 = outer boundary, -1 = hole
%
% Example:
%   [nodes, edges, edgeType, midpoints, loops, loopType] = dxfToGeom('part.dxf');
%   plotGeom(nodes, edges, edgeType, midpoints, loops, loopType);

fig = figure;

for k = 1:length(loops)
    loopEdges = loops{k};
    loopNodes = [];

    % Build ordered points for this loop
    for e = loopEdges
        if isnan(e)
            % seccond entry in circle
            continue;
        elseif edgeType(e) == 3
            % full circle
            nCenter = edges(e,1);
            center = nodes(nCenter,:);
            r = midpoints(e,1);
            theta = linspace(0,2*pi,50);
            x = center(1) + r*cos(theta);
            y = center(2) + r*sin(theta);
            loopNodes = [loopNodes; [x', y']];
        elseif edgeType(e) == 2
            % Arc
            n1 = edges(e,1);
            n2 = edges(e,2);
            p1 = nodes(n1,:);
            p2 = nodes(n2,:);
            pm = midpoints(e,:);
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
            h = 0.1*arcLength;
            n = max(1, ceil(arcLength / h));

            theta = linspace(theta1, theta2, n+1)'; % finds lil inside thetas

            % use lil thetas to find x and y pts with trig
            arcPts = [center(1) + R*cos(theta), center(2) + R*sin(theta)];
            loopNodes = [loopNodes; arcPts];
        else
            % Line
            n1 = edges(e,1);
            n2 = edges(e,2);
            loopNodes = [loopNodes; nodes(n1,:); nodes(n2,:)];
        end
    end

    % Remove duplicate consecutive points
    [~, ia, ~] = unique(round(loopNodes,8),'rows','stable');
    loopNodes = loopNodes(sort(ia),:);

    % Choose color
    if loopType(k) == +1
        faceColor = [0.8 0.8 0.8]; % outer boundary = light gray
    else
        faceColor = [1 1 1];       % hole = white
        % faceColor = [18 18 18]/255;       % hole = black
    end

    fill(loopNodes(:,1), loopNodes(:,2), faceColor, 'EdgeColor', 'k');
hold on;
end

axis equal;
xlabel(sprintf('x [%s]',units),'interpreter','latex');
ylabel(sprintf('y [%s]',units),'interpreter','latex');
title('Imported DXF Geometry','interpreter','latex');
set(gca,'TickLabelInterpreter','latex');
grid on;
set(gca,'Layer','top');
hold off;

end