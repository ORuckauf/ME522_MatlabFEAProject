function varargout = pdist2M(X,Y,varargin)
%PDIST2 Pairwise distance between two sets of observations.
%   D = PDIST2(X,Y) returns a matrix D containing the Euclidean distances
%   between each pair of observations in the MX-by-N data matrix X and
%   MY-by-N data matrix Y. Rows of X and Y correspond to observations,
%   and columns correspond to variables. D is an MX-by-MY matrix, with the
%   (I,J) entry equal to distance between observation I in X and
%   observation J in Y.
%
%   D = PDIST2(X,Y,DISTANCE) computes D using DISTANCE.  Choices are:
%
%       'euclidean'        - Euclidean distance (default)
%       'squaredeuclidean' - Squared Euclidean distance
%       'seuclidean'       - Standardized Euclidean distance. Each
%                            coordinate difference between rows in X and Y
%                            is scaled by dividing by the corresponding
%                            element of the standard deviation computed
%                            from X, S=NANSTD(X). To specify another value
%                            for S, use
%                            D = PDIST2(X,Y,'seuclidean',S).
%       'fasteuclidean'    - Euclidean distance computed by using an
%                            alternative algorithm that saves time. This
%                            faster algorithm can, in some cases, reduce
%                            accuracy.
%       'fastsquaredeuclidean'
%                          - Squared Euclidean distance computed by using an
%                            alternative algorithm that saves time. This
%                            faster algorithm can, in some cases, reduce
%                            accuracy.
%       'fastseuclidean'   - Standardized Euclidean distance computed by using
%                            an alternative algorithm that saves time. This
%                            faster algorithm can, in some cases, reduce
%                            accuracy.
%       'cityblock'        - City Block distance
%       'minkowski'        - Minkowski distance. The default exponent is 2.
%                            To specify a different exponent, use
%                            D = PDIST2(X,Y,'minkowski',P), where the
%                            exponent P is a scalar positive value.
%       'chebychev'        - Chebychev distance (maximum coordinate
%                            difference)
%       'mahalanobis'      - Mahalanobis distance, using the sample
%                            covariance of X as computed by NANCOV.  To
%                            compute the distance with a different
%                            covariance, use
%                            D = PDIST2(X,Y,'mahalanobis',C), where the
%                            matrix C is symmetric and positive definite.
%       'cosine'           - One minus the cosine of the included angle
%                            between observations (treated as vectors)
%       'correlation'      - One minus the sample linear correlation
%                            between observations (treated as sequences of
%                            values).
%       'spearman'         - One minus the sample Spearman's rank
%                            correlation between observations (treated as
%                            sequences of values)
%       'hamming'          - Hamming distance, percentage of coordinates
%                            that differ
%       'jaccard'          - One minus the Jaccard coefficient, the
%                            percentage of nonzero coordinates that differ
%       function           - A distance function specified using @, for
%                            example @DISTFUN
%
%   A distance function must be of the form
%
%         function D2 = DISTFUN(ZI,ZJ),
%
%   taking as arguments a 1-by-N vector ZI containing a single observation
%   from X or Y, an M2-by-N matrix ZJ containing multiple observations from
%   X or Y, and returning an M2-by-1 vector of distances D2, whose Jth
%   element is the distance between the observations ZI and ZJ(J,:).
%
%   For built-in distance metrics, the distance between observation I in X
%   and observation J in Y will be NaN if observation I in X or observation
%   J in Y contains NaNs.
%
%   D = PDIST2(X,Y,DISTANCE,'Smallest',K) returns a K-by-MY matrix D
%   containing the K smallest pairwise distances to observations in X for
%   each observation in Y. PDIST2 sorts the distances in each column of D
%   in ascending order. D = PDIST2(X,Y,DISTANCE, 'Largest',K) returns the K
%   largest pairwise distances sorted in descending order. If K is greater
%   than MX, PDIST2 returns an MX-by-MY distance matrix. For each
%   observation in Y, PDIST2 finds the K smallest or largest distances by
%   computing and comparing the distance values to all the observations in
%   X.
%
%   [D,I] = PDIST2(X,Y,DISTANCE,'Smallest',K) returns a K-by-MY matrix I
%   containing indices of the observations in X corresponding to the K
%   smallest pairwise distances in D. [D,I] = PDIST2(X,Y,DISTANCE,
%   'Largest',K) returns indices corresponding to the K largest pairwise
%   distances.
%
%   D = PDIST2(X,Y,DISTANCE,'CacheSize',CACHESIZE) uses an intermediate  
%   matrix stored in cache to compute D, when 'Distance' is one of 
%   {'fasteuclidean','fastsquaredeuclidean','fastseuclidean'}.
%   'CacheSize' can be a positive scalar or 'maximal'. The default is 1e3.
%   If numeric, 'CacheSize' specifies the cache size in megabytes (MB) to
%   allocate for an intermediate matrix.
%   If 'maximal', pdist2 attempts to allocate enough memory for an entire
%   intermediate matrix whose size is MX-by-MY (MX is the number of rows 
%   of the input data X, and MY is the number of rows of the input data Y).
%   'CacheSize' does not have to be large enough for an entire intermediate
%   matrix, but it must be at least large enough to hold an MX-by-1 vector. 
%   Otherwise, the regular algorithm of computing Euclidean distance will
%   be used instead. If the specified cache size exceeds the available
%   memory, MATLAB issues an out-of-memory error.
%
%   Example:
%      % Compute the ordinary Euclidean distance
%      X = randn(100, 5);
%      Y = randn(25, 5);
%      D = pdist2(X,Y,'euclidean');         % euclidean distance
%
%      % Compute the Euclidean distance with each coordinate difference
%      % scaled by the standard deviation
%      Dstd = pdist2(X,Y,'seuclidean');
%
%      % Use a function handle to compute a distance that weights each
%      % coordinate contribution differently.
%      Wgts = [.1 .3 .3 .2 .1];            % coordinate weights
%      weuc = @(XI,XJ,W)(sqrt((XI - XJ).^2 * W'));
%      Dwgt = pdist2(X,Y, @(Xi,Xj) weuc(Xi,Xj,Wgts));
%
%   See also PDIST, KNNSEARCH, CREATENS, KDTreeSearcher,
%            ExhaustiveSearcher.

%   An example of distance for data with missing elements:
%
%      X = randn(100, 5);     % some random points
%      Y = randn(25, 5);      % some more random points
%      X(unidrnd(prod(size(X)),1,20)) = NaN; % scatter in some NaNs
%      Y(unidrnd(prod(size(Y)),1,5)) = NaN; % scatter in some NaNs
%      D = pdist2(X, Y, @naneucdist);
%
%      function D = naneucdist(XI, YJ) % euclidean distance, ignoring NaNs
%      [m,p] = size(YJ);
%      sqdxy = (XI - YJ) .^ 2;
%      pstar = sum(~isnan(sqdxy),2); % correction for missing coordinates
%      pstar(pstar == 0) = NaN;
%      D = sqrt(nansum(sqdxy,2) .* p ./ pstar);
%
%
%   For a large number of observations, it is sometimes faster to compute
%   the distances by looping over coordinates of the data (though the code
%   is more complicated):
%
%      function D = nanhamdist(XI, YJ) % hamming distance, ignoring NaNs
%      [m,p] = size(YJ);
%      nesum = zeros(m,1);
%      pstar = zeros(m,1);
%      for q = 1:p
%          notnan = ~(isnan((XI(q)) | isnan(YJ(:,q)));
%          nesum = nesum + (XI(q) ~= YJ(:,q)) & notnan;
%          pstar = pstar + notnan;
%      end
%      D = nesum ./ pstar;

%   Copyright 2009-2022 The MathWorks, Inc.

[varargout{1:nargout}] = statslib.internal.pdist2(X,Y,varargin{:});
end