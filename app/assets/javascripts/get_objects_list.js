
var showMergeUI = function(event, node) {
  console.log(node);

  var button = '<button type="button" class="btn btn-warning btn-xs btn-merge" ' +
                  'data-toggle="modal" ' + 
                  'data-target="#myModal">' + 
                  '<span class="glyphicon glyphicon glyphicon-share" aria-hidden="true"></span>' + 
                '</button>'

  $(".btn-merge").remove();
  $("#object_desc li[data-nodeid='" + node.nodeId + "']").append(button);

  var modal = $('#myModal');
  modal.find('#old-val textarea').val(node.old_value);
  modal.find('#new-val textarea').val(node.new_value);
}

var getObjectDesc = function(event, node) {
  console.log(node);
  var obj_ref = node.config_obj_id;
  var diff_ref = node.diff_id;

  if (diff_ref != "") {
    link = '/diff_tree_format/' + diff_ref;
  } else {
    link = '/object_tree_format/' + obj_ref;
  }

  $.get(
    link, 
    function(data) { 
      $('#object_desc').treeview({ data: data, showTags: true, onNodeSelected: showMergeUI});
    });
}

$(function(){
  var ref = $("#configuration_list li.active a").attr("href"); 
  if (ref != undefined)
  {
    $.get(
      $("#configuration_list li.active a").attr("href") + "/get_object_index", 
      function(data) { 
        $('#objects').treeview({ data: data, levels: 1, showTags: true, onNodeSelected: getObjectDesc});
      });
  }
})