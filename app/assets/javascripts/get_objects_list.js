var getObjectDesc = function(event, node) {
  console.log(node);
  var ref = node.config_obj_id;
  if (ref != "")
  {
    $.get(
      "/configuration_objects/" + ref, 
      function(data) { 
        $('#object_desc').treeview({ data: data, showTags: true});
      });
  }
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