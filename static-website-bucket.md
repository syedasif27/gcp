
---

## Overview Architecture


```

User (HTTPS) ---> Cloudflare Edge (SSL Termination) ---> GCS Bucket (http/https)

```

By leveraging Cloudflare's **Proxied (Orange Cloud)** DNS feature, Cloudflare handles public SSL certificates and forwards requests to your storage bucket, eliminating the need for Google Cloud Load Balancers or complex certificate management.

---

## Step 1: Create GCS Bucket and Upload Website

When using Cloudflare CNAME proxying directly to Cloudflare, **the GCS bucket name must match your exact subdomain name** (e.g., `www.example.com`).

Run the following commands using the `gcloud` CLI:

```bash
# Define variable for your domain
export DOMAIN="[www.example.com](https://www.example.com)"

# 1. Create the bucket (location can be changed to your preferred region)
gcloud storage buckets create gs://$DOMAIN --location=asia-south1

# 2. Upload your website files (e.g., index.html)
gcloud storage cp index.html gs://$DOMAIN/index.html

# 3. Configure bucket as a static website (sets main entry page)
gcloud storage buckets update gs://$DOMAIN --web-main-page-suffix=index.html

# 4. Make all objects in the bucket publicly readable
gcloud storage buckets add-iam-policy-binding gs://$DOMAIN \\
  --member=allUsers \\
  --role=roles/storage.objectViewer

```

---

## Step 2: Configure Cloudflare DNS Record

1. Log into your **Cloudflare Dashboard** and select your primary domain (`example.com`).
2. Navigate to **DNS** → **Records**.
3. Click **Add record** and configure as follows:

| Setting | Value |
| --- | --- |
| **Type** | `CNAME` |
| **Name** | `www` |
| **Target / Content** | `c.storage.googleapis.com` |
| **Proxy Status** | **Proxied** (Orange Cloud 🧡) |
| **TTL** | `Auto` |

---

## Step 3: Configure Cloudflare SSL/TLS Settings

To ensure secure end-to-end routing and automatic HTTP-to-HTTPS redirection:

1. Go to **SSL/TLS** → **Overview** in Cloudflare.
2. Set the Encryption Mode to **Full** (or **Flexible**).
3. Go to **SSL/TLS** → **Edge Certificates**.
4. Enable **Always Use HTTPS** (toggle switch to **On**).

---

## Step 4: Verification

Once the DNS changes propagate (usually within seconds to a few minutes), test your deployment:

```bash
# Check HTTP headers and SSL status
curl -I [https://www.example.com](https://www.example.com)

```

You should receive an `HTTP/2 200 OK` response with headers indicating Cloudflare proxying (`server: cloudflare`).

---

## Troubleshooting & Maintenance

* **404 Not Found Errors:** Verify that the bucket name strictly matches `www.example.com`. If the bucket name differs, Google Cloud Storage cannot match the incoming host header from Cloudflare.
* **403 Access Denied:** Ensure you executed the `add-iam-policy-binding` command granting `roles/storage.objectViewer` to `allUsers`.
* **Updating Files:** To push updates to your site, simply overwrite the file in GCS:
```bash
gcloud storage cp index.html gs://[www.example.com/index.html](https://www.example.com/index.html)

```


*Note: If Cloudflare has cached your static content, you may need to purge the cache under **Caching** → **Configuration** → **Purge Everything**.*
"""

file_path = "gcs_cloudflare_static_hosting-v2.md"
with open(file_path, "w") as f:
f.write(markdown_content)

print(f"File created successfully: {file_path}")

```

```text?code_stdout&code_event_index=1
File created successfully: gcs_cloudflare_static_hosting-v2.md


```

Your Markdown file updated for `[www.example.com](https://www.example.com)` is ready:


---

### File Content Preview
