trigger OpportunityTrigger on Opportunity (after update) {

    if(Trigger.isAfter && Trigger.isUpdate){
        OpportunityTriggerHandler.afterUpdateHandler(Trigger.new, Trigger.oldMap);
    }

}
