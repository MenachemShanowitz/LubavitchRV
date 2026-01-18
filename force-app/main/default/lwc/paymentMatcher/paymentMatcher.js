import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

import getPaymentImports from '@salesforce/apex/PaymentMatcherController.getPaymentImports';
import getPaymentImport from '@salesforce/apex/PaymentMatcherController.getPaymentImport';
import findHouseholdMatches from '@salesforce/apex/PaymentMatcherController.findHouseholdMatches';
import getExistingPayments from '@salesforce/apex/PaymentMatcherController.getExistingPayments';
import getUnpaidPledges from '@salesforce/apex/PaymentMatcherController.getUnpaidPledges';
import updateMatchedHousehold from '@salesforce/apex/PaymentMatcherController.updateMatchedHousehold';
import markAsDuplicate from '@salesforce/apex/PaymentMatcherController.markAsDuplicate';
import markAsSkipped from '@salesforce/apex/PaymentMatcherController.markAsSkipped';
import createPayment from '@salesforce/apex/PaymentMatcherController.createPayment';
import searchCampaigns from '@salesforce/apex/PaymentMatcherController.searchCampaigns';
import createPledgeAndPayment from '@salesforce/apex/PaymentMatcherController.createPledgeAndPayment';
import getStatusCounts from '@salesforce/apex/PaymentMatcherController.getStatusCounts';

const STEPS = {
    CONTACT: 'contact',
    DUPLICATE: 'duplicate',
    PLEDGE: 'pledge'
};

export default class PaymentMatcher extends LightningElement {
    // List view state
    @track imports = [];
    @track statusCounts = {};
    @track selectedFilter = 'New';
    @track selectedImportId = null;
    @track selectedImport = null;

    // Wizard state
    @track currentStep = STEPS.CONTACT;
    @track isLoading = false;

    // Step 1: Household matching
    @track householdMatches = [];
    @track selectedHouseholdId = null;
    @track showManualSearch = false;

    // Step 2: Duplicate check
    @track existingPayments = [];
    @track selectedPaymentId = null;

    // Step 3: Pledge selection
    @track unpaidPledges = [];
    @track selectedPledgeId = null;

    // Create Pledge section
    @track showCreatePledge = false;
    @track campaignSearchTerm = '';
    @track campaignSearchResults = [];
    @track selectedCampaignId = null;
    @track selectedCampaignName = null;
    @track newPledgeDate = null;

    // Wire results for refresh
    wiredImportsResult;
    wiredCountsResult;

    // Filter options
    get filterOptions() {
        return [
            { label: `All (${this.statusCounts.All || 0})`, value: 'All' },
            { label: `New (${this.statusCounts.New || 0})`, value: 'New' },
            { label: `Contact Matched (${this.statusCounts['Contact Matched'] || 0})`, value: 'Contact Matched' },
            { label: `Completed (${this.statusCounts.Completed || 0})`, value: 'Completed' },
            { label: `Duplicate (${this.statusCounts.Duplicate || 0})`, value: 'Duplicate' },
            { label: `Skipped (${this.statusCounts.Skipped || 0})`, value: 'Skipped' }
        ];
    }

    // Wire status counts
    @wire(getStatusCounts)
    wiredCounts(result) {
        this.wiredCountsResult = result;
        if (result.data) {
            this.statusCounts = result.data;
        }
    }

    // Wire imports list
    @wire(getPaymentImports, { statusFilter: '$selectedFilter' })
    wiredImports(result) {
        this.wiredImportsResult = result;
        if (result.data) {
            this.imports = result.data.map((imp) => ({
                ...imp,
                isSelected: imp.id === this.selectedImportId,
                statusClass: this.getStatusClass(imp.status),
                formattedAmount: this.formatCurrency(imp.amount),
                formattedDate: this.formatDate(imp.paymentDate)
            }));
        } else if (result.error) {
            this.showError('Error loading imports', result.error);
        }
    }

    // Computed properties
    get hasSelectedImport() {
        return this.selectedImport !== null;
    }

    get isContactStep() {
        return this.currentStep === STEPS.CONTACT;
    }

    get isDuplicateStep() {
        return this.currentStep === STEPS.DUPLICATE;
    }

    get isPledgeStep() {
        return this.currentStep === STEPS.PLEDGE;
    }

    get stepIndicator() {
        const steps = [
            { label: '1. Match Household', active: this.isContactStep, completed: this.isDuplicateStep || this.isPledgeStep },
            { label: '2. Check Duplicates', active: this.isDuplicateStep, completed: this.isPledgeStep },
            { label: '3. Apply to Pledge', active: this.isPledgeStep, completed: false }
        ];
        return steps;
    }

    get householdQueryTemplate() {
        return "SELECT Id, Name, OneCRM__Primary_Contact__r.Email, OneCRM__Secondary_Contact__r.Email FROM Account WHERE Name LIKE '%{searchTerm}%' LIMIT 20";
    }

    get manualSearchButtonLabel() {
        return this.showManualSearch ? 'Hide Manual Search' : 'Search Manually';
    }

    get canProceedFromHousehold() {
        return this.selectedHouseholdId !== null;
    }

    get isHouseholdButtonDisabled() {
        return this.selectedHouseholdId === null;
    }

    get canProceedFromDuplicate() {
        return true; // User can always proceed (either mark duplicate or continue)
    }

    get canCreatePayment() {
        return this.selectedPledgeId !== null;
    }

    get isCreatePaymentDisabled() {
        return this.selectedPledgeId === null;
    }

    get noHouseholdMatches() {
        return this.householdMatches.length === 0;
    }

    get noExistingPayments() {
        return this.existingPayments.length === 0;
    }

    get noUnpaidPledges() {
        return this.unpaidPledges.length === 0;
    }

    get createPledgeButtonLabel() {
        return this.showCreatePledge ? 'Cancel' : 'Create New Pledge';
    }

    get canCreatePledgeAndPayment() {
        return this.selectedCampaignId !== null && this.newPledgeDate !== null;
    }

    get isCreatePledgeAndPaymentDisabled() {
        return !this.canCreatePledgeAndPayment;
    }

    get hasCampaignSearchResults() {
        return this.campaignSearchResults.length > 0;
    }

    get householdUrl() {
        if (this.selectedImport?.matchedAccountId) {
            return `/lightning/r/Account/${this.selectedImport.matchedAccountId}/view`;
        }
        return '#';
    }

    // Helper methods
    getStatusClass(status) {
        const classMap = {
            New: 'slds-badge slds-theme_warning',
            'Contact Matched': 'slds-badge slds-theme_info',
            Completed: 'slds-badge slds-theme_success',
            Duplicate: 'slds-badge slds-theme_error',
            Skipped: 'slds-badge'
        };
        return classMap[status] || 'slds-badge';
    }

    formatCurrency(amount) {
        if (amount == null) return '$0.00';
        return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(amount);
    }

    formatDate(dateStr) {
        if (!dateStr) return '';
        const date = new Date(dateStr + 'T00:00:00');
        return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
    }

    showError(title, error) {
        const message = error?.body?.message || error?.message || 'Unknown error';
        this.dispatchEvent(new ShowToastEvent({ title, message, variant: 'error' }));
    }

    showSuccess(message) {
        this.dispatchEvent(new ShowToastEvent({ title: 'Success', message, variant: 'success' }));
    }

    formatImport(imp) {
        return {
            ...imp,
            formattedAmount: this.formatCurrency(imp.amount),
            formattedDate: this.formatDate(imp.paymentDate)
        };
    }

    async refreshData() {
        await Promise.all([refreshApex(this.wiredImportsResult), refreshApex(this.wiredCountsResult)]);
    }

    // Event handlers - List view
    handleFilterChange(event) {
        this.selectedFilter = event.detail.value;
        this.selectedImportId = null;
        this.selectedImport = null;
        this.resetWizard();
    }

    async handleImportSelect(event) {
        const importId = event.currentTarget.dataset.id;
        this.selectedImportId = importId;
        this.isLoading = true;

        // Reset all wizard state when selecting a new import
        this.resetWizard();

        try {
            // Use already-loaded import data when available, fall back to Apex call
            const existingImport = this.imports.find(imp => imp.id === importId);
            this.selectedImport = existingImport
                ? { ...existingImport }
                : this.formatImport(await getPaymentImport({ importId }));

            // Update selection highlighting
            this.imports = this.imports.map((imp) => ({
                ...imp,
                isSelected: imp.id === importId
            }));

            // Determine starting step based on status
            if (this.selectedImport.status === 'New') {
                this.currentStep = STEPS.CONTACT;
                await this.loadHouseholdMatches();
            } else if (this.selectedImport.status === 'Contact Matched') {
                this.currentStep = STEPS.DUPLICATE;
                this.selectedHouseholdId = this.selectedImport.matchedAccountId;
                await this.loadExistingPayments();
            } else {
                this.currentStep = STEPS.CONTACT;
                // resetWizard() already called at start of handleImportSelect
            }
        } catch (error) {
            this.showError('Error loading import', error);
        } finally {
            this.isLoading = false;
        }
    }

    // Wizard methods
    resetWizard() {
        this.currentStep = STEPS.CONTACT;
        this.householdMatches = [];
        this.selectedHouseholdId = null;
        this.showManualSearch = false;
        this.existingPayments = [];
        this.selectedPaymentId = null;
        this.unpaidPledges = [];
        this.selectedPledgeId = null;
        // Reset create pledge state
        this.showCreatePledge = false;
        this.campaignSearchTerm = '';
        this.campaignSearchResults = [];
        this.selectedCampaignId = null;
        this.selectedCampaignName = null;
        this.newPledgeDate = null;
    }

    // Step 1: Household matching
    async loadHouseholdMatches() {
        if (!this.selectedImport) return;

        this.isLoading = true;
        try {
            const matches = await findHouseholdMatches({
                email: this.selectedImport.email,
                firstName: this.selectedImport.firstName,
                lastName: this.selectedImport.lastName
            });

            this.householdMatches = matches.map((m, idx) => ({
                ...m,
                isSelected: idx === 0,
                confidenceClass: m.confidence >= 80 ? 'slds-text-color_success' : m.confidence >= 50 ? 'slds-text-color_warning' : 'slds-text-color_weak'
            }));

            // Auto-select first match if high confidence
            if (matches.length > 0 && matches[0].confidence >= 80) {
                this.selectedHouseholdId = matches[0].id;
            }
        } catch (error) {
            this.showError('Error finding households', error);
        } finally {
            this.isLoading = false;
        }
    }

    handleHouseholdSelect(event) {
        const householdId = event.currentTarget.dataset.id;
        this.selectedHouseholdId = householdId;
        this.householdMatches = this.householdMatches.map((m) => ({
            ...m,
            isSelected: m.id === householdId
        }));
    }

    handleManualSearchToggle() {
        this.showManualSearch = !this.showManualSearch;
    }

    handleManualHouseholdSelect(event) {
        const selection = event.detail.selection;
        if (selection && selection.length > 0) {
            // For manual search, we get an Account ID directly
            this.selectedHouseholdId = selection[0].id;
            this.showManualSearch = false;
        }
    }

    async handleConfirmHousehold() {
        if (!this.selectedHouseholdId) return;

        this.isLoading = true;
        try {
            const updatedImport = await updateMatchedHousehold({
                importId: this.selectedImport.id,
                accountId: this.selectedHouseholdId
            });
            // Merge server data with client formatting
            this.selectedImport = this.formatImport({
                ...this.selectedImport,
                ...updatedImport
            });

            this.currentStep = STEPS.DUPLICATE;
            await this.loadExistingPayments();
            await this.refreshData();
        } catch (error) {
            this.showError('Error matching household', error);
        } finally {
            this.isLoading = false;
        }
    }

    handleSkipHousehold() {
        this.handleSkip();
    }

    // Step 2: Duplicate check
    async loadExistingPayments() {
        if (!this.selectedImport || !this.selectedImport.matchedAccountId) return;

        this.isLoading = true;
        try {
            const payments = await getExistingPayments({
                accountId: this.selectedImport.matchedAccountId,
                paymentDate: this.selectedImport.paymentDate,
                amount: this.selectedImport.amount
            });

            this.existingPayments = payments.map((p) => {
                const isPotentialDup = p.daysDifference <= 7 && Math.abs(p.amount - this.selectedImport.amount) < 1;
                return {
                    ...p,
                    formattedAmount: this.formatCurrency(p.amount),
                    formattedDate: this.formatDate(p.paymentDate),
                    isPotentialDup,
                    rowClass: isPotentialDup ? 'slds-hint-parent potential-dup' : 'slds-hint-parent'
                };
            });
        } catch (error) {
            this.showError('Error loading payments', error);
        } finally {
            this.isLoading = false;
        }
    }

    async handleMarkDuplicate() {
        this.isLoading = true;
        try {
            await markAsDuplicate({ importId: this.selectedImport.id });
            this.showSuccess('Marked as duplicate');
            await this.refreshData();
            this.selectNextImport();
        } catch (error) {
            this.showError('Error marking duplicate', error);
        } finally {
            this.isLoading = false;
        }
    }

    async handleNotDuplicate() {
        // Reset Step 3 state before entering
        this.unpaidPledges = [];
        this.selectedPledgeId = null;
        this.showCreatePledge = false;
        this.campaignSearchTerm = '';
        this.campaignSearchResults = [];
        this.selectedCampaignId = null;
        this.selectedCampaignName = null;
        this.newPledgeDate = null;

        this.currentStep = STEPS.PLEDGE;
        await this.loadUnpaidPledges();
    }

    // Step 3: Pledge selection
    async loadUnpaidPledges() {
        if (!this.selectedImport || !this.selectedImport.matchedAccountId) return;

        this.isLoading = true;
        try {
            const pledges = await getUnpaidPledges({
                accountId: this.selectedImport.matchedAccountId,
                paymentDate: this.selectedImport.paymentDate,
                isMembership: this.selectedImport.isMembership,
                paymentAmount: this.selectedImport.amount
            });

            this.unpaidPledges = pledges.map((p) => {
                const canApply = p.amountOutstanding >= this.selectedImport.amount;
                return {
                    ...p,
                    formattedAmount: this.formatCurrency(p.amount),
                    formattedOutstanding: this.formatCurrency(p.amountOutstanding),
                    formattedDate: this.formatDate(p.pledgeDate),
                    isSelected: false,
                    canApply,
                    cantApply: !canApply
                };
            });
        } catch (error) {
            this.showError('Error loading pledges', error);
        } finally {
            this.isLoading = false;
        }
    }

    handlePledgeSelect(event) {
        const pledgeId = event.currentTarget.dataset.id;
        const pledge = this.unpaidPledges.find((p) => p.id === pledgeId);

        if (!pledge.canApply) {
            this.showError('Cannot apply', { message: 'Pledge outstanding amount is less than payment amount' });
            return;
        }

        this.selectedPledgeId = pledgeId;
        this.unpaidPledges = this.unpaidPledges.map((p) => ({
            ...p,
            isSelected: p.id === pledgeId
        }));
    }

    async handleCreatePayment() {
        if (!this.selectedPledgeId) return;

        this.isLoading = true;
        try {
            await createPayment({
                importId: this.selectedImport.id,
                chargeId: this.selectedPledgeId
            });

            this.showSuccess('Payment created successfully');
            await this.refreshData();
            this.selectNextImport();
        } catch (error) {
            this.showError('Error creating payment', error);
        } finally {
            this.isLoading = false;
        }
    }

    // Create Pledge handlers
    handleToggleCreatePledge() {
        this.showCreatePledge = !this.showCreatePledge;
        if (this.showCreatePledge) {
            // Initialize date to payment date and reset search
            this.newPledgeDate = this.selectedImport.paymentDate;
            this.campaignSearchTerm = '';
            this.campaignSearchResults = [];
            this.selectedCampaignId = null;
            this.selectedCampaignName = null;
        }
    }

    async handleCampaignSearch(event) {
        const searchTerm = event.target.value;
        this.campaignSearchTerm = searchTerm;

        if (searchTerm.length < 2) {
            this.campaignSearchResults = [];
            return;
        }

        try {
            const results = await searchCampaigns({ searchTerm });
            this.campaignSearchResults = results.map((c) => ({
                ...c,
                displayName: `${c.name} (${c.campaignType || 'No Type'}${c.hebrewYear ? ' - ' + c.hebrewYear : ''})`,
                isSelected: c.id === this.selectedCampaignId
            }));
        } catch (error) {
            this.showError('Error searching campaigns', error);
        }
    }

    handleCampaignSelect(event) {
        const campaignId = event.currentTarget.dataset.id;
        const campaign = this.campaignSearchResults.find((c) => c.id === campaignId);

        this.selectedCampaignId = campaignId;
        this.selectedCampaignName = campaign?.displayName || campaign?.name;
        this.campaignSearchResults = this.campaignSearchResults.map((c) => ({
            ...c,
            isSelected: c.id === campaignId
        }));
    }

    handlePledgeDateChange(event) {
        this.newPledgeDate = event.target.value;
    }

    async handleCreatePledgeAndPayment() {
        if (!this.canCreatePledgeAndPayment) return;

        this.isLoading = true;
        try {
            await createPledgeAndPayment({
                importId: this.selectedImport.id,
                campaignId: this.selectedCampaignId,
                pledgeDate: this.newPledgeDate
            });

            this.showSuccess('Pledge and payment created successfully');
            await this.refreshData();
            this.selectNextImport();
        } catch (error) {
            this.showError('Error creating pledge and payment', error);
        } finally {
            this.isLoading = false;
        }
    }

    // Navigation helpers
    async handleSkip() {
        this.isLoading = true;
        try {
            await markAsSkipped({ importId: this.selectedImport.id });
            this.showSuccess('Import skipped');
            await this.refreshData();
            this.selectNextImport();
        } catch (error) {
            this.showError('Error skipping import', error);
        } finally {
            this.isLoading = false;
        }
    }

    handleBack() {
        if (this.currentStep === STEPS.DUPLICATE) {
            this.currentStep = STEPS.CONTACT;
        } else if (this.currentStep === STEPS.PLEDGE) {
            this.currentStep = STEPS.DUPLICATE;
        }
    }

    selectNextImport() {
        // Find next unprocessed import
        const currentIndex = this.imports.findIndex((i) => i.id === this.selectedImportId);
        const nextImport = this.imports.find((i, idx) => idx > currentIndex && (i.status === 'New' || i.status === 'Contact Matched'));

        if (nextImport) {
            this.handleImportSelect({ currentTarget: { dataset: { id: nextImport.id } } });
        } else {
            this.selectedImportId = null;
            this.selectedImport = null;
            this.resetWizard();
        }
    }

    // Keyboard navigation
    handleKeyDown(event) {
        if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
            event.preventDefault();
            const currentIndex = this.imports.findIndex((i) => i.id === this.selectedImportId);
            let nextIndex;

            if (event.key === 'ArrowDown') {
                nextIndex = currentIndex < this.imports.length - 1 ? currentIndex + 1 : 0;
            } else {
                nextIndex = currentIndex > 0 ? currentIndex - 1 : this.imports.length - 1;
            }

            if (this.imports[nextIndex]) {
                this.handleImportSelect({ currentTarget: { dataset: { id: this.imports[nextIndex].id } } });
            }
        }
    }
}
