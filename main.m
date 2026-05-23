clc
close all
clearvars

%% Step 1: pre-processing
% Testing an example mesh - HW26 from ME422
type='plane stress';
name='Q4';
E=70e9;
nu=0.3;
rho=2700;
h=0.01;

% Global system
xVec_g=[0;1;3;0;2;3];
yVec_g=[1.5;1.5;1.5;0;0;0];

% Think about pre-allocation
elemStruct(1).connectivity=[2;1;4;5];
elemStruct(1).dofs=reshape([2*elemStruct(1).connectivity-1;2*elemStruct(1).connectivity],2*length(elemStruct(1).connectivity),[]);
elemStruct(1).xcoords=xVec_g(elemStruct(1).connectivity); % index using the node numbers
elemStruct(1).ycoords=yVec_g(elemStruct(1).connectivity);

elemStruct(2).connectivity=[3;2;5;6];
elemStruct(2).dofs=reshape([2*elemStruct(2).connectivity-1;2*elemStruct(2).connectivity],2*length(elemStruct(2).connectivity),[]);
elemStruct(2).xcoords=xVec_g(elemStruct(2).connectivity); % index using the node numbers
elemStruct(2).ycoords=yVec_g(elemStruct(2).connectivity);

%% Step 2: formulating individual element matrices
syms N1 N2 N3 N4 N5 N6 N7 N8 N9 s t Dx Dy Dr Dz r real;
% Use function handles to remove superfluous symbolic function inputs
func_elasticity_matrix=@(type,E,nu)func_elasticity_matrix(type,E,nu,Dx,Dy,Dr,Dz,r);
func_shape_functions=@(name)func_shape_functions(name,N1,N2,N3,N4,N5,N6,N7,N8,N9,s,t);

% These are the same for all elements in the mesh
% Choice of elasticity/stress-strain matrix
[DMat,opMat]=func_elasticity_matrix(type,E,nu);
% Shape functions
[NVec,NstVec]=func_shape_functions(name);

% Loop through every element
nElem=2;
for NN=1:nElem
    [elemStruct(NN).BstMat, ... % store outputs in structure fields
        elemStruct(NN).meMat, ...
        elemStruct(NN).keMat, ...
        elemStruct(NN).ksMat]= ...
    func_element_matrices( ...
        name,DMat,opMat,NVec,NstVec, ...
        elemStruct(NN).xcoords, ...
        elemStruct(NN).ycoords, ...
        rho,h, ...
        s,t,Dx,Dy);
end

figure(1);
plot(elemStruct(1).xcoords,elemStruct(1).ycoords,'ro','MarkerFaceColor','r');
axis([-1 3 -1 2.5]);
set(gca,'TickLabelInterpreter','latex');
grid on;

hold on;

xVectest=subs(subs(NstVec'*elemStruct(1).xcoords,s,1),t,linspace(-1,1,1e2));
yVectest=subs(subs(NstVec'*elemStruct(1).ycoords,s,1),t,linspace(-1,1,1e2));

plot(xVectest,yVectest,'g');

%% Step 3: assembling into global system
MMat=zeros(2*length(xVec_g));
KeMat=zeros(2*length(xVec_g));

for NN=1:nElem
    % Populate the corresponding dofs
    MMat(elemStruct(NN).dofs,elemStruct(NN).dofs)= ...
        MMat(elemStruct(NN).dofs,elemStruct(NN).dofs)+ ...
        elemStruct(NN).meMat;
    KeMat(elemStruct(NN).dofs,elemStruct(NN).dofs)= ...
        KeMat(elemStruct(NN).dofs,elemStruct(NN).dofs)+ ...
        elemStruct(NN).keMat;
end

%% Step 4: applying boundary conditions

%% Step 5: solving for unknown variables

%% Step 6: post-processing