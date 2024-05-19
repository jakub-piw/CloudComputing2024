terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.51.0"
    }
  }
}

provider "google" {
  project = var.project
  region  = var.region
  zone    = var.zone
}

data "google_project" "project" {}

##############
# Service Account permissions
##############

## necessary for the Cloud Build service account to deploy to Cloud Run

# resource "google_project_iam_member" "cloud_build_run_admin" {
#   project = var.project
#   member  = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
#   role    = "roles/run.admin"
# }

# resource "google_project_iam_member" "cloud_build_sa_user" {
#   project = var.project
#   member  = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
#   role    = "roles/iam.serviceAccountUser"
# }

##############
# BigQuery
##############

# resource "google_bigquery_dataset" "meteo_dataset" {
#   dataset_id = "meteo_dataset"
#   location   = var.location
# }

# resource "google_bigquery_table" "gefs" {
#   dataset_id          = google_bigquery_dataset.meteo_dataset.dataset_id
#   table_id            = "gefs"
#   deletion_protection = false
#   schema              = <<EOF
# [
#   {
#     "name": "time",
#     "type": "TIMESTAMP",
#     "mode": "NULLABLE"
#   },
#   {
#     "name": "valid_time",
#     "type": "TIMESTAMP",
#     "mode": "NULLABLE"
#   },
#   {
#     "name": "latitude",
#     "type": "FLOAT",
#     "mode": "NULLABLE"
#   },
#   {
#     "name": "longitude",
#     "type": "FLOAT",
#     "mode": "NULLABLE"
#   },
#   {
#     "name": "u10",
#     "type": "FLOAT",
#     "mode": "NULLABLE"
#   },
#   {
#     "name": "v10",
#     "type": "FLOAT",
#     "mode": "NULLABLE"
#   },
#   {
#     "name": "tp",
#     "type": "FLOAT",
#     "mode": "NULLABLE"
#   },
#   {
#     "name": "tcc",
#     "type": "FLOAT",
#     "mode": "NULLABLE"
#   },
#   {
#     "name": "t2m",
#     "type": "FLOAT",
#     "mode": "NULLABLE"
#   },
#   {
#     "name": "gh",
#     "type": "FLOAT",
#     "mode": "NULLABLE"
#   },
#   {
#     "name": "h",
#     "type": "FLOAT",
#     "mode": "NULLABLE"
#   }
# ]
# EOF

#   time_partitioning {
#     type  = "DAY"
#     field = "time"
#   }
# }

##############
# Bucket
##############

# resource "google_storage_bucket" "meteo_bucket" {
#   name                        = "meteo_bucket_${var.project}"
#   location                    = var.location
#   storage_class               = "STANDARD"
#   uniform_bucket_level_access = true
#   force_destroy               = true
# }

##############
# CloudSQL
##############

# resource "google_sql_database_instance" "database_instance" {
#   name             = "database"
#   region           = var.region
#   database_version = "MYSQL_8_0"
#   settings {
#     tier = "db-f1-micro"
#   }

#   deletion_protection  = false
# }

# resource "google_sql_database" "users_database" {
#   name     = "users_database"
#   instance = google_sql_database_instance.database_instance.name
# }


##############
# CloudRun - streamlit
##############

# resource "null_resource" "build_streamlit_app_docker_image" {
#   provisioner "local-exec" {
#     command = "cd app && gcloud builds submit --region=${var.region} --tag gcr.io/${var.project}/streamlit-app:latest"
#   }
# }

# resource "google_cloud_run_v2_service" "streamlit_app" {
#   name     = "streamlit-app"
#   project  = var.project
#   location = var.region
#   ingress  = "INGRESS_TRAFFIC_ALL"

#   template {
#     containers {
#       image   = "gcr.io/${var.project}/streamlit-app:latest"
#       command = ["python"]
#       args    = ["-m", "streamlit", "run", "app.py", "--server.port", "8080"]
#     }
#   }
#   depends_on = [ null_resource.build_streamlit_app_docker_image ]
# }

# data "google_iam_policy" "noauth" {
#   binding {
#     role    = "roles/run.invoker"
#     members = ["allUsers"]
#   }
# }

# resource "google_cloud_run_service_iam_policy" "noauth_streamlit" {
#   location    = var.region
#   project     = var.project
#   service     = google_cloud_run_v2_service.streamlit_app.name
#   policy_data = data.google_iam_policy.noauth.policy_data
# }

## required for Continuous Deployment

# resource "google_sourcerepo_repository" "streamlit_repo" {
#   name = "streamlit_repo"
# }

# resource "google_cloudbuild_trigger" "streamlit_docker_build" {
#   trigger_template {
#     branch_name = "master"
#     repo_name   = google_sourcerepo_repository.streamlit_repo.name
#   }

#   build {
#     step {
#       name = "gcr.io/cloud-builders/docker"
#       args = ["build", "-t", "gcr.io/${var.project}/streamlit-app:latest", "."]
#     }

#     step {
#       name = "gcr.io/cloud-builders/docker"
#       args = ["push", "gcr.io/${var.project}/streamlit-app:latest"]
#     }

#     step {
#       name = "gcr.io/cloud-builders/gcloud"
#       args = [
#         "run", "deploy", google_cloud_run_v2_service.streamlit_app.name,
#         "--image", "gcr.io/${var.project}/streamlit-app:latest",
#         "--no-cpu-boost",
#         "--region", var.region,
#         "--project", var.project,
#       ]
#     }
#   }
# }

# resource "null_resource" "clone_streamlit_repo" {
#   provisioner "local-exec" {
#     command = <<EOT
#       gcloud source repos clone ${google_sourcerepo_repository.streamlit_repo.name} --project=${var.project}
#       EOT
#   }
#   depends_on = [google_sourcerepo_repository.streamlit_repo]
# }

##############
# CloudRun - api
##############

# resource "google_cloud_run_v2_service" "api" {
#   name     = "api"
#   project = var.project
#   location = "us-central1"

#   template {
#     containers {
#       image = "gcr.io/cloudrun/hello"
#     }
#   }
# }

# resource "google_cloud_run_service_iam_policy" "noauth_api" {
#   location = "us-central1"
#   project  = var.project
#   service  = google_cloud_run_v2_service.api.name

#   policy_data = data.google_iam_policy.noauth.policy_data
# }
