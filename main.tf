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
    "name": "gh",
    "type": "FLOAT",
    "mode": "NULLABLE"
  },
  {
    "name": "h",
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
# Bucket
##############

resource "google_storage_bucket" "meteo_bucket" {
  name                        = "meteo_bucket_${var.project}"
  location                    = var.location
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  force_destroy               = true
}

##############
# CloudSQL
##############

resource "google_sql_database_instance" "database_instance" {
  name             = "database"
  region           = var.region
  database_version = "MYSQL_8_0"
  settings {
    tier = "db-f1-micro"
  }

  deletion_protection  = false
}

resource "google_sql_database" "users_database" {
  name     = "users_database"
  instance = google_sql_database_instance.database_instance.name
}


##############
# CloudRun - streamlit
##############

resource "google_cloud_run_v2_service" "streamlit_app" {
  name     = "streamlitapp"
  project = var.project
  location = "us-central1"

  template {
    containers {
      image = "gcr.io/cloudrun/hello"
    }
  }
}

data "google_iam_policy" "noauth" {
  binding {
    role    = "roles/run.invoker"
    members = ["allUsers"]
  }
}

resource "google_cloud_run_service_iam_policy" "noauth_streamlit" {
  location = "us-central1"
  project  = var.project
  service  = google_cloud_run_v2_service.streamlit_app.name

  policy_data = data.google_iam_policy.noauth.policy_data
}

##############
# CloudRun - api
##############

resource "google_cloud_run_v2_service" "api" {
  name     = "api"
  project = var.project
  location = "us-central1"

  template {
    containers {
      image = "gcr.io/cloudrun/hello"
    }
  }
}

resource "google_cloud_run_service_iam_policy" "noauth_api" {
  location = "us-central1"
  project  = var.project
  service  = google_cloud_run_v2_service.api.name

  policy_data = data.google_iam_policy.noauth.policy_data
}
