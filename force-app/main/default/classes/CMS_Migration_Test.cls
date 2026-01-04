@isTest
public class CMS_Migration_Test {

    //test that exact dollar amount matches are matched
    public static testmethod void testMigrationWithDirectMatching() {
        Account donor = new Account(Name = 'donor');
        insert donor;
        OneCRM__Income__c charge = new OneCRM__Income__c(RecordTypeId = chargeType, OneCRM__Donor__c = donor.Id);
        OneCRM__Income__c payment1 = new OneCRM__Income__c(RecordTypeId = paymentType, OneCRM__Donor__c = donor.Id);
        OneCRM__Income__c payment2 = new OneCRM__Income__c(RecordTypeId = paymentType, OneCRM__Donor__c = donor.Id);

        insert charge;
        insert new List<OneCRM__Income__c>{payment1, payment2};

        OneCRM__Income_Line_Item__c[] clis = new List<OneCRM__Income_Line_Item__c>();
        clis.add(new OneCRM__Income_Line_Item__c(OneCRM__Amount__c = 18, OneCRM__Income__c = charge.Id));
        clis.add(new OneCRM__Income_Line_Item__c(OneCRM__Amount__c = 36, OneCRM__Income__c = charge.Id));
        clis.add(new OneCRM__Income_Line_Item__c(OneCRM__Amount__c = 18, OneCRM__Income__c = charge.Id));
        clis.add(new OneCRM__Income_Line_Item__c(OneCRM__Amount__c = 36, OneCRM__Income__c = charge.Id));
        clis.add(new OneCRM__Income_Line_Item__c(OneCRM__Amount__c = 72, OneCRM__Income__c = charge.Id));
        clis.add(new OneCRM__Income_Line_Item__c(OneCRM__Amount__c = 100, OneCRM__Income__c = charge.Id));

        insert clis;

        OneCRM__Income_Line_Item__c[] plis = new List<OneCRM__Income_Line_Item__c>();
        plis.add(new OneCRM__Income_Line_Item__c(OneCRM__Amount__c = 18, OneCRM__Income__c = payment1.Id, OneCRM__Related_Income__c = charge.Id));
        plis.add(new OneCRM__Income_Line_Item__c(OneCRM__Amount__c = 36, OneCRM__Income__c = payment1.Id, OneCRM__Related_Income__c = charge.Id));
        plis.add(new OneCRM__Income_Line_Item__c(OneCRM__Amount__c = 18, OneCRM__Income__c = payment2.Id, OneCRM__Related_Income__c = charge.Id));
        plis.add(new OneCRM__Income_Line_Item__c(OneCRM__Amount__c = 100, OneCRM__Income__c = payment1.Id, OneCRM__Related_Income__c = charge.Id));
        insert plis;

        OneCRM__Income_Line_Item__c[] clisp = [SELECT Id, OneCRM__Amount_Outstanding__c, OneCRM__Amount__c FROM OneCRM__Income_Line_Item__c WHERE Id in :clis];
        for (OneCRM__Income_Line_Item__c cli : clisp)
        {
            system.debug(cli.OneCRM__Amount_Outstanding__c);
        }

        //We are testing that both $18 clis are paid off and that one $36 cli is paid off and that the other isn't paid off. and that $72 isn't paid off and that $100 is paid off.
        CMS_Migration cm = new CMS_Migration();
        cm.start(null);
        cm.execute(null, [SELECT Id, OneCRM__Amount_Outstanding__c, OneCRM__Income__c, OneCRM__Related_Income__c, OneCRM__Income__r.RecordType.Name FROM OneCRM__Income_Line_Item__c WHERE OneCRM__Related_Income__c = :charge.Id]);
        cm.finish(null);
        
        clisp = [SELECT Id, OneCRM__Amount_Outstanding__c, OneCRM__Amount__c FROM OneCRM__Income_Line_Item__c WHERE Id in :clis];
        for (OneCRM__Income_Line_Item__c cli : clisp)
        {
            system.debug(cli);
        }

        Map<Double, List<OneCRM__Income_Line_Item__c>> paidOffAmountToRecords = new Map<Double, List<OneCRM__Income_Line_Item__c>>();
        OneCRM__Income_Line_Item__c[] updatedClis = [SELECT Id, OneCRM__Amount_Outstanding__c, OneCRM__Amount__c FROM OneCRM__Income_Line_Item__c WHERE Id in :clis];
        system.debug(updatedClis);
        for (OneCRM__Income_Line_Item__c cli : updatedClis)
        {
            if (cli.OneCRM__Amount_Outstanding__c == 0)
            {
                if (paidOffAmountToRecords.containsKey(cli.OneCRM__Amount__c))
                {
                    paidOffAmountToRecords.get(cli.OneCRM__Amount__c).add(cli);
                }
                else
                {
                    paidOffAmountToRecords.put(cli.OneCRM__Amount__c, new List<OneCRM__Income_Line_Item__c>{
                        cli
                    });
                }
            }
        }

        system.assert(paidOffAmountToRecords.containsKey(Double.valueOf(18)), 'There were 2 $18 charge line items that should have been paid off');
        system.assert(paidOffAmountToRecords.get(Double.valueOf(18)).size() == 2, 'There were 2 $18 charge line items that should have been paid off');
        system.assert(paidOffAmountToRecords.containsKey(Double.valueOf(36)), 'There was a $36 charge line item that should have been paid off');
        system.assert(paidOffAmountToRecords.get(Double.valueOf(36)).size() == 1, 'Only 1 $36 charge line item should have been paid off');
        system.assert(!paidOffAmountToRecords.containsKey(Double.valueOf(72)), 'The $72 charge line item should not have been paid off');
        system.assert(paidOffAmountToRecords.containsKey(Double.valueOf(100)), 'The $100 charge line item should have been paid off');
    }

    //test that when there is a single charge line item, and payment line items dont exceed its amount, they are all associated with it
    public static testmethod void testMigrationSingleCLIMultiplePLIs() {

        Account donor = new Account(Name = 'donor');
        insert donor;

        OneCRM__Income__c charge = new OneCRM__Income__c(RecordTypeId = chargeType, OneCRM__Donor__c = donor.Id);
        OneCRM__Income__c payment1 = new OneCRM__Income__c(RecordTypeId = paymentType, OneCRM__Donor__c = donor.Id);
        OneCRM__Income__c payment2 = new OneCRM__Income__c(RecordTypeId = paymentType, OneCRM__Donor__c = donor.Id);

        insert charge;
        insert new List<OneCRM__Income__c>{payment1, payment2};

        OneCRM__Income_Line_Item__c[] clis = new List<OneCRM__Income_Line_Item__c>();
        clis.add(new OneCRM__Income_Line_Item__c(OneCRM__Amount__c = 100, OneCRM__Income__c = charge.Id));

        insert clis;

        OneCRM__Income_Line_Item__c[] plis = new List<OneCRM__Income_Line_Item__c>();
        plis.add(new OneCRM__Income_Line_Item__c(OneCRM__Amount__c = 18, OneCRM__Income__c = payment1.Id, OneCRM__Related_Income__c = charge.Id));
        plis.add(new OneCRM__Income_Line_Item__c(OneCRM__Amount__c = 18, OneCRM__Income__c = payment2.Id, OneCRM__Related_Income__c = charge.Id));
        insert plis;

        OneCRM__Income_Line_Item__c[] clisPaid = [SELECT Id, OneCRM__Amount_Outstanding__c, OneCRM__Amount__c FROM OneCRM__Income_Line_Item__c WHERE Id in :clis];
        for (OneCRM__Income_Line_Item__c cli : clisPaid)
        {
            system.debug(cli.OneCRM__Amount_Outstanding__c);
        }   

        CMS_Migration cm = new CMS_Migration();
        cm.start(null);
        cm.execute(null, [SELECT Id, OneCRM__Amount_Outstanding__c, OneCRM__Income__c, OneCRM__Related_Income__c, OneCRM__Income__r.RecordType.Name FROM OneCRM__Income_Line_Item__c WHERE OneCRM__Related_Income__c = :charge.Id]);
        cm.finish(null);
        

        clisPaid = [SELECT Id, OneCRM__Amount_Outstanding__c, OneCRM__Amount__c, OneCRM__Paid__c FROM OneCRM__Income_Line_Item__c WHERE Id in :clis];
        system.assertEquals(clisPaid[0].OneCRM__Paid__c, 36, 'The charge line items were not associcated with the payment line item');

        plis = [SELECT OneCRM__Related_Income_Line_Item__c FROM OneCRM__Income_Line_Item__c WHERE Id IN :plis];
        for (OneCRM__Income_Line_Item__c pli : plis) {
            system.assertEquals(pli.OneCRM__Related_Income_Line_Item__c, clisPaid[0].Id, 'The charge line items were not associcated with the payment line item');
        }

    }

    //Test that is the charge if fully paid off (so arbitrariness is not an issue) all payment line items are sequentially matched to the corresponding charge line items,
    //the highest payment line item amount to the highest charge line item amount, and the payment line item is split when it exceeds the corresponding charge line item amount
    public static testmethod void testMigrationMultiplePLIsToMultipleCLISFullyPaid() {

        Account donor = new Account(Name = 'donor');
        insert donor;
        
        OneCRM__Income__c charge = new OneCRM__Income__c(RecordTypeId = chargeType, OneCRM__Donor__c = donor.Id);
        OneCRM__Income__c payment1 = new OneCRM__Income__c(RecordTypeId = paymentType, OneCRM__Donor__c = donor.Id);
        OneCRM__Income__c payment2 = new OneCRM__Income__c(RecordTypeId = paymentType, OneCRM__Donor__c = donor.Id);
        OneCRM__Income__c payment3 = new OneCRM__Income__c(RecordTypeId = paymentType, OneCRM__Donor__c = donor.Id);
        OneCRM__Income__c payment4 = new OneCRM__Income__c(RecordTypeId = paymentType, OneCRM__Donor__c = donor.Id);
        OneCRM__Income__c payment5 = new OneCRM__Income__c(RecordTypeId = paymentType, OneCRM__Donor__c = donor.Id);
        OneCRM__Income__c payment6 = new OneCRM__Income__c(RecordTypeId = paymentType, OneCRM__Donor__c = donor.Id);

        insert charge;
        insert new List<OneCRM__Income__c>{payment1, payment2, payment3, payment4, payment5, payment6};

        OneCRM__Income_Line_Item__c[] clis = new List<OneCRM__Income_Line_Item__c>();
        clis.add(new OneCRM__Income_Line_Item__c(OneCRM__Amount__c = 500, OneCRM__Income__c = charge.Id));
        clis.add(new OneCRM__Income_Line_Item__c(OneCRM__Amount__c = 450, OneCRM__Income__c = charge.Id));
        clis.add(new OneCRM__Income_Line_Item__c(OneCRM__Amount__c = 300, OneCRM__Income__c = charge.Id));
        clis.add(new OneCRM__Income_Line_Item__c(OneCRM__Amount__c = 200, OneCRM__Income__c = charge.Id));
        clis.add(new OneCRM__Income_Line_Item__c(OneCRM__Amount__c = 45, OneCRM__Income__c = charge.Id));
        clis.add(new OneCRM__Income_Line_Item__c(OneCRM__Amount__c = 4, OneCRM__Income__c = charge.Id));

        insert clis;

        OneCRM__Income_Line_Item__c[] plis = new List<OneCRM__Income_Line_Item__c>();
        plis.add(new OneCRM__Income_Line_Item__c(OneCRM__Amount__c = 600, OneCRM__Income__c = payment1.Id, OneCRM__Related_Income__c = charge.Id));
        plis.add(new OneCRM__Income_Line_Item__c(OneCRM__Amount__c = 400, OneCRM__Income__c = payment2.Id, OneCRM__Related_Income__c = charge.Id));
        plis.add(new OneCRM__Income_Line_Item__c(OneCRM__Amount__c = 201, OneCRM__Income__c = payment3.Id, OneCRM__Related_Income__c = charge.Id));
        plis.add(new OneCRM__Income_Line_Item__c(OneCRM__Amount__c = 104, OneCRM__Income__c = payment4.Id, OneCRM__Related_Income__c = charge.Id));
        plis.add(new OneCRM__Income_Line_Item__c(OneCRM__Amount__c = 99, OneCRM__Income__c = payment5.Id, OneCRM__Related_Income__c = charge.Id));
        plis.add(new OneCRM__Income_Line_Item__c(OneCRM__Amount__c = 96, OneCRM__Income__c = payment6.Id, OneCRM__Related_Income__c = charge.Id));
        insert plis;


        Test.startTest();
        CMS_Migration cm = new CMS_Migration();
        cm.start(null);
        cm.execute(null, [SELECT Id, OneCRM__Amount_Outstanding__c, OneCRM__Income__c, OneCRM__Related_Income__c, OneCRM__Income__r.RecordType.Name FROM OneCRM__Income_Line_Item__c WHERE OneCRM__Related_Income__c = :charge.Id]);
        cm.finish(null);
        Test.stopTest();

        Map<Double, OneCRM__Income_Line_Item__c> plisAmountToPli = new Map<Double, OneCRM__Income_Line_Item__c>();
        OneCRM__Income_Line_Item__c[] updatedPlis = [SELECT OneCRM__Amount__c, OneCRM__Income__c, OneCRM__Related_Income_Line_Item__c FROM OneCRM__Income_Line_Item__c];

        for (OneCRM__Income_Line_Item__c pli : updatedPlis) {
            plisAmountToPli.put(Math.abs(pli.OneCRM__Amount__c), pli);
        }

        system.assert(plisAmountToPli.containsKey(500.00) && plisAmountToPli.get(500.00).OneCRM__Related_Income_Line_Item__c == clis[0].Id && plisAmountToPli.get(500.00).Id == plis[0].Id, 'The first payment line item was not associcated or split correctly');
        system.assert(plisAmountToPli.containsKey(100.00) && plisAmountToPli.get(100.00).OneCRM__Related_Income_Line_Item__c == clis[1].Id && plisAmountToPli.get(100.00).OneCRM__Income__c == payment1.Id, 'The first payment line item was not associcated or split correctly');

        system.assert(plisAmountToPli.containsKey(350.00) && plisAmountToPli.get(350.00).OneCRM__Related_Income_Line_Item__c == clis[1].Id && plisAmountToPli.get(350.00).Id == plis[1].Id, 'The second payment line item was not associcated or split correctly');
        system.assert(plisAmountToPli.containsKey(50.00) && plisAmountToPli.get(50.00).OneCRM__Related_Income_Line_Item__c == clis[2].Id && plisAmountToPli.get(50.00).OneCRM__Income__c == payment2.Id, 'The second payment line item was not associcated or split correctly');

        system.assert(plisAmountToPli.containsKey(201.00) && plisAmountToPli.get(201.00).OneCRM__Related_Income_Line_Item__c == clis[2].Id && plisAmountToPli.get(201.00).Id == plis[2].Id, 'The third payment line item was not associcated correctly');
 
        system.assert(plisAmountToPli.containsKey(49.00) && plisAmountToPli.get(49.00).OneCRM__Related_Income_Line_Item__c == clis[2].Id && plisAmountToPli.get(49.00).Id == plis[3].Id, 'The fourth payment line item was not associcated or split correctly');
        system.assert(plisAmountToPli.containsKey(55.00) && plisAmountToPli.get(55.00).OneCRM__Related_Income_Line_Item__c == clis[3].Id && plisAmountToPli.get(55.00).OneCRM__Income__c == payment4.Id, 'The fourth payment line item was not associcated or split correctly');

        system.assert(plisAmountToPli.containsKey(99.00) && plisAmountToPli.get(99.00).OneCRM__Related_Income_Line_Item__c == clis[3].Id && plisAmountToPli.get(99.00).Id == plis[4].Id, 'The fifth payment line item was not associcated correctly');
 
        system.assert(plisAmountToPli.containsKey(46.00) && plisAmountToPli.get(46.00).OneCRM__Related_Income_Line_Item__c == clis[3].Id && plisAmountToPli.get(46.00).Id == plis[5].Id, 'The sixth payment line item was not associcated or split correctly');
        system.assert(plisAmountToPli.containsKey(45.00) && plisAmountToPli.get(45.00).OneCRM__Related_Income_Line_Item__c == clis[4].Id && plisAmountToPli.get(45.00).OneCRM__Income__c == payment6.Id, 'The sixth payment line item was not associcated or split correctly');
        system.assert(plisAmountToPli.containsKey(4.00) && plisAmountToPli.get(4.00).OneCRM__Related_Income_Line_Item__c == clis[5].Id && plisAmountToPli.get(4.00).OneCRM__Income__c == payment6.Id, 'The sixth payment line item was not associcated or split correctly');

        system.assert(plisAmountToPli.containsKey(1.00) && plisAmountToPli.get(1.00).OneCRM__Related_Income_Line_Item__c == null && plisAmountToPli.get(1.00).OneCRM__Income__c == payment6.Id, 'The sixth payment line item was not associcated or split correctly');
    }

    //Test that the discount line item is applied properly
    public static testmethod void testDiscountLineItemToSingleChargeLineItem() {

        Account donor = new Account(Name = 'donor');
        insert donor;
        
        OneCRM__Income__c charge = new OneCRM__Income__c(RecordTypeId = chargeType, OneCRM__Donor__c = donor.Id);

        insert charge;

        OneCRM__Income_Line_Item__c[] clis = new List<OneCRM__Income_Line_Item__c>();
        clis.add(new OneCRM__Income_Line_Item__c(OneCRM__Amount__c = 500, OneCRM__Income__c = charge.Id));
        clis.add(new OneCRM__Income_Line_Item__c(OneCRM__Amount__c = -200, OneCRM__Income__c = charge.Id));

        insert clis;

        Test.startTest();
        CMS_Migration cm = new CMS_Migration();
        cm.start(null);
        cm.execute(null, [SELECT OneCRM__Income__c, OneCRM__Related_Income__c, OneCRM__Income__r.RecordType.Name FROM OneCRM__Income_Line_Item__c WHERE OneCRM__Related_Income_Line_Item__c = null AND (OneCRM__Amount__c < 0 AND OneCRM__Income__r.RecordType.Name = 'Charge') AND OneCRM__Income__c = :charge.Id]);
        cm.finish(null);
        Test.stopTest();

        OneCRM__Income_Line_Item__c[] updatedDlis = [SELECT OneCRM__Amount__c, OneCRM__Income__c, OneCRM__Related_Income_Line_Item__c FROM OneCRM__Income_Line_Item__c WHERE OneCRM__Amount__c < 0];

        System.assert(updatedDlis[0].OneCRM__Related_Income_Line_Item__c == clis[0].Id, 'Discount line item was not properly assigned');
    }

    //Test that multiple discount line items are applied properly to a single charge
    public static testmethod void testMultipleDiscountLineItemToSingleChargeLineItem() {

        Account donor = new Account(Name = 'donor');
        insert donor;
        
        OneCRM__Income__c charge = new OneCRM__Income__c(RecordTypeId = chargeType, OneCRM__Donor__c = donor.Id);

        insert charge;

        OneCRM__Income_Line_Item__c[] clis = new List<OneCRM__Income_Line_Item__c>();
        clis.add(new OneCRM__Income_Line_Item__c(OneCRM__Amount__c = 500, OneCRM__Income__c = charge.Id));
        clis.add(new OneCRM__Income_Line_Item__c(OneCRM__Amount__c = -200, OneCRM__Income__c = charge.Id));
        clis.add(new OneCRM__Income_Line_Item__c(OneCRM__Amount__c = -100, OneCRM__Income__c = charge.Id));

        insert clis;

        Test.startTest();
        CMS_Migration cm = new CMS_Migration();
        cm.start(null);
        cm.execute(null, [SELECT OneCRM__Income__c, OneCRM__Related_Income__c, OneCRM__Income__r.RecordType.Name FROM OneCRM__Income_Line_Item__c WHERE OneCRM__Related_Income_Line_Item__c = null AND (OneCRM__Amount__c < 0 AND OneCRM__Income__r.RecordType.Name = 'Charge') AND OneCRM__Income__c = :charge.Id]);
        cm.finish(null);
        Test.stopTest();

        OneCRM__Income_Line_Item__c[] updatedDlis = [SELECT OneCRM__Amount__c, OneCRM__Income__c, OneCRM__Related_Income_Line_Item__c FROM OneCRM__Income_Line_Item__c WHERE OneCRM__Amount__c < 0];

        System.assert(updatedDlis[0].OneCRM__Related_Income_Line_Item__c == clis[0].Id, 'Discount line item was not properly assigned');
        System.assert(updatedDlis[1].OneCRM__Related_Income_Line_Item__c == clis[0].Id, 'Discount line item was not properly assigned');
    }

    //Test that multiple discount line items are applied properly to multiple charge line items
    public static testmethod void testMultipleDiscountLineItemToMultipleChargeLineItem() {

        Account donor = new Account(Name = 'donor');
        insert donor;
        
        OneCRM__Income__c charge = new OneCRM__Income__c(RecordTypeId = chargeType, OneCRM__Donor__c = donor.Id);

        insert charge;

        OneCRM__Income_Line_Item__c[] clis = new List<OneCRM__Income_Line_Item__c>();
        clis.add(new OneCRM__Income_Line_Item__c(OneCRM__Amount__c = 250, OneCRM__Income__c = charge.Id));
        clis.add(new OneCRM__Income_Line_Item__c(OneCRM__Amount__c = 150, OneCRM__Income__c = charge.Id));
        clis.add(new OneCRM__Income_Line_Item__c(OneCRM__Amount__c = -200, OneCRM__Income__c = charge.Id));
        clis.add(new OneCRM__Income_Line_Item__c(OneCRM__Amount__c = -100, OneCRM__Income__c = charge.Id));

        insert clis;

        Test.startTest();
        CMS_Migration cm = new CMS_Migration();
        cm.start(null);
        cm.execute(null, [SELECT OneCRM__Income__c, OneCRM__Related_Income__c, OneCRM__Income__r.RecordType.Name FROM OneCRM__Income_Line_Item__c WHERE OneCRM__Related_Income_Line_Item__c = null AND (OneCRM__Amount__c < 0 AND OneCRM__Income__r.RecordType.Name = 'Charge') AND OneCRM__Income__c = :charge.Id]);
        cm.finish(null);
        Test.stopTest();

        OneCRM__Income_Line_Item__c[] updatedDlis = [SELECT OneCRM__Amount__c, OneCRM__Income__c, OneCRM__Related_Income_Line_Item__c FROM OneCRM__Income_Line_Item__c WHERE OneCRM__Amount__c < 0];

        System.assert(updatedDlis[0].OneCRM__Related_Income_Line_Item__c == clis[0].Id, 'Discount line item was not properly assigned');
        System.assert(updatedDlis[1].OneCRM__Related_Income_Line_Item__c == clis[1].Id, 'Discount line item was not properly assigned');
    }

    static Id paymentType = [SELECT Id FROM RecordType WHERE Name = 'Payment' AND NamespacePrefix = 'OneCRM'].Id;
    static Id chargeType = [SELECT Id FROM RecordType WHERE Name = 'Charge' AND NamespacePrefix = 'OneCRM'].Id;
}