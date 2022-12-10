resource "google_compute_url_map" "default" {
  name            = "url-map"
  default_service = var.default_service_id


  host_rule {
    hosts        = var.hosts
    path_matcher = "allpaths"
  }

  path_matcher {
    name            = "allpaths"
    default_service = var.default_service_id
    dynamic "path_rule" {
      for_each = var.services
      content {
        paths   = [path_rule.key, "${path_rule.key}/*"]
        service = path_rule.value
        route_action {
          url_rewrite {
            path_prefix_rewrite = "/"
          }
        }
      }
    }
  }
}

resource "google_compute_url_map" "https_redirect" {
  name = "https-redirect-url-map"
  default_url_redirect {
    strip_query            = false
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
  }
}

resource "google_compute_target_http_proxy" "https_redirect" {
  name    = "http-proxy"
  url_map = google_compute_url_map.https_redirect.id
}

resource "google_compute_target_https_proxy" "default" {
  name             = "https-proxy"
  url_map          = google_compute_url_map.default.id
  ssl_certificates = [google_compute_managed_ssl_certificate.default.id]
}

resource "google_compute_managed_ssl_certificate" "default" {
  name = "default-cert"
  managed {
    domains = var.hosts
  }
}

resource "google_compute_global_forwarding_rule" "https_redirect" {
  name       = "https-redirect-forwarding-rule"
  target     = google_compute_target_http_proxy.https_redirect.id
  port_range = "80"
  ip_address = google_compute_global_address.default.address
}

resource "google_compute_global_forwarding_rule" "ssl-forward" {
  name       = "global-lb"
  target     = google_compute_target_https_proxy.default.id
  port_range = "443"
  ip_address = google_compute_global_address.default.address
}


resource "google_compute_global_address" "default" {
  name = "global-address"
}