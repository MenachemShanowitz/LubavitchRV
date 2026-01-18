# OneCRM Data Model Reference

This document describes the data structure of the OneCRM Salesforce package, a CRM system designed for Jewish synagogues with a focus on fundraising and donor management.

## Table of Contents

1. [Core Concepts](#core-concepts)
2. [Financial Model](#financial-model)
3. [Implementation: Campaign-Centric Categorization](#implementation-campaign-centric-categorization)
4. [Object Reference](#object-reference)
5. [Creating Records](#creating-records)
6. [Field Value Reference](#field-value-reference)

---

## Core Concepts

### Household-Based Model

OneCRM uses a **household-based donor model**:

- **Account** = Household (e.g., "Rabbi Yehuda & Mrs. Miri Shaffer")
- **Contact** = Individual person within the household (e.g., "Yehuda Shaffer")
- Each Contact has an `AccountId` linking to their primary household

Financial records link to **both** Account and Contact:
- `OneCRM__Donor__c` → Account (household, used for billing/tax receipts)
- `OneCRM__Related_Contact__c` → Contact (individual attribution)

### Double-Entry Accounting

OneCRM uses a **double-entry system** with signed amounts:

| Record Type | Amount Sign | Meaning |
|-------------|-------------|---------|
| **Charge** | Positive (+) | What the donor owes (pledge/invoice) |
| **Payment** | Negative (-) | What the donor paid (actual funds received) |

The sum of all Income records for a donor should equal their outstanding balance.

---

## Financial Model

### Income Records (OneCRM__Income__c)

The `OneCRM__Income__c` object stores all financial transactions. It has **two Record Types**:

#### Record Type: Charge (Pledge)

- **Description**: Represents what the donor owes (pledges, invoices, commitments)
- **Record Type ID**: `012fn000000SOkHAAW`
- **Amount**: Positive value (e.g., +$1,000)
- **Paid__c**: Running total of payments received against this charge
- **Amount_Outstanding__c**: Formula = Amount - Paid (what remains unpaid)
- **Payment_Type__c**: Always null (no payment method for a pledge)
- **Status__c**: Typically "Success" (meaning the pledge is confirmed)

#### Record Type: Payment

- **Description**: Represents actual funds received from the donor
- **Record Type ID**: `012fn000000SOkIAAW`
- **Amount**: Negative value (e.g., -$500)
- **Paid__c**: Always 0 (payments don't track partial payments)
- **Amount_Outstanding__c**: Always 0
- **Payment_Type__c**: Required (Cash, Check, CC, Zelle, etc.)
- **Status__c**: Can be Pending, Success, Declined, Failed, Cancelled

### Income Line Items (OneCRM__Income_Line_Item__c)

Each Income record has one or more line items. **Charge line items and Payment line items serve different purposes:**

#### Charge Line Items

- **Amount**: Positive (e.g., +$1,000)
- **Purpose**: Define what is being charged and link to Campaign for categorization
- **Related_Campaign__c**: **Required** - Links to Campaign which provides categorization
- **Related_Income__c**: Always null (this IS the charge)
- **Related_Income_Line_Item__c**: Always null

#### Payment Line Items

- **Amount**: Negative (e.g., -$500)
- **Purpose**: Record payment against a specific charge
- **Related_Campaign__c**: Do not set (categorization comes from the linked charge)
- **Related_Income__c**: **Required** - Must link to the Charge being paid
- **Related_Income_Line_Item__c**: **Required** - Must link to the specific Charge line item being paid

> **Important**: Every payment line item MUST link to a charge line item. Payment line items should NOT have any categorization fields populated - that information is inherited from the linked charge line item's Campaign.

### Balance Calculation

For a given donor (Account):

```
Total Owed = SUM(Charge.Amount__c)           -- All positive amounts
Total Paid = SUM(Payment.Amount__c)          -- All negative amounts (absolute value = paid)
Outstanding = Total Owed + Total Paid        -- Positive + Negative = Net balance
```

At the individual Charge level:
```
Charge.Amount_Outstanding__c = Charge.Amount__c - Charge.Paid__c
```

---

## Implementation: Campaign-Centric Categorization

### Overview

This implementation uses a **Campaign-centric categorization model** that differs from the traditional OneCRM approach:

| Traditional OneCRM | This Implementation |
|--------------------|---------------------|
| `OneCRM__Type__c` on line item | Hardcoded to "Campaign" (labeled "UNUSED T" in UI) |
| `OneCRM__SubType__c` on line item | **UNUSED** (labeled "UNUSED ST") |
| Categorization on line item | Categorization on **Campaign** |

### How It Works

1. **Every charge line item links to a Campaign** via `OneCRM__Related_Campaign__c`
2. **Campaign contains the categorization**:
   - `Type` (standard field): Category (Kibudim, Membership, Events, etc.)
   - `SubType__c`: Sub-category (holiday, event name, etc.)
   - `Hebrew_Year__c`: Hebrew calendar year (5785, 5786, etc.)
   - `Detail__c`: Specific honor detail (Aliyah, Hagbah, Psicha, etc.)
3. **Formula fields on line item** automatically derive values from Campaign:
   - `Campaign_Type__c` = `TEXT(OneCRM__Related_Campaign__r.Type)`
   - `Campaign_SubType__c` = `TEXT(OneCRM__Related_Campaign__r.SubType__c)`
   - `Campaign_Year__c` = `OneCRM__Related_Campaign__r.Hebrew_Year__c`

### Data Flow

```
CAMPAIGN
├── Type = "Kibudim"
├── SubType__c = "Yom Kipur"
├── Hebrew_Year__c = "5786"
└── Detail__c = "Aliyah"
        │
        │ Related_Campaign__c
        ▼
CHARGE LINE ITEM
├── OneCRM__Related_Campaign__c = [Campaign Id]
├── Campaign_Type__c = "Kibudim"        ← Formula (auto-populated)
├── Campaign_SubType__c = "Yom Kipur"   ← Formula (auto-populated)
├── Campaign_Year__c = "5786"           ← Formula (auto-populated)
├── OneCRM__Type__c = "Campaign"        ← Hardcoded to conform to package
└── OneCRM__SubType__c = null           ← UNUSED - Do not set
```

### Why This Approach?

1. **Single source of truth**: Campaign defines the categorization once; all line items inherit it
2. **Consistency**: All line items for a campaign automatically have matching categorization
3. **Easier reporting**: Query Campaign for aggregated totals by type/subtype/year
4. **Reduced data entry errors**: No need to manually set type/subtype on each line item

---

## Object Reference

### OneCRM__Income__c (Financial Transaction Header)

| Field | Type | Description |
|-------|------|-------------|
| `RecordTypeId` | Lookup | **Charge** (pledges) or **Payment** (funds received) |
| `OneCRM__Donor__c` | Lookup(Account) | **Required**. The household making the donation |
| `OneCRM__Related_Contact__c` | Lookup(Contact) | The individual person associated with this transaction |
| `OneCRM__Date__c` | Date | Transaction date |
| `OneCRM__Amount__c` | Currency (Rollup) | Sum of all line item amounts. Positive for Charges, negative for Payments |
| `OneCRM__Paid__c` | Currency | Amount paid against this record. Used on Charges only; always 0 for Payments |
| `OneCRM__Amount_Outstanding__c` | Currency (Formula) | `MAX(0, Amount__c - Paid__c)`. Only meaningful for Charges |
| `OneCRM__Payment_Type__c` | Picklist | Payment method. Required for Payments, null for Charges |
| `OneCRM__Status__c` | Picklist | Transaction status |
| `OneCRM__Credit_Card__c` | Lookup(OneCRM__Credit_Card__c) | Credit card used for payment |
| `OneCRM__Campaign__c` | Lookup(Campaign) | Associated Salesforce Campaign (header level) |
| `OneCRM__Payment_Program__c` | Lookup(OneCRM__Payment_Program__c) | If this Charge was generated by a recurring program |
| `OneCRM__Payment_Plan__c` | Lookup(OneCRM__Payment_Program__c) | If this Charge is being paid off by a recurring program |
| `Name` | Text (Auto) | Auto-generated name describing the transaction |

### OneCRM__Income_Line_Item__c (Financial Transaction Detail)

| Field | Type | Charge Lines | Payment Lines |
|-------|------|--------------|---------------|
| `OneCRM__Income__c` | Master-Detail(Income) | **Required** | **Required** |
| `OneCRM__Amount__c` | Currency | Positive (+) | Negative (-) |
| `OneCRM__Paid__c` | Currency | Tracks payments received | Do not use |
| `OneCRM__Amount_Outstanding__c` | Currency (Formula) | `MAX(0, Amount - Paid)` | Always 0 |
| `OneCRM__Type__c` | Picklist | Set to "Campaign" (hardcoded to conform to package) | Do not set |
| `OneCRM__SubType__c` | Picklist | **UNUSED** - Do not set | Do not set |
| `OneCRM__Donor__c` | Lookup(Account) | Household | Household |
| `OneCRM__Related_Contact__c` | Lookup(Contact) | Individual | Individual |
| `OneCRM__Related_Income__c` | Lookup(Income) | Always null | **Required** - Charge being paid |
| `OneCRM__Related_Income_Line_Item__c` | Lookup(Income_Line_Item) | Always null | **Required** - Charge line being paid |
| `OneCRM__Related_Campaign__c` | Lookup(Campaign) | **Required** - Provides categorization | Do not set |
| `Campaign_Type__c` | Text (Formula) | Auto from Campaign.Type | Auto from linked charge |
| `Campaign_SubType__c` | Text (Formula) | Auto from Campaign.SubType__c | Auto from linked charge |
| `Campaign_Year__c` | Text (Formula) | Auto from Campaign.Hebrew_Year__c | Auto from linked charge |
| `OneCRM__Date__c` | Date | Line item date | Line item date |
| `OneCRM__Transaction_Date__c` | Date | Transaction date | Transaction date |
| `OneCRM__Is_Tax_Deductible__c` | Checkbox | Tax-deductible flag | Do not set |
| `OneCRM__Memo__c` | Text | Short memo | Optional |
| `OneCRM__Notes__c` | Long Text | Additional notes | Optional |
| `Detail__c` | Picklist | Specific honor (Aliyah, Hagbah, etc.) | Do not set |

### Campaign (Salesforce Standard Object - Extended)

| Field | Type | Description |
|-------|------|-------------|
| `Name` | Text | Campaign name |
| `Type` | Picklist | **Category**: Kibudim, Membership, Events, Hall Rental, etc. |
| `SubType__c` | Picklist | **Sub-category**: Holiday name, event type, etc. |
| `Hebrew_Year__c` | Text | Hebrew calendar year (e.g., "5785", "5786") |
| `Detail__c` | Picklist | Specific honor detail (dependent on SubType) |
| `OneCRM__Is_Tax_Deductible__c` | Checkbox | Whether donations to this campaign are tax-deductible |
| `OneCRM__Total_Amount__c` | Number | Total amount charged |
| `OneCRM__Total_Amount_Paid__c` | Number | Total amount paid |
| `OneCRM__Total_Amount_Outstanding__c` | Number | Total amount outstanding |

### OneCRM__Relationship__c (Person-to-Household Links)

| Field | Type | Description |
|-------|------|-------------|
| `OneCRM__Account__c` | Master-Detail(Account) | The household |
| `OneCRM__Contact__c` | Lookup(Contact) | The individual person |
| `OneCRM__Type__c` | Picklist | Relationship type (Husband, Wife, Spouse, Father, Mother, Child, etc.) |
| `OneCRM__IsPrimary__c` | Checkbox | Whether this is the primary relationship |
| `OneCRM__Role__c` | Text | Role or title |

### OneCRM__Communication__c (Contact Information)

| Field | Type | Description |
|-------|------|-------------|
| `OneCRM__Related_Account__c` | Lookup(Account) | Associated household |
| `OneCRM__Related_Contact__c` | Lookup(Contact) | Associated individual |
| `OneCRM__Type__c` | Picklist | Address, Email, or Phone |
| `OneCRM__Primary__c` | Checkbox | Primary contact method |
| `OneCRM__Street__c` | Text | Street address |
| `OneCRM__City__c` | Text | City |
| `OneCRM__State__c` | Text | State/Province |
| `OneCRM__PostalCode__c` | Text | Postal/ZIP code |
| `OneCRM__Country__c` | Text | Country |
| `OneCRM__Email__c` | Email | Email address |
| `OneCRM__Phone__c` | Phone | Phone number |

### OneCRM__Credit_Card__c (Stored Payment Methods)

| Field | Type | Description |
|-------|------|-------------|
| `OneCRM__Cardholder__c` | Lookup(Account) | Account that owns the card |
| `OneCRM__Contact_Cardholder__c` | Lookup(Contact) | Individual cardholder |
| `OneCRM__Last4__c` | Text | Last 4 digits of card |
| `OneCRM__Type__c` | Picklist | Card type (Visa, Mastercard, etc.) |
| `OneCRM__Expiration_Date__c` | Text | Expiration date |
| `OneCRM__Expired__c` | Checkbox | Whether card is expired |

### OneCRM__Payment_Program__c (Recurring Donations)

| Field | Type | Description |
|-------|------|-------------|
| `OneCRM__Payor__c` | Lookup(Account) | **Required**. Account making recurring payments |
| `OneCRM__Amount_Per_Charge__c` | Currency | **Required**. Amount per recurring charge |
| `OneCRM__Schedule__c` | Picklist | Weekly, Monthly (default), or Yearly |
| `OneCRM__Charges_Remaining__c` | Number | Number of charges remaining |
| `OneCRM__Next_Charge_Date__c` | Date | Next scheduled charge date |
| `OneCRM__Next_Charge_Credit_Card__c` | Lookup(Credit_Card) | Card to charge |
| `OneCRM__Status__c` | Picklist | Inactive, Waiting, Auto Processing, Finished, Creating |
| `OneCRM__Campaign__c` | Lookup(Campaign) | Associated campaign |

---

## Creating Records

### Creating a Charge (Pledge)

```apex
// 1. Get record type
Id chargeRT = Schema.SObjectType.OneCRM__Income__c
    .getRecordTypeInfosByDeveloperName().get('Charge').getRecordTypeId();

// 2. Get the Contact and their household Account
Contact c = [SELECT Id, AccountId FROM Contact WHERE Id = :contactId];

// 3. Get or create the Campaign for categorization
Campaign camp = [SELECT Id FROM Campaign WHERE Id = :campaignId];

// 4. Create the Charge header
OneCRM__Income__c charge = new OneCRM__Income__c(
    RecordTypeId = chargeRT,
    OneCRM__Donor__c = c.AccountId,           // Account (required)
    OneCRM__Related_Contact__c = c.Id,        // Contact
    OneCRM__Date__c = Date.today(),
    OneCRM__Paid__c = 0,                      // Nothing paid yet
    OneCRM__Status__c = 'Success'             // Pledge is confirmed
    // Payment_Type__c is NULL for charges
);
insert charge;

// 5. Create Charge line item - link to Campaign for categorization
OneCRM__Income_Line_Item__c chargeLine = new OneCRM__Income_Line_Item__c(
    OneCRM__Income__c = charge.Id,
    OneCRM__Donor__c = c.AccountId,
    OneCRM__Related_Contact__c = c.Id,
    OneCRM__Amount__c = 1000,                 // POSITIVE amount

    // Link to Campaign - this provides all categorization
    OneCRM__Related_Campaign__c = camp.Id,

    // Type hardcoded to "Campaign" to conform to package
    OneCRM__Type__c = 'Campaign'

    // DO NOT SET: OneCRM__SubType__c (UNUSED)
    // Campaign_Type__c, Campaign_SubType__c, Campaign_Year__c are FORMULA fields
    // that auto-populate from the Campaign

    // Related_Income__c is NULL (this IS the charge)
    // Related_Income_Line_Item__c is NULL
);
insert chargeLine;
```

### Creating a Payment

```apex
// 1. Get record type
Id paymentRT = Schema.SObjectType.OneCRM__Income__c
    .getRecordTypeInfosByDeveloperName().get('Payment').getRecordTypeId();

// 2. Get the Contact and their household Account
Contact c = [SELECT Id, AccountId FROM Contact WHERE Id = :contactId];

// 3. Get the Charge and Charge Line Item being paid
OneCRM__Income__c charge = [SELECT Id FROM OneCRM__Income__c WHERE Id = :chargeId];
OneCRM__Income_Line_Item__c chargeLine = [SELECT Id FROM OneCRM__Income_Line_Item__c WHERE Id = :chargeLineId];

// 4. Create the Payment header
OneCRM__Income__c payment = new OneCRM__Income__c(
    RecordTypeId = paymentRT,
    OneCRM__Donor__c = c.AccountId,           // Account (required)
    OneCRM__Related_Contact__c = c.Id,        // Contact
    OneCRM__Date__c = Date.today(),
    OneCRM__Paid__c = 0,                      // Always 0 for payments
    OneCRM__Status__c = 'Success',
    OneCRM__Payment_Type__c = 'Cash'          // Required for payments
);
insert payment;

// 5. Create Payment line item - link to charge, NO categorization
OneCRM__Income_Line_Item__c paymentLine = new OneCRM__Income_Line_Item__c(
    OneCRM__Income__c = payment.Id,
    OneCRM__Donor__c = c.AccountId,
    OneCRM__Related_Contact__c = c.Id,
    OneCRM__Amount__c = -500,                             // NEGATIVE amount

    // REQUIRED: Link to the charge being paid
    OneCRM__Related_Income__c = charge.Id,
    OneCRM__Related_Income_Line_Item__c = chargeLine.Id

    // DO NOT SET: OneCRM__Related_Campaign__c, OneCRM__Type__c, OneCRM__SubType__c
    // Categorization is inherited from the linked charge line's Campaign
);
insert paymentLine;

// Note: OneCRM__Paid__c on the Charge and Charge Line Item is automatically
// updated by package automation - no manual update needed
```

### Multi-Allocation Payments

A single Payment can pay multiple Charges. Create multiple line items, each linking to different charge lines:

```apex
OneCRM__Income__c payment = new OneCRM__Income__c(
    RecordTypeId = paymentRT,
    OneCRM__Donor__c = accountId,
    OneCRM__Date__c = Date.today(),
    OneCRM__Payment_Type__c = 'Check',
    OneCRM__Status__c = 'Success'
);
insert payment;

List<OneCRM__Income_Line_Item__c> paymentLines = new List<OneCRM__Income_Line_Item__c>();

// Line 1: Pay $300 toward Charge Line A
paymentLines.add(new OneCRM__Income_Line_Item__c(
    OneCRM__Income__c = payment.Id,
    OneCRM__Donor__c = accountId,
    OneCRM__Amount__c = -300,                             // NEGATIVE
    OneCRM__Related_Income__c = chargeAId,                // Required
    OneCRM__Related_Income_Line_Item__c = chargeLineAId   // Required
    // No categorization - inherited from charge line's Campaign
));

// Line 2: Pay $200 toward Charge Line B
paymentLines.add(new OneCRM__Income_Line_Item__c(
    OneCRM__Income__c = payment.Id,
    OneCRM__Donor__c = accountId,
    OneCRM__Amount__c = -200,                             // NEGATIVE
    OneCRM__Related_Income__c = chargeBId,                // Required
    OneCRM__Related_Income_Line_Item__c = chargeLineBId   // Required
    // No categorization - inherited from charge line's Campaign
));

insert paymentLines;

// Note: OneCRM__Paid__c is automatically updated by package automation
```

---

## Field Value Reference

### OneCRM__Income_Line_Item__c.OneCRM__Type__c

| Value | Usage in This Implementation |
|-------|------------------------------|
| `Campaign` | **Use this value** - Hardcoded on all charge line items |
| `Donation` | Not used |
| `Event` | Not used |
| `Kibudim` | Not used |

> **Note**: In this implementation, always set `OneCRM__Type__c = 'Campaign'` on charge line items to conform to the package. The actual categorization comes from the linked Campaign object.

### OneCRM__Income__c.OneCRM__Payment_Type__c

Values observed in production:

| Value | Description |
|-------|-------------|
| `CC` | Credit Card |
| `Zelle` | Zelle transfer |
| `Cash` | Cash payment |
| `Paypal` | PayPal |
| `Wire` | Wire transfer |
| `Check` | Check payment |
| `CashApp` | Cash App |
| `In Kind` | In-kind donation (non-monetary) |

### OneCRM__Income__c.OneCRM__Status__c

| Value | Available For | Description |
|-------|---------------|-------------|
| `Success` | Both | Transaction completed successfully |
| `Pending` | Payment only | Awaiting processing |
| `Declined` | Payment only | Payment was declined |
| `Failed` | Payment only | Payment processing failed |
| `Cancelled` | Payment only | Transaction was cancelled |
| `Redirect` | Payment only | Redirected (for online payments) |

### Campaign.Type (Category)

| Value | Description |
|-------|-------------|
| `Kibudim` | Synagogue honors (aliyot, Torah readings, etc.) |
| `Membership` | Membership dues |
| `Events` | Event-related income |
| `Shul Renovation` | Building/renovation fund |
| `Hall Rental` | Facility rental |
| `General` | General donations |
| `Grants` | Grant funding |
| `Services` | Services |
| `Advertising` | Advertising |

### Campaign.SubType__c (Sub-Category)

Common values by category:

**Kibudim (Holiday-based):**
| Value | Description |
|-------|-------------|
| `Simchas Torah` | Simchat Torah holiday |
| `Yom Kipur` | Yom Kippur |
| `Rosh Hashana` | Rosh Hashanah |
| `Sukkos` | Sukkot |
| `Shabbos` | Regular Shabbat |
| `Pesach` | Passover |
| `Shavuos` | Shavuot |
| `Chanuka` | Chanukah |
| `Psicha Yearly` | Annual Ark opening honor |
| `Hagbah Yearly` | Annual Torah lifting honor |

**Events/Programs:**
| Value | Description |
|-------|-------------|
| `Kiddush` | Kiddush sponsorship |
| `Farbrengen Genaral` | General farbrengen |
| `Kids Rally` | Children's rally |
| `Mesibas Shabbos` | Shabbat party |
| `Shiurim` | Torah classes |
| `Nshei` | Women's programming |
| `Avos Ubonim` | Father-son learning |

**Donations:**
| Value | Description |
|-------|-------------|
| `General` | General donation |
| `Maos Chitim` | Passover charity fund |
| `Tishrei Yom Tov Fund` | High Holidays fund |
| `Mikvah Fund` | Mikvah fund |
| `Building Fund` | Building fund |
| `Torah Fund` | Torah fund |

**Hall Rental:**
| Value | Description |
|-------|-------------|
| `Big Hall` | Main hall |
| `Cheder Sheni` | Second room |

### Campaign.Detail__c (Specific Honor)

Dependent on SubType. For Kibudim:

| Value | Description |
|-------|-------------|
| `Aliyah` | Torah reading honor |
| `Hagbah` | Torah lifting |
| `Gelilah` | Torah dressing |
| `Psicha` | Ark opening |
| `Choson Torah` | Simchat Torah honoree |
| `Choson Breishis` | Simchat Torah honoree |
| `Kol Hane'orim` | Children's aliyah |
| `Ata Horisa` | Simchat Torah circuit |
| `Maftir Yona` | Yom Kippur reading |
| `Kol Nidrei` | Yom Kippur honor |
| `Geshem` | Rain prayer honor |
| `Tal` | Dew prayer honor |

### Campaign.Hebrew_Year__c

Hebrew calendar year in format: `5785`, `5786`, etc.

### OneCRM__Communication__c.OneCRM__Type__c

| Value | Description |
|-------|-------------|
| `Address` | Physical/mailing address |
| `Email` | Email address |
| `Phone` | Phone number |

### OneCRM__Relationship__c.OneCRM__Type__c

| Value | Description |
|-------|-------------|
| `Husband` | Male spouse |
| `Wife` | Female spouse |
| `Spouse` | Gender-neutral spouse |
| `Father` | Father |
| `Mother` | Mother |
| `Child` | Child (any gender) |
| `Son` | Male child |
| `Daughter` | Female child |

### OneCRM__Payment_Program__c.OneCRM__Schedule__c

| Value | Description |
|-------|-------------|
| `Weekly` | Weekly recurring charge |
| `Monthly` | Monthly recurring charge (default) |
| `Yearly` | Annual recurring charge |

### OneCRM__Payment_Program__c.OneCRM__Status__c

| Value | Description |
|-------|-------------|
| `Inactive` | Program is not active (default) |
| `Waiting` | Waiting for next charge date |
| `Auto Processing` | Currently processing a charge |
| `Finished` | All charges completed |
| `Creating` | Program is being set up |

---

## Visual Data Model

```
CAMPAIGN (Categorization Master)
├── Type = "Kibudim"
├── SubType__c = "Yom Kipur"
├── Hebrew_Year__c = "5786"
└── Detail__c = "Aliyah"
        │
        │ OneCRM__Related_Campaign__c
        ▼
ACCOUNT (Household)
│
├── OneCRM__Relationship__c[]
│   └── Contact (individual family members)
│
├── OneCRM__Communication__c[]
│   └── Addresses, Emails, Phones
│
├── OneCRM__Credit_Card__c[]
│   └── Stored payment methods
│
├── OneCRM__Income__c[] (via Donor__c)
│   │
│   ├── RecordType: Charge (Pledges)
│   │   ├── Amount: POSITIVE
│   │   ├── Paid__c: Running payment total
│   │   ├── Amount_Outstanding__c: Unpaid balance
│   │   └── Line Items:
│   │       ├── Amount: POSITIVE
│   │       ├── OneCRM__Related_Campaign__c: REQUIRED (→ Campaign)
│   │       ├── Campaign_Type__c: Formula (auto from Campaign)
│   │       ├── Campaign_SubType__c: Formula (auto from Campaign)
│   │       ├── Campaign_Year__c: Formula (auto from Campaign)
│   │       ├── OneCRM__Type__c: "Campaign" (hardcoded)
│   │       ├── OneCRM__SubType__c: UNUSED
│   │       └── Related_Income__c: NULL (this IS the charge)
│   │
│   └── RecordType: Payment (Funds Received)
│       ├── Amount: NEGATIVE
│       ├── Paid__c: Always 0
│       ├── Payment_Type__c: How paid
│       └── Line Items:
│           ├── Amount: NEGATIVE
│           ├── OneCRM__Related_Campaign__c: DO NOT SET
│           ├── Related_Income__c: REQUIRED (→ Charge)
│           └── Related_Income_Line_Item__c: REQUIRED (→ Charge Line)
```

---

## Key Rules Summary

1. **Charges have POSITIVE amounts; Payments have NEGATIVE amounts**

2. **Both Income and Line Items must have Donor__c (Account) populated**

3. **Payment line items MUST link to a Charge line item**
   - `Related_Income__c` → Required, points to the Charge (Income record)
   - `Related_Income_Line_Item__c` → Required, points to the Charge line item

4. **Categorization comes from Campaign, not line item fields**
   - `OneCRM__Type__c` should be hardcoded to "Campaign" on charge line items (to conform to package)
   - `OneCRM__SubType__c` on line items is **UNUSED**
   - Charge line items must set `OneCRM__Related_Campaign__c` to link to a Campaign
   - Campaign provides: `Type`, `SubType__c`, `Hebrew_Year__c`, `Detail__c`
   - Formula fields auto-populate: `Campaign_Type__c`, `Campaign_SubType__c`, `Campaign_Year__c`

5. **Payment line items do NOT set categorization**
   - Do not set `OneCRM__Related_Campaign__c` on payment lines
   - Categorization is inherited from the linked charge line's Campaign

6. **OneCRM__Paid__c is automatically updated by package automation** when payments are linked to charges

7. **Payment_Type__c is required for Payments, must be null for Charges**

8. **Hebrew years (5785, 5786) are used for Campaign.Hebrew_Year__c**
