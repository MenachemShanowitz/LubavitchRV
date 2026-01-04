trigger Hebrew_Date_Relationship on OneCRM__Relationship__c (before insert, before update)
{
	if (Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate))
	{
		new HCal.TriggerApplicator(Trigger.new, 'OneCRM__Relationship__c').Apply();
	}
}