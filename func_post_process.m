function [eng_stress_x, eng_stress_y, eng_stress_xy, eng_strain_x, eng_strain_y, eng_strain_xy] = func_post_process
global model nNodes nElem CMat;
% eng_stress is nNodesx1 and eng_strain is nNodesx1 vector, where it is
% assumed to be a constant at each node across any connected elements

displacements = model.results.qVec;

eng_strain_x = zeros([nElem,1]);
eng_strain_y = zeros([nElem,1]);
eng_strain_xy = zeros([nElem,1]);
eng_stress_x = zeros([nElem,1]);
eng_stress_y = zeros([nElem,1]);
eng_stress_xy = zeros([nElem,1]);

for II = 1:nElem
    B = model.mesh.BMat{II}; % element 1
    elem_nodes = model.mesh.connectivity(II,:);
    elem_dofs = func_dofs(elem_nodes);
    elem_qs = displacements(elem_dofs);
    temp = B*elem_qs;
    eng_strain_x(II) = temp(1); 
    eng_strain_y(II) = temp(2); 
    eng_strain_xy(II) = temp(3);
    
    temp2 =  CMat * temp;
    eng_stress_x(II) = temp2(1); 
    eng_stress_y(II) = temp2(2); 
    eng_stress_xy(II) = temp2(3); 
end

% true_stress = eng_stress*(1+eng_strain);
% true_strain = log(())

end