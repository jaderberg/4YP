% Max Jaderberg 28/12/11

function supercharge_images(coll, conf, histograms, ids, vocab)

    import com.mongodb.BasicDBObject;

    classes = coll.distinct('class').toArray();
     
%      create the super image for each class
    for i=1:length(classes)
%         get images of this class
        class_ims = coll.find(BasicDBObject('class', classes(i))).toArray();
    end