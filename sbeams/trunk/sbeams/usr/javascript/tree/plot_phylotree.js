var $jq = jQuery.noConflict(); 
var phylotree_extensions = new Object();

$jq("[data-direction]").on("click", function(e) {
	var which_function =
		$jq(this).data("direction") == "vertical"
			? tree.display.spacing_x.bind(tree.display)
			: tree.display.spacing_y.bind(tree.display);
	which_function(which_function() + +$jq(this).data("amount")).update();
});

$jq(".phylotree-layout-mode").on("click", function(e) {
	if (tree.display.radial() != ($jq(this).data("mode") == "radial")) {
		$jq(".phylotree-layout-mode").toggleClass("active");
		tree.display.radial(!tree.display.radial()).update();
	}
});

$jq(".phylotree-align-toggler").on("click", function(e) {
	var button_align = $jq(this).data("align");
	var tree_align = tree.display.options.alignTips;

	if (tree_align != button_align) {
		tree.display.alignTips(button_align == "right");
		$jq(".phylotree-align-toggler").toggleClass("active");
		tree.display.update();
	}
});

function sort_nodes(asc) {
	tree.resortChildren(function(a, b) {
		return (b.height - a.height || b.value - a.value) * (asc ? 1 : -1);
	});
}

$jq("#sort_original").on("click", function(e) {
	tree.resortChildren(function(a, b) {
		return a["original_child_order"] - b["original_child_order"];
	});
});

$jq("#sort_ascending").on("click", function(e) {
	sort_nodes(true);
	tree.display.update();
});

$jq("#sort_descending").on("click", function(e) {
	sort_nodes(false);
	tree.display.update();
});


function default_tree_settings() {
	tree = phylotree();
	tree.branchLength(null);
	tree.branchName(null);
	tree.display.radial(false).separation(function(a, b) {
		return 0;
	});
}

function node_colorizer(element, data) {
	try {
		var count_class = 0;

		selection_set.forEach(function(d, i) {
			if (data[d]) {
				count_class++;
				element.style(
					"fill",
					color_scheme(i),
					i == current_selection_id ? "important" : null
				);
			}
		});

		if (count_class > 1) {
		} else {
			if (count_class == 0) {
				element.style("fill", null);
			}
		}
	} catch (e) {}
}
function edge_colorizer(element, data) {

	try {
		var count_class = 0;

		selection_set.forEach(function(d, i) {
			if (data[d]) {
				count_class++;
				element.style(
					"stroke",
					color_scheme(i),
					i == current_selection_id ? "important" : null
				);
			}
		});

		if (count_class > 1) {
			element.classed("branch-multiple", true);
		} else if (count_class == 0) {
			element.style("stroke", null).classed("branch-multiple", false);
		}
	} catch (e) {}
}

var width = 800, 
	height = 800, 
	selection_set = ["Foreground"],
	current_selection_id = 0,
	max_selections = 10;
(color_scheme = d3.scaleOrdinal(d3.schemeCategory10)),
	(selection_menu_element_action = "phylotree_menu_element_action");

var container_id = "#tree_container";
var datamonkey_save_image = function(type, container) {
	var prefix = {
		xmlns: "http://www.w3.org/2000/xmlns/",
		xlink: "http://www.w3.org/1999/xlink",
		svg: "http://www.w3.org/2000/svg"
	};

	function get_styles(doc) {
		function process_stylesheet(ss) {
			try {
				if (ss.cssRules) {
					for (var i = 0; i < ss.cssRules.length; i++) {
						var rule = ss.cssRules[i];
						if (rule.type === 3) {
							// Import Rule
							process_stylesheet(rule.styleSheet);
						} else {
							// hack for illustrator crashing on descendent selectors
							if (rule.selectorText) {
								if (rule.selectorText.indexOf(">") === -1) {
									styles += "\n" + rule.cssText;
								}
							}
						}
					}
				}
			} catch (e) {
				console.log("Could not process stylesheet : " + ss); // eslint-disable-line
			}
		}

		var styles = "",
			styleSheets = doc.styleSheets;

		if (styleSheets) {
			for (var i = 0; i < styleSheets.length; i++) {
				process_stylesheet(styleSheets[i]);
			}
	 }

		return styles;
	}

	var svg = $jq(container).find("svg")[0];
	if (!svg) {
		svg = $jq(container)[0];
	}

	var styles = get_styles(window.document);

	svg.setAttribute("version", "1.1");

	var defsEl = document.createElement("defs");
	svg.insertBefore(defsEl, svg.firstChild);

	var styleEl = document.createElement("style");
	defsEl.appendChild(styleEl);
	styleEl.setAttribute("type", "text/css");

	// removing attributes so they aren't doubled up
	svg.removeAttribute("xmlns");
	svg.removeAttribute("xlink");

	// These are needed for the svg
	if (!svg.hasAttributeNS(prefix.xmlns, "xmlns")) {
		svg.setAttributeNS(prefix.xmlns, "xmlns", prefix.svg);
	}

	if (!svg.hasAttributeNS(prefix.xmlns, "xmlns:xlink")) {
		svg.setAttributeNS(prefix.xmlns, "xmlns:xlink", prefix.xlink);
	}

	var source = new XMLSerializer()
		.serializeToString(svg)
		.replace("</style>", "<![CDATA[" + styles + "]]></style>");
	var doctype =
		'<?xml version="1.0" standalone="no"?><!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">';
	var to_download = [doctype + source];
	var image_string =
		"data:image/svg+xml;base66," + encodeURIComponent(to_download);

	if (navigator.msSaveBlob) {
		// IE10
		download(image_string, "image.svg", "image/svg+xml");
	} else if (type == "png") {
		b64toBlob(
			image_string,
			function(blob) {
				var url = window.URL.createObjectURL(blob);
				var pom = document.createElement("a");
				pom.setAttribute("download", "image.png");
				pom.setAttribute("href", url);
				$jq("body").append(pom);
				pom.click();
				pom.remove();
			},
			function(error) {
				console.log(error); // eslint-disable-line
			}
		);
	} else {
		var pom = document.createElement("a");
		pom.setAttribute("download", "image.svg");
		pom.setAttribute("href", image_string);
		$jq("body").append(pom);
		pom.click();
		pom.remove();
	}
};

$jq(document).ready(function() {

	tree = new phylotree.phylotree(newick_string);

	tree.render({
		container: "#tree_container",
		"draw-size-bubbles": false,
		"node-styler": node_colorizer,
		zoom: false,
		"edge-styler": edge_colorizer
	});

	// Until a cleaner solution to supporting both Observable and regular HTML
	var container =  document.getElementById('tree_container');
	container.append(tree.display.show());

	$jq("#save_image").on("click", function(e) {
		datamonkey_save_image("svg", "#tree_container");
	});
});
