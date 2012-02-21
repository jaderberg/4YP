% Saves the figure as pdf, fallback to jpeg

function save_figure(fig, filepath)

    try
        vl_printsize(fig,1);
        print(fig,'-dpdf', [filepath '.pdf']);
    catch
        print(fig,'-djpeg90', [filepath '.jpeg']);
    end