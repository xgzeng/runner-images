# execute following command to setup permission to export image
## See: https://docs.aws.amazon.com/vm-import/latest/userguide/required-permissions.html
## Note: Bucket in role-policy.json need to be modified
aws iam create-role --role-name vmimport --assume-role-policy-document "file://./trust-policy.json"
aws iam put-role-policy --role-name vmimport --policy-name vmimport --policy-document "file://./role-policy.json" 

# list AMI image
# aws ec2 describe-images --owners self

# create task to export image
## See: https://docs.aws.amazon.com/vm-import/latest/userguide/start-image-export.html
aws ec2 export-image --image-id ami-0844be8d5a459e340 --disk-image-format VMDK \
    --s3-export-location S3Bucket=zengxg-packer,S3Prefix=exports/

# monitor export task
## See: https://docs.aws.amazon.com/vm-import/latest/userguide/monitor-image-export.html
aws ec2 describe-export-image-tasks
aws ec2 describe-export-image-tasks --export-image-task-ids export-ami-5f3c68aaff9c1b63t

# download exported image from S3
## Download single file
aws s3 cp s3://zengxg-packer/exports/export-ami-5f3c68aaff9c1b63t.vmdk ./exported-image.vmdk
