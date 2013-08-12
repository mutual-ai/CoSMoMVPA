function results_map = cosmo_searchlight(dataset, measure, varargin)
%  Generic searchlight function returns a map of results computed at each
%  searchlight location 
%   
%   results_map=cosmo_searchlight(dataset, measure, [args, radius])
%
%   Inputs
%       dataset: an instance of a cosmo_fmri_dataset
%       measure: a function handle to a dataset measure. A dataset measure has
%               the function signature: output = measure(dataset, args)
%       args:   a struct that contains all the fields necessary to the dataset
%               measure. args get passed directly to the dataset measure.
%
%   Returns
%       results_map:    an instance of a cosmo_fmri_dataset where the samples
%                       contain the results of the searchlight analysis.
% 
%   Example: Using the searchlight to compute a full-brain nearest neighbor
%               classification searchlight with n-fold cross validation:
%
%       ds = cosmo_fmri_dataset('data.nii.gz','mask','brain_mask.nii.gz', ...
%                                'targets',targets,'chunks',chunks);
%       cv = @cosmo_cross_validate;
%       cv_args = struct();
%       cv_args.classifier = @cosmo_classify_nn;
%       cv_args.partitions = cosmo_nfold_partitioner(ds.sa.chunks);
%       results = cosmo_searchlight(ds,cv,cv_args);     
%       
%       
% ACC Aug 2013, modified from run_voxel_selection_searchlight by NN0

    parser = inputParser;
    addOptional(parser,'radius',3);
    addOptional(parser,'args',struct());
    parse(parser,varargin{:});
    p = parser.Results;
    radius = p.radius;
    args = p.args;

    
    % 
    nfeatures=size(dataset.samples,2);
    center_ids=1:nfeatures; % for now, consider all voxels

    % use voxel selection function
    center2neighbors=cosmo_spherical_voxel_selection(dataset, radius, center_ids);

    % space for output, we will leave res empty for now because we can't know
    % yet the size of the array returned by our dtaset measure.
    ncenters=numel(center_ids);
    res=[];

    % go over all features, run cross-validation and store the classiifcation
    % accuracies.
    % >>
    for k=1:ncenters
        center_id=center_ids(k);
        sphere_feature_ids=center2neighbors{center_id};
        
        sphere_ds=cosmo_dataset_slice_features(dataset, sphere_feature_ids);
        
        % Call the dataset measure
        m = measure(sphere_ds, args);
        
        % Since a dataset measure may return an array of any length, we can
        % check the measures length on the first iteration and allocated the
        % appropriate amount of space for the results.
        if isempty(res) 
            [x,y] = size(m);
            if y>1 error('Dataset measure must return N x 1 array'); end
            res = zeros(x,ncenters);
        end

        % Store the results
        res(:,k)=m;
        
        % show progress every 1000 steps
        if k==1 || mod(k,1000)==0 || k==nfeatures
            fprintf('%d / %d features completed\n', k, nfeatures);
        end
    end
    % <<

    % store the output
    results_map=dataset;
    results_map.samples=res;

