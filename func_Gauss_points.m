function [rVec,alphaVec] = func_Gauss_points(n)

% n        [scalar] positive integer number of sampling points
% rVec     [vector] an ordered (ascending) list of sampling points
% alphaVec [vector] a corresponding ordered list of weights

% Methodology from and verified with Bathe (2014) Section 5.5.3

syms r real;
rVec=symmatrix2sym(symmatrix('r',[n,1]));

% Polynomial with roots at each sampling point
P_func=prod(r-rVec);

% Integral of (P_func) multiplied with ((i-1)th power of r) = (0)
eqnsVec=int(P_func*r.^([1:n]'-1),r,-1,1)==0;

% Solve the system of n simultaneous equations
solns=solve(eqnsVec,rVec);

% Take the first solution given, if n>1
if n>1
    fields=fieldnames(solns);
    for FF=1:length(fields)
        rVec(FF)=solns.(fields{FF})(1);
    end
else % n=1
    rVec(1)=solns;
end

% Sort sampling points in ascending order
rVec=double(sort(rVec));

% Lagrangian interpolation
l_func=sym(zeros(n,1));
if n>1
    for NN=1:n
        % Numerator:   product of differences between r     and r(j), j~=NN
        % Denominator: product of differences between r(NN) and r(j), j~=NN
        l_func(NN)=prod(r-rVec([1:NN-1,NN+1:end]))/ ...
            prod(rVec(NN)-rVec([1:NN-1,NN+1:end]));
    end
else % n=1
    l_func=1;
end

% Integrate to obtain weights
alphaVec=double(int(l_func,r,-1,1));

end