variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "video_bucket_name" {
  description = "Bucket Name Given to the Bucket that allocates Users Uploaded Videos"
  type = string
  default = "zodh-video-bucket"
}
