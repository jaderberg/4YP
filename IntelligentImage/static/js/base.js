$(function () {

    var fadeTime = 218;

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
        var session_key;
        var log_int;

        $('#log-box').fadeIn(218);

        $('#loading-box').fadeIn(218, function () {

            $('html, body').animate({scrollTop: $('#log-box').offset().top}, 800);

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
                                $('#tagged-img-box').append(data.html);
                                $('#tagged-img-box').fadeIn(fadeTime, function () {
                                    $('html, body').animate({scrollTop: $(this).offset().top}, 800);
                                });
                            } else {
                                alert(data.error);
                                $('#img-preview-box').fadeIn(fadeTime);
                            }
                        });
                    }
                });

            });

        });

        return false;
    });

});