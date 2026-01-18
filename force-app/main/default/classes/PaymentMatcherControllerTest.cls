/**
 * Test class for PaymentMatcherController
 */
@isTest
private class PaymentMatcherControllerTest {

    @TestSetup
    static void setupTestData() {
        // Create test Account (Household)
        Account testAccount = new Account(
            Name = 'Doe Household'
        );
        insert testAccount;

        // Create primary contact
        Contact testContact = new Contact(
            FirstName = 'John',
            LastName = 'Doe',
            Email = 'johndoe@test.com',
            AccountId = testAccount.Id
        );
        insert testContact;

        // Create secondary contact
        Contact secondaryContact = new Contact(
            FirstName = 'Jane',
            LastName = 'Doe',
            Email = 'janedoe@test.com',
            AccountId = testAccount.Id
        );
        insert secondaryContact;

        // Set primary and secondary contacts on the account
        testAccount.OneCRM__Primary_Contact__c = testContact.Id;
        testAccount.OneCRM__Secondary_Contact__c = secondaryContact.Id;
        update testAccount;

        // Create a Campaign for the charge
        Campaign testCampaign = new Campaign(
            Name = 'Test Membership Campaign',
            Type = 'Membership',
            IsActive = true
        );
        insert testCampaign;

        // Get record type IDs
        Id chargeRT = Schema.SObjectType.OneCRM__Income__c
            .getRecordTypeInfosByDeveloperName().get('Charge').getRecordTypeId();
        Id paymentRT = Schema.SObjectType.OneCRM__Income__c
            .getRecordTypeInfosByDeveloperName().get('Payment').getRecordTypeId();

        // Create a Charge (Pledge)
        OneCRM__Income__c testCharge = new OneCRM__Income__c(
            RecordTypeId = chargeRT,
            OneCRM__Donor__c = testAccount.Id,
            OneCRM__Related_Contact__c = testContact.Id,
            OneCRM__Date__c = Date.today().addDays(-30),
            OneCRM__Paid__c = 0,
            OneCRM__Status__c = 'Success'
        );
        insert testCharge;

        // Create Charge Line Item
        OneCRM__Income_Line_Item__c chargeLineItem = new OneCRM__Income_Line_Item__c(
            OneCRM__Income__c = testCharge.Id,
            OneCRM__Donor__c = testAccount.Id,
            OneCRM__Related_Contact__c = testContact.Id,
            OneCRM__Amount__c = 500,
            OneCRM__Related_Campaign__c = testCampaign.Id,
            OneCRM__Type__c = 'Campaign',
            OneCRM__Notes__c = 'Test pledge notes'
        );
        insert chargeLineItem;

        // Create an existing Payment for duplicate testing
        OneCRM__Income__c existingPayment = new OneCRM__Income__c(
            RecordTypeId = paymentRT,
            OneCRM__Donor__c = testAccount.Id,
            OneCRM__Related_Contact__c = testContact.Id,
            OneCRM__Date__c = Date.today().addDays(-5),
            OneCRM__Paid__c = 0,
            OneCRM__Status__c = 'Success',
            OneCRM__Payment_Type__c = 'Paypal'
        );
        insert existingPayment;

        // Create Payment Line Item
        OneCRM__Income_Line_Item__c paymentLineItem = new OneCRM__Income_Line_Item__c(
            OneCRM__Income__c = existingPayment.Id,
            OneCRM__Donor__c = testAccount.Id,
            OneCRM__Related_Contact__c = testContact.Id,
            OneCRM__Amount__c = -100,
            OneCRM__Related_Income__c = testCharge.Id,
            OneCRM__Related_Income_Line_Item__c = chargeLineItem.Id,
            OneCRM__Notes__c = 'Existing payment notes'
        );
        insert paymentLineItem;

        // Create Payment Import records
        List<Payment_Import__c> imports = new List<Payment_Import__c>();

        imports.add(new Payment_Import__c(
            Amount__c = 100,
            Date__c = Date.today(),
            First_Name__c = 'John',
            Last_Name__c = 'Doe',
            Email__c = 'johndoe@test.com',
            Is_Membership__c = true,
            Notes__c = 'Test payment notes',
            Payment_Type__c = 'Paypal',
            Status__c = 'New'
        ));

        imports.add(new Payment_Import__c(
            Amount__c = 200,
            Date__c = Date.today().addDays(-1),
            First_Name__c = 'Jane',
            Last_Name__c = 'Smith',
            Email__c = 'janesmith@test.com',
            Is_Membership__c = false,
            Notes__c = 'Another test payment',
            Payment_Type__c = 'Paypal',
            Status__c = 'New'
        ));

        imports.add(new Payment_Import__c(
            Amount__c = 150,
            Date__c = Date.today().addDays(-2),
            First_Name__c = 'Bob',
            Last_Name__c = 'Wilson',
            Status__c = 'Contact Matched'
        ));

        insert imports;
    }

    @isTest
    static void testGetPaymentImports() {
        Test.startTest();

        // Test with 'All' filter
        List<PaymentMatcherController.PaymentImportWrapper> allImports =
            PaymentMatcherController.getPaymentImports('All');
        System.assertEquals(3, allImports.size(), 'Should return all 3 imports');

        // Test with 'New' filter
        List<PaymentMatcherController.PaymentImportWrapper> newImports =
            PaymentMatcherController.getPaymentImports('New');
        System.assertEquals(2, newImports.size(), 'Should return 2 new imports');

        // Test with 'Contact Matched' filter
        List<PaymentMatcherController.PaymentImportWrapper> matchedImports =
            PaymentMatcherController.getPaymentImports('Contact Matched');
        System.assertEquals(1, matchedImports.size(), 'Should return 1 matched import');

        Test.stopTest();
    }

    @isTest
    static void testGetPaymentImport() {
        Payment_Import__c testImport = [SELECT Id FROM Payment_Import__c LIMIT 1];

        Test.startTest();
        PaymentMatcherController.PaymentImportWrapper wrapper =
            PaymentMatcherController.getPaymentImport(testImport.Id);
        Test.stopTest();

        System.assertNotEquals(null, wrapper, 'Wrapper should not be null');
        System.assertEquals(testImport.Id, wrapper.id, 'IDs should match');
    }

    @isTest
    static void testFindHouseholdMatches() {
        Test.startTest();

        // Get the test account for comparison
        Account testAccount = [SELECT Id, Name FROM Account LIMIT 1];

        // Test primary email match
        List<PaymentMatcherController.HouseholdMatch> primaryEmailMatches =
            PaymentMatcherController.findHouseholdMatches('johndoe@test.com', 'John', 'Doe');
        System.assert(!primaryEmailMatches.isEmpty(), 'Should find household by primary email');
        System.assertEquals(100, primaryEmailMatches[0].confidence, 'Primary email match should have 100 confidence');
        System.assertNotEquals(null, primaryEmailMatches[0].name, 'Should return household name');
        System.assertEquals(testAccount.Id, primaryEmailMatches[0].id, 'Should return correct household');
        System.assertEquals('johndoe@test.com', primaryEmailMatches[0].primaryContactEmail, 'Should have primary contact email');
        System.assertEquals('janedoe@test.com', primaryEmailMatches[0].secondaryContactEmail, 'Should have secondary contact email');

        // Test secondary email match
        List<PaymentMatcherController.HouseholdMatch> secondaryEmailMatches =
            PaymentMatcherController.findHouseholdMatches('janedoe@test.com', 'Jane', 'Doe');
        System.assert(!secondaryEmailMatches.isEmpty(), 'Should find household by secondary email');
        System.assertEquals(100, secondaryEmailMatches[0].confidence, 'Secondary email match should have 100 confidence');

        // Test household name match (using actual account name)
        // Note: OneCRM may rename accounts - search for part of the actual name
        String accountNamePart = testAccount.Name.length() > 3 ? testAccount.Name.substring(0, 4) : testAccount.Name;
        List<PaymentMatcherController.HouseholdMatch> nameMatches =
            PaymentMatcherController.findHouseholdMatches(null, 'Unknown', accountNamePart);
        System.assert(!nameMatches.isEmpty(), 'Should find household by name: ' + accountNamePart);

        // Test primary contact name match (when no email match)
        List<PaymentMatcherController.HouseholdMatch> contactNameMatches =
            PaymentMatcherController.findHouseholdMatches('nonexistent@test.com', 'John', 'Doe');
        // May find by contact name even if email doesn't match

        // Test no match
        List<PaymentMatcherController.HouseholdMatch> noMatches =
            PaymentMatcherController.findHouseholdMatches(null, 'Unknown', 'XyzNonExistent123');
        System.assert(noMatches.isEmpty(), 'Should not find matches for non-existent name');

        Test.stopTest();
    }

    @isTest
    static void testGetExistingPayments() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        List<PaymentMatcherController.ExistingPayment> payments =
            PaymentMatcherController.getExistingPayments(testAccount.Id, Date.today(), 100);
        Test.stopTest();

        System.assert(!payments.isEmpty(), 'Should find existing payments');
    }

    @isTest
    static void testGetUnpaidPledges() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        List<PaymentMatcherController.UnpaidPledge> pledges =
            PaymentMatcherController.getUnpaidPledges(testAccount.Id, Date.today(), true, 100);
        Test.stopTest();

        System.assert(!pledges.isEmpty(), 'Should find unpaid pledges');
        System.assertNotEquals(null, pledges[0].lineItems, 'Pledge should have line items');
    }

    @isTest
    static void testUpdateMatchedHousehold() {
        Payment_Import__c testImport = [SELECT Id FROM Payment_Import__c WHERE Status__c = 'New' LIMIT 1];
        Account testAccount = [SELECT Id, OneCRM__Primary_Contact__c FROM Account LIMIT 1];

        Test.startTest();
        PaymentMatcherController.PaymentImportWrapper result =
            PaymentMatcherController.updateMatchedHousehold(testImport.Id, testAccount.Id);
        Test.stopTest();

        System.assertEquals('Contact Matched', result.status, 'Status should be Contact Matched');
        System.assertEquals(testAccount.OneCRM__Primary_Contact__c, result.matchedContactId, 'Primary contact should be matched');
        System.assertEquals(testAccount.Id, result.matchedAccountId, 'Account should be matched');
    }

    @isTest
    static void testMarkAsDuplicate() {
        Payment_Import__c testImport = [SELECT Id FROM Payment_Import__c WHERE Status__c = 'New' LIMIT 1];

        Test.startTest();
        PaymentMatcherController.PaymentImportWrapper result =
            PaymentMatcherController.markAsDuplicate(testImport.Id);
        Test.stopTest();

        System.assertEquals('Duplicate', result.status, 'Status should be Duplicate');
    }

    @isTest
    static void testMarkAsSkipped() {
        Payment_Import__c testImport = [SELECT Id FROM Payment_Import__c WHERE Status__c = 'New' LIMIT 1];

        Test.startTest();
        PaymentMatcherController.PaymentImportWrapper result =
            PaymentMatcherController.markAsSkipped(testImport.Id);
        Test.stopTest();

        System.assertEquals('Skipped', result.status, 'Status should be Skipped');
    }

    @isTest
    static void testCreatePayment() {
        // Setup: Match a household to an import first
        Payment_Import__c testImport = [SELECT Id FROM Payment_Import__c WHERE Status__c = 'New' LIMIT 1];
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        OneCRM__Income__c testCharge = [
            SELECT Id FROM OneCRM__Income__c
            WHERE RecordType.DeveloperName = 'Charge'
            LIMIT 1
        ];

        // First update the matched household
        PaymentMatcherController.updateMatchedHousehold(testImport.Id, testAccount.Id);

        Test.startTest();
        PaymentMatcherController.PaymentImportWrapper result =
            PaymentMatcherController.createPayment(testImport.Id, testCharge.Id);
        Test.stopTest();

        System.assertEquals('Completed', result.status, 'Status should be Completed');
        System.assertNotEquals(null, result.id, 'Should have created payment');

        // Verify payment was created
        Payment_Import__c updatedImport = [
            SELECT Created_Payment__c, Applied_To_Charge__c
            FROM Payment_Import__c
            WHERE Id = :testImport.Id
        ];
        System.assertNotEquals(null, updatedImport.Created_Payment__c, 'Should have created payment reference');
        System.assertEquals(testCharge.Id, updatedImport.Applied_To_Charge__c, 'Should have charge reference');
    }

    @isTest
    static void testGetStatusCounts() {
        Test.startTest();
        Map<String, Integer> counts = PaymentMatcherController.getStatusCounts();
        Test.stopTest();

        System.assert(counts.containsKey('All'), 'Should have All count');
        System.assert(counts.containsKey('New'), 'Should have New count');
        System.assertEquals(3, counts.get('All'), 'All count should be 3');
        System.assertEquals(2, counts.get('New'), 'New count should be 2');
    }

    @isTest
    static void testWrapperComparison() {
        // Test HouseholdMatch comparison
        Account testAcc = [SELECT Id, Name, OneCRM__Primary_Contact__c, OneCRM__Primary_Contact__r.Name,
            OneCRM__Primary_Contact__r.Email, OneCRM__Secondary_Contact__r.Email FROM Account LIMIT 1];

        PaymentMatcherController.HouseholdMatch match1 = new PaymentMatcherController.HouseholdMatch(testAcc, 'Email', 100);
        PaymentMatcherController.HouseholdMatch match2 = new PaymentMatcherController.HouseholdMatch(testAcc, 'Name', 50);

        System.assertEquals(-1, match1.compareTo(match2), 'Higher confidence should sort first');

        // Test ExistingPayment comparison
        Id paymentRT = Schema.SObjectType.OneCRM__Income__c
            .getRecordTypeInfosByDeveloperName().get('Payment').getRecordTypeId();
        Account acc = [SELECT Id FROM Account LIMIT 1];

        // Create payment without setting Amount (it's a rollup field)
        OneCRM__Income__c inc1 = new OneCRM__Income__c(
            RecordTypeId = paymentRT,
            OneCRM__Donor__c = acc.Id,
            OneCRM__Date__c = Date.today(),
            OneCRM__Status__c = 'Success',
            OneCRM__Payment_Type__c = 'Cash'
        );
        insert inc1;

        // Create a line item to populate the rollup amount
        OneCRM__Income__c existingCharge = [SELECT Id FROM OneCRM__Income__c WHERE RecordType.DeveloperName = 'Charge' LIMIT 1];
        OneCRM__Income_Line_Item__c existingChargeLine = [SELECT Id FROM OneCRM__Income_Line_Item__c WHERE OneCRM__Income__c = :existingCharge.Id LIMIT 1];

        OneCRM__Income_Line_Item__c payLine = new OneCRM__Income_Line_Item__c(
            OneCRM__Income__c = inc1.Id,
            OneCRM__Donor__c = acc.Id,
            OneCRM__Amount__c = -100,
            OneCRM__Related_Income__c = existingCharge.Id,
            OneCRM__Related_Income_Line_Item__c = existingChargeLine.Id
        );
        insert payLine;

        inc1 = [SELECT Id, Name, OneCRM__Amount__c, OneCRM__Date__c, OneCRM__Payment_Type__c,
                OneCRM__Status__c, (SELECT Id, OneCRM__Notes__c FROM OneCRM__Income_Line_Items__r)
                FROM OneCRM__Income__c WHERE Id = :inc1.Id];

        PaymentMatcherController.ExistingPayment ep1 = new PaymentMatcherController.ExistingPayment(inc1, Date.today());
        PaymentMatcherController.ExistingPayment ep2 = new PaymentMatcherController.ExistingPayment(inc1, Date.today().addDays(-30));

        System.assertEquals(-1, ep1.compareTo(ep2), 'Closer date should sort first');
    }

    @isTest
    static void testNullInputs() {
        Test.startTest();

        // Test with null account
        List<PaymentMatcherController.ExistingPayment> nullPayments =
            PaymentMatcherController.getExistingPayments(null, Date.today(), 100);
        System.assertEquals(0, nullPayments.size(), 'Should return empty list for null account');

        List<PaymentMatcherController.UnpaidPledge> nullPledges =
            PaymentMatcherController.getUnpaidPledges(null, Date.today(), false, 100);
        System.assertEquals(0, nullPledges.size(), 'Should return empty list for null account');

        // Test with blank inputs
        List<PaymentMatcherController.HouseholdMatch> blankMatches =
            PaymentMatcherController.findHouseholdMatches('', '', '');
        // Should not throw error

        Test.stopTest();
    }

    @isTest
    static void testSearchCampaigns() {
        Test.startTest();

        // Test search with matching term
        List<PaymentMatcherController.CampaignWrapper> results =
            PaymentMatcherController.searchCampaigns('Membership');
        System.assert(!results.isEmpty(), 'Should find campaign by name');
        System.assertEquals('Membership', results[0].campaignType, 'Should have correct campaign type');

        // Test search with partial term
        List<PaymentMatcherController.CampaignWrapper> partialResults =
            PaymentMatcherController.searchCampaigns('Test');
        System.assert(!partialResults.isEmpty(), 'Should find campaign by partial name');

        // Test search with no match
        List<PaymentMatcherController.CampaignWrapper> noResults =
            PaymentMatcherController.searchCampaigns('NonExistentCampaign12345');
        System.assertEquals(0, noResults.size(), 'Should return empty list for no match');

        // Test search with empty string
        List<PaymentMatcherController.CampaignWrapper> emptyResults =
            PaymentMatcherController.searchCampaigns('');
        // Should not throw error

        Test.stopTest();
    }

    @isTest
    static void testCreatePledgeAndPayment() {
        // Setup: Match a household to an import first
        Payment_Import__c testImport = [SELECT Id FROM Payment_Import__c WHERE Status__c = 'New' LIMIT 1];
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Campaign testCampaign = [SELECT Id FROM Campaign WHERE IsActive = true LIMIT 1];

        // First update the matched household
        PaymentMatcherController.updateMatchedHousehold(testImport.Id, testAccount.Id);

        Test.startTest();
        PaymentMatcherController.PaymentImportWrapper result =
            PaymentMatcherController.createPledgeAndPayment(testImport.Id, testCampaign.Id, Date.today());
        Test.stopTest();

        System.assertEquals('Completed', result.status, 'Status should be Completed');

        // Verify both charge and payment were created
        Payment_Import__c updatedImport = [
            SELECT Created_Payment__c, Applied_To_Charge__c
            FROM Payment_Import__c
            WHERE Id = :testImport.Id
        ];
        System.assertNotEquals(null, updatedImport.Created_Payment__c, 'Should have created payment reference');
        System.assertNotEquals(null, updatedImport.Applied_To_Charge__c, 'Should have created charge reference');

        // Verify the charge was created with correct campaign
        OneCRM__Income__c charge = [
            SELECT Id, OneCRM__Amount__c, RecordType.DeveloperName,
                (SELECT Id, OneCRM__Related_Campaign__c, OneCRM__Amount__c FROM OneCRM__Income_Line_Items__r)
            FROM OneCRM__Income__c
            WHERE Id = :updatedImport.Applied_To_Charge__c
        ];
        System.assertEquals('Charge', charge.RecordType.DeveloperName, 'Should be a Charge record');
        System.assert(!charge.OneCRM__Income_Line_Items__r.isEmpty(), 'Charge should have line items');
        System.assertEquals(testCampaign.Id, charge.OneCRM__Income_Line_Items__r[0].OneCRM__Related_Campaign__c,
            'Charge line item should link to campaign');

        // Verify the payment was created
        OneCRM__Income__c payment = [
            SELECT Id, OneCRM__Amount__c, RecordType.DeveloperName,
                (SELECT Id, OneCRM__Related_Income__c, OneCRM__Related_Income_Line_Item__c, OneCRM__Amount__c
                 FROM OneCRM__Income_Line_Items__r)
            FROM OneCRM__Income__c
            WHERE Id = :updatedImport.Created_Payment__c
        ];
        System.assertEquals('Payment', payment.RecordType.DeveloperName, 'Should be a Payment record');
        System.assert(!payment.OneCRM__Income_Line_Items__r.isEmpty(), 'Payment should have line items');
        System.assertEquals(charge.Id, payment.OneCRM__Income_Line_Items__r[0].OneCRM__Related_Income__c,
            'Payment line item should link to charge');
    }
}
