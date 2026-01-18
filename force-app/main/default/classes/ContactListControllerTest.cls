@isTest
private class ContactListControllerTest {
    @TestSetup
    static void setupTestData() {
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < 5; i++) {
            contacts.add(new Contact(
                FirstName = 'Test' + i,
                LastName = 'Contact' + i,
                Email = 'test' + i + '@example.com',
                Phone = '555-000' + i
            ));
        }
        insert contacts;
    }

    @isTest
    static void testGetContacts() {
        Test.startTest();
        List<Contact> result = ContactListController.getContacts();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(5, result.size(), 'Should return 5 contacts');
    }
}
