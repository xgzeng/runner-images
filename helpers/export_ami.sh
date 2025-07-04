#!/bin/bash

# This script exports an AMI to an S3 bucket using AWS CLI; then download the image from S3 bucket.

S3_BUCKET="zengxg-packer"
S3_PREFIX="exports"
AMI_NAME="runner-image-ubuntu-24.04"

# Function to check if required commands exist
check_required_commands() {
    local required_commands=("aws" "jq" "qemu-img" "s5cmd")
    local missing_commands=()
    
    echo "Checking required commands..."
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        echo "Error: The following required commands are missing:"
        for cmd in "${missing_commands[@]}"; do
            echo "  - $cmd"
        done
        echo "Please install the missing commands and try again."
        exit 1
    fi
    
    echo "All required commands are available."
}

# Function to cancel existing export tasks
cancel_existing_exports() {
    echo "Checking for existing export tasks..."
    
    # Get all active export tasks
    local active_tasks=$(aws ec2 describe-export-image-tasks \
        --query 'ExportImageTasks[?Status==`active`].ExportImageTaskId' \
        --output text)
    
    if [[ -n "$active_tasks" && "$active_tasks" != "None" ]]; then
        echo "Found active export tasks. Cancelling them..."
        for task_id in $active_tasks; do
            echo "Cancelling export task: $task_id"
            aws ec2 cancel-export-task --export-task-id "$task_id"
            if [[ $? -eq 0 ]]; then
                echo "Successfully cancelled task: $task_id"
            else
                echo "Failed to cancel task: $task_id"
            fi
        done
        
        # Wait a moment for cancellation to process
        echo "Waiting for cancellation to process..."
        sleep 5
    else
        echo "No active export tasks found."
    fi
}

# Function to get AMI ID by name
get_ami_id() {
    local ami_name=$1
    aws ec2 describe-images \
        --owners self \
        --filters "Name=name,Values=$ami_name" \
        --query 'Images[0].ImageId' \
        --output text
}

# Function to start export task
start_export_task() {
    local ami_id=$1
    local stamped_name=$2
    aws ec2 export-image \
        --image-id "$ami_id" \
        --disk-image-format VMDK \
        --s3-export-location S3Bucket="$S3_BUCKET",S3Prefix="exports/${stamped_name}/" \
        --query 'ExportImageTaskId' \
        --output text
}

# Function to monitor export progress
wait_for_export() {
    local task_id=$1
    local status=""

    echo "Monitoring export task: $task_id"
    
    while [[ "$status" != "completed" ]]; do
        # Get status and progress information
        local task_info=$(aws ec2 describe-export-image-tasks \
            --export-image-task-ids "$task_id" \
            --query 'ExportImageTasks[0].[Status,Progress,StatusMessage]' \
            --output text)
        
        status=$(echo "$task_info" | awk '{print $1}')
        local progress=$(echo "$task_info" | awk '{print $2}')
        local status_message=$(echo "$task_info" | awk '{for(i=3;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/None//')
        
        # Display progress with timestamp
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        if [[ -n "$progress" && "$progress" != "None" ]]; then
            echo "[$timestamp] Export status: $status - Progress: $progress%"
        else
            echo "[$timestamp] Export status: $status"
        fi
        
        # Display status message if available
        if [[ -n "$status_message" && "$status_message" != " " ]]; then
            echo "Status message: $status_message"
        fi
        
        if [[ "$status" == "failed" ]]; then
            echo "Export failed!"
            aws ec2 describe-export-image-tasks \
                --export-image-task-ids "$task_id" \
                --query 'ExportImageTasks[0].StatusMessage' \
                --output text
            exit 1
        fi
        
        if [[ "$status" != "completed" ]]; then
            sleep 30
        fi
    done
    
    echo "Export completed successfully!"
}

# Function to get S3 path after export completion
get_s3_path() {
    local task_id=$1
    
    # Get S3 bucket and prefix
    local s3_info=$(aws ec2 describe-export-image-tasks \
        --export-image-task-ids "$task_id" \
        --query 'ExportImageTasks[0].S3ExportLocation' \
        --output json)
    
    local s3_bucket=$(echo "$s3_info" | jq -r '.S3Bucket')
    local s3_prefix=$(echo "$s3_info" | jq -r '.S3Prefix')
    
    # List objects in the S3 prefix to find the actual exported file
    aws s3 ls "s3://$s3_bucket/$s3_prefix" --recursive | grep '\.vmdk$' | awk '{print $4}' | head -1
}

# Function to convert VMDK to QCOW2
convert_to_qcow2() {
    local vmdk_file=$1
    local qcow2_file=$2
    
    echo "Converting VMDK to QCOW2 format..."
    
    # Check if VMDK file exists
    if [[ ! -f "$vmdk_file" ]]; then
        echo "Error: VMDK file '$vmdk_file' not found"
        exit 1
    fi
    
    # Convert using qemu-img
    qemu-img convert -f vmdk -O qcow2 "$vmdk_file" "$qcow2_file"
    
    if [[ $? -eq 0 ]]; then
        echo "Conversion completed successfully: $qcow2_file"
        
        # Get file sizes for comparison
        vmdk_size=$(stat -c%s "$vmdk_file" 2>/dev/null || echo "unknown")
        qcow2_size=$(stat -c%s "$qcow2_file" 2>/dev/null || echo "unknown")
        
        echo "Original VMDK size: $vmdk_size bytes"
        echo "Converted QCOW2 size: $qcow2_size bytes"
        
        # Optionally remove VMDK file to save space
        read -p "Remove original VMDK file? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm "$vmdk_file"
            echo "Original VMDK file removed"
        fi
    else
        echo "Failed to convert VMDK to QCOW2"
        exit 1
    fi
}

# Main execution
main() {
    # Check required commands first
    check_required_commands
    
    echo "Starting AMI export process for: $AMI_NAME"
    
    # Cancel any existing exports
    cancel_existing_exports
    
    # Get AMI ID
    echo "Getting AMI ID..."
    AMI_ID=$(get_ami_id "$AMI_NAME")
    
    if [[ "$AMI_ID" == "None" || -z "$AMI_ID" ]]; then
        echo "Error: AMI with name '$AMI_NAME' not found"
        exit 1
    fi
    
    echo "Found AMI ID: $AMI_ID"
    
    # Cancel any existing export tasks
    cancel_existing_exports
    
    # Start export
    echo "Starting export task..."
    local AMI_NAME_TIMESTAMP="${AMI_NAME}_$(date +%Y%m%d-%H%M%S)"

    TASK_ID=$(start_export_task "$AMI_ID" "$AMI_NAME_TIMESTAMP")

    if [[ -z "$TASK_ID" ]]; then
        echo "Error: Failed to start export task"
        exit 1
    fi
    
    echo "Export task started: $TASK_ID"
    
    # Wait for completion and get S3 key
    echo "Starting monitoring process..."
    wait_for_export "$TASK_ID"
    
    echo "Getting S3 path for exported image..."
    S3_KEY=$(get_s3_path "$TASK_ID")
    
    if [[ -z "$S3_KEY" ]]; then
        echo "Error: Failed to get S3 key for exported image"
        exit 1
    fi
    
    echo "Export completed, s3://$S3_BUCKET/$S3_KEY"
    
    # Download image
    mkdir output
    local filename="${AMI_NAME_TIMESTAMP}.vmdk"
    echo "Downloading exported image..."
    # aws s3 cp "s3://$S3_BUCKET/$S3_KEY" "./$filename"
    s5cmd -r 1000 cp --sp "s3://$S3_BUCKET/$S3_KEY" "output/${filename}"
    if [[ $? -eq 0 ]]; then
        echo "Image downloaded successfully: $filename"
    else
        echo "Failed to download image"
        exit 1
    fi

    # Convert to QCOW2
    convert_to_qcow2 "output/${AMI_NAME_TIMESTAMP}.vmdk" "output/${AMI_NAME_TIMESTAMP}.qcow2"
    echo "AMI export, download, and conversion process completed successfully!"
    echo "Final image at "
}

# Run main function
main "$@"
