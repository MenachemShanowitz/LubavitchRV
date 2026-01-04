@IsTest
public with sharing class Test_TriggerApplicator
{
	@IsTest
	private static void TriggerApplicatorForCampaign()
	{
		List<HCal__Date_Conversion_Config__mdt> customDateConversions = new List<HCal__Date_Conversion_Config__mdt>();

		customDateConversions.add(new HCal__Date_Conversion_Config__mdt(
				HCal__After_Sunset_Indicator__c = 'OneCRM__Wedding_After_Sunset__c',
				HCal__Date_Type__c = 'Anniversary',
				HCal__Field_Name__c = 'OneCRM__Wedding_Date__c',
				HCal__Hebrew_Date_Field__c = 'OneCRM__Hebrew_Wedding_Date__c',
				HCal__Is_Active__c = true,
				HCal__Next_Occurrence__c = 'OneCRM__Civil_Date_Of_Next_Hebrew_Anniversary__c',
				HCal__Next_Occurrence_Hebrew__c = 'OneCRM__Next_Hebrew_Anniversary__c',
				HCal__SObject_Name__c = 'OneCRM__Relationship__c'
		));



		Account act = new Account(Name = 'Test', RecordTypeId = getRecordTypeId('Account'));
		insert act;

		Id contactRtId = getRecordTypeId('Contact');

		List<Contact> contacts = new List<Contact>();

		Contact newContact = new Contact();
		newContact.put('LastName', 'Shanowitz');
		newContact.put('RecordTypeId', contactRtId);
		contacts.add(newContact);
		newContact = new Contact();
		newContact.put('FirstName', 'WifeA');
		newContact.put('LastName', 'Shanowitz');
		newContact.put('RecordTypeId', contactRtId);
		contacts.add(newContact);

		insert contacts;

		insert new OneCRM__Relationship__c(
				OneCRM__Related_Contact__c = contacts[0].Id,
				OneCRM__Account__c = act.Id,
				OneCRM__Contact__c = contacts[1].Id,
				OneCRM__Type__c = 'Wife',
				OneCRM__Wedding_Date__c = Date.NewInstance(1995, 1, 7)
		);

	/*List<OneCRM__Relationship__c> records = [SELECT Id,
				OneCRM__Contact__r.OneCRM__Wedding_Date__c,
				OneCRM__Wedding_Date__c,
				OneCRM__Civil_Date_Of_Next_Hebrew_Anniversary__c,
				OneCRM__Hebrew_Wedding_Date__c
		FROM OneCRM__Relationship__c];*/
 		// new TriggerApplicator(records, customDateConversions, 'Campaign').Apply();
//		System.assert(records[0].OneCRM__Wedding_Date__c == OneCRM__Contact__r.OneCRM__Wedding_Date__c, 'wedding date did not carry over to the contact');
//		System.assert(records[0].OneCRM__Hebrew_Wedding_Date__c == OneCRM__Contact__r.OneCRM__Hebrew_Wedding_Date__c, 'hebrew wedding date did not carry over to the contact');
//		System.assert(records[0].OneCRM__Hebrew_Wedding_Date__c != null, 'Hebrew_Date_Field__c not set');
//		System.assert(records[0].OneCRM__Civil_Date_Of_Next_Hebrew_Anniversary__c != null, 'Next_Occurrence__c not set');
//		System.assert(records[0].OneCRM__Next_Hebrew_Anniversary__c == '6 Shevat, 5756', 'wrong date');
//		System.assert(records[0].OneCRM__Hebrew_Wedding_Date__c == '6 Shevat, 5755', 'wrong date');
	}

	private static Id getRecordTypeId(String sObjectType)
	{
		List<RecordType> recordTypes = [SELECT Id FROM RecordType WHERE SObjectType = :sObjectType AND NamespacePrefix = 'OneCRM'];

		if (recordTypes.size() > 0)
		{
			return recordTypes[0].Id;
		}
		return null;
	}
 }