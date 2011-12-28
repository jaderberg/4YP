% Max Jaderberg 28/12/11

function useful_histogram = get_useful_histogram(q_im_f, q_im_w, q_im_h, I_f, I_w, I_h, vocab)
% q_im_f: frames of query image
% q_im_w: words of query image
% q_im_h: the tfidf weighted histogram of query image
% I_f: cells with frames of images to verify against
% I_w: cells with words of images to verify against
% I_h: the tfidf weighted histograms of images to verify against

    verified_words = sparse([]);
    useful_histograms = sparse([]);
    
%     TODO: dont repeat spatial verification for pairs

%     for each image to verify against
    for i=1:length(I_f)
        [score matches] = spatially_verify(q_im_f, q_im_w, I_f{i}, I_w{i}, 0);
        if score > 5
            unique_verified_words = unique(matches.words);
            verified_words(:,i) = sparse(double(unique_verified_words),1,...
                                               ones(length(unique_verified_words),1), ...
                                               vocab.size,1) ;
            useful_histograms(:,i) = I_h(:,i).*verified_words(:,i);
        end
    end
    
    useful_words = sum(verified_words, 1) ~= 0;
    
%     image augmentation
    useful_histogram = useful_words.*q_im_h + sum(useful_histograms, 1);
    
