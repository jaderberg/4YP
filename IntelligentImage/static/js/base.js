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
        $('#untagged-img-form').ajaxSubmit({
            dataType: 'json',
            beforeSubmit: function () {
                $('#img-preview-box').fadeOut(218, function () {
                    $('#loading-box').fadeIn(218);
                });
            },
            success: function (data) {
                $('#loading-box').fadeOut(fadeTime, function () {
                    if (data.success) {
                        $('#tagged-img-box').append(data.html);
                        $('#tagged-img-box').fadeIn(fadeTime);
                    } else {
                        alert(data.error);
                        $('#img-preview-box').fadeIn(fadeTime);
                    }
                });
            }
        });
        return false;
    });

});