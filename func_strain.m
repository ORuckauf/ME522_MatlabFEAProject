function out = func_strain(modelIn)
%FUNC_STRAIN External strain 
%
%   out = FUNC_STRAIN(model)
%   out = FUNC_STRAIN()              % uses global model
%
%   Computes strain from solved nodal displacements for T3 triangular
%   elements and returns fields compatible with the GUI:
%
%       out.results.StrainElem   = nElem  x 3  [eps_xx, eps_yy, gamma_xy]
%       out.results.StrainNodal  = nNodes x 3  [eps_xx, eps_yy, gamma_xy]
%
%   gamma_xy is engineering shear strain:
%       gamma_xy = du/dy + dv/dx
%
%   strain is an averaged/smoothed value for contour plotting.

    if nargin < 1 || isempty(modelIn)
        global model
        modelLocal = model;
    else
        modelLocal = modelIn;
    end

    validateModelForStrain(modelLocal);

    conn = modelLocal.mesh.connectivity;
    x = modelLocal.mesh.xcoords(:);
    y = modelLocal.mesh.ycoords(:);

    nNodesLocal = numel(x);
    nElemLocal = size(conn,1);

    elemType = upper(strtrim(modelLocal.mesh.elementType));
    if ~strcmp(elemType,'T3')
        error('func_strain currently supports T3 triangular elements only. Current element type: %s',elemType);
    end

    [ux,uy] = readDisplacementVector(modelLocal.results.Deformation,nNodesLocal);

    strainElem = zeros(nElemLocal,3);

    for e = 1:nElemLocal
        ids = conn(e,:);
        ids = ids(:).';

        if numel(ids) ~= 3
            error('T3 strain recovery expected 3 nodes per element. Element %d has %d.',e,numel(ids));
        end

        x1 = x(ids(1));  y1 = y(ids(1));
        x2 = x(ids(2));  y2 = y(ids(2));
        x3 = x(ids(3));  y3 = y(ids(3));

        % Signed area. Do not use abs(A) in B; the sign is part of the
        % derivative mapping for the element node order.
        A = 0.5 * det([1 x1 y1; 1 x2 y2; 1 x3 y3]);

        if abs(A) < eps
            strainElem(e,:) = [NaN NaN NaN];
            continue;
        end

        b1 = y2 - y3;
        b2 = y3 - y1;
        b3 = y1 - y2;

        c1 = x3 - x2;
        c2 = x1 - x3;
        c3 = x2 - x1;

        B = 1/(2*A) * [ ...
            b1  0   b2  0   b3  0;
            0   c1  0   c2  0   c3;
            c1  b1  c2  b2  c3  b3 ];

        ue = [ ...
            ux(ids(1)); uy(ids(1));
            ux(ids(2)); uy(ids(2));
            ux(ids(3)); uy(ids(3)) ];

        eps_e = B * ue;
        strainElem(e,:) = eps_e.';
    end

    strainNodal = elementToNodalAverage(conn,strainElem,nNodesLocal);

    out = struct();
    out.results = struct();
    out.results.StrainElem = strainElem;
    out.results.StrainNodal = strainNodal;

    out.results.StrainX  = strainNodal(:,1);
    out.results.StrainY  = strainNodal(:,2);
    out.results.StrainXY = strainNodal(:,3);

    % If called with no input, also update the global GUI model directly.
    if nargin < 1 || isempty(modelIn)
        global model
        model.results.StrainElem = strainElem;
        model.results.StrainNodal = strainNodal;
        model.results.StrainX = strainNodal(:,1);
        model.results.StrainY = strainNodal(:,2);
        model.results.StrainXY = strainNodal(:,3);
    end
end

function validateModelForStrain(modelLocal)
    if ~isfield(modelLocal,'mesh') || isempty(modelLocal.mesh)
        error('No mesh found in model. Generate/load a mesh first.');
    end
    requiredMeshFields = {'connectivity','xcoords','ycoords','elementType'};
    for k = 1:numel(requiredMeshFields)
        f = requiredMeshFields{k};
        if ~isfield(modelLocal.mesh,f) || isempty(modelLocal.mesh.(f))
            error('model.mesh.%s is missing or empty.',f);
        end
    end
    if ~isfield(modelLocal,'results') || ~isfield(modelLocal.results,'Deformation') || isempty(modelLocal.results.Deformation)
        error('No displacement results found. Solve the model before calling func_strain.');
    end
end

function [ux,uy] = readDisplacementVector(q,nNodesLocal)
    % The solver/GUI convention is interleaved DOFs:
    %   [ux1; uy1; ux2; uy2; ...]
    % This helper also accepts an nNodes x 2 displacement array.

    if isequal(size(q),[nNodesLocal 2])
        ux = q(:,1);
        uy = q(:,2);
        return;
    end

    q = q(:);
    if numel(q) ~= 2*nNodesLocal
        error('Displacement vector size mismatch. Expected 2*nNodes values, got %d.',numel(q));
    end

    ux = q(1:2:end);
    uy = q(2:2:end);
end

function nodalVals = elementToNodalAverage(conn,elemVals,nNodesLocal)
    nComp = size(elemVals,2);
    nodalVals = zeros(nNodesLocal,nComp);
    counts = zeros(nNodesLocal,1);

    for e = 1:size(conn,1)
        ids = conn(e,:);
        if any(isnan(elemVals(e,:)))
            continue;
        end
        for a = 1:numel(ids)
            nodeID = ids(a);
            nodalVals(nodeID,:) = nodalVals(nodeID,:) + elemVals(e,:);
            counts(nodeID) = counts(nodeID) + 1;
        end
    end

    counts(counts == 0) = 1;
    nodalVals = nodalVals ./ counts;
end
