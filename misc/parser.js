// JavaScript to provide interactive features for parser HTML

function highlight_error(elem, is_err) {
  var first_token = $(elem).find('.tokens .first').html();
  var last_token = $(elem).find('.tokens .last').html();

  var tokens = $('#token_'+first_token);
  for(i=first_token; i<=last_token; ++i) {
    tokens = tokens.add('#token_'+i);
  }
  tokens.addClass(is_err ? "error" : "warning");
}

function highlight_errors() {
  $('#errors_section .error').each(
    function() { highlight_error($(this), true); });
  $('#errors_section .warning').each(
    function() { highlight_error($(this), false); });
}

$(document).ready(function() {
  // highlight_errors();
});

// vim:sw=2:ts=2:et:autoindent
