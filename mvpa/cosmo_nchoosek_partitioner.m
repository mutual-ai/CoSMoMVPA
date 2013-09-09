function partitions = cosmo_nchoosek_partitioner(chunks, k)
% generates an choose(n,k), or a split-half, partition scheme.
%
% partitions=cosmo_nfold_partitioner(chunks, k)
%
% Input
%  - chunks          Px1 chunk indices for P samples. It can also be a
%                    dataset with field .sa.chunks
%  - k               When an integer, k chunks are in each test partition.
%                    When between 0 and 1, this is interpreted as
%                    round(k*nchunks) where nchunks is the number of unique
%                    chunks in chunks. 
%                    A special case, mostly aimed at split-half 
%                    correlations, is when k=='half'; this sets k to .5,
%                    and if k is even, it treats train_indices and 
%                    test_indices as symmetrical, meaning it returns only 
%                    half the number of partitions (avoiding duplicates).
%
% Output:
%  - partitions      A struct with fields .train_indices and .test_indices.
%                    Each of these is an 1xQ cell for Q partitions, where 
%                    Q=nchoosek(nchunks,k)). 
%                    .train_indices{k} and .test_indices{k} contain the
%                    sample indices for the k-th fold.
%
% Notes:
%  - when k=1 this is equivalent to cosmo_nfold_partitioner
%
% Examples:
%   cosmo_nchoosek_partitioner([1 2 1 2 2],.5)
%     >  train_indices: {[2 4 5]  [1 3]}
%     >  test_indices: {[1 3]  [2 4 5]}
%   cosmo_nchoosek_partitioner(1:4,.5)
%     >     train_indices: {[3 4]  [2 4]  [2 3]  [1 4]  [1 3]  [1 2]}
%     >     test_indices: {[1 2]  [1 3]  [1 4]  [2 3]  [2 4]  [3 4]}
%   cosmo_nchoosek_partitioner(1:4,'half')
%     >     train_indices: {[3 4]  [2 4]  [2 3]}
%     >     test_indices: {[1 2]  [1 3]  [1 4]}
% 
% See also cosmo_nfold_partitioner
%
% NNO Sep 2013

if isstruct(chunks)
    if isfield(chunks,'sa') && isfield(chunks.sa,'chunks')
        chunks=chunks.sa.chunks;
    else
        error('illegal input')
    end
end

% little optimization: if just two chunks, the split is easy
if all(sum(bsxfun(@eq,chunks(:),1:2),2))
    partitions=cosmo_oddeven_partitioner(chunks);
    return
end
    

[unq,foo,chunk_indices]=unique(chunks);
nclasses=numel(unq);

is_symmetric=false;
if ischar(k)
    if strcmp(k,'half')
        k=.5;
        is_symmetric=true;
    else
        error('illegal string k')
    end
end

if k ~= round(k)
    k=round(nclasses*k);
end

if ~any(k==1:(nclasses-1))
    error('illegal k: %d', k);
end

npartitions=nchoosek(nclasses,k);
combis=nchoosek(1:nclasses,k);

if is_symmetric && mod(nclasses,2)==0
    % when nclasses is even, return the first half of the permutations:
    % the current implementation of nchoosek results is that
    % combis(k,:) and combis(npartitions+1-k) are complementary
    % (i.e. together they make up 1:nchunks). In principle this could
    % change in the future leading to wrong results, so to be sure we check 
    % that the output matches what is expected.
    % The rationale is that this reduces computation time of subsequent
    % analyses by half, in particular for the widely-used split half
    % correlations.
    nhalf=npartitions/2;
    
    check_combis=[combis(1:nhalf,:) combis(npartitions:-1:(nhalf+1),:)];
    
    % each row, when sorted, should be 1:nchunks
    matches=bsxfun(@eq,sort(check_combis,2),1:nclasses);
    if ~all(matches(:))
        error('Unexpected result from nchoosek');
    end
    
    % we're good - just take the first half
    combis=combis(1:nhalf,:);
    npartitions=nhalf;
end

% allocate space for output
train_indices=cell(1,npartitions);
test_indices=cell(1,npartitions);

% fancy helper function. Given a list of class indices in the range 
% 1:nclasses, it returns indices where the class indices match chunks.
chunk_idx2mask=@(idx) sum(bsxfun(@eq,idx',chunk_indices'),1);

for j=1:npartitions
    combi=combis(j,:);
    sample_mask=chunk_idx2mask(combi);
    test_indices{j}=find(sample_mask);
    train_indices{j}=find(~sample_mask);
end

partitions=struct();
partitions.train_indices=train_indices;
partitions.test_indices=test_indices;
    