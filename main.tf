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
# APIs
##############

resource "google_project_service" "dataproc" {
 project = var.project
 service = "dataproc.googleapis.com"
}

resource "google_project_service" "cloudscheduler" {
  project = var.project
  service = "cloudscheduler.googleapis.com"
}

##############
# Service Accounts & permissions
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

## Dataproc & Cloud Scheduler service account

resource "google_service_account" "scheduler_service_account" {
  account_id   = "scheduler-service-account"
  display_name = "Scheduler Service Account"
}

resource "google_project_iam_custom_role" "dataproc_runner_role" {
  role_id = "dataprocWorkflowTemplateInstantiator"
  title   = "Dataproc Workflow Template Instantiator"
  permissions = [
    "dataproc.workflowTemplates.instantiate",
    "iam.serviceAccounts.actAs"
  ]
  project = var.project
}

resource "google_project_iam_member" "dataproc_scheduler" {
  project = var.project
  role    = google_project_iam_custom_role.dataproc_runner_role.name
  member  = "serviceAccount:${google_service_account.scheduler_service_account.email}"
}

##############
# Buckets
##############

# resource "google_storage_bucket" "meteo_bucket" {
#   name                        = "meteo_bucket_${var.project}"
#   location                    = var.location
#   storage_class               = "STANDARD"
#   uniform_bucket_level_access = true
#   force_destroy               = true
# }

resource "google_storage_bucket" "meteoetl_bucket" {
  name                        = "meteoetl-bucket"
  location                    = var.location
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  force_destroy               = true
}

resource "google_storage_bucket_object" "update_gefs_script" {
  name   = "update_gefs.py"
  bucket = google_storage_bucket.meteoetl_bucket.name
  source = "scripts/python/update_gefs.py"
}

##############
# BigQuery
##############

resource "google_bigquery_dataset" "meteo_dataset" {
  dataset_id = "meteo_dataset"
  location   = var.location
}

resource "google_bigquery_table" "gefs" {
  dataset_id          = google_bigquery_dataset.meteo_dataset.dataset_id
  table_id            = "gefs"
  deletion_protection = false
  schema              = <<EOF
[
  {
    "name": "time",
    "type": "TIMESTAMP",
    "mode": "NULLABLE"
  },
  {
    "name": "valid_time",
    "type": "TIMESTAMP",
    "mode": "NULLABLE"
  },
  {
    "name": "latitude",
    "type": "FLOAT",
    "mode": "NULLABLE"
  },
  {
    "name": "longitude",
    "type": "FLOAT",
    "mode": "NULLABLE"
  },
  {
    "name": "number",
    "type": "INT64",
    "mode": "NULLABLE"
  },
  {
    "name": "u10",
    "type": "FLOAT",
    "mode": "NULLABLE"
  },
  {
    "name": "v10",
    "type": "FLOAT",
    "mode": "NULLABLE"
  },
  {
    "name": "tp",
    "type": "FLOAT",
    "mode": "NULLABLE"
  },
  {
    "name": "tcc",
    "type": "FLOAT",
    "mode": "NULLABLE"
  },
  {
    "name": "t2m",
    "type": "FLOAT",
    "mode": "NULLABLE"
  },
  {
    "name": "prmsl",
    "type": "FLOAT",
    "mode": "NULLABLE"
  }
]
EOF

  time_partitioning {
    type  = "DAY"
    field = "time"
  }
}

##############
# Dataproc
##############

resource "google_dataproc_workflow_template" "meteoetl_template" {
  name     = "meteoetl-template"
  location = var.region
  placement {
    managed_cluster {
      cluster_name = "meteoetl-cluster"
      config {
        gce_cluster_config {
          internal_ip_only = false
          zone             = var.zone
        }
        master_config {
          num_instances = 1
          machine_type  = "n1-standard-2"
          disk_config {
            boot_disk_size_gb = 30
          }
        }
        worker_config {
          num_instances = 2
          machine_type  = "n1-standard-2"
          disk_config {
            boot_disk_size_gb = 30
          }
        }
        software_config {
          image_version = "2.2.16-debian12"
          properties = {
            "dataproc:pip.packages"   = "pandas-gbq==0.23.0"
            "dataproc:conda.packages" = "cfgrib==0.9.11.0"
          }
        }
      }
    }
  }
  jobs {
    step_id = "update-gefs-job"
    pyspark_job {
      main_python_file_uri = "gs://${google_storage_bucket.meteoetl_bucket.name}/${google_storage_bucket_object.update_gefs_script.name}"
    }
  }
}

##############
# Scheduler
##############

resource "google_cloud_scheduler_job" "meteoetl_job" {
  name        = "meteoetl-job"
  description = "Triggers the Dataproc Meteo ETL workflow template every day at 10 AM"
  schedule    = "0 10 * * *"
  time_zone   = "UTC"

  http_target {
    http_method = "POST"
    uri         = "https://dataproc.googleapis.com/v1/projects/${var.project}/regions/${var.region}/workflowTemplates/${google_dataproc_workflow_template.meteoetl_template.name}:instantiate?alt=json"
    oauth_token {
      service_account_email = google_service_account.scheduler_service_account.email
    }
  }
}

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

resource "null_resource" "build_streamlit_app_docker_image" {
  provisioner "local-exec" {
    command = "cd app && gcloud builds submit --region=${var.region} --tag gcr.io/${var.project}/streamlit-app:latest"
  }
}

resource "google_cloud_run_v2_service" "streamlit_app" {
  name     = "streamlit-app"
  project  = var.project
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    containers {
      image   = "gcr.io/${var.project}/streamlit-app:latest"
      command = ["python"]
      args    = ["-m", "streamlit", "run", "app.py", "--server.port", "8080"]
    }
  }
  depends_on = [ null_resource.build_streamlit_app_docker_image ]
}

data "google_iam_policy" "noauth" {
  binding {
    role    = "roles/run.invoker"
    members = ["allUsers"]
  }
}

resource "google_cloud_run_service_iam_policy" "noauth_streamlit" {
  location    = var.region
  project     = var.project
  service     = google_cloud_run_v2_service.streamlit_app.name
  policy_data = data.google_iam_policy.noauth.policy_data
}

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
