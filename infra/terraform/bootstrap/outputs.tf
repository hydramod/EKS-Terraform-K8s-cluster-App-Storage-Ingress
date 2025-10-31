output "bucket_name" {
  value       = aws_s3_bucket.state.bucket
  description = "S3 bucket created for Terraform backend"
}
