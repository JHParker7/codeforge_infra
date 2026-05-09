# ── HAProxy ───────────────────────────────────────────────────────────────────

variable "haproxy_pg_primary_port" {
  description = "HAProxy frontend port for PostgreSQL primary (read-write)"
  type        = number
  default     = 5000
}

variable "haproxy_pg_replica_port" {
  description = "HAProxy frontend port for PostgreSQL replicas (read-only)"
  type        = number
  default     = 5001
}

variable "haproxy_stats_port" {
  description = "HAProxy stats page port"
  type        = number
  default     = 7000
}
