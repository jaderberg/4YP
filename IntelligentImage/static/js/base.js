$(function () {

    var fadeTime = 218,
        scroll_to_elem = function($elem) {
            $('html, body').animate({scrollTop: $elem.offset().top - 20}, 800);
        };

    // image selected
    $('#id_image').change(function () {
        $(this).closest('form').ajaxSubmit({
            dataType: 'json',
            beforeSubmit: function () {
                $('#upload-box').fadeOut(fadeTime, function () {
                    $('#loading-box').fadeIn(fadeTime);
                });
            },
            success: function (data) {
                $('#loading-box').fadeOut(fadeTime, function () {
                    if (data.success){
                        $('#img-preview-box').prepend(data.html);
                        $('#img-preview-box').fadeIn(fadeTime);
                        scroll_to_elem($('#img-preview-box'));
                    } else {
                        alert(data.error);
                        $('#upload-box').fadeIn(fadeTime);
                    }
                });
            }
        });
    });

    // tag image button
    $('#tag-img-button').click(function () {
        var session_key,
            log_int,
            update_log = function (callback) {
                $.getJSON($('#tag-img-button').data('logurl'), {key:session_key}, function (data) {
                    if (data.success) {
                        var $log_window = $('#log-window').clone(),
                            $log_line = $log_window.find('#log-first-line').clone();
                        $log_window.html('');
                        $log_window.append($log_line.clone());

                        $log_line.attr('id', '');

                        for (var i=0; i < data.lines.length; i++){
                            $log_line.find('span').text(data.lines[i]);
                            $log_window.append($log_line.clone());
                            console.log(i+1, data.lines[i]);
                        }

                        $('#log-window').replaceWith($log_window);

                        scroll_to_elem($('#log-window').find('p').last());

                        if (callback) {
                            callback();
                        }
                    }
                });
            };

        $('#log-box').fadeIn(218);

        $('#loading-box').fadeIn(218, function () {

            scroll_to_elem($('#log-box'));

            $.getJSON($('#tag-img-button').data('sessionurl'), function(data){
                session_key = data.key;
                console.log('session_key: ', session_key);

                $('#untagged-img-form').ajaxSubmit({
                    dataType: 'json',
                    data: {
                        key: session_key
                    },
                    beforeSubmit: function () {
                        $('#loading-box').fadeIn(218);
                    },
                    success: function (data) {
                        $('#loading-box').fadeOut(fadeTime, function () {
                            if (data.success) {
                                clearInterval(log_int);
                                update_log(function () {
                                    $.getJSON($('#tag-img-button').data('logcleanupurl'), {key:session_key});
                                });
                                $('#tagged-img-box').append(data.html);
                                $('#tagged-img-box').fadeIn(fadeTime, function () {
                                    scroll_to_elem($(this));
                                });
                            } else {
                                alert(data.error);
                                $('#img-preview-box').fadeIn(fadeTime);
                            }
                        });
                    }
                });

                log_int = setInterval(update_log, 1000);

            });

        });

        return false;
    });

});