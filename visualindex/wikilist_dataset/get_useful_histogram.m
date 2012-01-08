% Max Jaderberg 28/12/11

function useful_histogram = get_useful_histogram(q_im_f, q_im_w, q_im_h, I_f, I_w, I_h, vocab, varargin)
% q_im_f: frames of query image
% q_im_w: words of query image
% q_im_h: the tfidf weighted histogram of query image
% I_f: cells with frames of images to verify against
% I_w: cells with words of images to verify against
% I_h: the tfidf weighted histograms of images to verify against

    opts.exclude = 0;
    opts = vl_argparse(opts, varargin);
    
    if length(I_f) == 1 && opts.exclude
%         its a singleton!
        useful_histogram = q_im_h;
        return
    end

    verified_words = sparse([]);
    useful_histograms = sparse([]);
    
%     TODO: dont repeat spatial verification for pairs

%     for each image to verify against
    for i=1:length(I_f)
        if opts.exclude == i
            continue
        end
        [score matches] = spatially_verify(q_im_f, q_im_w, I_f{i}, I_w{i}, 0);
        if score == 0
            continue
        end
        unique_verified_words = unique(matches.words);
        verified_words(:,i) = sparse(double(unique_verified_words),1,...
                                           ones(length(unique_verified_words),1), ...
                                           vocab.size,1) ;
        useful_histograms(:,i) = I_h(:,i).*verified_words(:,i);
    end
    
    useful_words = sum(verified_words, 2) ~= 0;
    
    if isempty(useful_words)
        useful_words = sparse(1:vocab.size, 1, 0);
    end
    
%     image augmentation
    useful_histogram = useful_words.*q_im_h + sum(useful_histograms, 2);
    
