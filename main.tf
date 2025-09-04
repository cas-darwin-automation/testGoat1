# Configure the AWS provider
provider "aws" {
  region = "us-east-1"
}

# Create a random suffix for the bucket name to ensure it's globally unique
resource "random_pet" "bucket_suffix" {
  length = 2
}

# Create an S3 bucket
resource "aws_s3_bucket" "insecure_bucket" {
  # Bucket names must be globally unique
  bucket = "insecure-bucket-${random_pet.bucket_suffix.id}"

  tags = {
    Name        = "Insecure Bucket"
    Environment = "Test"
  }
}

# THIS IS WHAT MAKES THE BUCKET INSECURE
# It explicitly disables the block on public policies for this bucket.
resource "aws_s3_bucket_public_access_block" "public_access_block" {
  bucket = aws_s3_bucket.insecure_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket" "my_bucket" {
  bucket = "my-public-bucket-that-will-fail-the-pre-plan"
  acl    = "public-read" # This is the policy violation
}

# THIS POLICY GRANTS PUBLIC READ-ONLY ACCESS TO ALL OBJECTS
# It allows anyone on the internet to view the objects in the bucket.
resource "aws_s3_bucket_policy" "public_read_policy" {
  bucket = aws_s3_bucket.insecure_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.insecure_bucket.arn}/*"
      },
    ]
  })

  # This depends on the public access block being configured first
  depends_on = [aws_s3_bucket_public_access_block.public_access_block]
}

# Output the name of the bucket
output "bucket_name" {
  description = "The name of the insecure S3 bucket."
  value       = aws_s3_bucket.insecure_bucket.bucket
}

# Output the bucket's website endpoint for easy access
output "bucket_endpoint" {
  description = "The HTTP URL endpoint for the S3 bucket."
  value       = "http://${aws_s3_bucket.insecure_bucket.bucket}.s3-website-${aws_s3_bucket.insecure_bucket.region}.amazonaws.com/"
}
