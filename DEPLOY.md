# Deployment guide

Ember is super easy to deploy with [kamal](https://kamal-deploy.org).

## step 1 - get a server

Set up a server on your favourite hosting provider, there are common ones like [hetzner](https://www.hetzner.com/) or [digital ocean](https://www.digitalocean.com/).

The demo chat that is live at [emberchat.org](https://emberchat.org) runs on a 4.11€/m machine with 4GB of memory and 40 GB of storage.

## step 2 - get a domain (optional)

If you want your own domain for the chat, buy one from anywhere. 

This is required i think for ssl to work properly with kamal. 

If you already have a domain, you can also just deploy emberchat under a subdomain like "chat.example.com"

## step 2 - set up kamal

In the file config/deploy.yml change the host name to your own host, this can be a domain name or the ip address of your server.

Now some values in the kamal deploy file will be fetched from your environment variables, that is

You can create the file .kamal/secrets, in which you can add your secrets:

my file looks like this, using bitwarden, however if you don't use any secret manager you can fill in these values directly in the file.

```
# first fetch the secrets from the env
SECRETS=$(kamal secrets fetch --adapter bitwarden-sm <my account number>)

# get things
KAMAL_REGISTRY_PASSWORD=$(kamal secret extract KAMAL_REGISTRY_PASSWORD $SECRETS)

# Generate with: mix phx.gen.secret
SECRET_KEY_BASE=$(kamal secret extract SECRET_KEY_BASE $SECRETS)

# Database path in the container
DATABASE_PATH=$(kamal secret extract DATABASE_PATH $SECRETS)

# SendGrid API key for sending emails
# Get this from your SendGrid account: https://app.sendgrid.com/settings/api_keys
SENDGRID_API_KEY=$(kamal secret extract SENDGRID_API_KEY $SECRETS)
```


## deploy!

deploy to your own server with 

`kamal setup` - if this is your first time deploying

`kamal deploy` - if you have made any changes to the code and want to redeploy

