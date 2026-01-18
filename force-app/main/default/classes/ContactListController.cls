public with sharing class ContactListController {
    @AuraEnabled(cacheable=true)
    public static List<Contact> getContacts() {
        return [
            SELECT Id, FirstName, LastName, Email, Phone, AccountId, Account.Name
            FROM Contact
            ORDER BY LastName, FirstName
            LIMIT 200
        ];
    }
}
