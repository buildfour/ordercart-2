# OrderCart Update Guide

This guide explains how to update your deployed OrderCart services without redeploying from scratch.

---

## 🎯 **Quick Start**

### **Update a Single Service**
```bash
./update.sh
# Choose which service to update
```

### **Update All Services**
```bash
./update.sh
# Choose option 5 (All Services)
```

---

## 📝 **What Happens During an Update**

When you redeploy a Cloud Run service:

✅ **Preserved (Stays the same):**
- Service URL (doesn't change)
- Environment variables
- IAM permissions
- Firestore data
- Pub/Sub topics/subscriptions
- Service configuration (memory, timeout, etc.)

🔄 **Updated:**
- Application code
- Python dependencies (requirements.txt)
- Container image

---

## 🔍 **Common Update Scenarios**

### **Scenario 1: Fixed a Bug in Agent Code**

**Example:** You fixed a validation bug in Agent 1's `main.py`

```bash
# Edit the file
nano agent-intake-validator/main.py

# Redeploy only Agent 1
cd agent-intake-validator
gcloud run deploy agent-intake-validator \
  --source . \
  --region us-central1
```

**Time:** ~2-3 minutes
**Downtime:** None (gradual rollout)
**Data:** Preserved

---

### **Scenario 2: Updated Web App UI**

**Example:** You changed the CSS or JavaScript

```bash
# Edit files
nano ordercart-webapp/static/css/style.css
nano ordercart-webapp/static/js/app.js

# Redeploy web app
cd ordercart-webapp
gcloud run deploy ordercart-webapp \
  --source . \
  --region us-central1
```

**Time:** ~2-3 minutes
**Downtime:** None
**Cache:** Users may need to refresh (Ctrl+F5)

---

### **Scenario 3: Added New Python Dependency**

**Example:** You added a new library to `requirements.txt`

```bash
# Edit requirements.txt
echo "pandas==2.0.0" >> agent-intake-validator/requirements.txt

# Redeploy (Cloud Build will install new dependency)
cd agent-intake-validator
gcloud run deploy agent-intake-validator \
  --source . \
  --region us-central1
```

**Time:** ~3-5 minutes (longer due to pip install)
**Downtime:** None

---

### **Scenario 4: Changed Environment Variable**

**Example:** You want to update the Google API Key

```bash
gcloud run services update agent-intake-validator \
  --region us-central1 \
  --update-env-vars GOOGLE_API_KEY=new-key-here
```

**Time:** ~30 seconds
**Downtime:** Brief (few seconds)
**No Code Build:** Just updates configuration

---

### **Scenario 5: Major Update (All Services)**

**Example:** You refactored code across all agents

```bash
# Use the update script
./update.sh
# Choose option 5

# OR manually:
cd agent-intake-validator && gcloud run deploy agent-intake-validator --source . --region us-central1 && cd ..
cd agent-fulfillment-processor && gcloud run deploy agent-fulfillment-processor --source . --region us-central1 && cd ..
cd agent-exception-handler && gcloud run deploy agent-exception-handler --source . --region us-central1 && cd ..
cd ordercart-webapp && gcloud run deploy ordercart-webapp --source . --region us-central1 && cd ..
```

**Time:** ~10-15 minutes total
**Downtime:** None (services update independently)

---

## 🚀 **Update Workflow**

### **Recommended Process:**

1. **Make changes locally**
   ```bash
   # Edit code
   nano agent-intake-validator/main.py
   ```

2. **Test locally (optional but recommended)**
   ```bash
   cd agent-intake-validator
   python main.py
   # Test at http://localhost:8080
   ```

3. **Commit to git**
   ```bash
   git add .
   git commit -m "Fix: Improved validation logic"
   git push
   ```

4. **Deploy update**
   ```bash
   ./update.sh
   ```

5. **Verify deployment**
   ```bash
   # Check health
   curl https://YOUR_SERVICE_URL/health

   # Check Cloud Run console
   # https://console.cloud.google.com/run
   ```

---

## 🔄 **Rollback (If Something Breaks)**

Cloud Run keeps previous versions (revisions). You can rollback instantly:

### **Via Cloud Console:**
1. Go to [Cloud Run Console](https://console.cloud.google.com/run)
2. Click your service
3. Click "REVISIONS" tab
4. Find previous working revision
5. Click "MANAGE TRAFFIC"
6. Route 100% traffic to old revision
7. Click "SAVE"

### **Via Command Line:**
```bash
# List revisions
gcloud run revisions list \
  --service agent-intake-validator \
  --region us-central1

# Rollback to specific revision
gcloud run services update-traffic agent-intake-validator \
  --region us-central1 \
  --to-revisions REVISION_NAME=100
```

**Time:** Instant (traffic routing change)
**Downtime:** None

---

## 📊 **What You NEVER Need to Redo**

When updating services, you **DO NOT** need to:

❌ Recreate Firestore database
❌ Recreate Pub/Sub topics
❌ Recreate Pub/Sub subscriptions
❌ Re-enable APIs
❌ Reconfigure project settings
❌ Get new service URLs
❌ Update environment variables (unless you changed them)

These are **infrastructure** and only need to be created once during initial deployment.

---

## 🔧 **When to Use deploy.sh vs update.sh**

### **Use `deploy.sh` when:**
- ✅ First-time deployment
- ✅ Starting fresh in a new project
- ✅ All infrastructure needs to be created

### **Use `update.sh` when:**
- ✅ Services already deployed
- ✅ Just updating code
- ✅ Changing dependencies
- ✅ Quick bug fixes

---

## 💡 **Advanced: Zero-Downtime Deployments**

Cloud Run automatically does **gradual rollouts**:

1. New revision is deployed
2. Traffic starts at 0%
3. Cloud Run gradually increases traffic to new revision
4. Old revision handles remaining traffic
5. Once new revision is healthy, gets 100% traffic
6. Old revision kept for potential rollback

**You get this for free!** No configuration needed.

---

## 🎯 **Update Checklist**

Before deploying an update:

- [ ] Code changes tested locally
- [ ] Dependencies updated in requirements.txt
- [ ] No hardcoded secrets (use environment variables)
- [ ] Changes committed to git
- [ ] Know which service(s) to update
- [ ] Have rollback plan if needed

After deploying:

- [ ] Check service health endpoint
- [ ] Test main functionality
- [ ] Check Cloud Run logs for errors
- [ ] Verify in web browser
- [ ] Monitor for ~15 minutes

---

## 📱 **Monitoring Updates**

### **Check Deployment Status:**
```bash
gcloud run services describe agent-intake-validator \
  --region us-central1 \
  --format="value(status.conditions)"
```

### **View Logs:**
```bash
gcloud run services logs read agent-intake-validator \
  --region us-central1 \
  --limit 50
```

### **Check Current Revision:**
```bash
gcloud run revisions list \
  --service agent-intake-validator \
  --region us-central1 \
  --limit 5
```

---

## 🐛 **Troubleshooting Updates**

### **Problem: Build Fails**
**Symptoms:** Deployment stuck at "Building..."

**Solutions:**
1. Check syntax errors in code
2. Verify requirements.txt format
3. Check Cloud Build logs:
   ```bash
   gcloud builds list --limit 5
   ```

---

### **Problem: Service Crashes After Update**
**Symptoms:** Service shows errors in logs

**Solutions:**
1. **Quick Fix:** Rollback to previous revision
2. Check logs:
   ```bash
   gcloud run services logs read SERVICE_NAME --limit 100
   ```
3. Common issues:
   - Missing environment variable
   - Import error (new dependency not installed)
   - Firestore connection issue

---

### **Problem: Changes Not Visible**
**Symptoms:** Updated code but app looks the same

**Solutions:**
1. **Web App:** Clear browser cache (Ctrl+Shift+R)
2. Verify deployment completed:
   ```bash
   gcloud run services describe ordercart-webapp --region us-central1
   ```
3. Check revision traffic:
   ```bash
   gcloud run services describe ordercart-webapp \
     --region us-central1 \
     --format="value(status.traffic)"
   ```

---

## 💰 **Update Costs**

**Cloud Run Deployments:**
- Build time: ~$0.01 - $0.05 per build
- No charge for deployment itself
- Regular Cloud Run usage charges apply

**Free Tier:**
- 120 build-minutes/day free
- Updates typically use 2-3 build-minutes

**Cost for typical update:** < $0.05

---

## 🎓 **Best Practices**

1. **Small, Frequent Updates**
   - Better than one big update
   - Easier to debug issues
   - Faster rollback if needed

2. **Test Locally First**
   - Run services locally before deploying
   - Saves Cloud Build time and cost

3. **Use Git**
   - Commit before deploying
   - Easy to track what changed
   - Can revert if needed

4. **Monitor After Deploy**
   - Check logs for 15 minutes
   - Watch for error patterns
   - Be ready to rollback

5. **Update Dependencies Carefully**
   - Test major version upgrades locally
   - Check for breaking changes
   - Update one service at a time

---

## 📚 **Additional Resources**

- [Cloud Run Deployment Docs](https://cloud.google.com/run/docs/deploying)
- [Cloud Run Revisions](https://cloud.google.com/run/docs/managing/revisions)
- [Traffic Management](https://cloud.google.com/run/docs/rollouts-rollbacks-traffic-migration)

---

**Summary:** Updating is easy! Just redeploy the service(s) you changed. Everything else stays intact. 🚀
