// JavaScript to provide interactive features for parser HTML

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

  // show the program nodes
  $('.ast_node.program').removeClass('tree-collapse');
  $('.ast_node.program').addClass('tree-show');
});

// vim:sw=2:ts=2:et:autoindent
