# Hermes Homelab Infrastructure Technical Documentation 

<craft a foreword based on my blog , make it hearfelt, specify that computers are better than humands coz they follow you, they dont argue with you and you specify what you want and they will deliver, expound this further>

## Changelog

## Table of Contents

## Infrastructure Overview

## Summary of Services deployed,  Proxmox nodes , Storage and Network Setup 


###  Network Setup 
    <get the inventory of my Omada devices, the model of switches,  eaps and gateways, document the network topology , get all the vlans and ssids and explain what each vlan is for. specify instructions on how to configure vlans and ssids. document the gatewway ,dns configurations and expound further. document my tailscale setup as well andh how I can reach my homelab from outside my network>

### Storage Setup 
    < get the specs of my synology nas , document the drive storage sizes, SHR configuraration , SSD cache configuration, specify and document the NFS shares i have and the permissions needed inorder for proxmox to access those NFS share in the storage level>

### Compute Setup 
    < document what is proxmox, where to get proxmox, how to install proxmox and the configuraiton of proxmox in my environment. I want you to explain in detail how and what each configuration does, document how to disable subnscription notification, enable non prod subscriptions and whats the purpose of that, how to add a node, how to cleanup and remove a node, how to add storage, templates, document how to  create a ubuntu template, how to setup cloudinit , how to change dns, vlan tagging confiugration and other network related proxmox stuff based on my environment. For all commands executed , I wnat you to explain in detail what that commands does , explain what each parameter does and any arguments. 
    
    Then document the nodes that I have, specify the specs, how many memory , cpu, storage each node has. sepcify the usecase of the nodes based on the current vm, lxc distribution. Also explain the difference between LCX, VMs and docker contianers and how they are being used in my ecosystem. specify and document helpful commands for proxmox like creating vms, lxcs, adding/removing a node, adding nfs shared on the proxmox nodes and connecting to the synology nas. >


## Services
   Go through all my deployed services one by one, check the arr suites, and all vms/lxcs running and document what are the services in there and how are they configured. I want you to also document the dependencies and how they are all interelated to each other. document the terraform codes if any, ansible codes and all ymal files that makes that service run. I want you to create a visual connecting the service to all its dependencies for example Traekic->Authentik->Pihole->Jellyfin and document where does dependencies are hosted. Follow this format for the service 

   ##Service Name
    What is this service. What does it do and where to download it.

    How is it configured. 
        explain all the codes, docker compose files and how to to run the docker compose if I were to redeploy this from scratch. Document the IP address, urls , api used for each service.

    
    Do that for all serviices running on my environment. 


## Observability 

Explain my Glance Dashboard. How it was configured. GO through each page and explain all the apis written to make the dashboard work. explain the dependencies, where it gets the data and how it gets the data. Explain in detail the prometheus , omada exporter and other export apis/jobs being ran to get the data. explain them in full deatail. 

## Backup 
explain how PBS was configured. the setup , how disks are organized 


## Discord Bots
Explain my discord bot architecture, all codes writteen , dependences, how they are configured and all technicalities. explain how to redeploy the bots if I were to create them from scratch. 


Add other information , documentation as you see fit based on what you know of my homelab. 