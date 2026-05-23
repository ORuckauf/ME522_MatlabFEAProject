function out = func_stress(modelIn)
%FUNC_STRESS External stress 
%
%   out = FUNC_STRESS(model)
%   out = FUNC_STRESS()              % uses global model
%
%   Computes stress from strain using the plane stress / plane strain
%   constitutive matrices:
%
%       sigma = D * epsilon
%
%   Output fields compatible with the GUI:
%
%       out.results.StressElem   = nElem  x 3  [sigma_xx, sigma_yy, tau_xy]
%       out.results.StressNodal  = nNodes x 3  [sigma_xx, sigma_yy, tau_xy]
%
%   This function calls func_strain.m first if strain is not already present.

    if nargin < 1 || isempty(modelIn)
        global model
        modelLocal = model;
        calledWithGlobal = true;
    else
        modelLocal = modelIn;
        calledWithGlobal = false;
    end

    validateModelForStress(modelLocal);

    % Ensure element strain exists
    % but use it here because stress depends on strain.
    if ~isfield(modelLocal.results,'StrainElem') || isempty(modelLocal.results.StrainElem)
        strainOut = func_strain(modelLocal);
        modelLocal.results.StrainElem = strainOut.results.StrainElem;
        modelLocal.results.StrainNodal = strainOut.results.StrainNodal;
        modelLocal.results.StrainX = strainOut.results.StrainX;
        modelLocal.results.StrainY = strainOut.results.StrainY;
        modelLocal.results.StrainXY = strainOut.results.StrainXY;
    end

    E = modelLocal.material.E;
    nu = modelLocal.material.nu;
    analysisType = lower(strtrim(modelLocal.material.analysisType));

    D = elasticityMatrix2D(E,nu,analysisType);

    strainElem = modelLocal.results.StrainElem;
    stressElem = (D * strainElem.').';

    conn = modelLocal.mesh.connectivity;
    nNodesLocal = numel(modelLocal.mesh.xcoords);
    stressNodal = elementToNodalAverage(conn,stressElem,nNodesLocal);

    out = struct();
    out.results = struct();

    % Return stress.
    out.results.StressElem = stressElem;
    out.results.StressNodal = stressNodal;
    out.results.StressX = stressNodal(:,1);
    out.results.StressY = stressNodal(:,2);
    out.results.StressXY = stressNodal(:,3);

    out.results.StrainElem = modelLocal.results.StrainElem;
    out.results.StrainNodal = modelLocal.results.StrainNodal;
    out.results.StrainX = modelLocal.results.StrainNodal(:,1);
    out.results.StrainY = modelLocal.results.StrainNodal(:,2);
    out.results.StrainXY = modelLocal.results.StrainNodal(:,3);

    if calledWithGlobal
        global model
        f = fieldnames(out.results);
        for k = 1:numel(f)
            model.results.(f{k}) = out.results.(f{k});
        end
    end
end

function validateModelForStress(modelLocal)
    if ~isfield(modelLocal,'mesh') || isempty(modelLocal.mesh)
        error('No mesh found in model. Generate/load a mesh first.');
    end
    if ~isfield(modelLocal,'material') || isempty(modelLocal.material)
        error('No material data found in model.');
    end
    if ~isfield(modelLocal.material,'E') || isempty(modelLocal.material.E)
        error('model.material.E is missing.');
    end
    if ~isfield(modelLocal.material,'nu') || isempty(modelLocal.material.nu)
        error('model.material.nu is missing.');
    end
    if ~isfield(modelLocal.material,'analysisType') || isempty(modelLocal.material.analysisType)
        error('model.material.analysisType is missing.');
    end
end

function D = elasticityMatrix2D(E,nu,analysisType)
    if contains(analysisType,'plane stress')
        % Plane stress, from sigma = D * epsilon:
        % D = E/(1-nu^2) * [1 nu 0; nu 1 0; 0 0 (1-nu)/2]
        D = E/(1-nu^2) * [ ...
            1   nu  0;
            nu  1   0;
            0   0   (1-nu)/2 ];

    elseif contains(analysisType,'plane strain')
        % Plane strain:
        % D = E(1-nu)/((1+nu)(1-2nu)) *
        %     [1, nu/(1-nu), 0;
        %      nu/(1-nu), 1, 0;
        %      0, 0, (1-2nu)/(2(1-nu))]
        D = E*(1-nu)/((1+nu)*(1-2*nu)) * [ ...
            1           nu/(1-nu)                  0;
            nu/(1-nu)   1                          0;
            0           0           (1-2*nu)/(2*(1-nu)) ];

    else
        error('func_stress currently supports Plane Stress and Plane Strain only. Current analysis type: %s',analysisType);
    end
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
