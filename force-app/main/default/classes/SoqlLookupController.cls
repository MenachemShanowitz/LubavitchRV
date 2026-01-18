/**
 * Controller for the soqlLookup LWC component.
 * Executes dynamic SOQL queries for lookup search functionality.
 */
public with sharing class SoqlLookupController {

    /**
     * Represents a single lookup search result
     */
    public class LookupSearchResult {
        @AuraEnabled public String id;
        @AuraEnabled public String title;
        @AuraEnabled public String subtitle;
        @AuraEnabled public String icon;

        public LookupSearchResult(String id, String title, String subtitle, String icon) {
            this.id = id;
            this.title = title;
            this.subtitle = subtitle;
            this.icon = icon;
        }
    }

    /**
     * Searches records based on a dynamic SOQL query template.
     *
     * @param queryTemplate SOQL query with {searchTerm} placeholder, e.g.:
     *        "SELECT Id, Name, Email FROM Contact WHERE Name LIKE '%{searchTerm}%' LIMIT 10"
     * @param searchTerm The search term entered by the user
     * @param titleField The field to use as the result title (e.g., 'Name')
     * @param subtitleField The field to use as the result subtitle (optional, e.g., 'Email')
     * @param iconName The SLDS icon name (e.g., 'standard:contact')
     * @return List of LookupSearchResult objects
     */
    @AuraEnabled(cacheable=true)
    public static List<LookupSearchResult> search(
        String queryTemplate,
        String searchTerm,
        String titleField,
        String subtitleField,
        String iconName
    ) {
        List<LookupSearchResult> results = new List<LookupSearchResult>();

        if (String.isBlank(queryTemplate) || String.isBlank(searchTerm)) {
            return results;
        }

        // Escape the search term to prevent SOQL injection
        String escapedSearchTerm = String.escapeSingleQuotes(searchTerm.trim());

        // Replace placeholder with escaped search term
        String query = queryTemplate.replace('{searchTerm}', escapedSearchTerm);

        try {
            // Execute the query with field-level security enforced
            List<SObject> records = Database.query(query);

            for (SObject record : records) {
                String recordId = (String) record.get('Id');
                String title = getFieldValue(record, titleField);
                String subtitle = String.isNotBlank(subtitleField) ? getFieldValue(record, subtitleField) : null;

                results.add(new LookupSearchResult(recordId, title, subtitle, iconName));
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error executing search: ' + e.getMessage());
        }

        return results;
    }

    /**
     * Gets a field value from an SObject, supporting dot notation for related fields.
     *
     * @param record The SObject record
     * @param fieldPath The field path (e.g., 'Name' or 'Account.Name')
     * @return The field value as a String, or empty string if null
     */
    private static String getFieldValue(SObject record, String fieldPath) {
        if (record == null || String.isBlank(fieldPath)) {
            return '';
        }

        // Handle dot notation for related fields (e.g., 'Account.Name')
        List<String> fieldParts = fieldPath.split('\\.');
        SObject currentRecord = record;

        for (Integer i = 0; i < fieldParts.size() - 1; i++) {
            currentRecord = currentRecord.getSObject(fieldParts[i]);
            if (currentRecord == null) {
                return '';
            }
        }

        Object value = currentRecord.get(fieldParts[fieldParts.size() - 1]);
        return value != null ? String.valueOf(value) : '';
    }

    /**
     * Gets records by their IDs for initial selection display.
     *
     * @param objectApiName The API name of the object (e.g., 'Contact')
     * @param recordIds List of record IDs to retrieve
     * @param titleField The field to use as the result title
     * @param subtitleField The field to use as the result subtitle (optional)
     * @param iconName The SLDS icon name
     * @return List of LookupSearchResult objects
     */
    @AuraEnabled(cacheable=true)
    public static List<LookupSearchResult> getRecordsById(
        String objectApiName,
        List<String> recordIds,
        String titleField,
        String subtitleField,
        String iconName
    ) {
        List<LookupSearchResult> results = new List<LookupSearchResult>();

        if (String.isBlank(objectApiName) || recordIds == null || recordIds.isEmpty()) {
            return results;
        }

        // Build field list
        Set<String> fields = new Set<String>{'Id'};
        fields.add(titleField);
        if (String.isNotBlank(subtitleField)) {
            fields.add(subtitleField);
        }

        // Build query
        String query = 'SELECT ' + String.join(new List<String>(fields), ', ') +
                       ' FROM ' + String.escapeSingleQuotes(objectApiName) +
                       ' WHERE Id IN :recordIds';

        try {
            List<SObject> records = Database.query(query);

            for (SObject record : records) {
                String recordId = (String) record.get('Id');
                String title = getFieldValue(record, titleField);
                String subtitle = String.isNotBlank(subtitleField) ? getFieldValue(record, subtitleField) : null;

                results.add(new LookupSearchResult(recordId, title, subtitle, iconName));
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving records: ' + e.getMessage());
        }

        return results;
    }
}
