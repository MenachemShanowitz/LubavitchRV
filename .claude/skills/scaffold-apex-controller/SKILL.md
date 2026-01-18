# Scaffold Apex Controller

Creates a new Apex controller with a matching test class, following OneCRM patterns.

## Arguments

`ControllerName` - The name of the controller (e.g., `DonorReportController`)

## Files Created

### 1. Controller: `force-app/main/default/classes/{ControllerName}.cls`

```apex
/**
 * Controller for {description}
 */
public with sharing class {ControllerName} {

    // Record Type IDs for Income (if needed)
    private static Id chargeRecordTypeId {
        get {
            if (chargeRecordTypeId == null) {
                chargeRecordTypeId = Schema.SObjectType.OneCRM__Income__c
                    .getRecordTypeInfosByDeveloperName().get('Charge').getRecordTypeId();
            }
            return chargeRecordTypeId;
        }
        set;
    }

    private static Id paymentRecordTypeId {
        get {
            if (paymentRecordTypeId == null) {
                paymentRecordTypeId = Schema.SObjectType.OneCRM__Income__c
                    .getRecordTypeInfosByDeveloperName().get('Payment').getRecordTypeId();
            }
            return paymentRecordTypeId;
        }
        set;
    }

    /**
     * Example wrapper class
     */
    public class DataWrapper {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        // Add fields as needed
    }

    /**
     * Example method
     */
    @AuraEnabled(cacheable=true)
    public static List<DataWrapper> getData() {
        List<DataWrapper> results = new List<DataWrapper>();
        // Implementation
        return results;
    }
}
```

### 2. Controller Meta: `force-app/main/default/classes/{ControllerName}.cls-meta.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<ApexClass xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>62.0</apiVersion>
    <status>Active</status>
</ApexClass>
```

### 3. Test Class: `force-app/main/default/classes/{ControllerName}Test.cls`

```apex
/**
 * Test class for {ControllerName}
 */
@isTest
private class {ControllerName}Test {

    @TestSetup
    static void setupTestData() {
        // 1. Create Account (Household)
        Account testAccount = new Account(Name = 'Test Household');
        insert testAccount;

        // 2. Create Contact
        Contact testContact = new Contact(
            FirstName = 'John',
            LastName = 'Doe',
            Email = 'johndoe@test.com',
            AccountId = testAccount.Id
        );
        insert testContact;

        // 3. IMPORTANT: Set primary contact relationship
        testAccount.OneCRM__Primary_Contact__c = testContact.Id;
        update testAccount;

        // 4. Create Campaign (if needed)
        Campaign testCampaign = new Campaign(
            Name = 'Test Campaign',
            Type = 'Membership',
            IsActive = true
        );
        insert testCampaign;

        // 5. Create Income records with correct RecordTypes (if needed)
        Id chargeRT = Schema.SObjectType.OneCRM__Income__c
            .getRecordTypeInfosByDeveloperName().get('Charge').getRecordTypeId();
        Id paymentRT = Schema.SObjectType.OneCRM__Income__c
            .getRecordTypeInfosByDeveloperName().get('Payment').getRecordTypeId();

        // Create a Charge (Pledge)
        OneCRM__Income__c testCharge = new OneCRM__Income__c(
            RecordTypeId = chargeRT,
            OneCRM__Donor__c = testAccount.Id,
            OneCRM__Related_Contact__c = testContact.Id,
            OneCRM__Date__c = Date.today(),
            OneCRM__Paid__c = 0,
            OneCRM__Status__c = 'Success'
        );
        insert testCharge;
    }

    @isTest
    static void testGetData() {
        Test.startTest();
        List<{ControllerName}.DataWrapper> results = {ControllerName}.getData();
        Test.stopTest();

        // Add assertions
        System.assertNotEquals(null, results, 'Results should not be null');
    }
}
```

### 4. Test Class Meta: `force-app/main/default/classes/{ControllerName}Test.cls-meta.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<ApexClass xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>62.0</apiVersion>
    <status>Active</status>
</ApexClass>
```

## Key Patterns Included

- **Lazy-loaded Record Type IDs** - Cached for performance
- **Wrapper classes with @AuraEnabled** - For LWC compatibility
- **@TestSetup with OneCRM relationships** - Includes setting `OneCRM__Primary_Contact__c`
- **with sharing** - Enforces security by default

## After Scaffolding

1. Customize the controller methods for your use case
2. Update the test class with appropriate assertions
3. Deploy using: `sf project deploy start --source-dir force-app/main/default/classes/{ControllerName}.cls --source-dir force-app/main/default/classes/{ControllerName}Test.cls --target-org lubavitchrv_partial --wait 10`
