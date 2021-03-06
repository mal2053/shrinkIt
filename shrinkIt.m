function [X_shrink lambda] = shrinkIt(X1_grp, X2_grp, Xodd_grp, Xeven_grp)
%
% This function performs shrinkage towards the group mean of subject-level 
% observations of any summary statistic computed from time series data.
% For example, consider an fMRI time series for each subject stored as a
% TxV array, and the VxV sample correlation matrix as the summary statistic
% we wish to shrink.  
%
% The correlation matrix is one type of similarity matrix, but shrinkage
% can be applied to any population of similarity or distance matrices as a
% preprocessing step before applying a clustering algorithm.
%
% Shrinkage computes a weighted average between subject-level estimates and
% the group mean.  Lambda represents the degree of shrinkage (weighting of 
% the group mean), which ranges from 0 (subject-level estimates perfectly 
% reliable, so no shrinkage) to 1 (no reliable subject-level information, 
% so complete shrinkage to the group mean).  Lambda is optimized as the ratio of 
% within-subject (noise) variance to total variance, which is the sum of
% within-subject variance and between-subject (signal) variance.
%
% This function estimates the variance components to determine the optimal
% degree of shrinkage for each estimated parameter.  Therefore lambda has
% the same dimensions as each subject's array of estimated parameters.  
%
% The inputs X1, X2, Xodd and Xeven can be computed with the split_ts function.
% X1, X2, Xodd and Xeven all have the same dimensions, (p1, p2, ..., pk,
% n).  Each subject 1,...,n has an array of parameters we want to estimate, 
% of dimension (p1, p2, ..., pk).
%
%Usage:
%   [X_shrink lambda] = shrinkIt(X1, X2, Xeven, Xodd)
%Inputs:
%   X1 - An array of dimensions (p1, p2, ..., pk, n) containing parameter
%       estimates for each subject computed using the first half of the 
%       time series for each subject (see split_ts.m and Example.m)
%
%   X2 - An array of dimensions (p1, p2, ..., pk, n) containing parameter
%       estimates for each subject computed using the second half of the 
%       time series for each subject (see split_ts.m and Example.m)
%
%   Xodd - An array of dimensions (p1, p2, ..., pk, n) containing parameter
%       estimates for each subject computed using the odd blocks of the 
%       time series for each subject (see split_ts.m and Example.m)
%
%   Xeven - An array of dimensions (p1, p2, ..., pk, n) containing parameter
%       estimates for each subject computed using the even blocks of the 
%       time series for each subject (see split_ts.m and Example.m)
%
%
%Outputs:
%   X_shrink - array of dimensions (p1, p2, ..., pk, n) containing the
%              shrinkage estimates of each parameter for each subject
%   lambda - array of dimensions (p1, p2, ..., pk) containing the degree
%            of shrinkage for each estimated parameter

%% Perform Checks

if(nargin ~= 4)
    error('Must specify four inputs')
end

if isempty(X1_grp) || isempty(X2_grp) || isempty(Xodd_grp) || isempty(Xeven_grp)
    error('one or more inputs is empty')
end

dims = size(X1_grp); %Returns the dimensions m by n of the observation matrix
if ~isequal(dims, size(X1_grp), size(Xodd_grp), size(Xeven_grp))
    error('dimensions of all inputs do not match')
end      

if ~isnumeric(X1_grp) || ~isnumeric(X2_grp) || ~isnumeric(Xodd_grp) || ~isnumeric(Xeven_grp)
    error('all inputs must be numeric arrays')
end

if size(X1_grp, ndims(X1_grp)) == 1 || max(dims) == 1
    error('last dimension of inputs must equal number of subjects > 1')
end

%% SET-UP

%compute array of estimates for each subject
X_grp = (X1_grp + X2_grp)/2; %subject-level estimates

%last dimension of arrays (indexes subjects)
nd = ndims(X_grp);

%number of subjects
n = size(X_grp,nd);

%% COMPUTE SAMPLING VARIANCE USING Xodd and Xeven

D = Xodd_grp - Xeven_grp; %compute even-odd differences
varU = (1/4)*var(D, 0, nd); %within-subject noise variance

%% COMPUTE PSUEDO-SCAN-RESCAN VARIANCE USING X1 and X2

D = X2_grp - X1_grp; %compute psuedo scan-rescan differences
varSR = var(D, 0, nd); %consists of within-subject signal and noise variance
varW = (1/2)*(varSR - 4*varU); %within-subject signal variance

%% COMPUTE TOTAL WITHIN-SUBJECT VARIANCE

var_within = varW + varU;
var_within(var_within < 0) = 0;

%% COMPUTE TOTAL VARIANCE

varTOT = var(X_grp, 0, nd);

%% COMPUTE LAMBDA (DEGREE OF SHRINKAGE)

lambda = var_within./varTOT;
lambda(lambda > 1) = 1; %occurs when within-subject var > between-subject variance of estimates 
lambda(lambda < 0) = 0;
lambda(varTOT==0) = 0; %for parameters with no variance, e.g. diagonal of correlation matrix 

%% PERFORM SHRINKAGE

%compute mean across subjects
X_bar = mean(X_grp, nd);

%make X_bar and lambda of same size as input arrays
X_bar = reshape(repmat(X_bar, 1, n), size(X1_grp));
lambda2 = reshape(repmat(lambda, 1, n), size(X1_grp));

%compute shrinkage estimates
X_shrink = (lambda2.*(X_bar))+((1-lambda2).*X_grp); 


