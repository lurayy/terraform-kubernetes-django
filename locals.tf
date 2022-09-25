locals {
#  deployments = var.celery_enabled == false ? var.deployments : merge(var.deployments, {
  deployments = merge(var.deployments, {
    "celery-beat" = var.celery_beat_defaults
  }, {
    "celery-worker" = var.celery_worker_defaults
  }
  )

  database_url = coalesce(
    lookup(var.secret_env, "DATABASE_URL", null),
    lookup(var.env, "DATABASE_URL", null),
    module.gcp != [] ? module.gcp.0.database_url : null,
    module.postgresql != [] ? module.postgresql.0.database_url : null,
  )

  redis_url = coalesce(
    lookup(var.secret_env, "REDIS_URL", null),
    lookup(var.env, "REDIS_URL", null),
    module.redis != [] ? module.redis.0.redis_url : null,
  )

  database_url_map = regex("^(?:(?P<scheme>[^:/?#]+):)?(?://(?P<user>[^/?#:]*):(?P<password>[^/?#:]*)@(?P<hostname>[^/?#:]*):(?P<port>[0-9]*)/(?P<database>.*))?", local.database_url)

  env        = var.env
  secret_env = merge(var.secret_env, {
    "DATABASE_URL"      = local.database_url
    "REDIS_URL"         = local.redis_url
    CELERY_BROKER_URL   = local.redis_url
    "POSTGRES_USER"     = lookup(local.database_url_map, "user")
    "POSTGRES_PASSWORD" = lookup(local.database_url_map, "password")
    "POSTGRES_HOST"     = lookup(local.database_url_map, "hostname")
    "POSTGRES_DB"       = lookup(local.database_url_map, "database")
    "POSTGRES_PORT"     = lookup(local.database_url_map, "port")
  })

  common_labels = merge(
    {
      "app.kubernetes.io/part-of" : var.name
      "app.kubernetes.io/version" : var.image_tag
      "app.kubernetes.io/managed-by" : "terraform"
    },
    var.extra_labels,
  )

  ingress_annotations = merge(var.ingress_annotations, {
    "kubernetes.io/ingress.class"                       = "nginx"
    "nginx.ingress.kubernetes.io/tls-acme"              = "true"
    "nginx.ingress.kubernetes.io/ssl-redirect"          = "true"
    "nginx.ingress.kubernetes.io/proxy-body-size"       = "30m"
    "nginx.ingress.kubernetes.io/proxy-read-timeout"    = "180s"
    "nginx.ingress.kubernetes.io/proxy-write-timeout"   = "180s"
    "nginx.ingress.kubernetes.io/proxy-connect-timeout" = "180s"
    "cert-manager.io/cluster-issuer"                    = "letsencrypt-prod"
    "nginx.ingress.kubernetes.io/enable-cors" : "true"
    "nginx.ingress.kubernetes.io/cors-allow-methods" : "DELETE, GET, OPTIONS, PATCH, POST, PUT"
    "nginx.ingress.kubernetes.io/cors-allow-headers" : "accept, accept-encoding, accept-language, cache-control, authorization, content-type, dnt, origin, user-agent, x-csrftoken, x-requested-with",
    #    "nginx.ingress.kubernetes.io/cors-allow-origin" : "https://client.${local.domain},https://expert.${local.domain}, https://book.${local.domain}"
    "kubernetes.io/tls-acme" : "true"
  }
  )
}
