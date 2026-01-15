# GitHub Actions Self-Hosted Runner LXC Containers
# These containers run GitHub Actions workflows for GitOps deployments

locals {
  github_runners = {
    github-runner-01 = {
      target_node = "node01"
      ip          = "192.168.40.50"
      description = "Primary GitHub Actions runner for homelab deployments"
    }
    github-runner-02 = {
      target_node = "node02"
      ip          = "192.168.40.51"
      description = "Secondary GitHub Actions runner for parallel workloads"
    }
  }
}

module "github_runners" {
  source   = "../modules/lxc"
  for_each = local.github_runners

  # Container Identification
  hostname     = each.key
  target_node  = each.value.target_node
  ostemplate   = "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
  unprivileged = false # Required for Docker-in-Docker

  # Resources - Sized for running GitHub Actions + Docker builds
  cores  = 4
  memory = 4096
  swap   = 1024

  # Storage
  storage   = "VMDisks"
  disk_size = "30G"

  # Network Configuration - VLAN 40 (Services)
  network_bridge = "vmbr0"
  vlan_tag       = 40
  ip_address     = each.value.ip
  subnet_mask    = 24
  gateway        = "192.168.40.1"
  nameserver     = "192.168.91.30"

  # SSH Keys
  ssh_keys = var.ssh_public_key

  # Container Behavior
  onboot = true
  start  = true

  # Features - Nesting required for Docker
  nesting = true
}

# Outputs for GitHub Runner containers
output "github_runner_summary" {
  description = "Summary of GitHub Actions runner containers"
  value = {
    for key, runner in module.github_runners : key => {
      hostname    = runner.hostname
      id          = runner.container_id
      ip          = runner.ip_address
      target_node = local.github_runners[key].target_node
    }
  }
}

output "github_runner_ips" {
  description = "Map of GitHub runner hostnames to IP addresses"
  value = {
    for key, runner in module.github_runners : runner.hostname => runner.ip_address
  }
}
