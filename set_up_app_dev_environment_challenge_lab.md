# Set Up an App Dev Environment on Google Cloud: Challenge Lab

## Overview

This challenge lab covers:
- Cloud Storage bucket creation
- Pub/Sub topic creation
- Cloud Run Functions (Gen2)
- Eventarc permissions
- IAM access management

---

# Prerequisites

## Configure gcloud for Qwiklabs

```bash
gcloud config configurations create qwiklabs
gcloud config configurations activate qwiklabs
gcloud auth login
```

Set project:

```bash
gcloud config set project PROJECT_ID
```

Set region and zone:

```bash
gcloud config set compute/region us-west4
gcloud config set compute/zone us-west4-c
```

Verify:

```bash
gcloud auth list
gcloud config list
```

---

# Task 1 - Create Cloud Storage Bucket

## Create bucket

```bash
gcloud storage buckets create gs://qwiklabs-gcp-00-07998f0545bf-bucket \
  --location=us-west4
```

## Verify

```bash
gcloud storage buckets list
```

---

# Task 2 - Create Pub/Sub Topic

## Create topic

```bash
gcloud pubsub topics create topic-memories-970
```

## Verify

```bash
gcloud pubsub topics list
```

---

# Task 3 - Create Cloud Run Function (Gen2)

## Create working directory

```bash
mkdir memories-thumbnail-creator
cd memories-thumbnail-creator
```

---

## Create index.js

```bash
cat > index.js <<'EOF'
const functions = require('@google-cloud/functions-framework');
const { Storage } = require('@google-cloud/storage');
const { PubSub } = require('@google-cloud/pubsub');
const sharp = require('sharp');

functions.cloudEvent('memories-thumbnail-creator', async cloudEvent => {
  const event = cloudEvent.data;

  console.log(`Event: ${JSON.stringify(event)}`);
  console.log(`Hello ${event.bucket}`);

  const fileName = event.name;
  const bucketName = event.bucket;
  const size = "64x64";
  const bucket = new Storage().bucket(bucketName);
  const topicName = "topic-memories-970";
  const pubsub = new PubSub();

  if (fileName.search("64x64_thumbnail") === -1) {
    const filename_split = fileName.split('.');
    const filename_ext = filename_split[filename_split.length - 1].toLowerCase();
    const filename_without_ext = fileName.substring(0, fileName.length - filename_ext.length - 1);

    if (filename_ext === 'png' || filename_ext === 'jpg' || filename_ext === 'jpeg') {

      console.log(`Processing Original: gs://${bucketName}/${fileName}`);

      const gcsObject = bucket.file(fileName);
      const newFilename = `${filename_without_ext}_64x64_thumbnail.${filename_ext}`;
      const gcsNewObject = bucket.file(newFilename);

      try {
        const [buffer] = await gcsObject.download();

        const resizedBuffer = await sharp(buffer)
          .resize(64, 64, {
            fit: 'inside',
            withoutEnlargement: true,
          })
          .toFormat(filename_ext)
          .toBuffer();

        await gcsNewObject.save(resizedBuffer, {
          metadata: {
            contentType: `image/${filename_ext}`,
          },
        });

        console.log(`Success: ${fileName} → ${newFilename}`);

        await pubsub
          .topic(topicName)
          .publishMessage({ data: Buffer.from(newFilename) });

        console.log(`Message published to ${topicName}`);

      } catch (err) {
        console.error(`Error: ${err}`);
      }

    } else {
      console.log(`gs://${bucketName}/${fileName} is not an image I can handle`);
    }

  } else {
    console.log(`gs://${bucketName}/${fileName} already has a thumbnail`);
  }
});
EOF
```

---

## Create package.json

```bash
cat > package.json <<'EOF'
{
  "name": "memories-thumbnail-creator",
  "version": "1.0.0",
  "main": "index.js",
  "dependencies": {
    "@google-cloud/functions-framework": "^3.0.0",
    "@google-cloud/pubsub": "^4.0.0",
    "@google-cloud/storage": "^7.0.0",
    "sharp": "^0.33.0"
  }
}
EOF
```

---

## Deploy Cloud Function

```bash
gcloud functions deploy memories-thumbnail-creator \
  --gen2 \
  --runtime=nodejs22 \
  --region=us-west4 \
  --source=. \
  --entry-point=memories-thumbnail-creator \
  --trigger-bucket=qwiklabs-gcp-00-07998f0545bf-bucket \
  --max-instances=2
```

If prompted:
- Enable required APIs
- Allow IAM role bindings

---

## Eventarc Permission Fix

### Get project number

```bash
PROJECT_NUMBER=$(gcloud projects describe $(gcloud config get-value project) \
--format="value(projectNumber)")
```

### Grant Eventarc Service Agent Role

```bash
gcloud projects add-iam-policy-binding $(gcloud config get-value project) \
--member="serviceAccount:service-${PROJECT_NUMBER}@gcp-sa-eventarc.iam.gserviceaccount.com" \
--role="roles/eventarc.serviceAgent"
```

---

## Grant Pub/Sub Publisher Role to Cloud Storage

```bash
gcloud services enable storage.googleapis.com
```

```bash
gcloud projects add-iam-policy-binding $(gcloud config get-value project) \
--member="serviceAccount:service-${PROJECT_NUMBER}@gs-project-accounts.iam.gserviceaccount.com" \
--role="roles/pubsub.publisher"
```

Wait 60 seconds and redeploy.

---

# Test Function

## Download test image

```bash
wget https://storage.googleapis.com/cloud-training/gsp315/map.jpg
```

## Upload image

```bash
gcloud storage cp map.jpg gs://qwiklabs-gcp-00-07998f0545bf-bucket
```

## Verify

```bash
gcloud storage ls gs://qwiklabs-gcp-00-07998f0545bf-bucket
```

Expected:
- map.jpg
- map_64x64_thumbnail.jpg

---

# Task 4 - Remove Previous Cloud Engineer Access

## Remove Viewer Role

```bash
gcloud projects remove-iam-policy-binding $(gcloud config get-value project) \
  --member="user:student-03-513a69462b5e@qwiklabs.net" \
  --role="roles/viewer"
```

---

# Cleanup

## Switch back to default config

```bash
gcloud config configurations activate default
```

## Revoke student account

```bash
gcloud auth revoke STUDENT_EMAIL
```

## Delete temporary config

```bash
gcloud config configurations delete qwiklabs
```
