% Max Jaderberg 2011

function max_db_creator()
%     Creates the mongodb database with the images.
%   NB: For mongodb driver reference see http://www.mongodb.org/display/DOCS/Java+Tutorial

    javaaddpath('mongo-2.7.2.jar')

    import com.mongodb.Mongo;
    import com.mongodb.DB;
    import com.mongodb.DBCollection;
    import com.mongodb.BasicDBObject;
    import com.mongodb.DBObject;
    import com.mongodb.DBCursor;

    m = Mongo(); % connect to local db
    db = m.getDB('test'); % get db object
    colls = db.getCollectionNames(); % get collection names
    coll = db.getCollection('things'); % get DBCollection object

    doc(1) = BasicDBObject();
    doc(1).put('name', 'MongoDB');
    doc(1).put('type', 'database');
    doc(1).put('count', 1);
    info = BasicDBObject();
    info.put('x', 203);
    info.put('y', 102);
    doc(1).put('info', info);
    coll.insert(doc);