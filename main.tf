resource "random_id" "project" {
  keepers = {
    # Generate a new id each time we switch to a new AMI id
    proj_id = var.proj_id
  }

  byte_length = 8
}


data "google_billing_account" "acct" {
  display_name = "My Billing Account"
  open         = true
}

resource "google_project" "node-red" {
  name       = "node-red host project"
  project_id = "node-red-host-${random_id.project.hex}"
  billing_account = data.google_billing_account.acct.id
}

resource "google_project_service" "project" {
  project = google_project.node-red.project_id
  service = "compute.googleapis.com"

  disable_dependent_services = true
}

data "template_file" "cloud-config" {
  template = file("cloud-config.yml")

  vars = {
    image       = "nodered/node-red:latest"
  }
}

resource "google_compute_instance" "vm" {
  name         = "node-red-vm"
  project = google_project.node-red.project_id
  machine_type = "f1-micro"
  zone         = "us-east1-b"


  boot_disk {
    initialize_params {
      type  = "pd-standard"
      image = "projects/cos-cloud/global/images/family/cos-stable"
      size  = var.boot_disk_size
    }
  }

  network_interface {
    network = "default"
    access_config {
      // Ephemeral IP
    }
  }

  metadata = {
    user-data                 = data.template_file.cloud-config.rendered
    #google-logging-enabled    = true
    #google-monitoring-enabled = true
  }
}

resource "google_compute_firewall" "node-red" {
  name    = "allow-node-red-traffic"
  project = google_project.node-red.project_id
  network = "default"

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "tcp"
    ports    = ["1880"]
  }
}