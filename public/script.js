$('.custom-file-input').on('change', function () {
  $(this).next('.custom-file-label').html($(this)[0].files[0].name);
})