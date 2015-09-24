function test_suite = test_chunkize
    initTestSuite;


function test_chunkize_basis
    ds=cosmo_synthetic_dataset('type','timelock','nreps',8);
    ds.sa.chunks=reshape(repmat((1:8),6,1),[],1);
    ds=cosmo_slice(ds,randperm(48));

    chunks=cosmo_chunkize(ds,8);
    assertEqual(chunks,ds.sa.chunks);

    for j=1:2:7
        chunks=cosmo_chunkize(ds,j);
        eq_chunks=bsxfun(@eq,chunks,chunks');
        eq_ds=bsxfun(@eq,ds.sa.chunks,ds.sa.chunks');

        m=eq_ds & ~eq_chunks;
        assert(~any(m(:)));
    end

    assertExceptionThrown(@()cosmo_chunkize(ds,9),'');
    ds=rmfield(ds.sa,'chunks');
    assertExceptionThrown(@()cosmo_chunkize(ds,2),'');


function test_chunkize_imbalance()
    ds=struct();
    ds.samples=(1:5)';
    assertExceptionThrown(@()cosmo_chunkize(ds,2),'');
    ds.sa.chunks=2+[1 1 2 2 2]';
    assertExceptionThrown(@()cosmo_chunkize(ds,2),'');
    ds.sa.targets=10+[1 2 1 2 2]';
    assertExceptionThrown(@()cosmo_chunkize(ds,3),'');

    count=2;
    res=cosmo_chunkize(ds,count);
    assert_chunkize_ok(ds,res,count);

    ds2=cosmo_stack({ds,ds});
    res2=cosmo_chunkize(ds2,count);
    assert_chunkize_ok(ds2,res2,count);



function test_all_unique_chunks_tiny()
    ds=struct();
    ds.samples=(1:5)';
    ds.sa.targets=2+[1 1 2 2 2]';
    ds.sa.chunks=10+[1 2 3 4 5]';

    for count=2:5
        res=cosmo_chunkize(ds,count);
        assert_chunkize_ok(ds,res,count);
    end

    assertExceptionThrown(@()cosmo_chunkize(ds,6),'');


function test_all_unique_chunks_big()
    % all chunks are unique, want a similar number of targets in each
    % output chunk
    ds=cosmo_synthetic_dataset('nreps',6,'ntargets',5);

    nsamples=size(ds.samples,1);
    ds.sa.chunks(:)=repmat((1:nsamples/2),1,2);
    ds.sa.targets(1:5)=ds.sa.targets(2:6); % slight imbalance

    nchunks=ceil(rand()*10);
    res=cosmo_chunkize(ds,nchunks);
    assert_chunkize_ok(ds,res,nchunks);


function test_all_unique_chunks_fully_balanceble()
    ds=cosmo_synthetic_dataset('ntargets',2,'nchunks',6*6);
    nsamples=size(ds.samples,1);
    ds.sa.chunks(:)=ceil(rand()*10)+(1:nsamples);
    ds.sa.targets=ds.sa.targets(randperm(nsamples));

    nchunks_candidates=[1 2 3 4 6 12 18];
    idx=ceil(rand()*numel(nchunks_candidates));
    nchunks=nchunks_candidates(idx);

    chunks=cosmo_chunkize(ds,nchunks);
    assert_chunkize_ok(ds,chunks,nchunks);

    idxs=cosmo_index_unique([ds.sa.targets chunks]);
    n=cellfun(@numel,idxs);

    % require full balance
    assert(all(n(1)==n(2:end)));


function assert_chunkize_ok(src_ds,chunks,count)
    if nargin<3
        count=numel(unique(src_ds.sa.chunks));
    end

    % number of items must match input dataset
    assertEqual(numel(src_ds.sa.chunks),numel(chunks));

    % must be balanced
    assert_chunks_targets_balanced(src_ds,chunks);

    % cannot have double dipping
    assert_no_double_dipping(src_ds,chunks);

    % must have the proper number of chunks
    assertEqual(numel(unique(chunks)),count);

    assert_chunks_targets_nonzero(src_ds,chunks);


function assert_chunks_targets_balanced(src_ds,chunks)
    idxs=cosmo_index_unique([src_ds.sa.targets chunks]);

    n=cellfun(@numel,idxs);

    % cannot test for 'optimal' balance due to combinatorial explosion;
    % this is a decent approach to make sure that chunks are not too
    % imbalanced
    assert(std(n)<=1);
    assert(min(n)+2>=max(n));


function assert_chunks_targets_nonzero(src_ds,chunks)
    [unused,unused,t_idxs]=unique(src_ds.sa.targets);
    [unused,unused,c_idxs]=unique(chunks);

    nt=max(t_idxs);
    nc=max(c_idxs);
    h=zeros(nt,nc);

    ns=numel(chunks);
    for k=1:ns
        t=t_idxs(k);
        c=c_idxs(k);
        h(t,c)=h(t,c)+1;
    end

    assert(all(max(h,[],1)>0));
    assert(all(max(h,[],2)>0));



function assert_no_double_dipping(src_ds,chunks)
    % samples that were in different chunks in src_ds must not be in the
    % same chunk in trg_ds
    [unq_src,unused,src_ids]=unique(src_ds.sa.chunks);
    [unq_trg,unused,trg_ids]=unique(chunks);

    n_src=numel(unq_src);
    n_trg=numel(unq_trg);
    n_samples=numel(src_ds.sa.chunks);
    chunk_count=zeros(n_src,n_trg);

    for k=1:n_samples
        i=src_ids(k);
        j=trg_ids(k);
        chunk_count(i,j)=chunk_count(i,j)+1;
    end

    assert(all(sum(chunk_count>0,2)==1));



