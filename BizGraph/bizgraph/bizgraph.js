/*
	Copyright (c) 2013, Cloud Sherpas, Inc.
	All rights reserved.
	
	Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
	* Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
	* Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
	
	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
function BizGraph(el, dataURL, fullURL) {
    // Initialise the graph object
    var graph = this.graph = {
        "nodes": [],
        "links": [],
        "legendMap": {},
        "strokeMap": {},
        "strokeCount": 0,
        "nodeMap": {},
        "linkMap": {},
        "linkScale": d3.scale.category20()
    };

    // Create the graph element
    graph.svg = d3.select("#" + el).append("svg:svg").attr("width", "100%").attr("height", "100%");

    // Get the actual width and height
    graph.w = graph.svg[0][0].offsetWidth;
    graph.h = graph.svg[0][0].offsetHeight;

    graph.dataURL = dataURL;
    graph.fullURL = fullURL;


    // Instantiate the force layout engine
    // You can tweak these numbers if you don't like how the engine behaves
    graph.force = d3.layout.force()
        .gravity(0.05)
        .distance(function (d) {
            return 250.0 - (d.decayedRelevance * 1.5);
        })
        .charge(-300)
        .linkStrength(function (d) {
            return d.decayedRelevance / 100.0;
        })
        .size([graph.w, graph.h]);

    // Create a reusable style for the arrowhead marker
    graph.svg.append("svg:defs").selectAll("marker")
        .data(["arrow"])
        .enter().append("svg:marker")
        .attr("id", String)
        .attr("viewBox", "0 -5 11 11")
        .attr("refX", 15)
        .attr("refY", -1.5)
        .attr("markerWidth", 3)
        .attr("markerHeight", 3)
        .attr("orient", "auto")
        .append("svg:path")
        .attr("d", "M0,-5L11,0L0,5");


    // Add style to the nodes and edges
    graph.addStyle = function () {

        // ERASE THE EXISTING NODES
        graph.svg.select(".link").remove();
        graph.svg.select(".node").remove();
        graph.svg.select("defs").remove();

        // STYLE THE LINK
        var link = graph.svg.selectAll(".link")
            .data(graph.links)
            .enter().append("svg:path")
            .attr("class", "link")
            .style("stroke", function (d) {
                return d3.interpolateRgb("#FFF", graph.linkColor(d.relationship))(d.decayedRelevance / 100);
            });
        //.style("opacity", function(d) { return d.decayedRelevance / 100; });
        //.attr("marker-end", "url(#arrow)");

        link
            .append("title")
            .classed("tooltip", true)
            .text(function (d) {
                return d.relationship
            });
            
        var defs = graph.svg.append("defs").selectAll("pattern")
            .data(graph.nodes)
            .enter();
        
        var pattern = defs.append("pattern")
        	.attr("id", function(d) { return d.id; } )
        	.attr("x","0").attr("y","0")
        	.attr("patternUnits","objectBoundingBox")
        	.attr("height","45").attr("width","45")
        	.append("image")
        	.attr("x","0").attr("y","0")
        	.attr("xlink:href", function (d) { return d.dat.SmallPhotoURL; })
        	.attr("height","45").attr("width","45");

        var node = graph.svg.selectAll(".node")
            .data(graph.nodes)
            .enter();

        // STYLE THE NODE
        var circle = node.append("circle")
            .attr("class", "node")
            .attr("r", function (d) {
            	return "22";
                return (d.IsRoot ? 12 : 8);
            })
            .style("fill", function (d) {
            	if (d.dat.SmallPhotoURL) {
            		return "url(#" + d.id + ") " + d3.interpolateRgb("#FFF", graph.nodeColor(d.typ))(d.decayedRelevance / 100);
            	}
            	else {
                	return d3.interpolateRgb("#FFF", graph.nodeColor(d.typ))(d.decayedRelevance / 100);
                }
            })
        //.style("opacity", function(d) { return d.decayedRelevance / 100; })
        .style("stroke", "#FFF")
            .style("stroke-width", 3)
            .call(graph.force.drag);

        circle
            .append("title")
            .classed("tooltip", true)
            .text(function (d) {
                return d.desc
            });

        // STYLE THE LABEL
        var hlink = node.append("svg:a")
            .attr("xlink:href", function (d) {
                return d.url;
            })
            .attr("target", "_blank");

        var text = hlink.append("text")
            .attr("dx", 12)
            .attr("dy", ".35em")
            .style("opacity", function (d) {
                return d.decayedRelevance / 100;
            })
            .text(function (d) {
                return d.label
            });

        // LAYOUT THE GRAPH LABELS
        graph.force.on("tick", function () {
            // Draw a line between the two nodes
            link.attr("d", function (d) {
                var dx = d.target.x - d.source.x,
                    dy = d.target.y - d.source.y,
                    dr = Math.sqrt(dx * dx + dy * dy);
                return "M" + d.source.x + "," + d.source.y + "A" + dr + "," + dr + " 0 0,1 " + d.target.x + "," + d.target.y;
            });

            // Move the circle and text around
            circle.attr("transform", function (d) {
                return "translate(" + d.x + "," + d.y + ")";
            });
            text.attr("transform", function (d) {
                return "translate(" + d.x + "," + d.y + ")";
            });
            text.attr("dx", function (d) {
                if (d.x > (graph.w / 2))
                    return 12;
                else {
                    return (-1 * this.offsetWidth) - 12;
                }
            });
            text.attr("dy", function (d) {
                if (d.y < (graph.h / 2))
                    return "0em";
                else {
                    return "0.65em";
                }
            });
        });
    };

    // Update the graph with new nodes and edges from a data source
    this.update = function (url) {
        d3.json(url, function (error, json) {
            // Add all the links and nodes to the graph
            for (i = 0; i < json.nodes.length; i++) {
                var node = json.nodes[i];
                if (!graph.nodeMap[node.id]) {
                    //if (node.dat) {
                    //    node.dat = JSON.parse(node.dat);
                    //}
                    graph.nodes.push(node);
                    graph.nodeMap[node.id] = node;
                }
            }
            for (i = 0; i < json.links.length; i++) {
                var link = json.links[i];
                if (!graph.linkMap[link.id]) {
                    link.source = graph.nodeMap[link.fromId];
                    link.target = graph.nodeMap[link.toId];
                    link.decayedRelevance = (link.source.decayedRelevance + link.target.decayedRelevance) / 2;

                    graph.links.push(link);
                    graph.linkMap[link.id] = link;
                }
            }

            graph.addStyle();
            graph.buildLegend();

            graph.force
                .nodes(graph.nodes)
                .links(graph.links)
                .start();
        });
    };

    // Build the legend
    graph.buildLegend = function () {

        // ERASE THE EXISTING LEGENDS
        graph.svg.select(".legend").remove();

        // BUILD THE CONTROL PANEL
        var controlPanel = graph.svg.append("g")
            .attr("class", "legend")
            .attr("x", graph.w - 120)
            .attr("y", graph.h - 20)
            .attr("height", graph.h)
            .attr("width", 120);

        var popoutLink = controlPanel.append("svg:a")
            .attr("xlink:href",  graph.fullURL)
            .attr("target", "_blank")
            .append("text")
            .attr("dx", graph.w - 60)
            .attr("dy", 20)
            .text("Full Screen");

        // BUILD THE LEGEND
        var legendArray = [];
        for (var k in graph.legendMap) legendArray.push({
            "type": "Node",
            "label": k,
            "color": graph.legendMap[k]
        });
        for (var k in graph.strokeMap) legendArray.push({
            "type": "Stroke",
            "label": k,
            "color": graph.strokeMap[k]
        });

        // add legend   
        var legend = graph.svg.append("g")
            .attr("class", "legend")
            .attr("x", 0)
            .attr("y", graph.h - 20)
            .attr("height", graph.h)
            .attr("width", 120);
        //.attr('transform', 'translate(-20,50)');

        // Add the colored squares
        var legendRect = legend.selectAll('rect')
            .data(legendArray)
            .enter()
            .append("rect")
            .attr("x", 0)
            .attr("y", function (d, i) {
                return i * 20 + (d.type == "Node" ? 0 : 4);
            })
            .attr("width", 10)
            .attr("height", function (d) {
                return d.type == "Node" ? 10 : 2;
            })
            .style("fill", function (d) {
                return d.color;
            });

        // Add the label
        var legendText = legend.selectAll('text')
            .data(legendArray)
            .enter()
            .append("text")
            .attr("x", 14)
            .attr("y", function (d, i) {
                return i * 20 + 9;
            })
            .text(function (d) {
                return d.label;
            });
    }

    // Given a label, return an appropriate color
    graph.linkColor = function (typ) {
        if (graph.strokeMap[typ]) {
            return graph.strokeMap[typ];
        }
        graph.strokeMap[typ] = graph.linkScale(graph.strokeCount);
        graph.strokeCount++;

        return graph.strokeMap[typ];
    };

    // Give a label, return an appropriate color
    graph.nodeColor = function (typ) {
        if (graph.legendMap[typ]) {
            return graph.legendMap[typ];
        }

        if (typ == "Account") graph.legendMap[typ] = "#236fbd";
        else if (typ == "Contact") graph.legendMap[typ] = "#56458c";
        else if (typ == "Opportunity") graph.legendMap[typ] = "#e5c130";
        else if (typ == "User") graph.legendMap[typ] = "#1797c0";
        else if (typ == "Case") graph.legendMap[typ] = "#b7a752";
        else {
        	graph.legendMap[typ] = graph.linkScale(graph.strokeCount);
        	graph.strokeCount++;
        }

        return graph.legendMap[typ];
    };

    // Add a parameter to a URL (not very efficient)
    graph.buildURL = function (url, key, val) {
        if (url.indexof("?") == -1)
            url = url + "?";
        else
            url = url + "&";
        url = url + encodeURIComponent(key) + "=" + encodeURIComponent(val);
        return url;
    };
};