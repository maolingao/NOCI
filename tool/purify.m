function [S,Y,Delta,GInv] = purify(s,y,delta,Ginv,MEMLIM)
% eliminate the component in new tuple [s,y,delta] which are
% already contained in previous spanned Krylov subspace.
% 
%
if nargin < 5
    MEMLIM = 10;
end
%     keyboard
if MEMLIM > size(s,2)
    S = s;
    Y = y;
    Delta = delta;
    GInv = Ginv;
else
    epsl = 1e-10;
    SIGMA = 'LM';
    % [U,D] = eigs(Ginv,(MEMLIM),SIGMA);
    G = s'*y;
    [U,D] = eigs(G,(MEMLIM),SIGMA);
    % keyboard
    U = real(U(:,1:MEMLIM));
    D = real(D(1:MEMLIM,1:MEMLIM));
    %
    % U = bsxfun(@rdivide, U, max(abs(U)));
    % keyboard
    figure(3), imagesc(real(log10(U'*U))), colormap gray, axis image, colorbar('southoutside')
    S = s*U;
    Y = y*U;
    Delta = delta * U;
    % M = S'*Y;
    % GInv = ( M'*M + epsl)\eye(size(S,2)) * M';
    % keyboard
    GInv = diag((diag(D) + eps).\1);
end
end
%
% unittest
%{
n = 80;
u = rand(n,1);
Q = RandomRotation(n); 
D = diag(u);
A = Q*D*Q';         % symmetric pos def matrix with eigenvalue btw [0,1]
[V,D] = eig(A);     % V eigenvector, mutally orthonormal
%
s = bsxfun(@times,V(:,1:30),rand(1,30));
G = s'*s;           % symmetric diagnal matrix 
Ginv = G\eye(size(G));
delta = zeros(size(s));
[S,Y,Delta,GInv] = purify(s,s,delta,Ginv);
%
%}