function [JstMat,BstMat,GstMat,meMat,keMat,ksMat] = func_element_matrices(name,DMat,opMat,NVec,NstVec,xVec,yVec,rho,h,s,t,Dx,Dy)

% name   [string] name of element ('T3','T6','Q4','Q8','Q9')
% DMat   [matrix] elasticity matrix
% opMat  [matrix] operator matrix for stress-displacement matrix [B]
% NVec   [vector] shape function names
% NstVec [vector] shape functions as functions of coordinates
% xVec   [vector] global x-coordinates of nodes, ordered appropriately
% yVec   [vector] global y-coordinates of nodes, ordered appropriately
% rho    [scalar] density of material
% h      [scalar] thickness of element
% JstMat [matrix] Jacobian matrix d(x,y)/d(s,t)
% BstMat [matrix] strain-displacement matrix
% GstMat [matrix] interpolation matrix
% meMat  [matrix] consistent mass matrix
% keMat  [matrix] element stiffness matrix
% ksMat  [matrix] stress stiffness matrix
% rest are symbolic variables

% syms N1 N2 N3 N4 N5 N6 N7 N8 N9 s t Dx Dy Dr Dz r real;

% Number of nodes per element
nNode=str2double(name(end));

% Pre-allocation for shape functions (interpolation) matrix
GMat=sym(zeros(2,length(NVec)*2));
for NN=1:length(NVec)
    % Populate with shape-function multiples of identity matrix
    GMat(:,2*NN-1:2*NN)=NVec(NN)*eye(2);
end

% Populate with functions of coordinates
GstMat=subs(GMat,NVec,NstVec);

% Global nodal coordinates (x,y) per row
node_coords_g=[xVec yVec]; % should be n-by-2

% Jacobian
temp=GstMat*reshape(node_coords_g',2*nNode,[]);
xstVec=simplify(temp(1));
ystVec=simplify(temp(2));
% clear temp;
JstMat=jacobian([xstVec ystVec],[s t])';

% Derivatives
diffstMat=JstMat\[diff(NstVec,s) diff(NstVec,t)]'; % transformed derivatives
DsymMat=[Dx*NVec Dy*NVec]';                        % corresponding symbolic derivatives

% Strain-displacement transformation matrix
BstMat=subs(opMat*GMat,DsymMat,diffstMat);

% % Integration using Gaussian quadrature
% if (strcmp(name,'T3')==1)||(strcmp(name,'Q4')==1) % Bathe Table 5.9
%     % If bilinear, use 2 points
%     np=2;
% else
%     % If biquadratic, use 3 points
%     np=3;
% end
np=5; % still need to refine this, use 5 to be safe for now

[rVec,alphaVec]=func_Gauss_points(np);

% Pre-allocation for output mass and stiffness matrices
meMat=zeros(2*nNode);
keMat=zeros(2*nNode);
ksMat=zeros(2*nNode);

% Set up integrand matrices
integrand_me=GstMat'*GstMat*det(JstMat);
integrand_ke=BstMat'*DMat*BstMat*det(JstMat);

for II=1:np     % for each Gauss point
    for JJ=1:np % loop twice for area integration
        meMat=meMat+alphaVec(II)*alphaVec(JJ)* ...
            rho*h*subs(integrand_me,[s t],[rVec(II) rVec(JJ)]);
        keMat=keMat+alphaVec(II)*alphaVec(JJ)* ...
            h*subs(integrand_ke,[s t],[rVec(II) rVec(JJ)]);
    end
end

meMat=double(meMat);
keMat=double(keMat);
ksMat=double(ksMat);

end