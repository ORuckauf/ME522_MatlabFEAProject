clear all
close all
clc

% Part4_HolesAndArcs.dxf
% Part3.dxf
% partFileName = 'ArcsTest.DXF';
% partFileName = 'Part4_HolesAndArcs.dxf';
partFileName = 'test.dxf';

% parse dxf - get user units!! 
% organize data in node; edges; edgeType; midPoints format

[units, scale] = getDXFUnits(partFileName);

[nodes, edges, edgeType, midpoints, loops, loopType] = dxfToGeomCircle(partFileName);

% Convert nodes to meters if needed
nodes = nodes * scale;
midpoints = midpoints * scale;
unitStr = 'meters';
fig = plotGeomCircle(nodes, edges, edgeType, midpoints, loops, loopType, unitStr);
[tr, p] = generateMesh(nodes, edges, edgeType, midpoints, loops, loopType,scale,0.1);

%% testing - Mark

hold on;
% Plot mesh edges as 2D lines instead of trimesh (avoids 3D/2D conflict)
for i = 1:size(tr, 1)
    triIdx = [tr(i,1), tr(i,2), tr(i,3), tr(i,1)];
    plot(p(triIdx, 1), p(triIdx, 2), '-', 'Color', [0 0.7 0.8], 'LineWidth', 0.75);
end

a=tr(2,:)
plot(p(a(1),1),p(a(1),2),'ko');
plot(p(a(2),1),p(a(2),2),'ro');
plot(p(a(3),1),p(a(3),2),'b*');

% tcopy=t;
% 
% tcopy.*(t==t(1,1))

type='plane stress';
name='T3';
E=70e9;
nu=0.3;
rho=2700;
h=0.01;

syms N1 N2 N3 N4 N5 N6 N7 N8 N9 s t Dx Dy Dr Dz r real;
% Use function handles to remove superfluous symbolic function inputs
func_elasticity_matrix=@(type,E,nu)func_elasticity_matrix(type,E,nu,Dx,Dy,Dr,Dz,r);
func_shape_functions=@(name)func_shape_functions(name,N1,N2,N3,N4,N5,N6,N7,N8,N9,s,t);

% These are the same for all elements in the mesh
% Choice of elasticity/stress-strain matrix
[DMat,opMat]=func_elasticity_matrix(type,E,nu);
% Shape functions
[NVec,NstVec]=func_shape_functions(name);

% for II=1:length(t) % loop through each element
for II=1:1
    xVec=p(tr(II,:),1);
    yVec=p(tr(II,:),2);
    [BMat,meMat,keMat,ksMat] = func_element_matrices(name,DMat,opMat,NVec,NstVec,xVec,yVec,rho,h,s,t,Dx,Dy)
end