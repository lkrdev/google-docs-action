# Google Docs Action (from Hub)

A lightweight, fully minimized standalone Looker Action Hub hosting **only** the Google Docs Looker action (`google_docs`).

## Connecting to Looker

Once your Cloud Run service is deployed, connect it to your Looker instance as a new standalone Action Hub:

1. In your Looker instance, navigate to **Admin** > **Platform** > **Actions**.
2. Scroll to the bottom and click **Add Action Hub**.
3. Enter the URL of your deployed Cloud Run service (e.g., `https://google-docs-action-xxx-uc.a.run.app`).
4. Enter the **Authorization Token** corresponding to your deployed service (configured via `ACTION_HUB_SECRET` or authorization headers).
5. Click **Add Hub**. The **Google Docs** action will now appear in your list of integrations ready to be enabled.

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

## Getting Started

### Prerequisites
- **Node.js**: `>= 20.16.0`
- **Yarn**: `>= 1.19.1`

### 1. Local Installation & Configuration
Install project dependencies via Yarn:
```bash
yarn install
```

Create a `.env` file from the example template to supply required OAuth and internal server variables:
```bash
cp .env.example .env
```
Ensure your `.env` contains your Google API credentials if executing live OAuth calls:
```env
GOOGLE_DOC_CLIENT_ID=your_google_client_id
GOOGLE_DOC_CLIENT_SECRET=your_google_client_secret
```

### 2. Starting the Local Server

To start the production server locally:
```bash
yarn start
```

To run the development server with hot-reloading:
```bash
yarn dev
```

---

## Running Tests

To run the complete test suite (Mocha unit & integration tests, TypeScript compilation, and TSLint):
```bash
yarn test
```
