# Google Docs Looker Action Hub

![output all results](assets/all-results.png)

A lightweight, fully minimized standalone Looker Action Hub hosting **only** the Google Docs Looker action (`google_docs`). The purpose of this is to get unlimited results into Google Docs which supports:

- Headers & Footers
- Page numbers and dynamic text
- Section breaks
- Table headers across all pages
- PDF and physical printing

Here is a link to an example [output document with unlimited results](https://docs.google.com/document/d/17Sk_EJdvKc1P8UI68z973-1zkn8Zm_W6sOfbGds4TCg/edit?usp=sharing) and a downloadable [PDF](https://docs.google.com/document/d/17Sk_EJdvKc1P8UI68z973-1zkn8Zm_W6sOfbGds4TCg/export?format=pdf).



## What It Does

When Looker sends a query payload via webhook, this service:
1. Validates OAuth2 user credentials (`drive` and `documents` scopes) against Google APIs, enforcing optional domain allowlists (`domain_allowlist`).
2. Creates a new blank Google Document (`application/vnd.google-apps.document`) within a target Drive folder or Shared Drive.
3. Formats page boundaries to Landscape (`11" x 8.5"`) with `0.5"` margins.
4. Streams Looker CSV payloads into a dynamic Google Doc table via batched `insertText` operations (default 100 insertions/batch) to optimize API payload constraints.
5. Additional formatting:
   - Applies pinned header rows (`pinTableHeaderRows: 1`) to repeat table headers across page breaks.
   - Styles header rows with a `rgb(0.95, 0.95, 0.95)` light-gray background and bold text.
   - Configures fixed column properties (first column at `0.5"`, remaining columns distributed evenly) and `8pt` typography.
6. Implements exponential backoff retries (up to 5 attempts) on Google API rate limits (`429`) or server failures (`5xx`).

---

## Connecting to Looker

Register the deployed Action Hub within Looker:
1. Navigate to **Admin** > **Platform** > **Actions**.
2. Click **Add Action Hub**.
3. Enter your deployed Cloud Run URL (e.g., `https://google-docs-action-xxx-uc.a.run.app`).
4. Supply your **Authorization Token** (`ACTION_HUB_SECRET` or authorization headers).
5. Click **Add Hub** and enable the **Google Docs** action.

---

## Deploying to Google Cloud Run

You can easily launch this standalone action integration into Google Cloud Run:

```bash
gcloud run deploy google-docs-action \
  --image=<image-url> \
  --platform=managed \
  --region=us-central1 \
  --allow-unauthenticated \
  --set-env-vars="GOOGLE_DOC_CLIENT_ID=your_id,GOOGLE_DOC_CLIENT_SECRET=your_secret"
```

---

## Local Development

### Prerequisites
- **Node.js**: `>= 20.16.0`
- **Yarn**: `>= 1.19.1`

### Setup & Run
```bash
# Install dependencies
yarn install

# Configure environment variables
cp .env.example .env
# Set GOOGLE_DOC_CLIENT_ID & GOOGLE_DOC_CLIENT_SECRET in .env

# Start production server
yarn start

# Run development server with hot-reloading
yarn dev
```

---

## Testing

Run the test suite (Mocha unit/integration tests, TypeScript compilation, and linter):
```bash
yarn test
```
