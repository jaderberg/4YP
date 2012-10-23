% Saves the figure as pdf, fallback to jpeg

function save_figure(fig, filepath)

%     if length(filepath) > 86
%         filepath = filepath(1:86);
%     end
    fprintf('Saving figure to %s\n', filepath);
    try
        vl_printsize(fig,1);
        print(fig,'-dpdf', '-r600', [filepath '.pdf']);
    catch
        try
            print(fig,'-djpeg90', [filepath '.jpeg']);
        catch
            fprintf('Error saving image\n');
        end
    end