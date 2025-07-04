#!/bin/bash
# This script sets up the necessary AWS permissions to export an AMI image to S3.
# See: https://docs.aws.amazon.com/vm-import/latest/userguide/required-permissions.html

# Check for help flag first
for arg in "$@"; do
    case $arg in
        --help|-h)
            echo "Usage: $0 BUCKET_NAME"
            echo "Arguments:"
            echo "  BUCKET_NAME      S3 bucket name for image exports"
            echo "Options:"
            echo "  --help           Show this help message"
            exit 0
            ;;
    esac
done

# Validate required arguments
if [ $# -lt 1 ]; then
    echo "Error: S3 bucket name is required"
    echo "Usage: $0 BUCKET_NAME"
    exit 1
fi

S3_BUCKET="$1"

# create trust-policy.json content inline
cat > trust-policy.json << 'EOF'
{
   "Version": "2012-10-17",
   "Statement": [
      {
         "Effect": "Allow",
         "Principal": { "Service": "vmie.amazonaws.com" },
         "Action": "sts:AssumeRole",
         "Condition": {
            "StringEquals":{
               "sts:Externalid": "vmimport"
            }
         }
      }
   ]
}
EOF

# create role-policy.json content inline
cat > role-policy.json << EOF
{
   "Version":"2012-10-17",
   "Statement":[
      {
         "Effect": "Allow",
         "Action": [
            "s3:GetBucketLocation",
            "s3:GetObject",
            "s3:ListBucket",
            "s3:PutObject",
            "s3:GetBucketAcl"
         ],
         "Resource": [
            "arn:aws:s3:::${S3_BUCKET}",
            "arn:aws:s3:::${S3_BUCKET}/*"
         ]
      },
      {
         "Effect": "Allow",
         "Action": [
            "ec2:ModifySnapshotAttribute",
            "ec2:CopySnapshot",
            "ec2:RegisterImage",
            "ec2:Describe*"
         ],
         "Resource": "*"
      }
   ]
}
EOF

aws iam create-role --role-name vmimport --assume-role-policy-document "file://./trust-policy.json"
aws iam put-role-policy --role-name vmimport --policy-name vmimport --policy-document "file://./role-policy.json"
         "Resource": "*"
      }
   ]
}
EOF

aws iam create-role --role-name vmimport --assume-role-policy-document "file://./trust-policy.json"
aws iam put-role-policy --role-name vmimport --policy-name vmimport --policy-document "file://./role-policy.json"
