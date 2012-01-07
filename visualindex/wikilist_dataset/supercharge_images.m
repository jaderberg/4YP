% Max Jaderberg 28/12/11

function [super_class_histograms classes_useful_hists] = supercharge_images(class_names, coll, conf, vocab)


    import com.mongodb.BasicDBObject;

    
    useful_histograms = sparse([]);
    useful_ids = {};
    super_class_histograms = sparse([]);
    
    classes_useful_hists = {};
     
%      create the super image for each class
    n = 1;
    for i=1:length(class_names)
        
        class_name = class_names{i};
        class_dir = [conf.classesDataDir '/' class_name];
        vl_xmkdir(class_dir);
        
        if exist(fullfile(conf.classhistsDataDir, [class_name '-histogram.mat']), 'file')
            fprintf('Loading super histograms for %s...\n', class_name);
            class_hist_struct = load(fullfile(conf.classhistsDataDir, [class_name '-histogram.mat']));
            super_class_histogram = class_hist_struct.super_class_histogram;
            clear class_hist_struct;
        else
            fprintf('Supercharging for %s...\n', class_name);
        
            super_class_histogram = sparse(1:vocab.size, 1,0);

%              get images of this class
            class_ims = coll.find(BasicDBObject('class', class_name));

            class_ids = {};
            class_frames = {};
            class_words = {};
            class_histograms = sparse([]);
            for j=1:class_ims.count()
                im = class_ims.next();
                class_ids{j} = im.get('_id').toString.toCharArray';
                class_frames{j} = load_frames(class_ids{j}, conf);
                class_words{j} = load_frames(class_ids{j}, conf);
                class_histograms(:,j) = load_histogram(class_ids{j}, conf);
            end
            
            if ~exist(fullfile(class_dir, 'class_ids.mat'), 'file')
                save(fullfile(class_dir, 'class_ids.mat'), 'class_ids');
            end

            class_useful_hists = sparse([]);
            
            for j=1:length(class_ids)
                id = class_ids{j};
                if ~exist(fullfile(conf.superhistsDataDir, [id '-superhist.mat']), 'file')
                    fprintf('Creating super histogram for image %d of %d\n', j, length(class_ids));
                    frames = load_frames(id, conf);
                    histogram = load_histogram(id, conf);
                    words = load_words(id, conf);
                    useful_histogram = get_useful_histogram(frames, words, histogram, class_frames, class_words, class_histograms, vocab, 'exclude', j);
%                     now use only the top 300
                    [y I] = sort(useful_histogram);
                    useful_histogram(I(1:end-300)) = 0;
%                     save a copy
                    save(fullfile(conf.superhistsDataDir, [id '-superhist.mat']), 'useful_histogram');
                else
                    fprintf('Already created super hist for image %d of %d\n', j, length(class_ids));
                    useful_hist_struct = load(fullfile(conf.superhistsDataDir, [id '-superhist.mat']));
                    useful_histogram = useful_hist_struct.useful_histogram;
                    clear useful_hist_struct;
                end
%                 add to list of useful histograms
                useful_histograms(:,n) = useful_histogram;
                useful_ids{n} = id;
                n = n + 1;
%                 Add to list of class useful hists
                class_useful_hists(:,j) = useful_histogram;
    %             create augmented class histogram
                super_class_histogram = super_class_histogram + useful_histogram;
            end
            
%             Save class useful hists
            save(fullfile(class_dir, 'class_useful_hists.mat'), 'class_useful_hists');
            classes_useful_hists{i} = class_useful_hists;

%     %         divide by number of images in class so that small classes are not
%     %         disadvantaged
%             super_class_histogram = super_class_histogram/length(class_ids);

%             normalize the histogram
            super_class_histogram = (1/sum(super_class_histogram))*super_class_histogram;
        end
        
        super_class_histograms(:, i) = super_class_histogram;
        save(fullfile(conf.classhistsDataDir, [class_name '-histogram.mat']), 'super_class_histogram');
    end
    
    save(fullfile(conf.modelDataDir, 'class_histograms.mat'), 'super_class_histograms');
    save(fullfile(conf.modelDataDir, 'useful_histograms.mat'), 'useful_histograms');
    save(fullfile(conf.modelDataDir, 'useful_ids.mat'), 'useful_ids');
    save(fullfile(conf.modelDataDir, 'classes_useful_hists.mat'), 'classes_useful_hists');