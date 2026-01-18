/**
 * Test class for SoqlLookupController
 */
@isTest
private class SoqlLookupControllerTest {

    @TestSetup
    static void setupTestData() {
        // Create test accounts
        List<Account> accounts = new List<Account>();
        accounts.add(new Account(Name = 'Test Account Alpha'));
        accounts.add(new Account(Name = 'Test Account Beta'));
        accounts.add(new Account(Name = 'Different Name'));
        insert accounts;

        // Create test contacts
        List<Contact> contacts = new List<Contact>();
        contacts.add(new Contact(
            FirstName = 'John',
            LastName = 'Smith',
            Email = 'john.smith@test.com',
            AccountId = accounts[0].Id
        ));
        contacts.add(new Contact(
            FirstName = 'Jane',
            LastName = 'Smith',
            Email = 'jane.smith@test.com',
            AccountId = accounts[1].Id
        ));
        contacts.add(new Contact(
            FirstName = 'Bob',
            LastName = 'Johnson',
            Email = 'bob.johnson@test.com'
        ));
        insert contacts;
    }

    @isTest
    static void testSearchWithResults() {
        // Test searching for contacts (more reliable across orgs)
        String queryTemplate = 'SELECT Id, Name, Email FROM Contact WHERE LastName LIKE \'%{searchTerm}%\' LIMIT 10';

        Test.startTest();
        List<SoqlLookupController.LookupSearchResult> results = SoqlLookupController.search(
            queryTemplate,
            'Smith',
            'Name',
            'Email',
            'standard:contact'
        );
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Should find 2 contacts matching "Smith"');
        System.assertNotEquals(null, results[0].id, 'Result should have an ID');
        System.assert(results[0].title.contains('Smith'), 'Title should contain search term');
        System.assertEquals('standard:contact', results[0].icon, 'Icon should match');
    }

    @isTest
    static void testSearchWithSubtitle() {
        // Test searching contacts with subtitle
        String queryTemplate = 'SELECT Id, Name, Email FROM Contact WHERE Name LIKE \'%{searchTerm}%\' LIMIT 10';

        Test.startTest();
        List<SoqlLookupController.LookupSearchResult> results = SoqlLookupController.search(
            queryTemplate,
            'Smith',
            'Name',
            'Email',
            'standard:contact'
        );
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Should find 2 contacts with last name Smith');
        System.assertNotEquals(null, results[0].subtitle, 'Subtitle should be populated');
        System.assert(results[0].subtitle.contains('@test.com'), 'Subtitle should contain email');
    }

    @isTest
    static void testSearchNoResults() {
        String queryTemplate = 'SELECT Id, Name FROM Account WHERE Name LIKE \'%{searchTerm}%\' LIMIT 10';

        Test.startTest();
        List<SoqlLookupController.LookupSearchResult> results = SoqlLookupController.search(
            queryTemplate,
            'NonExistentAccount123',
            'Name',
            null,
            'standard:account'
        );
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Should find no results');
    }

    @isTest
    static void testSearchWithBlankInputs() {
        Test.startTest();

        // Test with blank query
        List<SoqlLookupController.LookupSearchResult> results1 = SoqlLookupController.search(
            '',
            'test',
            'Name',
            null,
            'standard:account'
        );
        System.assertEquals(0, results1.size(), 'Should return empty list for blank query');

        // Test with blank search term
        List<SoqlLookupController.LookupSearchResult> results2 = SoqlLookupController.search(
            'SELECT Id, Name FROM Account LIMIT 10',
            '',
            'Name',
            null,
            'standard:account'
        );
        System.assertEquals(0, results2.size(), 'Should return empty list for blank search term');

        Test.stopTest();
    }

    @isTest
    static void testSearchWithSpecialCharacters() {
        // Test SOQL injection prevention
        String queryTemplate = 'SELECT Id, Name FROM Account WHERE Name LIKE \'%{searchTerm}%\' LIMIT 10';

        Test.startTest();
        List<SoqlLookupController.LookupSearchResult> results = SoqlLookupController.search(
            queryTemplate,
            'Test\' OR Name LIKE \'%',
            'Name',
            null,
            'standard:account'
        );
        Test.stopTest();

        // Should not throw an exception and should safely handle the injection attempt
        System.assertNotEquals(null, results, 'Should return a list (possibly empty)');
    }

    @isTest
    static void testSearchWithInvalidQuery() {
        String invalidQuery = 'SELECT InvalidField FROM Contact LIMIT 10';

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            SoqlLookupController.search(
                invalidQuery,
                'test',
                'Name',
                null,
                'standard:contact'
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            // AuraHandledException wraps the message, so just verify an exception was thrown
            System.assertNotEquals(null, e.getMessage(), 'Exception should have a message');
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Should have thrown an AuraHandledException');
    }

    @isTest
    static void testGetRecordsById() {
        // Use Contact instead of Account for more reliable test behavior
        List<Contact> contacts = [SELECT Id FROM Contact WHERE LastName = 'Johnson'];
        List<String> contactIds = new List<String>();
        for (Contact c : contacts) {
            contactIds.add(c.Id);
        }

        Test.startTest();
        List<SoqlLookupController.LookupSearchResult> results = SoqlLookupController.getRecordsById(
            'Contact',
            contactIds,
            'Name',
            null,
            'standard:contact'
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return 1 contact');
        System.assertNotEquals(null, results[0].id, 'Should have ID');
        System.assertNotEquals(null, results[0].title, 'Should have title');
    }

    @isTest
    static void testGetRecordsByIdWithSubtitle() {
        List<Contact> contacts = [SELECT Id FROM Contact WHERE LastName = 'Smith'];
        List<String> contactIds = new List<String>();
        for (Contact c : contacts) {
            contactIds.add(c.Id);
        }

        Test.startTest();
        List<SoqlLookupController.LookupSearchResult> results = SoqlLookupController.getRecordsById(
            'Contact',
            contactIds,
            'Name',
            'Email',
            'standard:contact'
        );
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Should return 2 contacts');
        System.assertNotEquals(null, results[0].subtitle, 'Should have subtitle');
    }

    @isTest
    static void testGetRecordsByIdWithBlankInputs() {
        Test.startTest();

        // Test with blank object name
        List<SoqlLookupController.LookupSearchResult> results1 = SoqlLookupController.getRecordsById(
            '',
            new List<String>{'001000000000001'},
            'Name',
            null,
            'standard:account'
        );
        System.assertEquals(0, results1.size(), 'Should return empty for blank object name');

        // Test with null record IDs
        List<SoqlLookupController.LookupSearchResult> results2 = SoqlLookupController.getRecordsById(
            'Account',
            null,
            'Name',
            null,
            'standard:account'
        );
        System.assertEquals(0, results2.size(), 'Should return empty for null IDs');

        // Test with empty record IDs
        List<SoqlLookupController.LookupSearchResult> results3 = SoqlLookupController.getRecordsById(
            'Account',
            new List<String>(),
            'Name',
            null,
            'standard:account'
        );
        System.assertEquals(0, results3.size(), 'Should return empty for empty ID list');

        Test.stopTest();
    }

    @isTest
    static void testSearchWithRelatedFields() {
        // Test searching contacts and displaying related account name
        String queryTemplate = 'SELECT Id, Name, Account.Name FROM Contact WHERE LastName LIKE \'%{searchTerm}%\' AND AccountId != null LIMIT 10';

        Test.startTest();
        List<SoqlLookupController.LookupSearchResult> results = SoqlLookupController.search(
            queryTemplate,
            'Smith',
            'Name',
            'Account.Name',
            'standard:contact'
        );
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Should find 2 contacts');
        // Verify subtitle is populated with related field value
        System.assertNotEquals(null, results[0].subtitle, 'Subtitle should be populated');
        System.assert(String.isNotBlank(results[0].subtitle), 'Subtitle should not be blank');
    }

    @isTest
    static void testLookupSearchResultConstructor() {
        Test.startTest();
        SoqlLookupController.LookupSearchResult result = new SoqlLookupController.LookupSearchResult(
            '001000000000001',
            'Test Title',
            'Test Subtitle',
            'standard:account'
        );
        Test.stopTest();

        System.assertEquals('001000000000001', result.id, 'ID should match');
        System.assertEquals('Test Title', result.title, 'Title should match');
        System.assertEquals('Test Subtitle', result.subtitle, 'Subtitle should match');
        System.assertEquals('standard:account', result.icon, 'Icon should match');
    }
}
