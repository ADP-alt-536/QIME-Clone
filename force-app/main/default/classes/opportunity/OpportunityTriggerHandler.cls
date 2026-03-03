public class OpportunityTriggerHandler {

    public static void afterUpdateHandler(List<Opportunity> newOpps, Map<Id, Opportunity> oldMap){
        List<Id> paidOppIds = new List<Id>();
        for(Opportunity opp : newOpps){
            Opportunity oldOpp = oldMap.get(opp.Id);
            if(opp.StageName == 'Paid' && oldOpp.StageName != 'Paid'){
                paidOppIds.add(opp.Id);
            }
        }
        if(!paidOppIds.isEmpty()){
            processInvoiceCreation(paidOppIds);
        }
    }

    @future(callout=true)
    public static void processInvoiceCreation(List<Id> oppIds){
        List<Opportunity> opps = [SELECT Id, Name, Amount, StageName, CloseDate,
                                        QuickBooks_Invoice__c,
                                        PAC_Amount__c,
                                        QuickBooks_Discount_Amount__c,
                                        RecordType.Name,
                                        AccountId,
                                        Account.Id,
                                        Account.Name,
                                        Account.QuickBooks_Customer_Id__c,
                                        Account.qime__QB_Id__c,
                                        Account.qime__QB_SyncToken__c,
                                        Account.qime__Taxable__c,
                                        Account.qime__Tax_Exemption_Reason__c,
                                        Account.ShippingCity,
                                        Account.ShippingStreet,
                                        Account.ShippingState,
                                        Account.ShippingCountry,
                                        Account.ShippingPostalCode,
                                        Account.Phone,
                                        Account.BillingCity,
                                        Account.BillingStreet,
                                        Account.BillingCountry,
                                        Account.BillingPostalCode,
                                        Account.BillingState,
                                        Account.BillingLatitude,
                                        Account.BillingLongitude
                                    FROM Opportunity
                                    WHERE Id IN :oppIds];

        for(Opportunity opp : opps){
            try{
                String customerId = opp.Account.QuickBooks_Customer_Id__c;

                // Phase 1: Ensure QB Customer exists
                if(String.isBlank(customerId)){
                    customerId = QBMap.syncCustomer(opp.Account);
                }

                // Phase 2: Create Invoice with dynamic line items
                String invoiceJson = QBMap.mapOpportunityInvoice(opp, customerId);
                QBInvoiceResponseJSON invoiceResponse = QBCallout.createInvoice(invoiceJson);

                if(invoiceResponse?.Invoice?.Id != null){
                    String invoiceId = invoiceResponse.Invoice.Id;
                    Decimal invoiceTotal = opp.Amount != null ? opp.Amount : 0;
                    if(opp.PAC_Amount__c != null) invoiceTotal += opp.PAC_Amount__c;
                    if(opp.QuickBooks_Discount_Amount__c != null) invoiceTotal -= opp.QuickBooks_Discount_Amount__c;

                    // Phase 2: Create Payment linked to the invoice
                    String paymentJson = QBMap.mapPaymentForInvoice(customerId, invoiceId, invoiceTotal);
                    QBCallout.createPayment(paymentJson);
                }
            } catch(Exception e){
                System.debug('OpportunityTriggerHandler error for opp ' + opp.Id + ': ' + e.getMessage());
            }
        }
    }
}
