/**
	Copyright (c) 2013, Cloud Sherpas, Inc.
	All rights reserved.
	
	Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
	* Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
	* Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
	
	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

 ** This class implements a generic breadth-first search.
 ** You must extend this class to implement the getNodes() method.
 **/
global abstract with sharing class GraphController {
	
	// Node and Link trimming information
	global Integer maxDepth {get; set;}
	global Decimal minRelevance {get; set;}
	global Decimal decayRate {get; set;}
	
	// The set of root IDs to be displayed on the Graph
	protected Set<Id> rootIDs {get; set;}
	// The set of root nodes
	protected Map<Id, GraphController.Node> rootNodes = new Map<Id, GraphController.Node>();
	
	// The set of all queried nodes and Links
	protected Map<Id, GraphController.Node> nodes = new Map<Id, GraphController.Node>();
	protected Map<String, GraphController.Link> Links = new Map<String, GraphController.Link>();
		
	// The set of all relevant nodes and all the Links that are attached to *two* relevant nodes
	protected Map<Id, GraphController.Node> relevantNodes = null;
	protected Map<String, GraphController.Link> relevantLinks = null;
	
	// The set of leaf nodes (nodes that will not be spidered, but that will be displayed)
	protected Map<Id, GraphController.Node> leafNodes = new Map<Id, GraphController.Node>();
	
	// The list of nodes to be displayed
	global List<GraphController.Node> nodeList {
		get {
			return relevantNodes.values();
		}
	}
	// The list of Links to be displayed
	global List<GraphController.Link> LinkList {
		get {
			return relevantLinks.values();
		}
	}
	
	// Act as a controller but accept a comma-separated list of IDs to act as the root nodes
	global GraphController() {
		maxDepth = 3;
		minRelevance = 50.0;
		decayRate = 0.9;
		
		String rootID = ApexPages.currentPage().getParameters().get('id');
		system.debug(LoggingLevel.Debug, 'RootID: ' + rootID);
		List<String> lstRootID = rootID.split(',');
		
		RootIDs = new Set<Id>();
		for (String id : lstRootID)
			RootIDs.add(id);
	}
	
	global abstract GraphController.Result getNodes(String typ, Set<Id> IDs);
	
	//this method builds the graph
	global void spider() {
		relevantNodes = new Map<Id, GraphController.Node>();
		relevantLinks = new Map<String, GraphController.Link>();
		
		Integer depth = 0;
		Set<Id> currNodeIDs = rootIDs;
		do {
				System.Debug(LoggingLevel.Info, 'Starting depth ' + depth + ' with node IDs: ' + currNodeIDs);
				Set<Id> nextNodeIDs = new Set<Id>();
				
				Map<String, Set<Id>> IDsByType = separateByType(currNodeIDs);
				System.Debug(LoggingLevel.Debug, 'Map of IDs by Type: ' + IDsByType);
				
				// Process each type of node in turn
				for (String typ : IDsByType.keySet()) {
					if (GraphController.nearLimits()) continue;
					
					Set<Id> IDs = IDsByType.get(typ);
					
					// Get the list of nodes
					try {
						// Call the user-implemented getNodes method to get the node details and the next level in the tree
						GraphController.Result result = getNodes(typ, IDs);
						
						// Add all the nodes to the list, filtering out the ones that are not relevant
						// This method returns a list of new NodeIDs (not sorted by type)
						Set<Id> newIDs = this.addNodesAndLinks(result.nodes, result.Links, depth);
						nextNodeIDs.addAll(newIDs);
					}
					catch (Exception e) {
						// Do nothing
						System.Debug(LoggingLevel.Warn, 'Exception getting nodes from user extension: ' + e.getMessage());
					}
				}
				
				// If this is the root of the tree, mark any and all nodes as "root"
				if (depth == 0) {
					for (GraphController.Node node : nodes.values()) {
						node.IsRoot = true;
						node.relevance = 100;
						node.decayedRelevance = 100;
						rootNodes.put(node.Id, node);
						relevantNodes.put(node.Id, node);
					}
				}
	
				// We should now have a complete set of the next level of nodes
				currNodeIDs = nextNodeIDs;
				depth++;
		
		// Repeat as long as we are below the max depth and there are more nodes to grab
		} while (depth <= maxDepth && !currNodeIDs.IsEmpty());
		
		
		// Identify the set of nodes that have at least the minimum relevance, and the list of Links that connect to relevant nodes
		for (GraphController.Link Link : Links.values()) {
			if (Link.toId == Link.fromId) continue; // We never follow recursive links
			
			if (relevantNodes.containsKey(Link.fromId) && relevantNodes.containsKey(Link.toId))
				relevantLinks.put(Link.id, Link);
		}
	}
	
	// Separates a set of IDs into a map of sObjectType -> Set of IDs of that type
	private Map<String, Set<Id>> separateByType(Set<Id> IDs) {
		Map<String, Set<Id>> IDsByType = new Map<String, Set<Id>>();
		for (Id id : IDs) {
			String typ = String.valueOf(id.getsObjectType());
			Set<Id> lst = IDsByType.get(typ);
			if (lst == null) {
				lst = new Set<Id>();
				IDsByType.put(typ, lst);
			}
			lst.add(id);
		}
		return IDsByType;
	}
	
	// Adds the nodes and Links to the parent set, and adds any next nodes to the list
	private Set<Id> addNodesAndLinks(Map<Id, GraphController.Node> newNodes, Map<String, GraphController.Link> newLinks, Integer depth) {
		Set<Id> nextNodeIDs = new Set<Id>();
		Decimal decay = decayRate.pow(depth); // We calculate the decay multiplier based on depth
		
		// For each of the new nodes
		for (GraphController.Node node : newNodes.values()) {
			// Only add the node to the map if it does not already exist
			// This means that we always use the relevance and other details from the first (closest) node we find
			if (!nodes.containsKey(node.id)) {
				node.depth = depth;
				node.decayedRelevance = decay * node.relevance;
				
				// We keep track of every node so that we don't query them twice
				nodes.put(node.id, node);
				
				// But only a few nodes are actually relevant. Nodes that are not relevant will not be returned to the UI
				if (node.decayedRelevance > minRelevance) {
					relevantNodes.put(node.id, node);
					
					// Leaf nodes are tracked separately, and links from them are never included in the next level of search
					// Links to leaf nodes are retained if they are found at later levels
					if (node.IsLeaf)
						leafNodes.put(node.id, node);
				}
			}
		}
		
		// For each of the new Links 
		for (GraphController.Link Link : newLinks.values()) {
			// Don't add Links with the same ID. The ID consists of the source ID, the Target ID, and the Role
			if (Links.containsKey(Link.id)) continue;
			if (Link.toId == Link.fromId) continue; // We never follow recursive links
			
			// We only follow Links that are attached to a relevant node
			if (relevantNodes.containsKey(Link.fromId) || relevantNodes.containsKey(Link.toId)) {
				Link.depth = depth;
				Links.put(Link.id, Link);
				
				// We make a list of all the IDs that are in the next and current level
				// We never follow Links that are attached to Leaf nodes
				if (!leafNodes.containsKey(Link.fromId)) nextNodeIDs.add(Link.toId);
				if (!leafNodes.containsKey(Link.toId)) nextNodeIDs.add(Link.fromId);
			}
		}
		
		// We trim out any IDs that refer to nodes we have already spidered
		System.Debug(LoggingLevel.Debug, 'Pre-trim nodes: ' + nextNodeIDs);
		nextNodeIDs.removeAll(nodes.keySet());
		System.Debug(LoggingLevel.Debug, 'Post-trim nodes: ' + nextNodeIDs);
		
		return nextNodeIDs;
	}
	
	global String serialize {
		global get {
			return JSON.serialize(new JSONResult(nodeList, LinkList));
		}
	}
	
	// A helper class that allows the user-developed extension to return a list of nodes and Links
	global class Result {
		global Result(Map<Id, GraphController.Node> nodes, Map<String, GraphController.Link> Links) {
			this.nodes = nodes;
			this.Links = Links;
		}
		
		global Map<Id, GraphController.Node> nodes = new Map<Id, Node>();
		global Map<String, GraphController.Link> Links = new Map<String, Link>();
	}
	
	global class JSONResult {
		global JSONResult(List<GraphController.Node> nodes, List<GraphController.Link> Links) {
			this.nodes = nodes;
			this.links = Links;
		}
		
		global List<GraphController.Node> nodes = new List<Node>();
		global List<GraphController.Link> links = new List<Link>();
	}
	
	// Returns true if we are nearing one or more of the relevant governor limits
	private static Boolean nearLimits() {
		if (Limits.getQueryRows() >= (Limits.getLimitQueryRows() * 0.95)) return true;
		if (Limits.getQueries() >= (Limits.getLimitQueries() * 0.95)) return true;
		if (Limits.getCpuTime() >= (Limits.getLimitCpuTime() * 0.95)) return true;
		if (Limits.getHeapSize() >= (Limits.getLimitHeapSize() * 0.95)) return true;
		
		// Removed 2014-04-04 because script statement limits are no longer used
		// if (Limits.getScriptStatements() >= (Limits.getLimitScriptStatements() * 0.95)) return true;
		
		return false;
	}
	
	// A generic implementation of a Node
	global class Node implements Comparable {
		global String id {
			get;
			set {
				id = value;
				if (url == null) url = '/' + value;
			}
		}
		global String label {
			get;
			set {
				label = value;
				if (descr == null) descr = value;
			}
		}
		global String descr {get; set;}
		global String url {get; set;}
		
		global Decimal relevance {get; set;}
		
		global Boolean IsRoot {get; set;}
		global Boolean IsLeaf {get; set;}
		
		global String typ {get; set;}
		global Integer depth {get; set;}
		
		global Decimal decayedRelevance {get; set;}
		
		global Map<String, String> dat {get; set;}
		
		global Node() {
			this.IsRoot = false;
			this.IsLeaf = false;
			this.dat = new map<String, String>();
		}
		
		global Integer compareTo(Object compareTo) {
			GraphController.Node otherNode = (GraphController.Node)compareTo;
			return this.id.compareto(otherNode.id);
		}
	}
	
	// A generic implementation of an Link
	global class Link implements Comparable {
		
		global String id {get; private set;}
		
		global Id fromId {get; private set;}
		global Id toId {get; private set;}
		global String fromRole {get; private set;}
		global String toRole {get; private set;}
		
		global Decimal weight {get; set;}
		global String relationship {get; set;}
		
		global Integer depth {get; set;}
		
		global Map<String, String> dat {get; set;}
		
		// Create a new Link with a role
		global Link(Id fromId, Id toId, String fromRole, String toRole) {
			this.fromId = fromId;
			this.toId = toId;
			this.fromRole = fromRole;
			this.toRole = toRole;
			this.weight = 1.0;
			this.relationship = this.fromRole + ' -> ' + this.toRole;
			this.dat = new map<String, String>();
			
			this.id = this.fromRole + ':' + this.fromId + '->' + this.toRole + ':' + this.toId;
		}
		
		global Integer compareTo(Object compareTo) {
			GraphController.Link otherNode = (GraphController.Link)compareTo;
			return this.id.compareto(otherNode.id);
		}
	}
}