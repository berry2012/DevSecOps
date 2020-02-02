#!/bin/bash

# Forseti gives you tools to understand all the resources you have in GCP. 
# Inventory regularly collects data from your GCP resources and makes it available to other modules.
# Scanner periodically compares your rules about GCP resource policies against the policies collected by Inventory, and saves the output for your review.
# Enforcer uses Google Cloud APIs to change resource policy state to match the state you define.
# Explain helps you understand, test, and develop Cloud Identity and Access Management (Cloud IAM) policies.
# Notifier keeps you up to date about Forseti findings and actions.

# Objectives
# Install the Forseti server and client
# Use Scanner to scan Inventory data
# Fix the violations you find

export PROJECT_ID=<PROJECT_ID>
export MEMBER=user:whaleberry@gmail.com


gcloud config set project $PROJECT_ID

# clone the Forseti code repository
git clone https://github.com/GoogleCloudPlatform/forseti-security.git
# Change into the Forseti repository directory:
cd forseti-security
# Switch to the correct branch:
git checkout release-2.17.0
# Execute the Forseti installer:
PROJECT_ID=$(gcloud projects describe ${GOOGLE_CLOUD_PROJECT} \
    --format="value(projectNumber)")
# automatically press enter for possible questions installation might ask    
yes "" | python3 install/gcp_installer.py \
    --composite-root-resources projects/${PROJECT_ID} & pid=$!
wait $pid
echo $pid completed
# Create a new bucket:    
gsutil mb gs://${GOOGLE_CLOUD_PROJECT}-shared
# ake the bucket world readable (a violation of default Forseti rules):
gsutil acl ch -g AllUsers:R gs://${GOOGLE_CLOUD_PROJECT}-shared
# add a gmail account with viewer access to your project 
gcloud projects add-iam-policy-binding \
    --role="roles/viewer" \
    --member="$MEMBER" \
    ${GOOGLE_CLOUD_PROJECT}
sleep 3
BUCKET=$(gsutil ls | grep forseti-server)
gsutil cp ${BUCKET}rules/iam_rules.yaml .

cat >> iam_rules.yaml << EOF

  - name: project viewers whitelist
    mode: whitelist
    resource:
      - type: project
        applies_to: self
        resource_ids:
          - '*'
    inherit_from_parents: true
    bindings:
      - role: 'roles/viewer'
        members:
          - user:*@qwiklabs.net
          - user:*@*.gserviceaccount.com
EOF

gsutil cp iam_rules.yaml ${BUCKET}rules/iam_rules.yaml
# In the Forseti Cloud Shell, connect to your Forseti server instance:
VM=$(gcloud compute instances list --filter="name~'forseti-server'" | tail -1)
SERVER=$(echo ${VM} | cut -f1 -d' ')
ZONE=$(echo ${VM} | cut -f2 -d' ')  

cat - << EOF 

# run the commands in another shell below to ssh into foreseti and perform scan on your GCP resources
    gcloud compute ssh ${SERVER} --zone ${ZONE}
# Forseti is configured to scan automatically every 2 hours. To manually perform a scan, execute the Forseti server run command:
    /home/ubuntu/forseti-security/install/gcp/scripts/run_forseti.sh

EOF

echo "Job done"
