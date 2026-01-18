# Verify LWC in Browser

Opens Salesforce in a browser, navigates to a page, and takes a screenshot for verification.

## Arguments

`PagePath` - The Lightning page path (e.g., `Payment_Matcher1` or full path `/lightning/n/Payment_Matcher1`)

## Steps

### 1. Get login URL

```bash
sf org open --target-org lubavitchrv_partial --url-only
```

Save the URL - it contains an OTP token for authentication.

### 2. Start browser and login (IPython Kernel)

```python
import asyncio
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

### 3. Login to Salesforce

```python
login_url = "{URL from step 1}"
await page.goto(login_url)
await asyncio.sleep(3)
```

### 4. Navigate to the page

```python
# If PagePath doesn't start with /, construct full URL
page_url = "https://lubavitchrv--partial.sandbox.lightning.force.com/lightning/n/{PagePath}"
await page.goto(page_url)
await asyncio.sleep(4)
```

### 5. Take screenshot

```python
await page.screenshot(path="/tmp/verify_{PagePath}.png")
```

### 6. Read and display the screenshot

Use the Read tool to view `/tmp/verify_{PagePath}.png`

### 7. Interactive testing (optional)

If the user wants to interact:

```python
# Click on elements
await page.click("text=Button Label")

# Fill inputs
await page.fill("input[placeholder='Search...']", "search term")

# Wait and screenshot
await asyncio.sleep(2)
await page.screenshot(path="/tmp/verify_step2.png")
```

### 8. Close browser when done

```python
if browser:
    await browser.close()
if pw:
    await pw.stop()
```

## Common Selectors

| Element | Selector |
|---------|----------|
| Lightning button | `button:has-text('Button Label')` |
| Input by placeholder | `input[placeholder='Search...']` |
| List item by data-id | `li[data-id]` |
| Combobox | `lightning-combobox` |
| App Launcher | `div.slds-icon-waffle` |

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Element not found | Add `await asyncio.sleep(2)` before selecting - page may still be loading |
| Setup page elements | Setup renders in iframe - use `iframe = await page.query_selector("iframe")` then `frame = await iframe.content_frame()` |
| Search not triggering | For live search, type with delay: `await input.type("text", delay=100)` |
