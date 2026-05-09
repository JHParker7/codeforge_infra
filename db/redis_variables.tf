# ── Redis Cluster ─────────────────────────────────────────────────────────────

variable "redis_password" {
  description = "Password for Redis cluster nodes (requirepass / masterauth)"
  type        = string
  # sensitive   = true
}

variable "redis_port" {
  description = "Redis client port"
  type        = number
  default     = 6379
}
