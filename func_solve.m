function [qVec,FVec]=func_solve
global model nNodes nElem DMat;

%% Step 2: formulating individual element matrices
syms N1 N2 N3 N4 N5 N6 N7 N8 N9 s t Dx Dy Dr Dz r real;

% Choice of elasticity/stress-strain matrix
[DMat,opMat]=func_elasticity_matrix(model.material.analysisType, ...
    model.material.E, ...
    model.material.nu, ...
    Dx,Dy,Dr,Dz,r);
% Shape functions
[NVec,NstVec]=func_shape_functions(model.mesh.elementType, ...
    N1,N2,N3,N4,N5,N6,N7,N8,N9,s,t);

% Loop through every element
for NN=1:nElem
    % Obtain corresponding node coordinates
    for OO=1:length(model.mesh.connectivity(NN,:))
        temp_nNode=model.mesh.connectivity(NN,OO);
        xcoords(OO,1)=model.mesh.xcoords(temp_nNode);
        ycoords(OO,1)=model.mesh.ycoords(temp_nNode);
    end

    % Store outputs in structure fields
    [model.mesh.JMat{NN}, ...
        model.mesh.BMat{NN}, ...
        model.mesh.GMat{NN}, ...
        model.mesh.meMat{NN}, ...
        model.mesh.keMat{NN}, ...
        model.mesh.ksMat{NN}]= ...
    func_element_matrices( ...
        model.mesh.elementType,DMat,opMat,NVec,NstVec, ...
        xcoords,ycoords, ...
        model.material.density,model.material.thickness, ...
        s,t,Dx,Dy);
end

%% Step 3: assembling into global system
MMat=zeros(2*nNodes);
KMat=zeros(2*nNodes);

for NN=1:nElem
    % Obtain and store corresponding dofs
    temp_nodes=model.mesh.connectivity(NN,:);
    dofs=func_dofs(temp_nodes);
    model.mesh.dofs{NN}=dofs;

    % Populate the corresponding dofs
    MMat(dofs,dofs)=MMat(dofs,dofs)+model.mesh.meMat{NN};
    KMat(dofs,dofs)=KMat(dofs,dofs)+model.mesh.keMat{NN};
end

%% Step 4: applying boundary conditions
%% Locate constraints
dof1Vec=[]; % known primary variables
U1Vec=[];

for II=1:length(model.constraints)
    % Locate affected nodes and obtain affected dofs
    dof1Vec=[dof1Vec,func_dofs(model.constraints(II).affected_nodes)];

    for JJ=1:length(model.constraints(II).affected_nodes)
        % For each node, record whether x or y is fixed
        % (NaN = free, remove later)
        U1Vec=[U1Vec, ...
            model.constraints(II).x_mag, ...
            model.constraints(II).y_mag];
    end
end

% Remove duplicates and free dofs
dof1Vec=dof1Vec(~isnan(U1Vec));
U1Vec=U1Vec(~isnan(U1Vec))';

[dof1Vec,ia,~]=unique(dof1Vec,'stable'); % without sorting
U1Vec=U1Vec(ia);

%% Locate loads
dof2Vec=setdiff([1:2*nNodes],dof1Vec); % known secondary variables
F2Vec=zeros(length(dof2Vec),1);        % set everything as 0 for now (remains 0 if not set)

% Number of nodes in an element, extracted from the string of elementType
nNodes_elem=str2double(model.mesh.elementType(end));
for II=1:length(model.loads)
    if strcmp(model.loads(II).type,'point load')
        % Locate affected nodes and affected dofs
        temp=func_dofs(model.loads(II).affected_nodes);

        % If there is no conflict with a known primary variable, then
        % store the load value
        if any(dof2Vec==temp(1))
            F2Vec(dof2Vec==temp(1))=F2Vec(dof2Vec==temp(1))+model.loads(II).x_mag;
        end
        if any(dof2Vec==temp(2))
            F2Vec(dof2Vec==temp(2))=F2Vec(dof2Vec==temp(2))+model.loads(II).y_mag;
        end
    elseif strcmp(model.loads(II).type,'traction load')
        % Search every element (connectivity set)
        temp_tract.nodes=zeros(nElem,nNodes_elem);
        for JJ=1:nElem
            % Note which nodes of which elements lie on the given edge
            temp_tract.nodes(JJ,:)=ismember(model.mesh.connectivity(JJ,:),model.loads(II).affected_nodes);
        end

        % An element with a threshold number of elements on this edge
        % (depends on type of element has an edge on this boundary) is
        % affected by the traction
        if strcmp(model.mesh.elementType,'T3')||strcmp(model.mesh.elementType,'Q4') % bilinear
            threshold=2;
        elseif strcmp(model.mesh.elementType,'T6')||strcmp(model.mesh.elementType,'Q8')||strcmp(model.mesh.elementType,'Q9') % biquadratic
            threshold=3;
        end
        temp_tract.elem=[1:nElem]';
        temp_tract.elem=temp_tract.elem(sum(temp_tract.nodes,2)>=threshold);
        temp_tract.nodes=temp_tract.nodes(sum(temp_tract.nodes,2)>=threshold,:);

        % To determine equivalent nodal loading for each element on the
        % edge, we need
        % 1. interpolation matrix
        % 2. traction vector
        % 3. Jacobian (along line element)
        for KK=1:length(temp_tract.elem)
            % Determine which natural coordinate is constant on this edge
            [s0,t0]=func_edge_map(model.mesh.elementType,find(temp_tract.nodes(KK,:)),r);

            % Extract general interpolation matrix and modify according to
            % which nodes are on the edge
            G_tract=model.mesh.GMat{temp_tract.elem(KK)};
            for LL=1:nNodes_elem
                temp_dofs=func_dofs(LL);
                % Interpolation function entry multiplied by 1 if on the
                % edge and 0 otherwies
                G_tract(:,temp_dofs)=G_tract(:,temp_dofs)*temp_tract.nodes(KK,LL);
            end

            % The traction vector is based on the input magnitudes
            [traction_length,~]=getEdgeLengths(model,model.loads(II));
            % Divide the input force by the edge's surface area to obtain
            % uniform traction
            w_tract=[model.loads(II).x_mag; ...
                model.loads(II).y_mag]/(traction_length*model.material.thickness);

            % The Jacobian for traction is related to the length of the
            % edge
            % Replace the logical indexing with global node numbers
            temp_tract.nodes(KK,:)=model.mesh.connectivity(temp_tract.elem(KK,1),:).*temp_tract.nodes(KK,:);
            temp_tract.nodes_trunc=temp_tract.nodes(KK,~(temp_tract.nodes(KK,1:min(nNodes_elem,4))==0)); % relevant global node numbers
            temp_tract.coords=[model.mesh.xcoords(temp_tract.nodes_trunc), ...
                model.mesh.ycoords(temp_tract.nodes_trunc)];

            % % Global length of the edge
            % Ll=sqrt((temp_conn.coords(1,1)-temp_conn.coords(2,1))^2+ ...
            %     (temp_conn.coords(1,2)-temp_conn.coords(2,2))^2);
            % % Natural length of the edge
            % Lr=double(int(sqrt(diff(s0,r)^2+diff(t0,r)^2),r,-1,1));
            % J_tract=Ll/Lr;

            % Partial derivative calculations
            dsdr=diff(s0,r);
            dtdr=diff(t0,r);

            % From the element's Jacobian matrix
            dxds=model.mesh.JMat{temp_tract.elem(KK)}(1,1);
            dyds=model.mesh.JMat{temp_tract.elem(KK)}(1,2);
            dxdt=model.mesh.JMat{temp_tract.elem(KK)}(2,1);
            dydt=model.mesh.JMat{temp_tract.elem(KK)}(2,2);

            % Chain rule expansions
            dxdr=dxds*dsdr+dxdt*dtdr;
            dydr=dyds*dsdr+dydt*dtdr;

            % J_tract=int(subs(sqrt(dxdr^2+dydr^2),[s t],[s0 t0]),r,-1,1);
            J_tract=sqrt(dxdr^2+dydr^2);

            % Integration using Gaussian quadrature
            np=3; % probably enough
            [rVec,alphaVec]=func_Gauss_points(np);

            % Set up integrand vector (use r as the generic variable of
            % integration)
            integrand_Fe=subs(G_tract'*w_tract*J_tract,[s t],[s0 t0]);

            % Pre-allocation for elemental forcing vector
            F2Vec_e=zeros(2*nNodes_elem,1);
            for MM=1:np % for each Gauss point
                F2Vec_e=F2Vec_e+alphaVec(MM)* ...
                    model.material.thickness*subs(integrand_Fe,r,rVec(MM));
            end
            F2Vec_e=double(F2Vec_e);

            % If there is no conflict with a known primary variable, then
            % store the load value
            % Extract all dofs associated with the KKth element, in the
            % same order as F2Vec_e
            temp=func_dofs(model.mesh.connectivity(temp_tract.elem(KK,1),:));
            % Fill in F2Vec accordingly
            for NN=1:2*nNodes_elem
                if any(dof2Vec==temp(NN))
                    F2Vec(dof2Vec==temp(NN))=F2Vec(dof2Vec==temp(NN))+F2Vec_e(temp==temp(NN));
                end
            end
        end
    end
end

% Partitioning submatrices for condensed equations
K11Mat=KMat(dof1Vec,dof1Vec);
K12Mat=KMat(dof1Vec,dof2Vec);
K21Mat=KMat(dof2Vec,dof1Vec);
K22Mat=KMat(dof2Vec,dof2Vec);

%% Step 5: solving for unknown variables
% Row 2
U2Vec=K22Mat\(F2Vec-K21Mat*U1Vec);
% Row 1
F1Vec=K11Mat*U1Vec+K12Mat*U2Vec;

% Primary variables
qVec=zeros(2*nNodes,1);
qVec(dof1Vec)=U1Vec;
qVec(dof2Vec)=U2Vec;

% Secondary variables
FVec=zeros(2*nNodes,1);
FVec(dof1Vec)=F1Vec;
FVec(dof2Vec)=F2Vec;

%% Step 6: post-processing - mostly new function

end