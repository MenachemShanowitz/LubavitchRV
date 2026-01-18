# Claude Code Development Guide for LubavitchRV

This document describes how to perform end-to-end AI-driven Salesforce development on this codebase, including automated browser verification without human involvement.

## Project Structure

```
LubavitchRV/
├── force-app/main/default/
│   ├── classes/           # Apex controllers and test classes
│   ├── lwc/               # Lightning Web Components
│   ├── tabs/              # Custom tab metadata
│   ├── flexipages/        # Lightning App Pages
│   ├── objects/           # Custom object metadata
│   ├── triggers/          # Apex triggers
│   └── flows/             # Flow definitions
├── docs/
│   └── ONECRM_DATA_MODEL.md  # Data model reference (READ THIS FIRST)
└── sfdx-project.json      # Project configuration
```

## Key Documentation

**Always read `docs/ONECRM_DATA_MODEL.md` before working with financial data.** It explains the household-based donor model, double-entry accounting system, and campaign-centric categorization.

## Salesforce Org Access

| Property | Value |
|----------|-------|
| **Alias** | `lubavitchrv_partial` |
| **Type** | Sandbox |
| **Instance** | `chbd12461--partial.sandbox.my.salesforce.com` |

## Development Workflow

### 1. Understand Requirements
- Read relevant documentation in `docs/`
- Explore existing code patterns in `force-app/main/default/`

### 2. Create/Edit Files
Standard Salesforce DX structure. Key file types:
- **Apex**: `.cls` + `.cls-meta.xml`
- **LWC**: `.js` + `.html` + `.js-meta.xml`
- **FlexiPage**: `.flexipage-meta.xml` (component instances need `<identifier>` element)

### 3. Deploy
```bash
sf project deploy start \
  --source-dir force-app/main/default/classes/MyController.cls \
  --source-dir force-app/main/default/lwc/myComponent \
  --target-org lubavitchrv_partial \
  --wait 10
```

### 4. Verify in Browser
Use automated browser to confirm changes work correctly.

## Automated Browser Verification

### Setup Browser Session (IPython Kernel)
```python
from playwright.async_api import async_playwright

pw = None
browser = None
context = None
page = None

async def start_browser():
    global pw, browser, context, page
    pw = await async_playwright().start()
    browser = await pw.chromium.launch(headless=False)
    context = await browser.new_context()
    page = await context.new_page()
    return page

await start_browser()
```

### Login to Salesforce
```bash
# Get login URL with embedded OTP
sf org open --target-org lubavitchrv_partial --url-only
```

```python
login_url = "https://chbd12461--partial.sandbox.my.salesforce.com/secur/frontdoor.jsp?otp=..."
await page.goto(login_url)
await asyncio.sleep(3)
# Now authenticated on Lightning home page
```

### Navigate and Verify
```python
# Direct navigation
await page.goto("https://chbd12461--partial.sandbox.lightning.force.com/lightning/n/My_Page")

# Or via App Launcher
app_launcher = await page.wait_for_selector("div.slds-icon-waffle", timeout=5000)
await app_launcher.click()
search_input = await page.wait_for_selector("input[placeholder*='Search']", timeout=5000)
await search_input.fill("My Page")
await asyncio.sleep(2)
await page.click("span:has-text('My Page')")

# Screenshot for verification
await page.screenshot(path="/tmp/verification.png")
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Playwright: "Sync API inside asyncio loop" | Use async API: `from playwright.async_api import async_playwright` |
| Can't find elements in Setup pages | Setup renders in iframe - use `iframe.content_frame()` |
| FlexiPage deploy fails: "no identifier" | Add `<identifier>` to `<componentInstance>` elements |
| LWC search input not firing on keystroke | Use `onkeyup` instead of `onchange`. `onchange` only fires on blur. |
| SOQL: "Unexpected token 'Account.Field'" in WHERE | Can't compare `Id = Account.Field__c` directly. Use subquery: `WHERE Id IN (SELECT Field__c FROM Account)` |
| Test fails after adding relationship filter | Ensure test setup populates the relationship (e.g., `Account.OneCRM__Primary_Contact__c = contact.Id`) |

## Useful Commands

```bash
# List authenticated orgs
sf org list

# Get login URL for automation
sf org open --target-org lubavitchrv_partial --url-only

# Deploy with tests
sf project deploy start --target-org lubavitchrv_partial --test-level RunLocalTests --wait 10

# Retrieve metadata
sf project retrieve start --target-org lubavitchrv_partial --metadata ApexClass:MyClass
```

## API Version

Current: **62.0**
