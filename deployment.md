# OrderCart - Complete Deployment Guide

This guide will walk you through deploying all 4 OrderCart services (3 AI agents + 1 web app) to Google Cloud Platform. Written for absolute beginners.

---

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Method 1: Using the Deployment Script](#method-1-using-the-deployment-script)
3. [Method 2: Using Google Cloud Shell IDE](#method-2-using-google-cloud-shell-ide)
4. [Post-Deployment Setup](#post-deployment-setup)
5. [Testing Your Deployment](#testing-your-deployment)
6. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### What You'll Need:
1. **Google Cloud Account** (free trial available with $300 credit)
2. **Google API Key** for Gemma AI
3. **Gmail Account** with App Password (for email features)
4. **Credit Card** (required for GCP, but won't be charged with free trial)

### Before You Start:

#### 1. Create a Google Cloud Project
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Click "Select a project" → "New Project"
3. Name it `ordercart-project` (or any name you like)
4. Click "Create"
5. **Write down your Project ID** (you'll need it later)

#### 2. Enable Billing
1. In Google Cloud Console, go to "Billing"
2. Link your credit card (free tier available)
3. Confirm billing is enabled for your project

#### 3. Get Your Google API Key (for Gemma AI)
1. Go to [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Click "Create API Key"
3. **Copy and save this key** - you'll need it during deployment

#### 4. Set Up Gmail for Email Sending
1. Go to your [Google Account Settings](https://myaccount.google.com/)
2. Navigate to Security → 2-Step Verification (enable if not already)
3. Go to Security → App passwords
4. Generate a new app password for "Mail"
5. **Copy and save this 16-character password**

---

## Method 1: Using the Deployment Script

### Step 1: Open Google Cloud Shell
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Click the terminal icon (">_") in the top right corner
3. A terminal will open at the bottom of the page

### Step 2: Download the OrderCart Code
```bash
# Clone or download the repository
git clone <your-repo-url>
cd ordercart-2

# OR if you have the files already, upload them to Cloud Shell:
# Click the "Upload File" button (⋮ menu) → Upload folder
```

### Step 3: Make the Deploy Script Executable
```bash
chmod +x deploy.sh
```

### Step 4: Run the Deployment Script
```bash
./deploy.sh
```

### Step 5: Follow the Prompts
The script will ask you for:
1. **Google Cloud Project ID** (from Prerequisites step 1)
2. **Google API Key** (from Prerequisites step 3)
3. **Gmail address** (for sending emails)
4. **Gmail App Password** (from Prerequisites step 4)
5. **Region** (recommended: `us-central1`)

The script will:
- ✓ Enable required Google Cloud APIs
- ✓ Create Firestore database
- ✓ Create Pub/Sub topics and subscriptions
- ✓ Deploy all 4 services to Cloud Run
- ✓ Configure environment variables
- ✓ Set up service-to-service communication
- ✓ Display all service URLs

**Deployment Time:** Approximately 10-15 minutes

---

## Method 2: Using Google Cloud Shell IDE

This method gives you a graphical interface if you prefer.

### Step 1: Open Cloud Shell Editor
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Click the terminal icon (">_") → Click "Open Editor"
3. You'll see a VSCode-like interface

### Step 2: Upload Files
1. Click File → Upload Folder
2. Select the `ordercart-2` folder
3. Wait for upload to complete

### Step 3: Open Terminal in Editor
1. Click Terminal → New Terminal
2. Navigate to the folder:
```bash
cd ordercart-2
```

### Step 4: Configure Google Cloud Project
```bash
# Set your project ID
gcloud config set project YOUR_PROJECT_ID

# Verify it's set
gcloud config get-value project
```

### Step 5: Enable Required APIs
```bash
# Enable all required Google Cloud services
gcloud services enable \
  run.googleapis.com \
  firestore.googleapis.com \
  pubsub.googleapis.com \
  cloudbuild.googleapis.com
```

**Wait 2-3 minutes** for APIs to be fully enabled.

### Step 6: Create Firestore Database
```bash
# Create Firestore in Native mode
gcloud firestore databases create --region=us-central1
```

### Step 7: Create Pub/Sub Topics
```bash
# Create topics for agent communication
gcloud pubsub topics create order-validated
gcloud pubsub topics create order-exception
gcloud pubsub topics create communication-request

# Create subscriptions
gcloud pubsub subscriptions create processor-sub \
  --topic=order-validated

gcloud pubsub subscriptions create exception-sub \
  --topic=order-exception

gcloud pubsub subscriptions create communication-sub \
  --topic=communication-request
```

### Step 8: Deploy Agent 1 (Intake & Validation)
```bash
cd agent-intake-validator

gcloud run deploy agent-intake-validator \
  --source . \
  --region us-central1 \
  --platform managed \
  --allow-unauthenticated \
  --set-env-vars="GOOGLE_CLOUD_PROJECT=YOUR_PROJECT_ID,GOOGLE_API_KEY=YOUR_API_KEY" \
  --memory 512Mi \
  --timeout 120

cd ..
```

**Replace:**
- `YOUR_PROJECT_ID` with your actual project ID
- `YOUR_API_KEY` with your Google API key

**Copy the Service URL** - you'll need it later!

### Step 9: Deploy Agent 2 (Fulfillment Processor)
```bash
cd agent-fulfillment-processor

gcloud run deploy agent-fulfillment-processor \
  --source . \
  --region us-central1 \
  --platform managed \
  --allow-unauthenticated \
  --set-env-vars="GOOGLE_CLOUD_PROJECT=YOUR_PROJECT_ID,GOOGLE_API_KEY=YOUR_API_KEY" \
  --memory 512Mi \
  --timeout 120

cd ..
```

**Copy the Service URL!**

### Step 10: Deploy Agent 3 (Exception Handler)
```bash
cd agent-exception-handler

gcloud run deploy agent-exception-handler \
  --source . \
  --region us-central1 \
  --platform managed \
  --allow-unauthenticated \
  --set-env-vars="GOOGLE_CLOUD_PROJECT=YOUR_PROJECT_ID,GOOGLE_API_KEY=YOUR_API_KEY,GMAIL_USER=your-email@gmail.com,GMAIL_APP_PASSWORD=your-16-char-password" \
  --memory 512Mi \
  --timeout 120

cd ..
```

**Replace:**
- `your-email@gmail.com` with your Gmail address
- `your-16-char-password` with your Gmail App Password

**Copy the Service URL!**

### Step 11: Deploy Web Application
```bash
cd ordercart-webapp

gcloud run deploy ordercart-webapp \
  --source . \
  --region us-central1 \
  --platform managed \
  --allow-unauthenticated \
  --set-env-vars="GOOGLE_CLOUD_PROJECT=YOUR_PROJECT_ID,AGENT_INTAKE_URL=INTAKE_URL,AGENT_PROCESSOR_URL=PROCESSOR_URL,AGENT_EXCEPTION_URL=EXCEPTION_URL" \
  --memory 512Mi \
  --timeout 120

cd ..
```

**Replace:**
- `INTAKE_URL` with Agent 1 Service URL (from Step 8)
- `PROCESSOR_URL` with Agent 2 Service URL (from Step 9)
- `EXCEPTION_URL` with Agent 3 Service URL (from Step 10)

### Step 12: Save Your Service URLs
You should now have 4 URLs. Save them:

```bash
echo "=== DEPLOYMENT COMPLETE ==="
echo ""
echo "Agent 1 (Intake): YOUR_AGENT1_URL"
echo "Agent 2 (Processor): YOUR_AGENT2_URL"
echo "Agent 3 (Exception): YOUR_AGENT3_URL"
echo "Web App: YOUR_WEBAPP_URL"
echo ""
echo "Open the Web App URL in your browser to start using OrderCart!"
```

---

## Post-Deployment Setup

### Verify All Services Are Running

1. Go to [Cloud Run Console](https://console.cloud.google.com/run)
2. You should see 4 services with green checkmarks:
   - ✓ agent-intake-validator
   - ✓ agent-fulfillment-processor
   - ✓ agent-exception-handler
   - ✓ ordercart-webapp

### Check Service Health

Test each service health endpoint:

```bash
# Agent 1
curl https://YOUR_AGENT1_URL/health

# Agent 2
curl https://YOUR_AGENT2_URL/health

# Agent 3
curl https://YOUR_AGENT3_URL/health

# Web App
curl https://YOUR_WEBAPP_URL/health
```

Each should return: `{"status": "healthy", ...}`

---

## Testing Your Deployment

### Test 1: Open the Web Application
1. Open your Web App URL in a browser
2. You should see the OrderCart dashboard
3. Try toggling dark mode (moon icon in top right)

### Test 2: Submit a Test Order
1. Click "Capture" in the sidebar
2. Click "Manual Entry"
3. Fill in the form:
   - Customer Name: `Test User`
   - Email: `test@example.com`
   - Phone: `1234567890`
   - Address: `123 Main St`
   - City: `New York`
   - State: `NY`
   - ZIP: `10001`
   - Product SKU: `TEST-001`
   - Product Name: `Test Product`
   - Quantity: `1`
   - Price: `50.00`
4. Click "Submit Order"
5. You should see a success message with an Order ID

### Test 3: View the Order
1. Go to "Dashboard"
2. Your test order should appear in "Recent Orders"
3. Check the statistics at the top

### Test 4: Test Exception Handling
1. Submit another order with an invalid email: `notanemail`
2. This should create an exception
3. Go to "Exceptions" page
4. Click "Analyze with AI" on the exception
5. You should see AI-generated analysis and suggestions

### Test 5: Test Batch Suggestions
1. Submit 3-4 more test orders (all with State: `CA`)
2. Go to "Batches" page
3. You should see AI-suggested batches grouping California orders

---

## Troubleshooting

### Problem: "Permission Denied" Errors

**Solution:**
```bash
# Grant necessary permissions
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:YOUR_PROJECT_NUMBER-compute@developer.gserviceaccount.com" \
  --role="roles/datastore.user"
```

### Problem: Services Won't Deploy

**Solution:**
1. Check that billing is enabled
2. Verify all APIs are enabled:
```bash
gcloud services list --enabled
```
3. Look for error messages in the deployment output

### Problem: Web App Shows "Service Unavailable"

**Solution:**
1. Verify agent URLs are correct in web app environment variables
2. Check Cloud Run logs:
```bash
gcloud run services logs read ordercart-webapp --region us-central1
```

### Problem: Orders Not Saving

**Solution:**
1. Verify Firestore database exists:
```bash
gcloud firestore databases list
```
2. Check agent logs for errors:
```bash
gcloud run services logs read agent-intake-validator --region us-central1
```

### Problem: Emails Not Sending

**Solution:**
1. Verify Gmail credentials are correct
2. Check that 2-Step Verification is enabled
3. Generate a new App Password and redeploy Agent 3

### Problem: "Quota Exceeded" Errors

**Solution:**
- Free tier has limits on Gemma AI API calls
- Wait for quota to reset or upgrade your account

---

## Resources Created

After successful deployment, these resources exist in your Google Cloud Project:

### Cloud Run Services (4)
- `agent-intake-validator` (Port 8080)
- `agent-fulfillment-processor` (Port 8081)
- `agent-exception-handler` (Port 8082)
- `ordercart-webapp` (Port 8000)

### Firestore Collections
- `orders` - All order documents
- `batches` - Batch processing records
- `communications` - Email communication logs

### Pub/Sub Topics (3)
- `order-validated` - Validated orders
- `order-exception` - Exception orders
- `communication-request` - Communication requests

### Pub/Sub Subscriptions (3)
- `processor-sub` - Agent 2 subscription
- `exception-sub` - Agent 3 subscription
- `communication-sub` - Communication handler

---

## Cost Estimates

With Google Cloud Free Tier:
- **Cloud Run**: 2 million requests/month free
- **Firestore**: 1 GB storage free, 50K reads/day free
- **Pub/Sub**: 10 GB messages/month free
- **Gemma AI**: Free tier available (with limits)

**Expected Monthly Cost (with free tier):** $0 - $5 for light usage

**Expected Monthly Cost (production):** $20 - $50 depending on traffic

---

## Stopping/Deleting Resources

### To Stop Services (to avoid charges):
```bash
# Delete all Cloud Run services
gcloud run services delete agent-intake-validator --region us-central1 --quiet
gcloud run services delete agent-fulfillment-processor --region us-central1 --quiet
gcloud run services delete agent-exception-handler --region us-central1 --quiet
gcloud run services delete ordercart-webapp --region us-central1 --quiet
```

### To Delete Everything:
```bash
# Delete the entire project (WARNING: Irreversible!)
gcloud projects delete YOUR_PROJECT_ID
```

---

## Next Steps

1. **Customize** - Modify the code to fit your business needs
2. **Add Authentication** - Implement Firebase Auth for user login
3. **Custom Domain** - Map a custom domain to your web app
4. **Monitoring** - Set up Cloud Monitoring and alerts
5. **Scale** - Adjust Cloud Run memory/CPU as needed

---

## Support

- **Documentation**: See individual README.md files in each agent folder
- **Issues**: Check service logs in Cloud Run console
- **Community**: Google Cloud Community Forums

---

**Congratulations! Your OrderCart system is now live!** 🎉

Visit your Web App URL to start managing orders with AI.
