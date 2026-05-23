clc
close all
clearvars

%% Step 1: pre-processing
% Testing an example mesh - HW26 from ME422
type='plane stress';
name='Q9';
E=70e9;
nu=0.3;
rho=2700;
h=0.01;

model.constraints(1).type='constraint';
model.constraints(1).x_mag=0;
model.constraints(1).y_mag=NaN;
model.constraints(1).affected_nodes=1;

model.constraints(2).type='constraint';
model.constraints(2).x_mag=NaN;
model.constraints(2).y_mag=1;
model.constraints(2).affected_nodes=5;

model.loads(1).type='traction load';
model.loads(1).x_mag=10;
model.loads(1).y_mag=4;
model.loads(1).affected_nodes=[31 32 33 34 35 36 37 38 39 40 41];
model.loads(1).point=[0.15 0];
model.loads(1).regionType='Edge';
model.loads(1).regionID=4;

model.mesh.connectivity{1}=[1 31 32];
model.mesh.connectivity{2}=[40 41 10];
model.mesh.connectivity{3}=[41 42 11];
model.mesh.connectivity{4}=[32 33 2];
model.mesh.connectivity{5}=[33 34 3];
model.mesh.connectivity{6}=[34 35 4];
model.mesh.connectivity{7}=[35 36 5];
model.mesh.connectivity{8}=[36 37 6];
model.mesh.connectivity{9}=[37 38 7];
model.mesh.connectivity{10}=[38 39 8];
model.mesh.connectivity{11}=[39 40 9

% model.mesh.GMat{1}=cell(1,1);
% 
% model.mesh.GMat{1}=[1 2 3 4 5 6;7 8 9 10 11 12];
% model.mesh.GMat{2}=[1 2 3 4 5 6;7 8 9 10 11 12];
% model.mesh.GMat{3}=[1 2 3 4 5 6;7 8 9 10 11 12];

model.mesh.elementType='T3';

%% Step 4: applying boundary conditions
nNodes=6;

dof1Vec=[]; % known primary variables
U1Vec=[];

% Locate constraints
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
[dof1Vec,ia,~]=unique(dof1Vec,'stable'); % without sorting
U1Vec=U1Vec(ia);
dof1Vec=dof1Vec(~isnan(U1Vec))
U1Vec=U1Vec(~isnan(U1Vec))'

%% Locate loads
dof2Vec=setdiff([1:2*nNodes],dof1Vec) % known secondary variables
F2Vec=zeros(length(dof2Vec),1);       % set everything as 0 for now (remains 0 if not set)

nNodes_elem=str2double(model.mesh.elementType(end));
for II=1:length(model.loads)
    if strcmp(model.loads(II).type,'point load')
        % Locate affected nodes and affected dofs
        temp_dofs=func_dofs(model.loads(II).affected_nodes);

        % If there is no conflict with a known primary variable, then
        % store the load value
        if any(dof2Vec==temp_dofs(1))
            F2Vec(dof2Vec==temp_dofs(1))=F2Vec(dof2Vec==temp_dofs(1))+model.loads(II).x_mag;
        end
        if any(dof2Vec==temp_dofs(2))
            F2Vec(dof2Vec==temp_dofs(2))=F2Vec(dof2Vec==temp_dofs(2))+model.loads(II).y_mag;
        end
    elseif strcmp(model.loads(II).type,'traction load')
        % Search every element (connectivity set)
        temp_conn.nodes=zeros(length(model.mesh.connectivity),nNodes_elem);
        for JJ=1:length(model.mesh.connectivity)
            % Note which nodes of which elements lie on the given edge
            temp_conn.nodes(JJ,:)=ismember(model.mesh.connectivity{JJ},model.loads(II).affected_nodes);
        end

        % An element with a threshold number of elements on this edge
        % (depends on type of element has an edge on this boundary) is
        % affected by the traction
        if strcmp(model.mesh.elementType,'T3')||strcmp(model.mesh.elementType,'Q4') % bilinear
            threshold=2;
        elseif strcmp(model.mesh.elementType,'T6')||strcmp(model.mesh.elementType,'Q8')||strcmp(model.mesh.elementType,'Q9') % biquadratic
            threshold=3;
        end
        temp_conn.elem=[1:length(model.mesh.connectivity)]';
        temp_conn.elem=temp_conn.elem(sum(temp_conn.nodes,2)>=threshold)
        temp_conn.nodes=temp_conn.nodes(sum(temp_conn.nodes,2)>=threshold,:)

        % To determine equivalent nodal loading for each element, determine
        % 1. interpolation matrix
        % 2. traction vector
        % 3. Jacobian (along line element)
        for KK=1:1%length(temp_conn.elem)
            % Extract general interpolation matrix and modify according to
            % which nodes are on the edge
            GMat=model.mesh.GMat{temp_conn.elem(KK)};
            for LL=1:nNodes_elem
                temp_dofs=func_dofs(LL);
                GMat(:,temp_dofs)=GMat(:,temp_dofs)*temp_conn.elem(LL)
            end
            % G_tract

            % w_tract
            % J_tract
        end

        % Jacobian (along line element) for traction
        % J_tract=sqrt()

        % Local elemental loading vector
        % F2Vec_e=

        % for KK=1:length(edge_elem)
        %     % For each element that is on the edge, determine which nodes
        %     % lie along the edge...
        %     temp_nodes_elem=model.mesh.connectivity{KK}
        % 
        %     temp_nodes_edge=[];
        %     for LL=1:length(temp_nodes_elem)
        %         if find(model.loads(II).affected_nodes==temp_nodes_elem(LL))
        %             temp_nodes_edge=[temp_nodes_edge;LL]
        %         end
        %     end
        % 
        %     % ...and which edge on the natural coordinate system lies along
        %     % the edge
        % 
        %     fprintf('do stuff\n');
        % end
    end
end

% F2Vec