variable "vm_password" {
  description = "The shared password for the n0id3a user"
  type        = string
  sensitive   = true
}

###############################################
#Provider Setup
###############################################
terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.8.2"
    }
  }
}

# Connect to the local KVM daemon inside WSL2
provider "libvirt" {
  uri = "qemu:///system"
}

###############################################
#Networking
###############################################
#resource "libvirt_network" "k8s_net" {
#  name      = "k8s_network"
#  mode      = "nat" 
#  domain    = "k8s.local"
#  addresses = ["10.17.3.0/24"]
#  dhcp {
#    enabled = true
#  }
#}

###############################################
#Storage Pools
###############################################
resource "libvirt_pool" "master_pool" {
  name = "master_pool"
  type = "dir"
  path = "/mnt/s/kvm_master" 
}

resource "libvirt_pool" "worker_pool" {
  name = "worker_pool"
  type = "dir"
  path = "/mnt/h/kvm_worker"
}

###############################################
#The OS Images
###############################################
resource "libvirt_volume" "ubuntu_base_master" {
  name   = "ubuntu-base-master.qcow2"
  pool   = libvirt_pool.master_pool.name
  source = "https://cloud-images.ubuntu.com/releases/26.04/release/ubuntu-26.04-server-cloudimg-amd64.img"
  format = "qcow2"
}

resource "libvirt_volume" "ubuntu_base_worker" {
  name   = "ubuntu-base-worker.qcow2"
  pool   = libvirt_pool.worker_pool.name
  source = "https://cloud-images.ubuntu.com/releases/26.04/release/ubuntu-26.04-server-cloudimg-amd64.img"
  format = "qcow2"
}

###############################################
#The Actual Disks
###############################################
resource "libvirt_volume" "master_disk" {
  name           = "master-disk.qcow2"
  pool           = libvirt_pool.master_pool.name
  base_volume_id = libvirt_volume.ubuntu_base_master.id
  size           = 25 * 1024 * 1024 * 1024 # 25 GB
}

resource "libvirt_volume" "master_openebs_disk" {
  name   = "master-openebs-disk.qcow2"
  pool   = libvirt_pool.master_pool.name
  size   = 70 * 1024 * 1024 * 1024 # 70 GB
  format = "qcow2"
}

resource "libvirt_volume" "worker_disk" {
  name           = "worker-disk.qcow2"
  pool           = libvirt_pool.worker_pool.name
  base_volume_id = libvirt_volume.ubuntu_base_worker.id
  size           = 50 * 1024 * 1024 * 1024 # 50 GB
}

###############################################
#Bootstrapping
###############################################
resource "libvirt_cloudinit_disk" "commoninit_master" {
  name      = "commoninit_master.iso"
  pool      = libvirt_pool.master_pool.name
  user_data = templatefile("${path.module}/cloud_init.tftpl", {
    admin_password = var.vm_password
    hostname       = "master"
    pub_key        = file(pathexpand("~/.ssh/ansible.pub"))
  })
}

resource "libvirt_cloudinit_disk" "commoninit_worker" {
  name      = "commoninit_worker.iso"
  pool      = libvirt_pool.worker_pool.name
  user_data = templatefile("${path.module}/cloud_init.tftpl", {
    admin_password = var.vm_password
    hostname       = "worker"
    pub_key        = file(pathexpand("~/.ssh/ansible.pub"))
  })
}

###############################################
#The Virtual Machines
###############################################
# Master Node
resource "libvirt_domain" "k8s_master" {
  name   = "k8s-master"
  memory = "16384" # 16 GB
  vcpu   = 5       # 5 processors

  cloudinit = libvirt_cloudinit_disk.commoninit_master.id

  network_interface {
    network_name     = "k8s_network"
    addresses      = ["10.17.3.10"]
    wait_for_lease = true
  }

  # Primary Disk
  disk {
    volume_id = libvirt_volume.master_disk.id
  }

  # Secondary Disk
  disk {
    volume_id = libvirt_volume.master_openebs_disk.id
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }
}

# Worker Node
resource "libvirt_domain" "k8s_worker" {
  name   = "k8s-worker"
  memory = "16384" # 16 GB
  vcpu   = 5       # 5 processors

  cloudinit = libvirt_cloudinit_disk.commoninit_worker.id

  network_interface {
    network_name     = "k8s_network"
    addresses      = ["10.17.3.20"]
    wait_for_lease = true
  }

  # Primary Disk
  disk {
    volume_id = libvirt_volume.worker_disk.id
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }
}