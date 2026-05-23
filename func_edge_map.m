function [s,t] = func_edge_map(name,nodes,r)

% name    [string] name of element ('T3','T6','Q4','Q8','Q9')
% nodes   [vector] corner nodes
% sets s and t to either symbolic r (to be integrated) or +1/-1 (constant),
% depending on the edge
% rest are symbolic variables

% Only need to look at the general shape since corner nodes are the same
shape=name(1);

% Default edge map for quadrilateral: each indicates which corner nodes are
% on this edge
if strcmp(shape,'T') % triangular
    edge_map=[1 2;
        2 3;
        3 1];
else
    edge_map=[1 2;
        2 3;
        3 4;
        4 1];
end

% Match the input corner nodes to an edge
for II=1:length(edge_map)
    if sum(ismember(nodes,edge_map(II,:)))==2
        edge=II;
    end
end

if strcmp(shape,'T') % triangular
    switch edge
        case 1
            s=r;
            t=1;
        case 2
            s=-1/2*(r+1);
            t=r;
        case 3
            s=1/2*(r+1);
            t=r;
    end
else
    switch edge
        case 1
            s=r;
            t=1;
        case 2
            s=-1;
            t=r;
        case 3
            s=r;
            t=-1;
        case 4
            s=1;
            t=r;
    end
    int_low=-1;
    int_upp=1;
end

end