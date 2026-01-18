import { LightningElement, wire } from 'lwc';
import getContacts from '@salesforce/apex/ContactListController.getContacts';

const COLUMNS = [
    { label: 'First Name', fieldName: 'FirstName', type: 'text' },
    { label: 'Last Name', fieldName: 'LastName', type: 'text' },
    { label: 'Email', fieldName: 'Email', type: 'email' },
    { label: 'Phone', fieldName: 'Phone', type: 'phone' },
    { label: 'Account', fieldName: 'AccountName', type: 'text' }
];

export default class ContactList extends LightningElement {
    columns = COLUMNS;
    contacts;
    error;

    @wire(getContacts)
    wiredContacts({ error, data }) {
        if (data) {
            this.contacts = data.map(contact => ({
                ...contact,
                AccountName: contact.Account ? contact.Account.Name : ''
            }));
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.contacts = undefined;
        }
    }

    get hasContacts() {
        return this.contacts && this.contacts.length > 0;
    }
}
