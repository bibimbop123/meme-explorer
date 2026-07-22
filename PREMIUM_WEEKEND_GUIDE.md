# 🚀 Premium Tier - Weekend Deployment Guide

**Goal**: Launch premium subscriptions THIS WEEKEND and start earning $300-600/month!

**Time Required**: 4-6 hours total (mostly setup & testing)

---

## ✅ Already Complete!

- [x] Stripe gem installed
- [x] Routes created (`routes/premium.rb`)
- [x] Views created (`views/premium.erb`, `views/premium_success.erb`)
- [x] PremiumService ready (`lib/services/premium_service.rb`)
- [x] Database migration ready (`db/migrations/add_premium_tier_2026.sql`)

---

## 🎯 THIS WEEKEND: Complete These Steps

### STEP 1: Wire Up Routes in app.rb (5 minutes)

Add this line to `app.rb` near the other route requires:

```ruby
require_relative 'routes/premium'
```

**Location**: Around line 50-60 where other routes are loaded

---

### STEP 2: Get Stripe Account & Keys (15 minutes)

1. **Sign up for Stripe**: https://dashboard.stripe.com/register
2. **Get API Keys**:
   - Go to: https://dashboard.stripe.com/test/apikeys
   - Copy "Publishable key" (starts with `pk_test_`)
   - Copy "Secret key" (starts with `sk_test_`)

3. **Create Products**:
   - Go to: https://dashboard.stripe.com/test/products
   - Click "+ Add product"
   
   **Monthly Plan**:
   - Name: "Meme Explorer Premium - Monthly"
   - Price: $2.99 USD
   - Billing period: Monthly
   - Click "Save product"
   - Copy the Price ID (starts with `price_`)
   
   **Yearly Plan**:
   - Name: "Meme Explorer Premium - Yearly"  
   - Price: $29.99 USD
   - Billing period: Yearly
   - Click "Save product"
   - Copy the Price ID (starts with `price_`)

---

### STEP 3: Add Environment Variables (2 minutes)

Add these to `.env` (local testing):

```bash
# Stripe Keys (TEST MODE)
STRIPE_PUBLISHABLE_KEY=pk_test_YOUR_KEY_HERE
STRIPE_SECRET_KEY=sk_test_YOUR_KEY_HERE
STRIPE_PRICE_ID_MONTHLY=price_YOUR_MONTHLY_PRICE_ID
STRIPE_PRICE_ID_YEARLY=price_YOUR_YEARLY_PRICE_ID
STRIPE_WEBHOOK_SECRET=whsec_YOUR_WEBHOOK_SECRET
```

**To get webhook secret** (do this after first deploy):
1. Go to: https://dashboard.stripe.com/test/webhooks
2. Click "+ Add endpoint"
3. URL: `https://your-app.onrender.com/webhooks/stripe`
4. Events: Select `checkout.session.completed`, `customer.subscription.updated`, `customer.subscription.deleted`, `invoice.payment_succeeded`, `invoice.payment_failed`
5. Copy the "Signing secret" (starts with `whsec_`)

---

### STEP 4: Run Database Migration (2 minutes)

```bash
ruby scripts/run_premium_migration.rb
```

This adds premium columns to your users table.

---

### STEP 5: Test Locally (30 minutes)

```bash
# Start your server
ruby app.rb

# Open browser
open http://localhost:4567/premium
```

**Test the flow**:
1. Sign up/login
2. Visit `/premium`
3. Click "Get Started" on monthly plan
4. You'll be redirected to Stripe Checkout (TEST MODE)
5. Use test card: `4242 4242 4242 4242`, any future date, any CVC
6. Complete checkout
7. Should redirect to success page

---

### STEP 6: Deploy to Production (1 hour)

1. **Add environment variables to Render**:
   ```bash
   # In Render Dashboard → Environment
   STRIPE_PUBLISHABLE_KEY=pk_live_YOUR_LIVE_KEY
   STRIPE_SECRET_KEY=sk_live_YOUR_LIVE_KEY
   STRIPE_PRICE_ID_MONTHLY=price_YOUR_LIVE_MONTHLY_PRICE_ID
   STRIPE_PRICE_ID_YEARLY=price_YOUR_LIVE_YEARLY_PRICE_ID
   STRIPE_WEBHOOK_SECRET=whsec_YOUR_LIVE_WEBHOOK_SECRET
   ```

2. **Switch to LIVE mode in Stripe**:
   - Toggle "Test mode" OFF in Stripe Dashboard
   - Create products again (same prices)
   - Get LIVE API keys
   - Update Render environment variables

3. **Deploy**:
   ```bash
   git add .
   git commit -m "Add premium subscription tier"
   git push origin main
   ```

4. **Run migration on production**:
   ```bash
   # SSH into Render or use web shell
   ruby scripts/run_premium_migration.rb
   ```

5. **Set up webhook**:
   - Stripe Dashboard → Webhooks → "+ Add endpoint"
   - URL: `https://meme-explorer.onrender.com/webhooks/stripe`
   - Select events (same as before)
   - Copy signing secret to Render environment variables

---

### STEP 7: Add Premium Link to Navigation (5 minutes)

Add to `views/layout.erb` navigation:

```erb
<% if logged_in? %>
  <% if PremiumService.premium?(current_user['id']) %>
    <a href="/premium" class="premium-badge">⭐ Premium</a>
  <% else %>
    <a href="/premium" class="upgrade-link">Upgrade to Premium</a>
  <% end %>
<% end %>
```

---

### STEP 8: Update Ad Helper (5 minutes)

Modify `lib/helpers/ad_helpers.rb` to check premium status:

```ruby
def should_show_ads?
  return false unless logged_in?
  return false if PremiumService.premium?(current_user['id'])
  true
end
```

---

## 🎉 YOU'RE DONE!

Your premium tier is LIVE and ready to accept subscriptions!

---

## 💰 Expected Revenue Timeline

### Week 1-2:  
- 5-10 early adopters
- $15-30/month

### Month 1:  
- 50-100 subscribers
- $150-300/month

### Month 3:  
- 200-300 subscribers
- **$600-900/month**

### Month 6:  
- 500-1000 subscribers
- **$1,500-3,000/month**

---

## 📊 Track Your Success

Monitor in Stripe Dashboard:
- Revenue: https://dashboard.stripe.com/revenue
- Customers: https://dashboard.stripe.com/customers
- Subscriptions: https://dashboard.stripe.com/subscriptions

---

## 🔥 Pro Tips

1. **Announce it!**  
   - Add a banner: "New! Go Premium - Ad-Free Experience"
   - Email your users
   - Post on social media

2. **A/B test pricing**:
   - Try $1.99/month after 2 weeks if conversion is low
   - Or try $4.99/month if conversion is high!

3. **Add urgency**:
   - "Early Bird: 50% off first month!"
   - "Limited time: $1.99/month"

4. **Track metrics**:
   - Conversion rate (visitors → premium)
   - Churn rate (cancellations)
   - Customer lifetime value

---

## 🐛 Troubleshooting

**Webhook not working?**
- Check Stripe Dashboard → Webhooks → View logs
- Ensure URL is correct
- Verify signing secret matches

**Payment fails?**
- Check Stripe logs
- Verify price IDs are correct
- Make sure you're in LIVE mode (not test)

**User not getting premium?**
- Check webhook logs
- Verify `handle_successful_payment` is being called
- Check database: `SELECT * FROM users WHERE premium = true`

---

## 🚀 NEXT: After Premium is Live

**Week 2**: Deploy AJAX Loading (4 hours)
- Boost ad revenue
- Better UX
- More page views = more money

**Month 2**: Optimize Conversion
- A/B test pricing
- Add testimonials
- Improve copy

**Month 3-6**: Scale to $2K-5K/month
- Marketing push
- SEO improvements
- Content strategy

---

## 📞 Need Help?

Check these resources:
- **Stripe Docs**: https://stripe.com/docs/payments/checkout
- **Render Docs**: https://render.com/docs/environment-variables
- **Your guides**: `PREMIUM_INTEGRATION_COMPLETE.md`

---

**You've got this! See you on the other side at $2K-5K/month! 💰**
