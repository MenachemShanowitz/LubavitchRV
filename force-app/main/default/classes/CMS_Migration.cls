/*
* Class is quite simple. If there are any exactly matching amounts between the payment line item and a charge line item of the related charge, it is related to that line item
*/
public class CMS_Migration implements Database.Batchable<sObject>
{
    class specialException extends Exception{}
    public Database.QueryLocator start(Database.BatchableContext context)
    {
        string query = 'SELECT OneCRM__Income__c, OneCRM__Related_Income__c, OneCRM__Income__r.RecordType.Name ' +
            ' FROM OneCRM__Income_Line_Item__c WHERE OneCRM__Related_Income_Line_Item__c = null AND (OneCRM__Income__r.RecordType.Name = \'Payment\' OR (OneCRM__Amount__c < 0 AND OneCRM__Income__r.RecordType.Name = \'Charge\')) ';

        /* old query  */
        //query = 'select id, OneCRM__Amount_Outstanding__c from OneCRM__income__c where recordtype.name = \'Charge\' AND Id IN (SELECT OneCRM__Related_Income__c FROM OneCRM__Income_Line_Item__c WHERE OneCRM__Related_Income_Line_Item__c = null AND OneCRM__Income__r.RecordType.Name = \'Payment\')';
        

        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext context, List<sObject> scope)
    {
        Set<String> recordTypes = new Set<String>();
        Set<Id> charges = new Set<Id>();
        for (sObject item : scope)
        {
            OneCRM__Income_Line_Item__c lineItem = (OneCRM__Income_Line_Item__c)item;

            if (lineItem.OneCRM__Income__r.RecordType.Name == 'Payment')
                charges.add((Id)lineItem.OneCRM__Related_Income__c);
            else
                charges.add((Id)lineItem.OneCRM__Income__c);

            recordTypes.add(lineItem.OneCRM__Income__r.RecordType.Name);
        }

        if (charges.size() > 1)
            throw new specialException('batch size cannot be more than one');

        
        /* OLD
        OneCRM__Income__c charge = (OneCRM__Income__c)scope[0];
        processForPayments(charge.Id, charge);
        */

        OneCRM__Income_Line_Item__c charge = (OneCRM__Income_Line_Item__c)scope[0];
        String recordType = charge.OneCRM__Income__r.RecordType.Name;

        if (recordTypes.size() == 2)
        {
            processForPayments((Id)charge.OneCRM__Related_Income__c, charge /* payment line item */);
            processForDiscounts((Id)charge.OneCRM__Income__c, charge /* discount line item */);
        }
        else
        {
            if (recordType == 'Payment')
                processForPayments((Id)charge.OneCRM__Related_Income__c, charge /* payment line item */);
            else
                processForDiscounts((Id)charge.OneCRM__Income__c, charge /* discount line item */);
        }
    }

    private void processForDiscounts(Id chargeId, sobject chargeLine)
    {
        OneCRM__Income_Line_Item__c[] clis = [SELECT Id, OneCRM__Amount__c, OneCRM__Amount_Outstanding__c FROM OneCRM__Income_Line_Item__c WHERE OneCRM__Income__c = :chargeId AND OneCRM__Amount__c > 0];
        //discount lines
        OneCRM__Income_Line_Item__c[] dlis = [SELECT Id, OneCRM__Positive_Amount__c, OneCRM__Amount__c, OneCRM__Related_Income_Line_Item__c FROM OneCRM__Income_Line_Item__c WHERE OneCRM__Income__c = :chargeId AND OneCRM__Amount__c < 0 AND OneCRM__Related_Income_Line_Item__c = null];
        system.debug(dlis);

        if (clis.size() == 1 && dlis.size() == 1)
        {
            dlis[0].OneCRM__Related_Income_Line_Item__c = clis[0].Id;

            update dlis;
            return;
        }
        
        // LIMIT to items that have an outstanding amount AND are not discounts
        clis = [SELECT Id, OneCRM__Amount__c, OneCRM__Amount_Outstanding__c FROM OneCRM__Income_Line_Item__c WHERE OneCRM__Income__c = :chargeId AND OneCRM__Amount_Outstanding__c > 0 AND OneCRM__Amount__c > 0 ORDER BY OneCRM__Amount_Outstanding__c DESC];
        dlis = [SELECT Id, OneCRM__Positive_Amount__c, OneCRM__Amount__c, OneCRM__Related_Income_Line_Item__c FROM OneCRM__Income_Line_Item__c WHERE OneCRM__Income__c = :chargeId AND OneCRM__Related_Income_Line_Item__c = null AND OneCRM__Amount__c < 0 ORDER BY OneCRM__Positive_Amount__c DESC];

        List<OneCRM__Income_Line_Item__c> dlisToUpdate = new List<OneCRM__Income_Line_Item__c>();
            
        //If there is only 1 outstanding charge line item and the payment line item amounts dont exceed the outstanding cli amount, then you can safely assign them to that charge line item
        if (clis.size() == 1 && dlis.size() > 1)
        {
            for (OneCRM__Income_Line_Item__c dli : dlis) {
                
                dli.OneCRM__Related_Income_Line_Item__c = clis[0].Id;
                dlisToUpdate.add(dli);
            }
        }
        else
        {
            List<chargeLineItem> chargeLineItems = new List<chargeLineItem>();

            for (OneCRM__Income_Line_Item__c cli : clis)
            {
                chargeLineItems.add(new chargeLineItem(cli.Id, cli.OneCRM__Amount_Outstanding__c));
            }

            for (chargeLineItem cli : chargeLineItems)
            {
                for (OneCRM__Income_Line_Item__c dli : dlis)
                {
                    if (cli.AmountOutstanding >= dli.OneCRM__Positive_Amount__c)
                    {
                        //change the amount outstanding on the charge line item so that another discount line item must match the new outstanding amount.
                        cli.AmountOutstanding = cli.AmountOutstanding - dli.OneCRM__Positive_Amount__c;

                        dli.OneCRM__Related_Income_Line_Item__c = cli.IId;
                        dlisToUpdate.add(dli);
                    }
                }
            }
        }

        if (dlisToUpdate.size() > 0)
            update dlisToUpdate;

        // TODO: Does not yet support multiple discount line items to multiple charge line items or multiple charge line items to a single discount.
    }

    private void processForPayments(Id chargeId, sObject chargeLine)
    {
        OneCRM__Income_Line_Item__c[] clis = [SELECT Id, OneCRM__Amount__c, OneCRM__Amount_Outstanding__c FROM OneCRM__Income_Line_Item__c WHERE OneCRM__Income__c = :chargeId  AND OneCRM__Amount__c > 0];
        OneCRM__Income_Line_Item__c[] plis = [SELECT Id, OneCRM__Positive_Amount__c, OneCRM__Amount__c, OneCRM__Related_Income_Line_Item__c FROM OneCRM__Income_Line_Item__c WHERE OneCRM__Related_Income__c = :chargeId AND OneCRM__Related_Income_Line_Item__c = null AND OneCRM__Income__r.RecordType.Name = 'Payment'];
        system.debug(plis);
        
        Map<Double, List<OneCRM__Income_Line_Item__c>> cliAmountToRecord = new Map<Double, List<OneCRM__Income_Line_Item__c>>();
        for (OneCRM__Income_Line_Item__c cli : clis)
        {
            if (cliAmountToRecord.containsKey(cli.OneCRM__Amount_Outstanding__c))
                cliAmountToRecord.get(cli.OneCRM__Amount_Outstanding__c).add(cli);
            else
                cliAmountToRecord.put(cli.OneCRM__Amount_Outstanding__c, new List<OneCRM__Income_Line_Item__c>{
                    cli
                });
        }
        
        system.debug(cliAmountToRecord);

        List<OneCRM__Income_Line_Item__c> plisToUpdate = new List<OneCRM__Income_Line_Item__c>();
        for (OneCRM__Income_Line_Item__c pli : plis)
        {
            Boolean pliUpdated = false;
            
            if (cliAmountToRecord.containsKey(Math.abs(pli.OneCRM__Amount__c)) && cliAmountToRecord.get(Math.abs(pli.OneCRM__Amount__c)).size() > 0)
            {
                pli.OneCRM__Related_Income_Line_Item__c = cliAmountToRecord.get(Math.abs(pli.OneCRM__Amount__c))[0].Id;             
                pliUpdated = true;
                cliAmountToRecord.get(Math.abs(pli.OneCRM__Amount__c)).remove(0);
            }

            if (pli.OneCRM__Amount__c > 0) {
                pli.OneCRM__Amount__c = -pli.OneCRM__Amount__c;
                pliUpdated = true;
            }

            if (pliUpdated){
                plisToUpdate.add(pli);
            }

        }
        system.debug(plisToUpdate);
        update plisToUpdate;

        /* LIMIT to items that have an outstanding amount AND are not discounts */
        clis = [SELECT Id, OneCRM__Amount__c, OneCRM__Amount_Outstanding__c FROM OneCRM__Income_Line_Item__c WHERE OneCRM__Income__c = :chargeId AND OneCRM__Amount_Outstanding__c > 0 AND OneCRM__Amount__c > 0 ORDER BY OneCRM__Amount_Outstanding__c DESC];
        plis = [SELECT Id, OneCRM__Positive_Amount__c, OneCRM__Amount__c, OneCRM__Related_Income_Line_Item__c, OneCRM__Income__c, OneCRM__Related_Income__c FROM OneCRM__Income_Line_Item__c WHERE OneCRM__Related_Income__c = :chargeId AND OneCRM__Related_Income_Line_Item__c = null AND OneCRM__Income__r.RecordType.Name = 'Payment' ORDER BY OneCRM__Positive_Amount__c DESC];


        if (clis.size() == 1 && plis.size() == 1)
        {
            plis[0].OneCRM__Related_Income_Line_Item__c = clis[0].Id;

            update plis[0];
        }
        //If there is only 1 outstanding charge line item and the payment line item amounts dont exceed the outstanding cli amount, then you can safely assign them to that charge line item
        else if (clis.size() == 1 && plis.size() > 0) {

            plisToUpdate = new List<OneCRM__Income_Line_Item__c>();
            
            Double totalPliAmount = 0;
            for (OneCRM__Income_Line_Item__c pli : plis) {
                totalPliAmount+= pli.OneCRM__Positive_Amount__c;
            }

            if (totalPliAmount <= clis[0].OneCRM__Amount__c) {

                for (OneCRM__Income_Line_Item__c pli : plis) {
                    
                    pli.OneCRM__Related_Income_Line_Item__c = clis[0].Id;
                    plisToUpdate.add(pli);
                }
            }

            update plisToUpdate;

        } //it matches the payment line items to charge line items top down 
        // (starts with the highest payment line item and pays off the highest charge line item) and splits them when necessary
        else if (clis.size() > 1 && plis.size() > 0) {

            PaymentLineItemApplier applier = new PaymentLineItemApplier(clis);

            List<OneCRM__Income_Line_Item__c> plisToUpsert = new List<OneCRM__Income_Line_Item__c>();

            Map<Id, Double> cliToAmountOutstanding = new Map<Id, Double>();

            for (Integer i = 0; i < plis.size(); i++) {

                plisToUpsert.addAll(applier.applyPliToCli(plis[i]));
            }

            upsert plisToUpsert;
        }
    }

    //need to create separate class/object because cannot adjust amount outstanding otherwise (as its a read only field)
    class chargeLineItem {

		Id IId;
    	Decimal AmountOutstanding;

    	public chargeLineItem(Id iId, Decimal amountOutstanding) {

    		this.IId = iId;
    		this.AmountOutstanding = amountOutstanding;
    	}
    }

    class PaymentLineItemApplier {
    	
    	List<chargeLineItem> clis = new List<chargeLineItem>();
    	Integer currentIndex = 0;

    	public PaymentLineItemApplier(List<OneCRM__Income_Line_Item__c> chargeLineItems) {

    		for (Integer i = 0; i < chargeLineItems.size(); i++) {

    			this.clis.add(new chargeLineItem(chargeLineItems[i].Id, chargeLineItems[i].OneCRM__Amount_Outstanding__c));
    		}
		}

		public List<OneCRM__Income_Line_Item__c> applyPliToCli(OneCRM__Income_Line_Item__c paymentLineItem) {

			adjustIndex();

			List<OneCRM__Income_Line_Item__c> plis = new List<OneCRM__Income_Line_Item__c>();

			if (currentIndex >= clis.size()) {

				plis.add(paymentLineItem);
				return plis;
			}

			chargelineitem cli = clis[currentIndex];

			if (Math.abs(paymentLineItem.OneCRM__Amount__c) <= cli.AmountOutstanding) {

				plis.add(relatePliToCli(paymentLineItem, cli));
			} //if the payment line item amount is more it splits it into two and runs the latter through this same process
			else if (Math.abs(paymentLineItem.OneCRM__Amount__c) > cli.AmountOutstanding) {

				Double newPaymentLineItemAmount = Math.abs(paymentLineItem.OneCRM__Amount__c) - cli.AmountOutstanding;
				
                //We need to make sure this is negative
				paymentLineItem.OneCRM__Amount__c = -Math.abs(cli.AmountOutstanding);
				plis.add(relatePliToCli(paymentLineItem, cli));

				plis.addAll(applyPliToCli(
					new OneCRM__Income_Line_Item__c(
						OneCRM__Amount__c 		 = -newPaymentLineItemAmount, 
						OneCRM__Income__c 		 = paymentLineItem.OneCRM__Income__c,
						OneCRM__Related_Income__c = paymentLineItem.OneCRM__Related_Income__c)));
			}

			return plis;
		}

		public OneCRM__Income_Line_Item__c relatePliToCli(OneCRM__Income_Line_Item__c paymentLineItem, chargeLineItem cli) {

			paymentLineItem.OneCRM__Related_Income_Line_Item__c = cli.IId;
			cli.AmountOutstanding -= Math.abs(paymentLineItem.OneCRM__Amount__c);
			return paymentLineItem;
		}

		public void adjustIndex() {

            if (currentIndex >= clis.size())
                return;

			Boolean noOutstanding = clis[currentIndex].AmountOutstanding <= 0;

			while (noOutstanding && currentIndex < clis.size()) {

				currentIndex += 1;

				if (currentIndex < this.clis.size()) {
					noOutstanding = clis[currentIndex].AmountOutstanding <= 0;
				}
			}
		}

    }

    public void finish(Database.BatchableContext context){}

}