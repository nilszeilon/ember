# Kamal SendGrid Setup Guide

This guide explains how to configure SendGrid for your Kamal deployment.

## Prerequisites

1. A SendGrid account (sign up at https://sendgrid.com)
2. A verified sender identity in SendGrid
3. An API key from SendGrid

## Steps to Configure

### 1. Create a SendGrid API Key

1. Log in to your SendGrid account
2. Navigate to Settings → API Keys
3. Click "Create API Key"
4. Give it a name (e.g., "Emberchat Production")
5. Select "Full Access" or "Restricted Access" with Mail Send permissions
6. Copy the generated API key (you won't be able to see it again!)

### 2. Configure Environment Variables

Edit the `.env` file in your project root and update:

```bash
# Your actual SendGrid API key
SENDGRID_API_KEY=SG.xxxxxxxxxxxxxxxxxxxxxx

# Your Phoenix secret key base (generate with: mix phx.gen.secret)
SECRET_KEY_BASE=your_generated_secret_here

# Database path (leave as is for SQLite)
DATABASE_PATH=/app/data/emberchat.db
```

### 3. Deploy with Kamal

```bash
# Deploy your application
kamal deploy

# Or if you only need to update environment variables
kamal env push
```

### 4. Verify Email Configuration

After deployment, you can test email sending from your application's IEx console:

```bash
# Connect to your running container
kamal app exec -i --reuse bash

# Start IEx console
bin/emberchat remote

# Test sending an email
Emberchat.Mailer.deliver(
  Swoosh.Email.new()
  |> Swoosh.Email.to("test@example.com")
  |> Swoosh.Email.from("noreply@yourdomain.com")
  |> Swoosh.Email.subject("Test Email")
  |> Swoosh.Email.text_body("This is a test email from Emberchat")
)
```

## Important Notes

- The `.env` file is already added to `.gitignore` - never commit it!
- Make sure your sender email is verified in SendGrid
- For production, consider using restricted API keys with only Mail Send permissions
- SendGrid requires sender authentication for better deliverability

## Troubleshooting

If emails aren't sending:

1. Check your SendGrid API key is correct
2. Verify your sender identity is authenticated in SendGrid
3. Check application logs: `kamal app logs`
4. Ensure your domain has proper SPF/DKIM records configured