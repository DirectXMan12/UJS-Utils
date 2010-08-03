// custom ajax handlers
(function() {   
	document.on("ajax:success", function(event) {
    var element = event.findElement();
    var tag_to_update = element.readAttribute('data-update');
		var success_code = element.readAttribute('data-ajax-success');
    
    if (element && tag_to_update)
    {
			var response_text = event.memo.request.responseText;
	  	$(tag_to_update).update(response_text);
     	$(tag_to_update).appear();
    }

		if (element && success_code)
		{
			var success_function = function(event) { eval(success_code); }
			success_function(event);
		}
    
    return false;
  });
  document.on("ajax:before", function(event) {
    var element = event.findElement();
    var tag_to_update = element.readAttribute('data-update');
		var success_code = element.readAttribute('data-ajax-success');

    if (element && tag_to_update)
    {
      $(tag_to_update).hide();
    }
  });

	function do_ajax(element, event, observe_url)
	{
		var event = element.fire("ajax:before");
		if (event.stopped) return false;

		new Ajax.Request(observe_url, {
			method: "POST",
			parameters: element.serialize(true),
			asynchronous: true,
			evalScripts: true,

			onLoading:     function(request) { element.fire("ajax:loading", {request: request}); },
			onLoaded:      function(request) { element.fire("ajax:loaded", {request: request}); },
			onInteractive: function(request) { element.fire("ajax:interactive", {request: request}); },
			onComplete:    function(request) { element.fire("ajax:complete", {request: request}); },
			onSuccess:     function(request) { element.fire("ajax:success", {request: request}); },
			onFailure:     function(request) { element.fire("ajax:failure", {request: request}); }
		});

		element.fire("ajax:after");	
	}

	document.on("change", function(event) {
		var element = event.findElement("textarea[data-observe]") || event.findElement("input[data-observe]");
		var observe_url = element.readAttribute("data-observe");
		var monitor_rate = element.readAttribute("data-observe-rate") || "0";
		
		if (!element) return false;
		if (monitor_rate == "0") // 0 -> event-based - non event-based observers are dealt with below
		{	
			if (observe_url.match(/https?\:?/) && observe_url.match(/https?\:?/) != -1)
			{
				do_ajax(element, event, observe_url);
			}
			else
			{
				// assume code
				call_code = function(event) { eval(observe_url); }
				call_code(event);
			}
		}

	});

	// deal with non-event-based observers here
	function init_timed_observers() {
		var observe_inputs = $$('input[data-observe][data-observe-rate != 0]', 'textarea[data-observe][data-observe-rate != 0]');
		observe_inputs.each(function(obj, index) {
			var observe_action = obj.readAttribute('data-observe');
			if (!obj.readAttribute('name'))
			{
				obj.writeAttribute('name', 'auto_named_box_'+index.toString());
			}

			if (observe_action.match(/https?\:?/) && observe_action.match(/https?\:?/) != -1)
			{
				new Form.Element.Observer(obj, obj.readAttribute('data-observe-rate'), function(event) {do_ajax(obj,event,observe_action);}); 
			}
			else {
				new Form.Element.Observer(obj, obj.readAttribute('data-observe-rate'), function(event) { eval(obj.readAttribute('data-observe')); });
			}
		});
	}
	// we must wait until the dom has been loaded to do this
	document.on("dom:loaded", function() { init_timed_observers(); });
})();
