% Max Jaderberg 28/12/11

function [m_classes super_class_histograms useful_histograms] = supercharge_images(coll, conf, vocab)

    if exist(fullfile(conf.modelDataDir, 'useful_histograms.mat') ,'file')
        temp_struct = load(fullfile(conf.modelDataDir, 'class_names.mat'));
        m_classes = temp_struct.class_names;
        temp_struct = load(fullfile(conf.modelDataDir, 'class_histograms.mat'));
        super_class_histograms = temp_struct.super_class_histograms;
        temp_struct = load(fullfile(conf.modelDataDir, 'useful_histograms.mat'));
        useful_histograms = temp_struct.useful_histograms;
        clear temp_struct;
        return
    end

    import com.mongodb.BasicDBObject;

    classes = coll.distinct('class').toArray();
    
    m_classes = {};
    
    useful_histograms = sparse([]);
    super_class_histograms = sparse([]);
     
%      create the super image for each class
    for i=1:length(classes)
        
        m_classes{i} = classes(i);
        
        if exist(fullfile(conf.classhistsDataDir, [m_classes{i} '-histogram.mat']), 'file')
            fprintf('Loading super histograms for %s...\n', m_classes{i});
            class_hist_struct = load(fullfile(conf.classhistsDataDir, [m_classes{i} '-histogram.mat']));
            super_class_histogram = class_hist_struct.super_class_histogram;
            clear class_hist_struct;
        else
            fprintf('Supercharging for %s...\n', m_classes{i});
        
            super_class_histogram = sparse(1:vocab.size, 1,0);

    %         get images of this class
            class_ims = coll.find(BasicDBObject('class', classes(i)));

            class_ids = {};
            class_frames = {};
            class_words = {};
            class_histograms = sparse([]);
            for j=1:class_ims.count()
                im = class_ims.next();
                class_ids{j} = im.get('_id').toString.toCharArray';
                im_model = im.get('model');
                class_frames{j} = eval(im_model.get('frames'));
                class_words{j} = eval(im_model.get('words'));
                class_histograms(:,j) = eval(im_model.get('histogram'));
            end

            for j=1:length(class_ids)
                id = class_ids{j};
                if ~exist(fullfile(conf.superhistsDataDir, [id '-superhist.mat']), 'file')
                    fprintf('Creating super histogram for image %d of %d\n', j, length(class_ids));
                    frames = mongo_get_frames(coll, 'id', id);
                    histogram = mongo_get_histogram(coll, 'id', id);
                    words = mongo_get_words(coll, 'id', id);
                    useful_histogram = get_useful_histogram(frames, words, histogram, class_frames, class_words, class_histograms, vocab, 'exclude', j);
        %             now use only the top 300
                    [y I] = sort(useful_histogram);
                    useful_histogram(I(1:end-300)) = 0;
                    save(fullfile(conf.superhistsDataDir, [id '-superhist.mat']), 'useful_histogram');
                else
                    useful_hist_struct = load(fullfile(conf.superhistsDataDir, [id '-superhist.mat']));
                    useful_histogram = useful_hist_struct.useful_histograms;
                    clear useful_hist_struct;
                end
    %             add to list of useful histograms and save a copy
                useful_histograms(:,j) = useful_histogram;
    %             create augmented class histogram
                super_class_histogram = super_class_histogram + useful_histogram;
            end

    %         divide by number of images in class so that small classes are not
    %         disadvantaged
            super_class_histogram = super_class_histogram/length(class_ids);
        end
        
        super_class_histograms(:, i) = super_class_histogram;
        save(fullfile(conf.classhistsDataDir, [m_classes{i} '-histogram.mat']), 'super_class_histogram');
    end
    
    save(fullfile(conf.modelDataDir, 'class_names.mat'), 'm_classes');
    save(fullfile(conf.modelDataDir, 'class_histograms.mat'), 'super_class_histograms');
    save(fullfile(conf.modelDataDir, 'useful_histograms.mat'), 'useful_histograms');