function [quality_elemental, quality_average] = meshQuality(t,p,h0)
% allows you to compute the element quality fo a mesh given t, p, and h0
% sample plotting: 
%     histogram(quality_elemental, 'FaceColor','#54585A')
%     ylabel('\# Elements', Interpreter='latex')
%     xlabel('Element Quality', Interpreter='latex')
%     grid on
%     temp = xlim;
%     set(gca, "TickLabelInterpreter","latex")
%     xlim([temp(1),1.02])
%     temp=ylim;
%     ylim([temp(1),temp(2)+10]) 

quality_elemental = zeros(length(t),1);
radii_elemental = zeros(length(t),1);

for II=1:length(quality_elemental)
    p1 = p(t(II,1),:);
    p2 = p(t(II,2),:);
    p3 = p(t(II,3),:);
    a = dist(p1,p2);
    b = dist(p1,p3);
    c = dist(p2,p3);
    quality_elemental(II) = ((b+c-a)*(c+a-b)*(a+b-c))/(a*b*c);
    s = (a+b+c)/2; % semi-perimeter
    A = sqrt(s*(s-a)*(s-b)*(s-c)); % Heron's formula 
    radii_elemental(II) = a*b*c/(4*A); % circumradius 
end

quality_average = std(radii_elemental/h0)/mean(radii_elemental/h0);


function d = dist(p1,p2)
    d = sqrt((p1(1)-p2(1))^2 + (p1(2)-p2(2))^2);
end
end