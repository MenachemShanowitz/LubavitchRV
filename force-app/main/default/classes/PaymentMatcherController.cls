/**
 * Controller for the Payment Matcher LWC component.
 * Handles contact matching, duplicate detection, and payment creation.
 */
public with sharing class PaymentMatcherController {

    // Record Type IDs for Income
    private static Id chargeRecordTypeId {
        get {
            if (chargeRecordTypeId == null) {
                chargeRecordTypeId = Schema.SObjectType.OneCRM__Income__c
                    .getRecordTypeInfosByDeveloperName().get('Charge').getRecordTypeId();
            }
            return chargeRecordTypeId;
        }
        set;
    }

    private static Id paymentRecordTypeId {
        get {
            if (paymentRecordTypeId == null) {
                paymentRecordTypeId = Schema.SObjectType.OneCRM__Income__c
                    .getRecordTypeInfosByDeveloperName().get('Payment').getRecordTypeId();
            }
            return paymentRecordTypeId;
        }
        set;
    }

    /**
     * Wrapper class for Payment Import records with additional display info
     */
    public class PaymentImportWrapper {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public Date paymentDate;
        @AuraEnabled public String firstName;
        @AuraEnabled public String lastName;
        @AuraEnabled public String fullName;
        @AuraEnabled public String email;
        @AuraEnabled public Boolean isMembership;
        @AuraEnabled public String notes;
        @AuraEnabled public String paymentType;
        @AuraEnabled public String status;
        @AuraEnabled public Id matchedContactId;
        @AuraEnabled public String matchedContactName;
        @AuraEnabled public Id matchedAccountId;
        @AuraEnabled public String matchedAccountName;

        public PaymentImportWrapper(Payment_Import__c pi) {
            this.id = pi.Id;
            this.name = pi.Name;
            this.amount = pi.Amount__c;
            this.paymentDate = pi.Date__c;
            this.firstName = pi.First_Name__c;
            this.lastName = pi.Last_Name__c;
            this.fullName = pi.First_Name__c + ' ' + pi.Last_Name__c;
            this.email = pi.Email__c;
            this.isMembership = pi.Is_Membership__c;
            this.notes = pi.Notes__c;
            this.paymentType = pi.Payment_Type__c;
            this.status = pi.Status__c;
            this.matchedContactId = pi.Matched_Contact__c;
            this.matchedContactName = pi.Matched_Contact__r?.Name;
            this.matchedAccountId = pi.Matched_Account__c;
            this.matchedAccountName = pi.Matched_Account__r?.Name;
        }
    }

    /**
     * Wrapper class for Household matches with confidence score.
     * Matching is centered on the household (Account), not the contact.
     */
    public class HouseholdMatch implements Comparable {
        @AuraEnabled public Id id;  // Account Id
        @AuraEnabled public String name;  // Household name
        @AuraEnabled public Id primaryContactId;
        @AuraEnabled public String primaryContactName;
        @AuraEnabled public String primaryContactEmail;
        @AuraEnabled public String secondaryContactEmail;
        @AuraEnabled public String matchReason;
        @AuraEnabled public Integer confidence; // 1-100

        public HouseholdMatch(Account a, String reason, Integer conf) {
            this.id = a.Id;
            this.name = a.Name;
            this.primaryContactId = a.OneCRM__Primary_Contact__c;
            this.primaryContactName = a.OneCRM__Primary_Contact__r?.Name;
            this.primaryContactEmail = a.OneCRM__Primary_Contact__r?.Email;
            this.secondaryContactEmail = a.OneCRM__Secondary_Contact__r?.Email;
            this.matchReason = reason;
            this.confidence = conf;
        }

        public Integer compareTo(Object other) {
            HouseholdMatch otherMatch = (HouseholdMatch)other;
            // Sort by confidence descending
            if (this.confidence > otherMatch.confidence) return -1;
            if (this.confidence < otherMatch.confidence) return 1;
            return 0;
        }
    }

    /**
     * Wrapper class for existing payments (for duplicate check)
     */
    public class ExistingPayment implements Comparable {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public Date paymentDate;
        @AuraEnabled public String paymentType;
        @AuraEnabled public String status;
        @AuraEnabled public Integer daysDifference;
        @AuraEnabled public String notes;

        public ExistingPayment(OneCRM__Income__c inc, Date compareDate) {
            this.id = inc.Id;
            this.name = inc.Name;
            this.amount = Math.abs(inc.OneCRM__Amount__c); // Convert from negative
            this.paymentDate = inc.OneCRM__Date__c;
            this.paymentType = inc.OneCRM__Payment_Type__c;
            this.status = inc.OneCRM__Status__c;
            this.daysDifference = compareDate != null && inc.OneCRM__Date__c != null
                ? Math.abs(compareDate.daysBetween(inc.OneCRM__Date__c))
                : 9999;

            // Get notes from first line item if available
            if (inc.OneCRM__Income_Line_Items__r != null && !inc.OneCRM__Income_Line_Items__r.isEmpty()) {
                this.notes = inc.OneCRM__Income_Line_Items__r[0].OneCRM__Notes__c;
            }
        }

        public Integer compareTo(Object other) {
            ExistingPayment otherPayment = (ExistingPayment)other;
            // Sort by days difference ascending (closest first)
            if (this.daysDifference < otherPayment.daysDifference) return -1;
            if (this.daysDifference > otherPayment.daysDifference) return 1;
            return 0;
        }
    }

    /**
     * Wrapper class for unpaid pledges
     */
    public class UnpaidPledge implements Comparable {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public Decimal amountOutstanding;
        @AuraEnabled public Decimal amountPaid;
        @AuraEnabled public Date pledgeDate;
        @AuraEnabled public String campaignType;
        @AuraEnabled public String campaignSubType;
        @AuraEnabled public String campaignDetail;
        @AuraEnabled public String campaignName;
        @AuraEnabled public Integer daysDifference;
        @AuraEnabled public String notes;
        @AuraEnabled public String memo;
        @AuraEnabled public List<PledgeLineItem> lineItems;

        public UnpaidPledge(OneCRM__Income__c inc, Date compareDate) {
            this.id = inc.Id;
            this.name = inc.Name;
            this.amount = inc.OneCRM__Amount__c;
            this.amountOutstanding = inc.OneCRM__Amount_Outstanding__c;
            this.amountPaid = inc.OneCRM__Paid__c;
            this.pledgeDate = inc.OneCRM__Date__c;
            this.daysDifference = compareDate != null && inc.OneCRM__Date__c != null
                ? Math.abs(compareDate.daysBetween(inc.OneCRM__Date__c))
                : 9999;

            // Get campaign info, notes, and memo from line items
            this.lineItems = new List<PledgeLineItem>();
            if (inc.OneCRM__Income_Line_Items__r != null) {
                for (OneCRM__Income_Line_Item__c li : inc.OneCRM__Income_Line_Items__r) {
                    if (li.OneCRM__Amount_Outstanding__c > 0) {
                        this.lineItems.add(new PledgeLineItem(li));
                    }
                    // Get campaign info from first line item
                    if (this.campaignType == null && li.OneCRM__Related_Campaign__c != null) {
                        this.campaignType = li.OneCRM__Related_Campaign__r?.Type;
                        this.campaignSubType = li.OneCRM__Related_Campaign__r?.SubType__c;
                        this.campaignDetail = li.OneCRM__Related_Campaign__r?.Detail__c;
                        this.campaignName = li.OneCRM__Related_Campaign__r?.Name;
                    }
                    // Concatenate notes
                    if (String.isNotBlank(li.OneCRM__Notes__c)) {
                        this.notes = String.isBlank(this.notes) ? li.OneCRM__Notes__c : this.notes + '; ' + li.OneCRM__Notes__c;
                    }
                    // Concatenate memo
                    if (String.isNotBlank(li.OneCRM__Memo__c)) {
                        this.memo = String.isBlank(this.memo) ? li.OneCRM__Memo__c : this.memo + '; ' + li.OneCRM__Memo__c;
                    }
                }
            }
            // Sort line items by amount (smallest first)
            this.lineItems.sort();
        }

        public Integer compareTo(Object other) {
            UnpaidPledge otherPledge = (UnpaidPledge)other;
            // Sort by days difference ascending (closest first)
            if (this.daysDifference < otherPledge.daysDifference) return -1;
            if (this.daysDifference > otherPledge.daysDifference) return 1;
            return 0;
        }
    }

    /**
     * Wrapper for pledge line items
     */
    public class PledgeLineItem implements Comparable {
        @AuraEnabled public Id id;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public Decimal amountOutstanding;
        @AuraEnabled public String campaignName;
        @AuraEnabled public String notes;

        public PledgeLineItem(OneCRM__Income_Line_Item__c li) {
            this.id = li.Id;
            this.amount = li.OneCRM__Amount__c;
            this.amountOutstanding = li.OneCRM__Amount_Outstanding__c;
            this.campaignName = li.OneCRM__Related_Campaign__r?.Name;
            this.notes = li.OneCRM__Notes__c;
        }

        public Integer compareTo(Object other) {
            PledgeLineItem otherItem = (PledgeLineItem)other;
            if (this.amountOutstanding < otherItem.amountOutstanding) return -1;
            if (this.amountOutstanding > otherItem.amountOutstanding) return 1;
            return 0;
        }
    }

    /**
     * Wrapper for Campaign lookup results
     */
    public class CampaignWrapper {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String campaignType;
        @AuraEnabled public String subType;
        @AuraEnabled public String hebrewYear;

        public CampaignWrapper(Campaign c) {
            this.id = c.Id;
            this.name = c.Name;
            this.campaignType = c.Type;
            this.subType = c.SubType__c;
            this.hebrewYear = c.Hebrew_Year__c;
        }
    }

    /**
     * Gets all payment imports for the list view
     */
    @AuraEnabled(cacheable=true)
    public static List<PaymentImportWrapper> getPaymentImports(String statusFilter) {
        List<PaymentImportWrapper> results = new List<PaymentImportWrapper>();

        String query = 'SELECT Id, Name, Amount__c, Date__c, First_Name__c, Last_Name__c, ' +
            'Email__c, Is_Membership__c, Notes__c, Payment_Type__c, Status__c, ' +
            'Matched_Contact__c, Matched_Contact__r.Name, ' +
            'Matched_Account__c, Matched_Account__r.Name ' +
            'FROM Payment_Import__c ';

        if (String.isNotBlank(statusFilter) && statusFilter != 'All') {
            query += 'WHERE Status__c = :statusFilter ';
        }

        query += 'ORDER BY Date__c ASC, Name ASC LIMIT 500';

        for (Payment_Import__c pi : Database.query(query)) {
            results.add(new PaymentImportWrapper(pi));
        }

        return results;
    }

    /**
     * Gets a single payment import by ID
     */
    @AuraEnabled
    public static PaymentImportWrapper getPaymentImport(Id importId) {
        Payment_Import__c pi = [
            SELECT Id, Name, Amount__c, Date__c, First_Name__c, Last_Name__c,
                Email__c, Is_Membership__c, Notes__c, Payment_Type__c, Status__c,
                Matched_Contact__c, Matched_Contact__r.Name,
                Matched_Account__c, Matched_Account__r.Name
            FROM Payment_Import__c
            WHERE Id = :importId
            LIMIT 1
        ];
        return new PaymentImportWrapper(pi);
    }

    /**
     * Finds potential household matches based on email and name.
     * Searches both primary and secondary contact emails on the household.
     * Returns household (Account) data with both contacts' info.
     */
    @AuraEnabled
    public static List<HouseholdMatch> findHouseholdMatches(String email, String firstName, String lastName) {
        List<HouseholdMatch> results = new List<HouseholdMatch>();
        Set<Id> addedAccountIds = new Set<Id>();

        // Clean inputs
        email = String.isBlank(email) ? null : email.trim().toLowerCase();
        firstName = String.isBlank(firstName) ? '' : firstName.trim().toLowerCase();
        lastName = String.isBlank(lastName) ? '' : lastName.trim().toLowerCase();

        // Standard fields to query
        String accountFields = 'Id, Name, OneCRM__Primary_Contact__c, OneCRM__Primary_Contact__r.Name, ' +
            'OneCRM__Primary_Contact__r.Email, OneCRM__Secondary_Contact__r.Email';

        // 1. Search by email match on primary OR secondary contact (highest confidence)
        if (String.isNotBlank(email)) {
            for (Account a : Database.query(
                'SELECT ' + accountFields + ' FROM Account ' +
                'WHERE OneCRM__Primary_Contact__r.Email = :email ' +
                'OR OneCRM__Secondary_Contact__r.Email = :email ' +
                'LIMIT 10'
            )) {
                String reason = a.OneCRM__Primary_Contact__r?.Email == email ?
                    'Primary email match' : 'Secondary email match';
                results.add(new HouseholdMatch(a, reason, 100));
                addedAccountIds.add(a.Id);
            }
        }

        // 2. Search by household name match
        if (String.isNotBlank(lastName)) {
            String lastNameLike = '%' + lastName + '%';
            for (Account a : Database.query(
                'SELECT ' + accountFields + ' FROM Account ' +
                'WHERE Name LIKE :lastNameLike ' +
                'AND Id NOT IN :addedAccountIds ' +
                'LIMIT 10'
            )) {
                Integer conf = a.Name.toLowerCase().contains(lastName) ? 70 : 50;
                results.add(new HouseholdMatch(a, 'Household name match', conf));
                addedAccountIds.add(a.Id);
            }
        }

        // 3. Search by primary contact name
        if (String.isNotBlank(firstName) && String.isNotBlank(lastName) && results.isEmpty()) {
            for (Account a : Database.query(
                'SELECT ' + accountFields + ' FROM Account ' +
                'WHERE OneCRM__Primary_Contact__r.FirstName = :firstName ' +
                'AND OneCRM__Primary_Contact__r.LastName = :lastName ' +
                'AND Id NOT IN :addedAccountIds ' +
                'LIMIT 10'
            )) {
                results.add(new HouseholdMatch(a, 'Primary contact name match', 60));
                addedAccountIds.add(a.Id);
            }
        }

        // Sort by confidence descending
        results.sort();

        return results;
    }

    /**
     * Gets existing payments for duplicate detection
     */
    @AuraEnabled
    public static List<ExistingPayment> getExistingPayments(Id accountId, Date paymentDate, Decimal amount) {
        List<ExistingPayment> results = new List<ExistingPayment>();

        if (accountId == null) {
            return results;
        }

        // Get payments within 60 days of the payment date
        Date startDate = paymentDate.addDays(-60);
        Date endDate = paymentDate.addDays(60);

        // Convert amount to negative for comparison (payments are stored as negative)
        Decimal negativeAmount = -Math.abs(amount);
        Decimal amountLow = negativeAmount * 1.1; // 10% tolerance (more negative)
        Decimal amountHigh = negativeAmount * 0.9; // 10% tolerance (less negative)

        List<OneCRM__Income__c> payments = [
            SELECT Id, Name, OneCRM__Amount__c, OneCRM__Date__c, OneCRM__Payment_Type__c,
                OneCRM__Status__c,
                (SELECT Id, OneCRM__Notes__c FROM OneCRM__Income_Line_Items__r LIMIT 1)
            FROM OneCRM__Income__c
            WHERE RecordTypeId = :paymentRecordTypeId
            AND OneCRM__Donor__c = :accountId
            AND OneCRM__Date__c >= :startDate
            AND OneCRM__Date__c <= :endDate
            ORDER BY OneCRM__Date__c DESC
            LIMIT 50
        ];

        for (OneCRM__Income__c p : payments) {
            results.add(new ExistingPayment(p, paymentDate));
        }

        // Sort by days difference
        results.sort();

        return results;
    }

    /**
     * Gets unpaid pledges for the account
     */
    @AuraEnabled
    public static List<UnpaidPledge> getUnpaidPledges(Id accountId, Date paymentDate, Boolean isMembership, Decimal paymentAmount) {
        List<UnpaidPledge> results = new List<UnpaidPledge>();

        if (accountId == null) {
            return results;
        }

        // Query charges with outstanding balance where amount >= payment amount
        List<OneCRM__Income__c> charges = [
            SELECT Id, Name, OneCRM__Amount__c, OneCRM__Amount_Outstanding__c, OneCRM__Paid__c,
                OneCRM__Date__c, OneCRM__Donor__c,
                (SELECT Id, OneCRM__Amount__c, OneCRM__Amount_Outstanding__c, OneCRM__Notes__c,
                    OneCRM__Memo__c, OneCRM__Related_Campaign__c, OneCRM__Related_Campaign__r.Name,
                    OneCRM__Related_Campaign__r.Type, OneCRM__Related_Campaign__r.SubType__c,
                    OneCRM__Related_Campaign__r.Detail__c
                FROM OneCRM__Income_Line_Items__r
                WHERE OneCRM__Amount_Outstanding__c > 0
                ORDER BY OneCRM__Amount_Outstanding__c ASC)
            FROM OneCRM__Income__c
            WHERE RecordTypeId = :chargeRecordTypeId
            AND OneCRM__Donor__c = :accountId
            AND OneCRM__Amount_Outstanding__c >= :paymentAmount
            ORDER BY OneCRM__Date__c DESC
            LIMIT 50
        ];

        List<UnpaidPledge> membershipPledges = new List<UnpaidPledge>();
        List<UnpaidPledge> otherPledges = new List<UnpaidPledge>();

        for (OneCRM__Income__c c : charges) {
            UnpaidPledge pledge = new UnpaidPledge(c, paymentDate);

            // Categorize by membership
            if (pledge.campaignType == 'Membership') {
                membershipPledges.add(pledge);
            } else {
                otherPledges.add(pledge);
            }
        }

        // Sort each list by days difference
        membershipPledges.sort();
        otherPledges.sort();

        // If is_membership, put membership pledges first
        if (isMembership) {
            results.addAll(membershipPledges);
            results.addAll(otherPledges);
        } else {
            results.addAll(otherPledges);
            results.addAll(membershipPledges);
        }

        return results;
    }

    /**
     * Updates the matched contact on the import record
     */
    @AuraEnabled
    public static PaymentImportWrapper updateMatchedHousehold(Id importId, Id accountId) {
        // Get the account's primary contact
        Account a = [SELECT Id, OneCRM__Primary_Contact__c FROM Account WHERE Id = :accountId LIMIT 1];

        Payment_Import__c pi = new Payment_Import__c(
            Id = importId,
            Matched_Contact__c = a.OneCRM__Primary_Contact__c,
            Matched_Account__c = accountId,
            Status__c = 'Contact Matched'
        );
        update pi;

        return getPaymentImport(importId);
    }

    /**
     * Marks the import as a duplicate
     */
    @AuraEnabled
    public static PaymentImportWrapper markAsDuplicate(Id importId) {
        Payment_Import__c pi = new Payment_Import__c(
            Id = importId,
            Status__c = 'Duplicate'
        );
        update pi;

        return getPaymentImport(importId);
    }

    /**
     * Marks the import as skipped
     */
    @AuraEnabled
    public static PaymentImportWrapper markAsSkipped(Id importId) {
        Payment_Import__c pi = new Payment_Import__c(
            Id = importId,
            Status__c = 'Skipped'
        );
        update pi;

        return getPaymentImport(importId);
    }

    /**
     * Creates a payment for the specified charge
     */
    @AuraEnabled
    public static PaymentImportWrapper createPayment(Id importId, Id chargeId) {
        // Get the import record
        Payment_Import__c importRec = [
            SELECT Id, Amount__c, Date__c, Payment_Type__c, Notes__c,
                Matched_Contact__c, Matched_Account__c
            FROM Payment_Import__c
            WHERE Id = :importId
            LIMIT 1
        ];

        // Get the charge and its line items
        OneCRM__Income__c charge = [
            SELECT Id, OneCRM__Donor__c, OneCRM__Related_Contact__c,
                (SELECT Id, OneCRM__Amount__c, OneCRM__Amount_Outstanding__c
                FROM OneCRM__Income_Line_Items__r
                WHERE OneCRM__Amount_Outstanding__c > 0
                ORDER BY OneCRM__Amount_Outstanding__c ASC)
            FROM OneCRM__Income__c
            WHERE Id = :chargeId
            LIMIT 1
        ];

        // Create the payment header
        OneCRM__Income__c payment = new OneCRM__Income__c(
            RecordTypeId = paymentRecordTypeId,
            OneCRM__Donor__c = importRec.Matched_Account__c,
            OneCRM__Related_Contact__c = importRec.Matched_Contact__c,
            OneCRM__Date__c = importRec.Date__c,
            OneCRM__Paid__c = 0,
            OneCRM__Status__c = 'Success',
            OneCRM__Payment_Type__c = importRec.Payment_Type__c,
            Created_By_Matching_System__c = true
        );
        insert payment;

        // Create payment line items, applying to smallest charge line items first
        Decimal remainingAmount = importRec.Amount__c;
        List<OneCRM__Income_Line_Item__c> paymentLineItems = new List<OneCRM__Income_Line_Item__c>();

        for (OneCRM__Income_Line_Item__c chargeLine : charge.OneCRM__Income_Line_Items__r) {
            if (remainingAmount <= 0) break;

            // Determine how much to apply to this line item
            Decimal amountToApply = Math.min(remainingAmount, chargeLine.OneCRM__Amount_Outstanding__c);

            OneCRM__Income_Line_Item__c paymentLine = new OneCRM__Income_Line_Item__c(
                OneCRM__Income__c = payment.Id,
                OneCRM__Donor__c = importRec.Matched_Account__c,
                OneCRM__Related_Contact__c = importRec.Matched_Contact__c,
                OneCRM__Amount__c = -amountToApply, // Negative for payment
                OneCRM__Related_Income__c = chargeId,
                OneCRM__Related_Income_Line_Item__c = chargeLine.Id,
                OneCRM__Notes__c = importRec.Notes__c,
                Created_By_Matching_System__c = true
            );
            paymentLineItems.add(paymentLine);

            remainingAmount -= amountToApply;
        }

        if (!paymentLineItems.isEmpty()) {
            insert paymentLineItems;
        }

        // Update the import record
        Payment_Import__c piUpdate = new Payment_Import__c(
            Id = importId,
            Status__c = 'Completed',
            Applied_To_Charge__c = chargeId,
            Created_Payment__c = payment.Id
        );
        update piUpdate;

        return getPaymentImport(importId);
    }

    /**
     * Gets counts by status for the filter badges
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Integer> getStatusCounts() {
        Map<String, Integer> counts = new Map<String, Integer>{
            'All' => 0,
            'New' => 0,
            'Contact Matched' => 0,
            'Duplicate' => 0,
            'Completed' => 0,
            'Skipped' => 0
        };

        for (AggregateResult ar : [
            SELECT Status__c, COUNT(Id) cnt
            FROM Payment_Import__c
            GROUP BY Status__c
        ]) {
            String status = (String)ar.get('Status__c');
            Integer cnt = (Integer)ar.get('cnt');
            counts.put(status, cnt);
            counts.put('All', counts.get('All') + cnt);
        }

        return counts;
    }

    /**
     * Searches for campaigns by name
     */
    @AuraEnabled
    public static List<CampaignWrapper> searchCampaigns(String searchTerm) {
        List<CampaignWrapper> results = new List<CampaignWrapper>();

        String searchPattern = '%' + (String.isBlank(searchTerm) ? '' : searchTerm.trim()) + '%';

        List<Campaign> campaigns = [
            SELECT Id, Name, Type, SubType__c, Hebrew_Year__c
            FROM Campaign
            WHERE Name LIKE :searchPattern
            AND IsActive = true
            ORDER BY Name ASC
            LIMIT 20
        ];

        for (Campaign c : campaigns) {
            results.add(new CampaignWrapper(c));
        }

        return results;
    }

    /**
     * Creates a new pledge and payment together
     * Used when no existing pledge matches the imported payment
     */
    @AuraEnabled
    public static PaymentImportWrapper createPledgeAndPayment(Id importId, Id campaignId, Date pledgeDate) {
        // Get the import record
        Payment_Import__c importRec = [
            SELECT Id, Amount__c, Date__c, Payment_Type__c, Notes__c,
                Matched_Contact__c, Matched_Account__c
            FROM Payment_Import__c
            WHERE Id = :importId
            LIMIT 1
        ];

        // Get the contact for attribution
        Contact matchedContact = [
            SELECT Id, AccountId
            FROM Contact
            WHERE Id = :importRec.Matched_Contact__c
            LIMIT 1
        ];

        // 1. Create the Charge (Pledge) header
        OneCRM__Income__c charge = new OneCRM__Income__c(
            RecordTypeId = chargeRecordTypeId,
            OneCRM__Donor__c = importRec.Matched_Account__c,
            OneCRM__Related_Contact__c = importRec.Matched_Contact__c,
            OneCRM__Date__c = pledgeDate,
            OneCRM__Paid__c = 0,
            OneCRM__Status__c = 'Success',
            Created_By_Matching_System__c = true
        );
        insert charge;

        // 2. Create the Charge Line Item - linked to Campaign for categorization
        OneCRM__Income_Line_Item__c chargeLine = new OneCRM__Income_Line_Item__c(
            OneCRM__Income__c = charge.Id,
            OneCRM__Donor__c = importRec.Matched_Account__c,
            OneCRM__Related_Contact__c = importRec.Matched_Contact__c,
            OneCRM__Amount__c = importRec.Amount__c, // POSITIVE amount
            OneCRM__Related_Campaign__c = campaignId,
            OneCRM__Type__c = 'Campaign', // Hardcoded per data model
            OneCRM__Notes__c = importRec.Notes__c,
            Created_By_Matching_System__c = true
        );
        insert chargeLine;

        // 3. Create the Payment header
        OneCRM__Income__c payment = new OneCRM__Income__c(
            RecordTypeId = paymentRecordTypeId,
            OneCRM__Donor__c = importRec.Matched_Account__c,
            OneCRM__Related_Contact__c = importRec.Matched_Contact__c,
            OneCRM__Date__c = importRec.Date__c, // Payment date from import
            OneCRM__Paid__c = 0,
            OneCRM__Status__c = 'Success',
            OneCRM__Payment_Type__c = importRec.Payment_Type__c,
            Created_By_Matching_System__c = true
        );
        insert payment;

        // 4. Create the Payment Line Item - linked to Charge
        OneCRM__Income_Line_Item__c paymentLine = new OneCRM__Income_Line_Item__c(
            OneCRM__Income__c = payment.Id,
            OneCRM__Donor__c = importRec.Matched_Account__c,
            OneCRM__Related_Contact__c = importRec.Matched_Contact__c,
            OneCRM__Amount__c = -importRec.Amount__c, // NEGATIVE amount
            OneCRM__Related_Income__c = charge.Id,
            OneCRM__Related_Income_Line_Item__c = chargeLine.Id,
            OneCRM__Notes__c = importRec.Notes__c,
            Created_By_Matching_System__c = true
            // DO NOT SET: OneCRM__Related_Campaign__c, OneCRM__Type__c
            // Categorization inherited from linked charge line's Campaign
        );
        insert paymentLine;

        // 5. Update the import record
        Payment_Import__c piUpdate = new Payment_Import__c(
            Id = importId,
            Status__c = 'Completed',
            Applied_To_Charge__c = charge.Id,
            Created_Payment__c = payment.Id
        );
        update piUpdate;

        return getPaymentImport(importId);
    }
}
