function [NVec,NstVec] = func_shape_functions(name,N1,N2,N3,N4,N5,N6,N7,N8,N9,s,t)

% name   [string] name of element ('T3','T6','Q4','Q8','Q9')
% NVec   [vector] shape function names
% NstVec [vector] shape functions as functions of coordinates
% rest are symbolic variables

% syms N1 N2 N3 N4 N5 N6 N7 N8 N9 s t real;

if (strcmp(name,'T3')==1)||(strcmp(name,'Q4')==1) % bilinear element
    % Start with Q4
    % Natural coordinate system
    sVec=[-1;1];
    tVec=[-1;1];
    % Polynomial basis
    pVec=[1;s;t;s*t];
    % Number of nodes per element
    n=4;

    HMat=subs(subs(pVec',s,sVec),t,tVec);
    HMat=HMat([4 2 1 3],:); % order by inspection
    HMat_inv=HMat\eye(n);

    % Shape functions
    NVec=[N1;N2;N3;N4];
    NstVec=(pVec'*HMat_inv)';

    if strcmp(name,'T3')==1 % collapse Q4 (3,4)
        % N3=N3+N4;
        NVec=[N1;N2;N3];
        NstVec=[NstVec(1:2);sum(NstVec(3:4))];
    end
else % biquadratic element
    % Start with Q9
    % Natural coordinate system
    sVec=[-1;0;1];
    tVec=[-1;0;1];

    % Polynomial basis
    pVec=[1;s;t;s*t;s^2;t^2;s*t^2;s^2*t;t^2*s^2];

    % Number of nodes per element
    n=9;

    HMat=subs(subs(pVec',s,sVec),t,tVec);
    HMat=HMat([9 3 1 7 6 2 4 8 5],:); % order by inspection
    HMat_inv=HMat\eye(n);

    % Shape functions
    NVec=[N1;N2;N3;N4;N5;N6;N7;N8;N9];
    NstVec=(pVec'*HMat_inv)';

    if (strcmp(name,'Q8')==1)||(strcmp(name,'T6')==1)
        % Polynomial basis is the same as for Q9 except without quartic
        % term
        pVec=[1;s;t;s*t;s^2;t^2;s*t^2;s^2*t];

        % Number of nodes per element (must formulate Q8 before
        % collapsing)
        n=8;

        HMat=subs(subs(pVec',s,sVec),t,tVec); % ignore row 5 [(s,t)=(0,0)]
        HMat=HMat([9 3 1 7 6 2 4 8],:); % order by inspection
        HMat_inv=HMat\eye(n);

        % Shape functions
        NVec=[N1;N2;N3;N4;N5;N6;N7;N8];
        NstVec=(pVec'*HMat_inv)';

        if strcmp(name,'T6')==1 % collapse Q8 (1,2,5)
            % % Rename all nodes (nominally, not in code)
            % N1=N1+N2+N5;
            % N2=N3;
            % N3=N4;
            % N4=N6;
            % N5=N7;
            % N6=N8;

            % 3(->2),4(->3),7(->5) need to be corrected (Bathe)
            Deltah=(1-t^2)*(1-s^2)/8;

            NVec=[N1;N2;N3;N4;N5;N6];
            NstVec=[sum(NstVec([1 2 5]));
                NstVec(3)+Deltah;
                NstVec(4)+Deltah;
                NstVec(6);
                NstVec(7)-2*Deltah;
                NstVec(8)];
        end
    end
end

end