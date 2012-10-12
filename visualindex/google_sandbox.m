% Google image api sandbox

query = '10%20downing';

request_url = ['https://ajax.googleapis.com/ajax/services/search/images?v=1.0' ...
    '&q=' query ...
    '&as_filetype=jpg' ...
    '&imgtype=photo' ...
    '&rsz=8' ...
];

display(request_url);

response = urlread(request_url);

resp = parse_json(response);

results = resp{1}.responseData.results;
n = length(results);

id = results{1}.imageId;
url = results{1}.url;