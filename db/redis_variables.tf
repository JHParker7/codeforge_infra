# ── Redis ─────────────────────────────────────────────────────────────────────

variable "redis_password" {
  description = "Password for the standalone Redis instance on pg-1"
  type        = string
}

variable "redis_port" {
  description = "Redis client port"
  type        = number
  default     = 6379
}
