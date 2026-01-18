# Deploy and Test

Deploys Apex classes to the org and runs their associated tests.

## Arguments

`ClassName` - The name of the Apex class to deploy (without .cls extension)

## Steps

### 1. Deploy the class and its test

```bash
sf project deploy start \
  --source-dir force-app/main/default/classes/{ClassName}.cls \
  --source-dir force-app/main/default/classes/{ClassName}Test.cls \
  --target-org lubavitchrv_partial \
  --wait 10
```

If deployment fails, report the errors and stop.

### 2. Run the tests

```bash
sf apex run test \
  --class-names {ClassName}Test \
  --target-org lubavitchrv_partial \
  --result-format human \
  --wait 10
```

### 3. Report results

Summarize:
- Deployment status (success/failure)
- Test results (pass rate, any failures with details)
- If failures, show the specific assertion or error message

## Example Usage

User: "deploy and test PaymentMatcherController"

This will:
1. Deploy `PaymentMatcherController.cls` and `PaymentMatcherControllerTest.cls`
2. Run `PaymentMatcherControllerTest`
3. Report pass/fail status
