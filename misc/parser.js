// JavaScript to provide interactive features for parser HTML

$(function(){
	$.extend($.fn.disableTextSelect = function() {
		return this.each(function(){
			if($.browser.mozilla){//Firefox
				$(this).css('MozUserSelect','none');
			}else if($.browser.msie){//IE
				$(this).bind('selectstart',function(){return false;});
			}else{//Opera, etc.
				$(this).mousedown(function(){return false;});
			}
		});
	});
});


function setup_collapsable_nodes(node_selector, label_selector) {
  // close all AST nodes
  $(node_selector).addClass("tree-collapse");

  // wire up click event
  $(node_selector + ' ' + label_selector).click(function() {
    var node = $(this).parents(node_selector).first();
    if(node.hasClass('tree-collapse')) {
      node.removeClass('tree-collapse');
      node.addClass('tree-show');
    } else if(node.hasClass('tree-show')) {
      node.removeClass('tree-show');
      node.addClass('tree-collapse');
    }
  });
}

$(document).ready(function() {
  setup_collapsable_nodes('.ast_node', '.type');
  setup_collapsable_nodes('.children', '.label');
  setup_collapsable_nodes('.tokens', 'caption');

  // show the program nodes
  $('.ast_node.program').removeClass('tree-collapse');
  $('.ast_node.program').addClass('tree-show');

  // show the source nodes
  $('.tokens').removeClass('tree-collapse');
  $('.tokens').addClass('tree-show');

  // show the child nodes
  $('.children').removeClass('tree-collapse');
  $('.children').addClass('tree-show');

	$('.ast_node .label').disableTextSelect();
	$('.ast_node .type').disableTextSelect();
	$('.tokens caption').disableTextSelect();

  // convert layout to splitter layout
  $('body').append('<div id="split_main"><div id="split_v" /></div>');
  $('#tokens_section').detach().appendTo('#split_v');
  $('#errors_section').detach().appendTo('#split_v');
  $('#programs_section').detach().appendTo('#split_main');
  $('#split_v').splitter({ type: 'h', sizeBottom: true, outline: false });
  $('#split_main').splitter({
    anchorToWindow: true, sizeRight: true, outline: false });
});

// vim:sw=2:ts=2:et:autoindent
