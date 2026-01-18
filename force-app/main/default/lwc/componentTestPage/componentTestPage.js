import { LightningElement, track } from 'lwc';

export default class ComponentTestPage extends LightningElement {
    @track selectedContactIds = [];
    @track selectedAccountIds = [];
    @track lastSelectionEvent = '';

    // Contact lookup query
    contactQueryTemplate = "SELECT Id, Name, Email, Account.Name FROM Contact WHERE Name LIKE '%{searchTerm}%' ORDER BY Name LIMIT 10";

    // Account lookup query
    accountQueryTemplate = "SELECT Id, Name, Industry, Phone FROM Account WHERE Name LIKE '%{searchTerm}%' ORDER BY Name LIMIT 10";

    handleContactSelectionChange(event) {
        const { selectedIds, selection } = event.detail;
        this.selectedContactIds = selectedIds || [];
        this.lastSelectionEvent = JSON.stringify({
            type: 'Contact',
            selectedIds: this.selectedContactIds,
            selection: selection
        }, null, 2);
    }

    handleAccountSelectionChange(event) {
        const { selectedIds, selection } = event.detail;
        this.selectedAccountIds = selectedIds || [];
        this.lastSelectionEvent = JSON.stringify({
            type: 'Account',
            selectedIds: this.selectedAccountIds,
            selection: selection
        }, null, 2);
    }

    get contactSelectionDisplay() {
        return this.selectedContactIds.length > 0
            ? this.selectedContactIds.join(', ')
            : 'None';
    }

    get accountSelectionDisplay() {
        return this.selectedAccountIds.length > 0
            ? this.selectedAccountIds.join(', ')
            : 'None';
    }
}
