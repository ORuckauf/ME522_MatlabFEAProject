function [t, p] = generateMesh(nodes, edges, edgeType, midpoints, loops, loopType,scale, h0)
% outputs t, connectivity map and p, node locationss
% ============== GENERATE MESH ===========================================
    % discretize loops into points:
        % generate boundary of --> line segments --> points formed from nodes (convert arcs to lines)
        % line segements should have side length corresponding to mesh size
        % nodes should be in counter-clockwise order

h0 = h0; % * scale; % converts to m
loopsPoints = {}; % indexing still corresponds to loop type
for II=1:length(loops)
    loopsPoints{end+1,1} = discretizeLoops(nodes, edges, edgeType, midpoints, loops{II}, h0);
    hold on
end

% Meshing algorithm (Koko 2015)
% Identify the maximum and minimum x- and y-locations to define the
% bounding box
for II=1:length(loops) % for each loop
    % Only need the exterior loop
    if loopType(II)==1 
        xbound(1,1)=min(loopsPoints{II}(:,1));
        xbound(2,1)=max(loopsPoints{II}(:,1));
        ybound(1,1)=min(loopsPoints{II}(:,2));
        ybound(2,1)=max(loopsPoints{II}(:,2));
    end
end

% xline(xbound(1));
% xline(xbound(2));
% yline(ybound(1));
% yline(ybound(2));

xlim([xbound(1)-2*h0;xbound(2)+2*h0]);

% Create initial distribution in bounding box of overall geometry
bbox=[xbound(1),ybound(1);
    xbound(2),ybound(2)];

% % Rectangle interior grid
% [xgrid,ygrid]=meshgrid(bbox(1,1):h0:bbox(2,1),bbox(1,2):h0:bbox(2,2));
% xgrid(2:2:end,:) = xgrid(2:2:end,:); 

% equilateral interior grid
[xgrid,ygrid]=meshgrid(bbox(1,1):h0:bbox(2,1),bbox(1,2):h0*sqrt(3)/2:bbox(2,2));
xgrid(2:2:end,:) = xgrid(2:2:end,:)+h0/2; % Shifts even rows


% put them into vectors 
xVec=reshape(xgrid,numel(xgrid),[]);
yVec=reshape(ygrid,numel(ygrid),[]);

[in,on]=inpolygon(xVec,yVec,loopsPoints{1}(:,1),loopsPoints{1}(:,2));
pfix = [loopsPoints{1}(:,1),loopsPoints{1}(:,2)]; % boundarypoints
for L =2:length(loopsPoints)
    [inHole,onHole]=inpolygon(xVec,yVec,loopsPoints{L}(:,1),loopsPoints{L}(:,2));
    in = in&~inHole;
    on = on|onHole;
    pfix = [pfix;[loopsPoints{L}(:,1),loopsPoints{L}(:,2)]]; % boundarypoints

end

interiorPts = [xVec(in&~on),yVec(in&~on)];

% dist btwn interior pts and bounds
interiorPtsDist2bound = pdist2M(interiorPts, pfix);
tooClose2bounds = any(interiorPtsDist2bound <= h0/2, 2);
interiorPts = [interiorPts(~tooClose2bounds,1),interiorPts(~tooClose2bounds,2)];

p = [pfix;interiorPts(:,1),interiorPts(:,2)]; % list of boundary and contained nodes
N = size(p,1);

ttol = 0.1;
dptol = 0.001;
Fscale = 1.2;
deltat=0.2;
geps = 0.001*h0;
deps=sqrt(eps)*h0;

pold = inf; % for first iteration
num_loops=0;
while num_loops<30
    % retriangulation using delaunay algorithm
    pstart=p;
    if max(sqrt(sum((p-pold).^2,2))/h0)>ttol % any large movement? 
        pold = p;
        t=delaunay(p);
        pmid = (p(t(:,1),:)+p(t(:,2),:)+p(t(:,3),:))/3; % For each triangle, find centroid
        % keep only those with centroid inside it
        [in,on]=inpolygon(pmid(:,1),pmid(:,2),loopsPoints{1}(:,1),loopsPoints{1}(:,2));
        for L =2:length(loopsPoints)
            [inHole,onHole]=inpolygon(pmid(:,1),pmid(:,2),loopsPoints{L}(:,1),loopsPoints{L}(:,2));
            in = in&~inHole; % remove if it's inside a hole
            on = on|onHole; % add if it's on a bound
        end
        t = t(in&~on,:); % keep only ones where within shape
        bars = [t(:,[1,2]);t(:,[1,3]);t(:,[2,3])]; % interior bars duplicated 
        bars=unique(sort(bars,2),'rows'); % bars as node pairs

        
    end
    barvec = p(bars(:,1),:)-p(bars(:,2),:);
    L = sqrt(sum(barvec.^2,2));
    hbars = h0*ones(length(barvec(:,1)),1);
    L0 = hbars*Fscale*sqrt(sum(L.^2)/sum(hbars(:,1).^2));
    F=max(L0-L,0);
    Fvec = F./L*[1,1].*barvec; % barforces, x-,y-components
    Ftot = full(sparse(bars(:,[1,1,2,2]),ones(size(F))*[1,2,1,2],[Fvec,-Fvec],N,2));
    Ftot(1:size(pfix,1),:)=0;
    p = p+deltat*Ftot;
    
    % =====================================================================
    % bring pts moved outside during adjustment back inside
    [in,on]=inpolygon(p(:,1),p(:,2),loopsPoints{1}(:,1),loopsPoints{1}(:,2));
    for L =2:length(loopsPoints)
        [inHole,onHole]=inpolygon(p(:,1),p(:,2),loopsPoints{L}(:,1),loopsPoints{L}(:,2));
        in = in&~inHole; % remove if it's inside a hole
        in = in|onHole; % add if it's on a bound
    end
    out = ~(in); 
    
    % move to closest point on boundary
    [ixs_first_closest, ds_first] = dsearchn(pfix,p(out,:)); % indicies of boundary pts closest to search guys

    out_ix = find(out>0);
    ixs_second_closest = zeros(length(out_ix),1);
    ds_second = zeros(length(out_ix),1);
   
    % find second closest boundary pt to interpolate with   
    for ix = 1:length(out_ix)
        % find closest point that wasn't already found
        % First, locate where the point we want is (what loop & ix in loop)
        pout = p(out_ix(ix),:);
        pbound_center = pfix(ixs_first_closest(ix),:);
        
        % look to left and right in loop
        % find your point's loop
        cell_ix = cellfun(@(x) any(ismember(x, pbound_center, 'rows')), loopsPoints);
        cell_ix = find(cell_ix);
        ix_found = loopsPoints{cell_ix}==pbound_center;
        ix_found = find(ix_found(:,1) & ix_found(:,2));
        firstpt = loopsPoints{cell_ix}(ix_found,:);
        size_cell = length(loopsPoints{cell_ix}(:,1));
        
        % mod(ix-1,size)+1 = shifts range to be [1,size] instead of [0,size-1]
        leftPt_ix = mod(ix_found-2,size_cell)+1;
        rightPt_ix = mod(ix_found,size_cell)+1;
        leftPt = loopsPoints{cell_ix}(leftPt_ix,:);
        rightPt = loopsPoints{cell_ix}(rightPt_ix,:);
        
        psides = [leftPt;rightPt];
        pixs = [leftPt_ix;rightPt_ix];
        [ixs, ds] = dsearchn(psides,pout);

        % Put in terms of global, instead of loop indexing
        pt_found = psides(ixs,:);
        ix_found = find(pfix(:,1)==pt_found(:,1)&pfix(:,2)==pt_found(:,2));
        ixs_second_closest(ix,:) = ix_found;
        ds_second(ix,:) = ds;  
        pside = pfix(ix_found,:);        

        % find perpendicular intersecion
        A = pfix(ixs_first_closest(ix),:);
        B = pfix(ixs_second_closest(ix),:);
        v = B-A;          % Vector along the line, B-A
        w = pout-A;          % Vector from line start to the point, P-A

        % Use the dot product to find the projection scalar
        projP = A + (dot(w, v) / dot(v, v)) * v;
        p(out_ix(ix),:) = projP;
    end
    % now that we have our closest points, interpolate and place point on
    % boundary
    
    d = sqrt(sum((p-pold).^2, 2)); % Row-wise Euclidean distance

    if max(sqrt(sum((p-pold).^2,2))/h0)<dptol
        break;
    end
    num_loops=num_loops+1;

end
