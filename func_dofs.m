function [dofs] = func_dofs(nNode)

% Assuming two dofs per node and that the dofs are numbered in the same
% order as the nodes (and x before y), then the two dofs corresponding to a
% given node number nNode are:

dofs=reshape([2*(nNode-1)'+(1:2)]',1,[]);

end