/**
	Copyright (c) 2013, Cloud Sherpas, Inc.
	All rights reserved.
	
	Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
	* Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
	* Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
	
	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
	
	
 ** This class extends the capabilities of the GraphController class
 **/
global with sharing class GraphExtension extends GraphController {
	
			/*********************************************/
			/****** Configure the tool here **************/
			/*********************************************/
	
	// Customize the maximum recursion depth, minimum relevance, and decay rate
	global GraphExtension() {
		super();
		
		maxDepth = 4; // This is the maximum depth that we will spider under any circumstances
		minRelevance = 30.0; // This is the minimum "Decayed Relevance" (on a scale from 1.0 to 100.0) for a node to be spidered and displayed in the UI
		decayRate = 0.7; // The "Decayed Relevance" is a function of depth, the decay rate, and a relevance that you specify in getNodes()
	}
	
			/*********************************************/
	
	// This is where you specify the spidering logic for your graph
	// You do not need to worry about recursion or governor limits - those are all taken care of in the core application
	// HOWEVER - you are still limited by the Salesforce (read only) governor limits, which means:
	//   * You should make the minimum possible number of SOQL Queries necessary
	//   * You cannot make any DML calls
	//   * You should always use LIMIT statements for your sub-queries to avoid exceeding governor limits and to avoid overloading the UI
	//   * When querying a large amount of data, try to use restrictive queries wherever possible
	//   * You will be able to specify a relevance score (0.0 to 100.0) for the nodes you return, but you DO NOT HAVE TO RETURN A NODE for every ID you are passed
	
	global override GraphController.Result getNodes(String typ, Set<Id> IDs) {
		
		// These fields should not be changed... You must return a map of Nodes and a map of Links, even if one or both maps is empty
		Map<Id, GraphController.Node> myNodes = new Map<Id, GraphController.Node>();
		Map<String, GraphController.Link> myLinks = new Map<String, GraphController.Link>();
	
		// For each object type that you intend to display on the Graph, define a handler.
		// You may, but are not required to, return a node for each ID that you were provided
		// You may return additional nodes if you want, including nodes that were not requested.
		// 
		// You may, but are not required to, return one or more Links
		// You may return any number of Links, including Links that you do not return a node for.
		if (typ == 'Account') {
			//query account details and related cases, opportunity and account contact roles
			List<Account> lstObj = new List<Account>([SELECT Id, OwnerId, Owner.Name, Name, Description, ParentId, (SELECT Id FROM Cases), (Select Id FROM Opportunities), (Select Id, ContactId, Role From AccountContactRoles), (Select Id FROM Contacts) FROM Account WHERE (Id in :IDs)]);
			for (Account obj : lstObj) {
				// Create the node for this object
				GraphController.Node node = new GraphController.Node();
				node.id = obj.Id; // The Salesforce ID of the Node
				node.label = obj.Name; // The display label
				node.relevance = 100.0; // The raw relevance of this node. This number will be automatically discounted based on the depth of the node in the tree and the decay rate you specify above.
					// Relevance (actually the decayed relevance, which is a function of depth, decay rate, and your relevance) is used to:
						// * Determine the opacity of the node
						// * Determine the strength (the stretchiness) of the link
						// * Determine the opacity of the link
					// The relevance of a root node is always exactly 100.0
				node.typ = 'Account'; // The type of the Node. This is not used by the engine, but you may find it useful to distinguish different types of nodes by color in the UI.
				node.descr = obj.Description; // The description of this node
				myNodes.put(node.id, node);
				
				// Add this Account's Parent
				if (obj.ParentId != null) {
					GraphController.Link Link = new GraphController.Link(obj.Id, obj.ParentId, 'Child Account', 'Parent Account');
					myLinks.put(Link.id, Link);
				}
					
				// Create the list of Links. You don't need to worry about adding Nodes at this point, they will be queried 
				for (AccountContactRole role : obj.AccountContactRoles) {
					GraphController.Link Link = new GraphController.Link(role.ContactId, obj.Id, role.Role, 'Account');
					myLinks.put(Link.id, Link);
				}
				for (Contact contact : obj.Contacts) {
					GraphController.Link Link = new GraphController.Link(contact.Id, obj.Id, 'Contact', 'Account');
					myLinks.put(Link.id, Link);
				}
				for (Opportunity opportunity : obj.Opportunities) {
					GraphController.Link Link = new GraphController.Link(opportunity.Id, obj.Id, 'Opportunity', 'Account');
					myLinks.put(Link.id, Link);
				}
				for (Case cas : obj.Cases) {
					GraphController.Link Link = new GraphController.Link(cas.Id, obj.Id, 'Case', 'Account');
					myLinks.put(Link.id, Link);
				}
				
				//GraphController.Link ownerLink = new GraphController.Link(obj.Id, obj.OwnerId, 'Object', 'Owner');
				//ownerLink.relationship = 'Owner';
				//myLinks.put(ownerLink.id, ownerLink);
				
			}
		}
		else if (typ == 'Contact') {
			List<Contact> lstObj = new List<Contact>([SELECT Id, Name, Owner.Name, OwnerId, AccountId, Description, (Select Id FROM Cases), (Select Id, AccountId, ContactId, Role From AccountContactRoles), (Select Id, ContactId, OpportunityId, Role FROM OpportunityContactRoles) FROM Contact WHERE (Id in :IDs)]);
			for (Contact obj : lstObj) {
				GraphController.Node node = new GraphController.Node();
				node.id = obj.Id;
				node.label = obj.Name;
				node.relevance = 100.0;
				node.typ = 'Contact';
				node.descr = obj.Description;
				myNodes.put(node.id, node);
				
				for (AccountContactRole role : obj.AccountContactRoles) {
					GraphController.Link Link = new GraphController.Link(role.ContactId, role.AccountId, role.Role, 'Account');
					myLinks.put(Link.id, Link);
				}
				
				for (OpportunityContactRole role : obj.OpportunityContactRoles) {
					GraphController.Link Link = new GraphController.Link(role.ContactId, role.OpportunityId, role.Role, 'Opportunity');
					myLinks.put(Link.id, Link);
				}
				for (Case cas : obj.Cases) {
					GraphController.Link Link = new GraphController.Link(cas.Id, obj.Id, 'Case', 'Contact');
					myLinks.put(Link.id, Link);
				}
				
				GraphController.Link Link = new GraphController.Link(obj.Id, obj.AccountId, 'Contact', 'Account');
				myLinks.put(Link.id, Link);
				
				//GraphController.Link ownerLink = new GraphController.Link(obj.Id, obj.OwnerId, 'Object', 'Owner');
				//ownerLink.relationship = 'Owner';
				//myLinks.put(ownerLink.id, ownerLink);
			}
		}
		else if (typ == 'Case') {
			List<Case> lstObj = new List<Case>([SELECT Id, OwnerId, Owner.Name, CaseNumber, Subject, ContactId, AccountId FROM Case WHERE (Id in :IDs)]);
			for (Case obj : lstObj) {
				GraphController.Node node = new GraphController.Node();
				node.id = obj.Id;
				node.label =  obj.CaseNumber;
				node.relevance = 100.0;
				node.typ = 'Case';
				node.descr = obj.Subject;
				myNodes.put(node.id, node);
				
				GraphController.Link Link1 = new GraphController.Link(obj.Id, obj.AccountId, 'Case', 'Account');
				myLinks.put(Link1.id, Link1);
				
				GraphController.Link Link2 = new GraphController.Link(obj.Id, obj.ContactId, 'Case', 'Contact');
				myLinks.put(Link2.id, Link2);
				
				//GraphController.Link ownerLink = new GraphController.Link(obj.Id, obj.OwnerId, 'Object', 'Owner');
				//ownerLink.relationship = 'Owner';
				//myLinks.put(ownerLink.id, ownerLink);
			}
		}
		else if (typ == 'Opportunity') {
			List<Opportunity> lstObj = new List<Opportunity>([SELECT Id, OwnerId, Owner.Name, Name, Amount, StageName, AccountId, Description, (Select Id, ContactId, OpportunityId, Role FROM OpportunityContactRoles) FROM Opportunity WHERE (ID in :IDs)]);
			for (Opportunity obj : lstObj) {
				GraphController.Node node = new GraphController.Node();
				node.id = obj.Id;
				node.label = obj.Name;
				node.relevance = 100.0;
				node.typ = 'Opportunity';
				node.descr = obj.Description;
				myNodes.put(node.id, node);
				
				for (OpportunityContactRole role : obj.OpportunityContactRoles) {
					GraphController.Link Link = new GraphController.Link(role.ContactId, role.OpportunityId, role.Role, 'Opportunity');
					myLinks.put(Link.id, Link);
				}
				
				GraphController.Link Link1 = new GraphController.Link(obj.Id, obj.AccountId, 'Opportunity', 'Account');
				myLinks.put(Link1.id, Link1);
				
				//GraphController.Link ownerLink = new GraphController.Link(obj.Id, obj.OwnerId, 'Object', 'Owner');
				//ownerLink.relationship = 'Owner';
				//myLinks.put(ownerLink.id, ownerLink);
			}
		}
		// In this sample all of the links to User are commented out.
		// It could make sense to add links FROM the User, though if you wanted to do a graph of Cases, Opportunities, etc owned by a user.
		// If you do so, consider filtering the list to include (eg) only open Cases or only high-value Opportunities.
		else if (typ == 'User') {
			List<User> lstObj = new List<User>([SELECT Id, Name, ManagerId FROM User WHERE (ID in :IDs)]);
			for (User obj : lstObj) {
				GraphController.Node node = new GraphController.Node();
				node.id = obj.Id;
				node.label = obj.Name;
				node.relevance = 100.0;
				node.typ = 'User';
				node.descr = obj.Name;
				node.IsLeaf = true;
				myNodes.put(node.id, node);
				
				GraphController.Link Link = new GraphController.Link(obj.Id, obj.ManagerId, 'User', 'Manager');
				Link.relationship = 'Manager';
				myLinks.put(Link.id, Link);
			}
		}
		
		return new GraphController.Result(myNodes, myLinks);
	}
}