/**
	Copyright (c) 2013, Cloud Sherpas, Inc.
	All rights reserved.
	
	Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
	* Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
	* Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
	
	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
	
	
 ** This test code is highly dependent on the individual logic of the GraphExtension, and so is superficial in this reference implementation
 **/
 @IsTest
public with sharing class testGraphExtension {
	static Account pAcc, acc;
	static Contact cont;
	static AccountContactRole acr;
	static Opportunity oppt;
	static Case c;
	static OpportunityContactRole ocr;
	static Profile p;
	static User pu, u;
	
	static {
    	pAcc = new Account();
    	pAcc.Name = 'Parent Account Name';
    	
    	acc = new Account();
    	acc.Name = 'Account Name';
    	
    	cont = new Contact();
    	cont.FirstName = 'First Name';
    	cont.LastName = 'Last Name';
    	
    	acr = new AccountContactRole();
    	acr.Role = 'Account';
    	
    	oppt = new Opportunity();
    	oppt.Name = 'Opportunity';
    	oppt.CloseDate = Date.today();
    	oppt.StageName = 'Prospecting';
    	
    	c = new Case();
    	c.Status = 'New';
    	c.Origin = 'Email';
    	
    	ocr = new OpportunityContactRole();
    	ocr.Role = 'Opportunity';
    	
    	p = [SELECT Id FROM Profile WHERE Name='Standard User'];
        pu = new User();
        pu.Alias = 'standt';
        pu.Email = 'standarduser@testorg.com';
        pu.EmailEncodingKey = 'UTF-8';
        pu.LastName = 'User';
        pu.LanguageLocaleKey = 'en_US';
        pu.LocaleSidKey = 'en_US';
        pu.ProfileId = p.Id;
        pu.TimeZoneSidKey = 'America/Los_Angeles';
        pu.Username = 'parentuser@testorg.com';
        
        u = new User();
        u.Alias = 'standt';
        u.Email = 'standarduser@testorg.com';
        u.EmailEncodingKey = 'UTF-8';
        u.LastName = 'User';
        u.LanguageLocaleKey = 'en_US';
        u.LocaleSidKey = 'en_US';
        u.ProfileId = p.Id;
        u.TimeZoneSidKey = 'America/Los_Angeles';
        u.Username = 'standuser@testorg.com';
        
        
        
		//insert parent user
		insert pu;
		//insert User
		u.ManagerId = pu.Id;
		insert u;
		//insert Parent Account
		pAcc.OwnerId = u.Id;
		insert pAcc;
		acc.ParentId = pAcc.Id;
		acc.OwnerId = u.Id;
		//insert Account with Parent Account
		insert acc;
		//insert Contact record
		cont.AccountId = acc.Id;
		cont.OwnerId = u.Id;
		insert cont;
		//insert Account Contact Role
		acr.AccountId = acc.Id;
		acr.ContactId = cont.Id;
		insert acr;
		//insert Opportunity record
		oppt.AccountId = acc.Id;
		oppt.OwnerId = u.Id;
		insert oppt;
		//insert Case record
		c.AccountId = acc.Id;
		c.ContactId = cont.Id;
		c.OwnerId = u.Id;
		insert c;
		//insert OpportunityContactRole
		ocr.ContactId = cont.Id;
		ocr.OpportunityId = oppt.Id;
		insert ocr;
	}
	
	// Confirm that the basic spider function works properly when used out of the box
	static testMethod void testGraphController1() {
    	test.startTest();
    		
    		// Set up the test page
	        PageReference testPage = Page.GraphData;
	        testPage.getParameters().put('id', acc.Id);
	        Test.setCurrentPage(testPage);
	        GraphExtension graphExt = new GraphExtension();
	        
	        // Spider the test page
	        graphExt.spider();
	        
        test.stopTest();
        
        System.Assert(graphExt.rootNodes.containsKey(acc.Id)); // The root node list contains the input node
        
        System.AssertEquals(5, graphExt.nodeList.size());
        for (GraphController.Node node: graphExt.nodeList) {
        	if (node.id == (String)acc.Id) {
        		System.Assert(node.IsRoot);
        		System.AssertEquals(0, node.depth);
        	}
        	
        	System.AssertNotEquals(node.Id, u.Id);
        }
        
        System.AssertEquals(7, graphExt.LinkList.size());
        for (GraphController.Link Link: graphExt.LinkList) {
        	if (Link.fromId == (String)acc.Id) {
        		System.AssertEquals(0, Link.depth);
        	}
        	
        	System.AssertNotEquals(Link.toId, u.Id);
        	System.AssertNotEquals(Link.fromId, u.Id);
        }
    }
    
	// Confirm that the basic spider function works properly when used out of the box
	static testMethod void testGraphController2() {
    	test.startTest();
    		
    		// Set up the test page
	        PageReference testPage = Page.GraphData;
	        testPage.getParameters().put('id', acc.Id + ',' + u.Id);
	        Test.setCurrentPage(testPage);
	        GraphExtension graphExt = new GraphExtension();
	        
	        // Spider the test page
	        graphExt.spider();
	        
        test.stopTest();
        
        System.Assert(graphExt.rootNodes.containsKey(acc.Id)); // The root node list contains the input node
        
        // We have two root nodes this time
        System.AssertEquals(6, graphExt.nodeList.size());
        for (GraphController.Node node: graphExt.nodeList) {
        	if (node.id == (String)acc.Id) {
        		System.Assert(node.IsRoot);
        		System.AssertEquals(0, node.depth);
        	}
        	if (node.id == (String)u.Id) {
        		System.Assert(node.IsRoot);
        		System.AssertEquals(0, node.depth);
        	}
        }
        
        // We do NOT have any additional Links
        System.AssertEquals(7, graphExt.LinkList.size());
        for (GraphController.Link Link: graphExt.LinkList) {
        	System.AssertNotEquals(Link.toId, u.Id);
        	System.AssertNotEquals(Link.fromId, u.Id);
        }
    }
}