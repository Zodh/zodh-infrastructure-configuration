variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "video_bucket_name" {
  description = "Bucket Name Given to the Bucket that allocates Users Uploaded Videos"
  type = string
  default = "zodh-raw-video-bucket"
}

variable "processed_images_bucket_name" {
  description = "Bucket Name Given to the Bucket that allocates Users Uploaded Videos"
  type = string
  default = "zodh-processed-images-bucket"
}

variable "pending_video_topic_name" {
  description = "This variable is the name of the topic used by S3 to notify zodh-video-service and zodh-video-processor that a new file was uploaded by an user."
  type = string
  default = "pending-video-topic"
}

variable "video_status_update_queue_name" {
  description = "This variable is the name of the queue used by zodh-video-service to receive a video status update."
  type = string
  default = "video-status-update-queue"
}

variable "video_awaiting_processing_queue_name" {
  description = "This variable is the name of the queue used by zodh-processor-service to receive a video to process"
  type = string
  default = "video-awaiting-processing-queue"
}
