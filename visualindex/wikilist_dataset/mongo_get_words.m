% Max Jaderberg 24/11/11

function words = mongo_get_words( collection, varargin )
%MONGO_GET_FRAME returns the words object for the id
%   input either 'id', id (the mongoDB id as char) or 'dir', dir, 'name', name. If not found an
%   empty vector is returned. Assumes vl_setup has been run.


import com.mongodb.DBCollection;
import com.mongodb.BasicDBObject;
import org.bson.types.ObjectId;

opts.id = []; opts.dir = []; opts.name = [];
opts = vl_argparse(opts, varargin);

if ~isempty(opts.id)
    image = collection.findOne(BasicDBObject('_id', ObjectId(opts.id)));
end

if (~isempty(opts.dir)) && (~isempty(opts.name))
    query = BasicDBObject();
    query.put('directory', opts.dir); query.put('name', opts.name);
    image = collection.findOne(query);
end

model = image.get('model');

if ~isempty(model)
    ser = model.get('words');
    if ~isempty(ser)
        words = eval(ser);
        return
    end
end

words = [];

end


