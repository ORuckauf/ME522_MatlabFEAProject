function [DMat,opMat] = func_elasticity_matrix(type,E,nu,Dx,Dy,Dr,Dz,r)

% type  [string] type of analysis ('plane stress','plane strain','axisymmetric')
% E     [scalar] modulus of elasticity of material
% nu    [scalar] Poisson's ratio of material (-1<nu<0.5)
% DMat  [matrix] elasticity matrix
% opMat [matrix] operator matrix for stress-displacement matrix [B]
% rest are symbolic variables

if strcmp(type,'axisymmetric')==1
    % Operator matrix for definition of axisymmetric strain
    % syms Dr Dz r real;
    opMat=[Dr 0;
        0 Dz;
        1/r 0;
        Dz Dr];
    % Axisymmetry elasticity matrix
    DMat=E*(1-nu)/((1+nu)*(1-2*nu))* ...
        [1 nu/(1-nu) nu/(1-nu) 0;
        nu/(1-nu) 1 nu/(1-nu) 0;
        nu/(1-nu) nu/(1-nu) 1 0;
        0 0 0 (1-2*nu)/(2*(1-nu))];
else
    % Operator matrix from definition of (planar) strain
    % syms Dx Dy real;
    opMat=[Dx 0;
        0 Dy;
        Dy Dx];
    if strcmp(type,'plane strain')==1
        % Plane strain elasticity matrix
        DMat=E*(1-nu)/((1+nu)*(1-2*nu))* ...
            [1 nu/(1-nu) 0;
            nu/(1-nu) 1 0;
            0 0 (1-2*nu)/(2*(1-nu))];
    elseif strcmp(type,'plane stress')==1
        % Plane stress elasticity matrix
        DMat=E/(1-nu^2)* ...
            [1 nu 0;
            nu 1 0;
            0 0 (1-nu)/2];
    end
end

end