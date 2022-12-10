

resource "google_cloud_run_service" "default" {
  name     = var.name
  location = var.location
  template {
    spec {
      containers {
        image = var.image
        resources {
          limits = {
            cpu : "1"
            memory : "512Mi"
          }
          requests = {
            cpu : "1"
            memory : "512Mi"
          }
        }
        ports {
          container_port = var.port
        }
      }
      container_concurrency = var.max-concurrency
    }
    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale"  = var.max-instances
        "autoscaling.knative.dev/minScale"  = var.min-instances
        "run.googleapis.com/cpu-throttling" = var.cpu-throttling
      }
      labels = var.labels
    }
  }
  metadata {
    annotations = {
      "run.googleapis.com/ingress" = "internal-and-cloud-load-balancing"
    }
  }
  traffic {
    percent         = 100
    latest_revision = true
  }
  autogenerate_revision_name = true
}

resource "google_cloud_run_service_iam_binding" "default" {
  location = google_cloud_run_service.default.location
  project  = google_cloud_run_service.default.project
  service  = google_cloud_run_service.default.name
  role     = "roles/run.invoker"
  members  = ["allUsers"]
}

resource "google_compute_region_network_endpoint_group" "default" {
  name                  = "${var.name}-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.location
  cloud_run {
    service = google_cloud_run_service.default.name
  }
}


resource "google_compute_backend_service" "default" {
  name        = "${var.name}-service"
  protocol    = "HTTP"
  port_name   = "http"
  timeout_sec = 30
  backend {
    group = google_compute_region_network_endpoint_group.default.id
  }
}
