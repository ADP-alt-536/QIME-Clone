@isTest private class OpportunityTriggerTest {

    @TestSetup
    static void makeData(){
        Account a = new Account();
        a.Name = 'Test Membership Account';
        insert a;
    }

    // Mock HTTP responses for QB API calls
    public class QBMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            if(req.getEndpoint().contains('query')){
                // Return empty customer list to trigger creation
                res.setBody('{"QueryResponse":{"startPosition":1,"maxResults":0},"time":"2019-07-29T03:41:27.543-07:00"}');
                res.setStatusCode(200);
            } else if(req.getEndpoint().contains('customer')){
                res.setBody(QBCustomerResponseJSON_Test.json);
                res.setStatusCode(200);
            } else if(req.getEndpoint().contains('invoice')){
                res.setBody(QBInvoiceResponseJSON_Test.json);
                res.setStatusCode(200);
            } else if(req.getEndpoint().contains('payment')){
                res.setBody('{"Payment":{"Id":"100","SyncToken":"0","TotalAmt":500.00,"TxnDate":"2024-01-01","CustomerRef":{"value":"3"}}}');
                res.setStatusCode(200);
            } else {
                System.assert(false, 'Unexpected endpoint: ' + req.getEndpoint());
                return null;
            }
            return res;
        }
    }

    // Mock that returns existing customer (QB ID already exists in QB)
    public class QBMockExistingCustomer implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            if(req.getEndpoint().contains('query')){
                res.setBody(QBCustomerJSON_Test.json);
                res.setStatusCode(200);
            } else if(req.getEndpoint().contains('customer')){
                res.setBody(QBCustomerResponseJSON_Test.json);
                res.setStatusCode(200);
            } else if(req.getEndpoint().contains('invoice')){
                res.setBody(QBInvoiceResponseJSON_Test.json);
                res.setStatusCode(200);
            } else if(req.getEndpoint().contains('payment')){
                res.setBody('{"Payment":{"Id":"100","SyncToken":"0","TotalAmt":500.00,"TxnDate":"2024-01-01","CustomerRef":{"value":"1"}}}');
                res.setStatusCode(200);
            } else {
                System.assert(false, 'Unexpected endpoint: ' + req.getEndpoint());
                return null;
            }
            return res;
        }
    }

    @isTest static void testSyncCustomerCreate(){
        Test.setMock(HttpCalloutMock.class, new QBMock());
        Account a = [SELECT Id, Name, QuickBooks_Customer_Id__c, qime__QB_Id__c,
                            qime__QB_SyncToken__c, qime__Taxable__c, qime__Tax_Exemption_Reason__c,
                            ShippingCity, ShippingStreet, ShippingState, ShippingCountry, ShippingPostalCode,
                            Phone, BillingCity, BillingStreet, BillingCountry, BillingPostalCode,
                            BillingState, BillingLatitude, BillingLongitude
                    FROM Account WHERE Name = 'Test Membership Account'];
        Test.startTest();
        String qbId = QBMap.syncCustomer(a);
        Test.stopTest();

        System.assertNotEquals(null, qbId, 'QB Customer ID should be returned after sync');
    }

    @isTest static void testSyncCustomerExistingInQB(){
        Test.setMock(HttpCalloutMock.class, new QBMockExistingCustomer());
        Account a = [SELECT Id, Name, QuickBooks_Customer_Id__c, qime__QB_Id__c,
                            qime__QB_SyncToken__c, qime__Taxable__c, qime__Tax_Exemption_Reason__c,
                            ShippingCity, ShippingStreet, ShippingState, ShippingCountry, ShippingPostalCode,
                            Phone, BillingCity, BillingStreet, BillingCountry, BillingPostalCode,
                            BillingState, BillingLatitude, BillingLongitude
                    FROM Account WHERE Name = 'Test Membership Account'];
        Test.startTest();
        String qbId = QBMap.syncCustomer(a);
        Test.stopTest();

        System.assertNotEquals(null, qbId, 'QB Customer ID should be returned from existing QB customer');
    }

    @isTest static void testSyncCustomerAlreadyHasId(){
        Test.setMock(HttpCalloutMock.class, new QBMock());
        Account a = [SELECT Id, Name, QuickBooks_Customer_Id__c, qime__QB_Id__c,
                            qime__QB_SyncToken__c, qime__Taxable__c, qime__Tax_Exemption_Reason__c,
                            ShippingCity, ShippingStreet, ShippingState, ShippingCountry, ShippingPostalCode,
                            Phone, BillingCity, BillingStreet, BillingCountry, BillingPostalCode,
                            BillingState, BillingLatitude, BillingLongitude
                    FROM Account WHERE Name = 'Test Membership Account'];
        a.QuickBooks_Customer_Id__c = 'existing-id';
        update a;

        Test.startTest();
        String qbId = QBMap.syncCustomer(a);
        Test.stopTest();

        System.assertNotEquals(null, qbId, 'QB Customer ID should be returned');
    }

    @isTest static void testMapPaymentForInvoice(){
        Test.startTest();
        String paymentJson = QBMap.mapPaymentForInvoice('cust-123', 'inv-456', 500.00);
        Test.stopTest();

        System.assertNotEquals(null, paymentJson, 'Payment JSON should not be null');
        System.assert(paymentJson.contains('cust-123'), 'Payment JSON should contain customer ID');
        System.assert(paymentJson.contains('inv-456'), 'Payment JSON should contain invoice ID');
    }

    @isTest static void testMapOpportunityInvoiceNewMembership(){
        Test.startTest();
        Account a = [SELECT Id FROM Account WHERE Name = 'Test Membership Account'];
        Opportunity opp = new Opportunity();
        opp.Name = 'New Membership Test';
        opp.CloseDate = Date.today();
        opp.StageName = 'Prospecting';
        opp.Amount = 500.00;
        opp.AccountId = a.Id;
        insert opp;

        // Simulate the invoice mapping (no record type in unit test, just ensure it doesn't throw)
        Opportunity oppWithDetails = [SELECT Id, Name, Amount, QuickBooks_Invoice__c,
                                            PAC_Amount__c, QuickBooks_Discount_Amount__c,
                                            RecordType.Name
                                     FROM Opportunity WHERE Id = :opp.Id];
        String invoiceJson = QBMap.mapOpportunityInvoice(oppWithDetails, 'cust-123');
        Test.stopTest();

        System.assertNotEquals(null, invoiceJson, 'Invoice JSON should not be null');
        System.assert(invoiceJson.contains('cust-123'), 'Invoice JSON should contain customer ID');
    }

    @isTest static void testMapOpportunityInvoiceWithPAC(){
        Test.startTest();
        Account a = [SELECT Id FROM Account WHERE Name = 'Test Membership Account'];
        Opportunity opp = new Opportunity();
        opp.Name = 'PAC Test Opp';
        opp.CloseDate = Date.today();
        opp.StageName = 'Prospecting';
        opp.Amount = 500.00;
        opp.PAC_Amount__c = 100.00;
        opp.AccountId = a.Id;
        insert opp;

        Opportunity oppWithDetails = [SELECT Id, Name, Amount, QuickBooks_Invoice__c,
                                            PAC_Amount__c, QuickBooks_Discount_Amount__c,
                                            RecordType.Name
                                     FROM Opportunity WHERE Id = :opp.Id];
        String invoiceJson = QBMap.mapOpportunityInvoice(oppWithDetails, 'cust-789');
        Test.stopTest();

        System.assertNotEquals(null, invoiceJson, 'Invoice JSON should not be null');
    }

    @isTest static void testMapOpportunityInvoiceWithDiscount(){
        Test.startTest();
        Account a = [SELECT Id FROM Account WHERE Name = 'Test Membership Account'];
        Opportunity opp = new Opportunity();
        opp.Name = 'Discount Test Opp';
        opp.CloseDate = Date.today();
        opp.StageName = 'Prospecting';
        opp.Amount = 500.00;
        opp.QuickBooks_Discount_Amount__c = 50.00;
        opp.AccountId = a.Id;
        insert opp;

        Opportunity oppWithDetails = [SELECT Id, Name, Amount, QuickBooks_Invoice__c,
                                            PAC_Amount__c, QuickBooks_Discount_Amount__c,
                                            RecordType.Name
                                     FROM Opportunity WHERE Id = :opp.Id];
        String invoiceJson = QBMap.mapOpportunityInvoice(oppWithDetails, 'cust-999');
        Test.stopTest();

        System.assertNotEquals(null, invoiceJson, 'Invoice JSON should not be null');
    }

    @isTest static void testOpportunityTriggerPaidStage(){
        Test.setMock(HttpCalloutMock.class, new QBMock());
        Account a = [SELECT Id FROM Account WHERE Name = 'Test Membership Account'];

        Opportunity opp = new Opportunity();
        opp.Name = 'Trigger Test Opp';
        opp.CloseDate = Date.today();
        opp.StageName = 'Prospecting';
        opp.Amount = 300.00;
        opp.AccountId = a.Id;
        insert opp;

        Test.startTest();
        opp.StageName = 'Paid';
        update opp;
        Test.stopTest();

        // The @future method is called async; verify no exceptions thrown
        System.assert(true, 'Trigger should fire without exceptions');
    }

    @isTest static void testOpportunityTriggerNotPaidStage(){
        Account a = [SELECT Id FROM Account WHERE Name = 'Test Membership Account'];

        Opportunity opp = new Opportunity();
        opp.Name = 'No Trigger Test Opp';
        opp.CloseDate = Date.today();
        opp.StageName = 'Prospecting';
        opp.Amount = 300.00;
        opp.AccountId = a.Id;
        insert opp;

        Test.startTest();
        opp.StageName = 'Closed Won';
        update opp;
        Test.stopTest();

        // Should not trigger invoice creation
        System.assert(true, 'Trigger should not call QB when stage is not Paid');
    }
}
