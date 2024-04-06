terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.51.0"
    }
  }
}

provider "google" {
  project = "cloud-computing-2024-419513"
}

resource "google_bigquery_dataset" "meteo_dataset" {
  dataset_id    = "meteo_dataset"
  friendly_name = "Meteo Dataset"
  description   = "Dataset for meteo purposes"
  location      = "EU"
}

resource "google_bigquery_table" "gefs" {
  dataset_id = google_bigquery_dataset.meteo_dataset.dataset_id
  table_id   = "gefs"
  deletion_protection = false
  schema = <<EOF
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
    type   = "DAY"
    field  = "time"
  }
}

resource "google_storage_bucket" "meteo_bucket" {
  name          = "meteo_bucket"
  location      = "EU"
  storage_class = "STANDARD"
  uniform_bucket_level_access = true
  force_destroy = true
}

resource "google_sql_database_instance" "database" {
  name             = "database"
  region           = "europe-west1"
  database_version = "MYSQL_8_0"
  settings {
    tier = "db-f1-micro"
  }

  deletion_protection  = "false"
}

resource "google_sql_database" "users_database" {
  name     = "users_database"
  instance = google_sql_database_instance.database.name
}

resource "google_sql_user" "users" {
  name     = "root"
  instance = google_sql_database_instance.database.name
  password = "root123"
}

resource "google_sql_database_instance" "user_table" {
  name             = "user_table"
  region           = "europe-west1"
  database_version = "MYSQL_8_0"

  depends_on = [google_sql_database_instance.database]

  settings {
    tier = "db-f1-micro"
  }

  provisioner "remote-exec" {
    inline = [
      "mysql --user=root --password=root123 --host=${google_sql_database_instance.database.ip_address} --execute='CREATE TABLE users (id INT AUTO_INCREMENT PRIMARY KEY, username VARCHAR(255) NOT NULL, password VARCHAR(255) NOT NULL, email VARCHAR(255) NOT NULL)'"
    ]
  }
}

# resource "google_app_engine_application" "app" {
#   project     = "cloud-computing-2024-419513"
#   location_id = "europe-west1"
# }
