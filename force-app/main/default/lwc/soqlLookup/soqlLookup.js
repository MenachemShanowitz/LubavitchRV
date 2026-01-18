import { LightningElement, api } from 'lwc';
import search from '@salesforce/apex/SoqlLookupController.search';
import getRecordsById from '@salesforce/apex/SoqlLookupController.getRecordsById';

/**
 * A reusable SOQL-based lookup component that wraps the lookup component.
 * Simply pass a SOQL query template and field mappings to enable searching.
 *
 * @example
 * <c-soql-lookup
 *     label="Search Contacts"
 *     query-template="SELECT Id, Name, Email FROM Contact WHERE Name LIKE '%{searchTerm}%' LIMIT 10"
 *     title-field="Name"
 *     subtitle-field="Email"
 *     icon-name="standard:contact"
 *     onselectionchange={handleSelectionChange}>
 * </c-soql-lookup>
 */
export default class SoqlLookup extends LightningElement {
    // Query configuration
    @api queryTemplate = '';
    @api titleField = 'Name';
    @api subtitleField = '';
    @api iconName = 'standard:default';

    // For loading initial selection
    @api objectApiName = '';

    // Pass-through properties to lookup component
    @api label = '';
    @api placeholder = 'Search...';
    @api required = false;
    @api disabled = false;
    @api isMultiEntry = false;
    @api minSearchTermLength = 2;
    @api scrollAfterNItems = null;
    @api variant = 'label-stacked';

    // Private properties
    _selection = [];
    _errors = [];
    _initialSelectionLoaded = false;

    // PUBLIC API

    /**
     * Gets the current selection
     */
    @api
    get selection() {
        return this._selection;
    }

    /**
     * Sets the initial selection by record IDs
     */
    set selection(value) {
        if (value) {
            this._selection = Array.isArray(value) ? value : [value];
            // If these are just IDs (strings), we need to load the full records
            if (this._selection.length > 0 && typeof this._selection[0] === 'string') {
                this.loadInitialSelection(this._selection);
            } else {
                this.updateLookupSelection();
            }
        } else {
            this._selection = [];
            this.updateLookupSelection();
        }
    }

    /**
     * Gets the selected record IDs
     */
    @api
    get value() {
        return this._selection.map((item) => item.id);
    }

    /**
     * Sets errors on the lookup
     */
    @api
    set errors(value) {
        this._errors = value || [];
        this.updateLookupErrors();
    }

    get errors() {
        return this._errors;
    }

    /**
     * Gets the validity state
     */
    @api
    get validity() {
        const lookup = this.template.querySelector('c-lookup');
        return lookup ? lookup.validity : { valid: true };
    }

    /**
     * Gets the current selection from the lookup
     */
    @api
    getSelection() {
        const lookup = this.template.querySelector('c-lookup');
        return lookup ? lookup.getSelection() : [];
    }

    /**
     * Focuses the lookup input
     */
    @api
    focus() {
        const lookup = this.template.querySelector('c-lookup');
        if (lookup) {
            lookup.focus();
        }
    }

    /**
     * Blurs the lookup input
     */
    @api
    blur() {
        const lookup = this.template.querySelector('c-lookup');
        if (lookup) {
            lookup.blur();
        }
    }

    // LIFECYCLE HOOKS

    renderedCallback() {
        if (!this._initialSelectionLoaded && this._selection.length > 0) {
            this.updateLookupSelection();
            this._initialSelectionLoaded = true;
        }
    }

    // PRIVATE METHODS

    updateLookupSelection() {
        const lookup = this.template.querySelector('c-lookup');
        if (lookup && this._selection.length > 0) {
            lookup.selection = this._selection;
        }
    }

    updateLookupErrors() {
        const lookup = this.template.querySelector('c-lookup');
        if (lookup) {
            lookup.errors = this._errors;
        }
    }

    async loadInitialSelection(recordIds) {
        if (!this.objectApiName) {
            console.warn('soqlLookup: objectApiName is required to load initial selection by IDs');
            return;
        }

        try {
            const results = await getRecordsById({
                objectApiName: this.objectApiName,
                recordIds: recordIds,
                titleField: this.titleField,
                subtitleField: this.subtitleField,
                iconName: this.iconName
            });

            this._selection = results;
            this.updateLookupSelection();
        } catch (error) {
            console.error('Error loading initial selection:', error);
        }
    }

    // EVENT HANDLERS

    async handleSearch(event) {
        const searchTerm = event.detail.searchTerm;
        const lookup = event.target;

        if (!this.queryTemplate) {
            console.error('soqlLookup: queryTemplate is required');
            lookup.setSearchResults([]);
            return;
        }

        try {
            const results = await search({
                queryTemplate: this.queryTemplate,
                searchTerm: searchTerm,
                titleField: this.titleField,
                subtitleField: this.subtitleField,
                iconName: this.iconName
            });

            lookup.setSearchResults(results);
        } catch (error) {
            console.error('Error searching:', error);
            lookup.setSearchResults([]);

            // Optionally show error to user
            const errorMessage = error.body?.message || error.message || 'An error occurred while searching';
            lookup.errors = [{ id: 'search-error', message: errorMessage }];
        }
    }

    handleSelectionChange(event) {
        const selectedIds = event.detail;
        const lookup = this.template.querySelector('c-lookup');

        // Update internal selection
        this._selection = lookup ? lookup.getSelection() : [];

        // Dispatch event to parent
        this.dispatchEvent(
            new CustomEvent('selectionchange', {
                detail: {
                    selectedIds: selectedIds,
                    selection: this._selection
                }
            })
        );
    }
}
