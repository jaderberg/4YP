% Max Jaderberg 2011

function json_response = web_feval(headers, config)
%WEB_FEVAL Returns a json object of the result of calling the funciton
%   This allows you to run any local matlab file. To be used with webserver.m. 
%   HTTP POST to /web_feval.m with the following parameters:
%       func_path: a string which is the path to the .m file you want to
%       call
%       arguments: a json string of the arguments structure to pass to the
%       function you are calling
% 
%   Returns a json object containing the result

    response.success = 'false';
    field_names = fieldnames(headers.Content);
    
    if size(field_names)
        response.content = headers.Content;
    else
        response.content = '';
    end
    
    func_path_check = false;
    arguments_check = false;
    if size(field_names)
        if find([field_names{:}]=='func_path') > 0
            func_path_check = true;
        end
        if find([field_names{:}]=='arguments') > 0
            arguments_check = true;
        end
    end
    
    if ~func_path_check
        response.message = 'No function given as func_path POST parameter';
        json_response = mat2json(response);
        return
    end
    
    func_path = headers.Content.func_path;
    
    if arguments_check
        arguments = json2mat(headers.Content.arguments);
    else
        arguments = false;
    end
    
    response.result = run_dot_m(func_path, arguments);
    response.success = 'true';

    json_response = mat2json(response);
    
    return
end

