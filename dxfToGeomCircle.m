function [nodes, edges, edgeType, midpoints, loops, loopType] = dxfToGeomCircle(filename)
    % filename is the string name of the .dxf file
    % nodes includes x,y pairs of all points in loops (Nx2)
    % edges is an (Mx2) matrix that shows connectivity (which nodes connect
    % to form an edge) [start end] <-- indicies in [nodes]
    % edgeType is an (Mx2) vector where 1=line, 2=arc, 3=circle
    % radii is an (Mx1) vector of the radius of an arc or the radius of a circle. NaN for a line.
    % loops is a cell structure with connectivity for each closed loop of edges
    % loopType indicated if it is the outer loop or a hole; 1=out, -1=in

    % Developed using info found at:
    % https://help.autodesk.com/view/OARX/2018/ENU/?guid=GUID-8663262B-222C-414D-B133-4A8506A27C18

% ---------- READ FILE ----------
fid = fopen(filename);
C = textscan(fid, '%s', 'Delimiter', '\n');
fclose(fid);
lines = strtrim(C{1});

i = 1;

raw.lines = []; % raw is a structure contianing the types of edges/shapes
raw.arcs = struct('start', {}, 'end', {}, 'mid', {});
raw.polylines = {};
raw.circles = struct('center', {}, 'radius', {});

% ---------- PARSE DXF ----------
while i < length(lines)-1

    code = str2double(lines{i});
    value = lines{i+1};

    if code == 0

        % ===== LINE =====
        if strcmp(value, 'LINE')
            x1=[]; y1=[]; x2=[]; y2=[];
            i = i + 2;

            while i < length(lines)-1
                code = str2double(lines{i});
                value = lines{i+1};
                if code == 0, break; end

                switch code % indicators 
                    case 10, x1 = str2double(value);
                    case 20, y1 = str2double(value);
                    case 11, x2 = str2double(value);
                    case 21, y2 = str2double(value);
                end
                i = i + 2;
            end

            raw.lines(end+1,:) = [x1 y1 x2 y2];

            % ===== ARC =====
        elseif strcmp(value, 'ARC')
            xc=[]; yc=[]; r=[]; t1=[]; t2=[];
            i = i + 2;

            while i < length(lines)-1
                code = str2double(lines{i});
                value = lines{i+1};
                if code == 0, break; end

                switch code
                    case 10, xc = str2double(value);
                    case 20, yc = str2double(value);
                    case 40, r  = str2double(value);
                    case 50, t1 = deg2rad(str2double(value));
                    case 51, t2 = deg2rad(str2double(value));
                end
                i = i + 2;
            end

            p1 = [xc + r*cos(t1), yc + r*sin(t1)];
            p2 = [xc + r*cos(t2), yc + r*sin(t2)];
            tm = angleMid(t1, t2);
            pm = [xc + r*cos(tm), yc + r*sin(tm)];

            raw.arcs(end+1).start = p1;
            raw.arcs(end).end = p2;
            raw.arcs(end).mid = pm;

            % ===== LWPOLYLINE =====
        elseif strcmp(value, 'LWPOLYLINE')
            pts = [];
            i = i + 2;

            while i < length(lines)-1
                code = str2double(lines{i});
                value = lines{i+1};
                if code == 0, break; end

                if code == 10
                    x = str2double(value);
                    y = str2double(lines{i+3});
                    pts(end+1,:) = [x y];
                end
                i = i + 2;
            end

            raw.polylines{end+1} = pts;

            % ===== CIRCLE =====
        elseif strcmp(value, 'CIRCLE') || strcmp(value, 'AcDbCircle')
            xc=[]; yc=[]; r=[];
            i = i + 2;

            while i < length(lines)-1
                code = str2double(lines{i});
                value = lines{i+1};
                if code == 0, break; end

                switch code
                    case 10, xc = str2double(value);
                    case 20, yc = str2double(value);
                    case 40, r  = str2double(value);
                end
                i = i + 2;
            end

            raw.circles(end+1).center = [xc,yc];
            raw.circles(end).radius = [r,NaN];
        else
            i = i + 2;
        end

    else
        i = i + 2;
    end
end

% ---------- COLLECT POINTS ----------
pts = [];
for k=1:length(raw.lines)
    pts = [pts; raw.lines(:,1:2); raw.lines(:,3:4)];
end

for k = 1:length(raw.arcs)
    pts = [pts; raw.arcs(k).start; raw.arcs(k).end]; % add arc start and stop nodes to pts
end

for k = 1:length(raw.polylines)
    pts = [pts; raw.polylines{k}]; % add polyline nodes to pts
end
for k = 1:length(raw.circles)
    pts = [pts; raw.circles(k).center]; % add circle centers to pts
end

% ---------- UNIQUE NODES ----------
tol = 1e-8;
ptsRounded = round(pts/tol)*tol;
[nodes, ~, ~] = unique(ptsRounded, 'rows');

% ---------- BUILD EDGES ----------
edges = [];
edgeType = [];
midpoints = [];

% Lines
for k = 1:size(raw.lines,1)
    i1 = findNode(nodes, raw.lines(k,1:2));
    i2 = findNode(nodes, raw.lines(k,3:4));

    edges(end+1,:) = [i1 i2];
    edgeType(end+1) = 1; % 1 signals a line
    midpoints(end+1,:) = [NaN,NaN];
end

% Arcs
for k = 1:length(raw.arcs)
    i1 = findNode(nodes, raw.arcs(k).start);
    i2 = findNode(nodes, raw.arcs(k).end);
    
    % =========================================================================

    edges(end+1,:) = [i1 i2];
    edgeType(end+1) = 2; % 2 signals an arc
    midpoints(end+1,:) = raw.arcs(k).mid;
end

% Polylines
for k = 1:length(raw.polylines)
    pts = raw.polylines{k};

    for i = 1:size(pts,1)-1
        i1 = findNode(nodes, pts(i,:));
        i2 = findNode(nodes, pts(i+1,:));

        edges(end+1,:) = [i1 i2];
        edgeType(end+1) = 1;% 1 signals a line
        midpoints(end+1,:) = [NaN,NaN];
    end
end
% add circles later bcs special kind of loop

% ---------- FIND LOOPS ----------
% find loops for lines and arcs
[loops, edges] = findLoops(edges, size(nodes,1));

% --------- ADD CIRCLES to loops and edges -----------
% add circles as edge = [in1, NaN] and loops = e1
% Circles' Edges & Loops (they form their own loop)
for k = 1:length(raw.circles)
    i1 = findNode(nodes, raw.circles(k).center); % find index of center node
    
    edges(end+1,:) = [i1 NaN]; % [center NaN] (there is no end)
    edgeType(end+1) = 3; % 3 signals a circle
    midpoints(end+1,:) = raw.circles(k).radius; % [r,NaM]   

    loops{end+1} = [length(edges), NaN]; % adds last edges index to loops
end

% ---------- CLASSIFY LOOPS ----------
loopType = zeros(length(loops),1);

areas = zeros(length(loops),1);

for k = 1:length(loops)
    poly = loopToPolygon(nodes, edges, loops{k}, midpoints);
    areas(k) = polygonArea(poly);
    
    if areas(k) < 0
        % it's CW, gotta flip it and edges
        loops{k} = flip(loops{k});
        for e=loops{k}
            edges(e,:) = flip(edges(e,:));
        end
    end
end

% Largest magnitude area = outer boundary
[~, outerIdx] = max(abs(areas));

for k = 1:length(loops)
    if k == outerIdx
        loopType(k) = +1;
    else
        loopType(k) = -1;
    end
end

% Put outer loop first
[loopType, sortix] = sort(loopType, 'descend');
loops = loops(sortix);

end

% =========================================================================
% ===================== HELPER FUNCS ======================================

function idx = findNode(nodes, p)
    d = vecnorm(nodes - p, 2, 2);
    [~, idx] = min(d);
end

function tm = angleMid(t1, t2)
    dt = mod(t2 - t1, 2*pi);
    tm = t1 + dt/2;
end

function poly = loopToPolygon(nodes, edges, loop, midpoints)
% if edges doesn't have an end, then it's a circle
    if (isnan(edges(loop(1),2)))
        poly = [midpoints(loop(1)),NaN];

    else
        e = edges(loop,:); % get edge indicies that make the loop
        poly = nodes(e(:,1),:); % get nodes that make the loop
    end
end

function A = polygonArea(poly)
    x = poly(:,1);
    y = poly(:,2);

    % if second entry is NaN, then we got a circle
    if (isnan(y))
        r = poly(1);
        A = pi()*r^2;
    else
        A = 0.5 * sum(x.*circshift(y,-1) - y.*circshift(x,-1));
    end
end

function [loops,edges] = findLoops(edges, nNodes)
    adj = cell(nNodes,1);
    for i = 1:size(edges,1)
        adj{edges(i,1)}(end+1) = i;
        adj{edges(i,2)}(end+1) = i;
    end
    
    used = false(size(edges,1),1);
    loops = {};
    
    for startEdge = 1:size(edges,1)
    
        if used(startEdge), continue; end
    
        loop = [];
        current = startEdge;
        while ~used(current) 
            used(current) = true;
            loop(end+1) = current;
            
            node = edges(current,2);
            
            % find the next edge
            [rows, cols] = find(edges == node);
            e1 = [rows(1), cols(1)];
            e2 = [rows(2), cols(2)];
            nextEdge = e1;
            if nextEdge(1) == current
                nextEdge = e2;
            end
    
            if nextEdge(2) == 2
                % next edge is backwards
                edges(nextEdge(1),:) = [edges(nextEdge(1),2), edges(nextEdge(1),1)]; 
            end
            % add next edge and begin again
            current = nextEdge(1); 
        end      
    
        loops{end+1} = loop;
    end
end