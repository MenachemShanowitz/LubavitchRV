public with sharing class CampaignGeneratorAction {

    public class FlowInput {
        @InvocableVariable(label='Hebrew Year' description='The Hebrew Year string (e.g., 5784)' required=true)
        public String hebrewYear;
    }

    @InvocableMethod(label='Generate Financial Campaigns' description='Creates Campaigns based on Metadata configuration and Hebrew Year')
    public static void generateCampaigns(List<FlowInput> inputs) {
        // Flow passes a list, but usually we only run this for one year at a time.
        // We'll take the first input.
        if (inputs == null || inputs.isEmpty()) return;
        String inputYear = inputs[0].hebrewYear;

        // 1. Fetch all Metadata Configuration Records
        // Note: Ensure the API names match your actual Metadata object
        List<Financial_Campaign_Config__mdt> configs = [
            SELECT Type__c, SubType__c, Detail__c, Campaign_Name__c, Has_Year__c 
            FROM Financial_Campaign_Config__mdt
        ];

        if (configs.isEmpty()) return;

        // 2. Build a set of "Keys" for existing campaigns to prevent duplicates.
        // We want to minimize the query scope. We only care about campaigns that match
        // the Types in our config, and either match the input year OR have no year.
        
        Set<String> configTypes = new Set<String>();
        for (Financial_Campaign_Config__mdt mdt : configs) {
            configTypes.add(mdt.Type__c);
        }

        List<Campaign> existingCampaigns = [
            SELECT Type, SubType__c, Detail__c, Hebrew_Year__c 
            FROM Campaign 
            WHERE Type IN :configTypes 
            AND (Hebrew_Year__c = :inputYear OR Hebrew_Year__c = null)
        ];

        // Create a unique key for every existing campaign found
        // Key Format: "Type|SubType|Detail|HebrewYear"
        Set<String> existingKeys = new Set<String>();
        for (Campaign c : existingCampaigns) {
            existingKeys.add(generateKey(c.Type, c.SubType__c, c.Detail__c, c.Hebrew_Year__c));
        }

        // 3. Iterate Metadata and prepare new Campaigns
        List<Campaign> campaignsToInsert = new List<Campaign>();

        for (Financial_Campaign_Config__mdt config : configs) {
            
            // Determine the year value for this specific record
            // If Has_Year is true, we use the input year. If false, we use null.
            String yearForRecord = config.Has_Year__c ? inputYear : null;

            // Generate the key to check if it already exists
            String checkKey = generateKey(config.Type__c, config.SubType__c, config.Detail__c, yearForRecord);

            // If this permutation already exists, skip it
            if (existingKeys.contains(checkKey)) {
                continue; 
            }

            // 4. Create the new Campaign
            Campaign newCamp = new Campaign();
            newCamp.Type = config.Type__c;
            newCamp.SubType__c = config.SubType__c;
            newCamp.Detail__c = config.Detail__c;
            newCamp.IsActive = true;

            // Handle Name and Year Logic
            // get last 2 chracters for campaign name
            String finalName = config.Campaign_Name__c;

            if (config.Has_Year__c) {
                // Populate the year field
                newCamp.Hebrew_Year__c = inputYear;
                
                // Replace {year} token in name
                if (finalName != null && finalName.containsIgnoreCase('{year}')) {
                    // get last 2 chars of the year
                    finalName = finalName.replace('{year}', inputYear.substring(inputYear.length() - 2));
                }
            } else {
                // Do not populate Hebrew_Year__c
                // Do not replace {year} (per requirements)
                newCamp.Hebrew_Year__c = null;
            }

            // Safety check for Name length (Salesforce max is 80)
            if (finalName.length() > 80) {
                finalName = finalName.substring(0, 80);
            }
            newCamp.Name = finalName;

            campaignsToInsert.add(newCamp);
        }

        // 5. Insert
        if (!campaignsToInsert.isEmpty()) {
            insert campaignsToInsert;
        }
    }

    // Helper to create consistent unique keys
    private static String generateKey(String typeVal, String subTypeVal, String detailVal, String yearVal) {
        // Handle nulls to avoid "null" string issues
        String t = (typeVal == null) ? '' : typeVal;
        String s = (subTypeVal == null) ? '' : subTypeVal;
        String d = (detailVal == null) ? '' : detailVal;
        String y = (yearVal == null) ? '' : yearVal;
        
        return (t + '|' + s + '|' + d + '|' + y).toLowerCase();
    }
}