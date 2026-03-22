# Networking - VPC Infrastructure Modules

This directory contains five sub-modules that together build the complete network infrastructure for the project. They create a Virtual Private Cloud (VPC), subnets, an internet gateway, route tables, and security groups. Think of this as building the "roads and walls" of your cloud -- every other resource (EKS, databases, etc.) lives inside this network.

Each sub-module is designed to be reusable and is called from the root module at `root/dev/networking/`.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        VPC (vpc-module)                         │
│                     CIDR: 10.0.0.0/16                           │
│                                                                 │
│   ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐    │
│   │ Public       │  │ Public       │  │ Public              │    │
│   │ Subnet AZ-a  │  │ Subnet AZ-b  │  │ Subnet AZ-c         │    │
│   │ (EKS nodes)  │  │ (EKS nodes)  │  │ (EKS nodes)         │    │
│   └──────┬───────┘  └──────┬───────┘  └──────┬──────────┘    │
│          │                 │                 │               │
│          └────────┬────────┘                 │               │
│                   │   Public Route Table     │               │
│                   │   0.0.0.0/0 -> IGW       │               │
│                   └──────────┬───────────────┘               │
│                              │                               │
│                   ┌──────────┴──────────┐                    │
│                   │  Internet Gateway   │ (igw)              │
│                   │  Connects VPC to    │                    │
│                   │  the internet       │                    │
│                   └─────────────────────┘                    │
│                                                              │
│   ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│   │ Private      │  │ Private      │  │ Private             │ │
│   │ Subnet AZ-a  │  │ Subnet AZ-b  │  │ Subnet AZ-c        │ │
│   │ (Database)   │  │ (Database)   │  │ (Database)          │ │
│   └──────────────┘  └──────────────┘  └─────────────────────┘ │
│          Private Route Table (no internet route)              │
│                                                               │
│   Security Groups (security-group)                            │
│   ┌──────────────┐ ┌──────────────────┐ ┌────────────────┐   │
│   │ cluster-sg   │ │ worker-nodes-sg  │ │ database-sg    │   │
│   │ Port 443     │ │ Port 10250       │ │ Port 3306      │   │
│   │ (EKS API)    │ │ (Kubelet)        │ │ (MySQL)        │   │
│   └──────────────┘ └──────────────────┘ └────────────────┘   │
└───────────────────────────────────────────────────────────────┘
```

## Sub-Module Descriptions

### 1. `vpc-module/` - Virtual Private Cloud

Creates the VPC itself -- an isolated virtual network in AWS where all resources live.

| File | Purpose |
|------|---------|
| `vpc.tf` | Creates the VPC with DNS support and DNS hostnames enabled. Tags it with project name and environment. |
| `variables.tf` | Declares inputs: `vpc_cidr` (the IP range), `project_name`, and `environment`. |
| `outputs.tf` | Exposes `vpc_id`, `cidr_block`, and `ipv6_cidr_block` for other modules to use. |

**Inputs:**

| Variable | Type | Required | Description |
|----------|------|----------|-------------|
| `vpc_cidr` | `string` | Yes | The CIDR block for the VPC (e.g., `10.0.0.0/16`). Defines the IP address range. |
| `project_name` | `string` | Yes | Project name, used in tags. |
| `environment` | `string` | Yes | Environment name (e.g., `dev`), used in tags. |

**Outputs:**

| Output | Description |
|--------|-------------|
| `vpc_id` | The unique ID of the created VPC. Used by every other networking sub-module. |
| `cidr_block` | The CIDR block of the VPC. Used by security group rules to allow internal traffic. |
| `ipv6_cidr_block` | The IPv6 CIDR block of the VPC (if assigned). |

---

### 2. `subnets/` - Subnet Creation

Creates all subnets (both public and private) inside the VPC using a dynamic `for_each` map. This means you define your subnets as a variable and this module creates them all in one go.

| File | Purpose |
|------|---------|
| `subnets.tf` | Uses `for_each` to create subnets from the input map. Sets `map_public_ip_on_launch` for public subnets and tags each with `Type = public/private`. |
| `variables.tf` | Declares `vpc_id`, `environment`, and the `subnets` map (each entry has cidr, AZ, and public flag). |
| `outputs.tf` | Outputs a map of `subnet_name => subnet_id` used by route tables and other modules. |

**Inputs:**

| Variable | Type | Required | Description |
|----------|------|----------|-------------|
| `vpc_id` | `string` | Yes | VPC ID to create subnets in. Comes from `vpc-module`. |
| `environment` | `string` | Yes | Environment name for tagging. |
| `subnets` | `map(object)` | Yes | A map where each key is the subnet name and value has `cidr_block`, `availability_zone`, and `public` (bool). |

**Outputs:**

| Output | Description |
|--------|-------------|
| `subnet_ids` | A map of `subnet_name => subnet_id`. Used by route tables, EKS, and database modules. |

---

### 3. `igw/` - Internet Gateway

Creates an Internet Gateway that allows resources in public subnets to communicate with the internet.

| File | Purpose |
|------|---------|
| `igw.tf` | Creates the internet gateway and attaches it to the VPC. |
| `variable.tf` | Declares `vpc_id` and `environment`. |
| `outputs.tf` | Exposes the `igw_id` for route tables to reference. |

**Inputs:**

| Variable | Type | Required | Description |
|----------|------|----------|-------------|
| `vpc_id` | `string` | Yes | VPC ID to attach the gateway to. |
| `environment` | `string` | Yes | Environment name for tagging. |

**Outputs:**

| Output | Description |
|--------|-------------|
| `igw_id` | The Internet Gateway ID. Used by the route-tables module to create an internet route. |

---

### 4. `route-tables/` - Route Tables and Associations

Creates public and private route tables and associates the correct subnets to each. Public subnets get a route to the internet (via the IGW); private subnets do not.

| File | Purpose |
|------|---------|
| `route-tables.tf` | Creates a public route table (with `0.0.0.0/0 -> IGW` route) and a private route table (no internet route). Dynamically associates subnets based on the `public` flag in the subnets variable. |
| `variables.tf` | Declares `vpc_id`, `igw_id`, `subnet_ids` (map from subnets module), `subnets` (the same map used to create them), and `environment`. |

**Inputs:**

| Variable | Type | Required | Description |
|----------|------|----------|-------------|
| `vpc_id` | `string` | Yes | VPC ID for the route tables. |
| `igw_id` | `string` | Yes | Internet Gateway ID for the public route. |
| `subnet_ids` | `map(string)` | Yes | Map of subnet names to IDs (from subnets module output). |
| `subnets` | `map(object)` | Yes | The same subnet definition map, used to determine which are public vs private. |
| `environment` | `string` | Yes | Environment name for tagging. |

---

### 5. `security-group/` - Security Groups

A reusable module that creates a security group with dynamic ingress rules. Called multiple times from the root networking module to create `cluster-sg`, `worker-nodes-sg`, and `database-sg`.

| File | Purpose |
|------|---------|
| `security-group.tf` | Creates the security group, dynamic ingress rules (supporting both IPv4 and IPv6), and permissive egress rules (allow all outbound). |
| `variables.tf` | Declares `name`, `vpc_id`, `description`, `rules` (list of ingress rule objects), `tags`, and `environment`. |
| `outputs.tf` | Exposes the `security_group_id`. |

**Inputs:**

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `name` | `string` | Yes | - | Security group name. |
| `vpc_id` | `string` | Yes | - | VPC ID where the security group is created. |
| `description` | `string` | No | `"Managed by Terraform"` | Description of the security group. |
| `rules` | `list(object)` | No | `[]` | List of ingress rules. Each has `cidr`, `from_port`, `to_port`, optional `protocol` (default `tcp`), and optional `ip_version` (default `ipv4`). |
| `tags` | `map(string)` | No | `{}` | Additional tags. |
| `environment` | `string` | Yes | - | Environment name for tagging. |

**Outputs:**

| Output | Description |
|--------|-------------|
| `security_group_id` | The ID of the created security group. Referenced by EKS and database modules. |

## Dependency Chain

```
vpc-module          (no dependencies -- created first)
    │
    ├── subnets     (needs vpc_id)
    │       │
    │       └── route-tables  (needs vpc_id, igw_id, subnet_ids, subnets)
    │
    ├── igw         (needs vpc_id)
    │       │
    │       └── route-tables  (needs igw_id)
    │
    └── security-group  (needs vpc_id, called 3 times)
            │
            ├── cluster-sg       -> used by EKS cluster
            ├── worker-nodes-sg  -> used by EKS worker nodes
            └── database-sg      -> used by RDS database
```

## Usage Example

These modules are not called directly. They are orchestrated from `root/dev/networking/main.tf`:

```hcl
module "vpc" {
  source       = "../../../networking/vpc-module"
  vpc_cidr     = "10.0.0.0/16"
  project_name = "projectx"
  environment  = "dev"
}

module "subnets" {
  source      = "../../../networking/subnets"
  vpc_id      = module.vpc.vpc_id
  environment = "dev"
  subnets = {
    "public-1a"  = { cidr_block = "10.0.1.0/24",  availability_zone = "us-east-1a", public = true  }
    "public-1b"  = { cidr_block = "10.0.2.0/24",  availability_zone = "us-east-1b", public = true  }
    "private-1a" = { cidr_block = "10.0.10.0/24", availability_zone = "us-east-1a", public = false }
    "private-1b" = { cidr_block = "10.0.11.0/24", availability_zone = "us-east-1b", public = false }
  }
}

module "igw" {
  source      = "../../../networking/igw"
  vpc_id      = module.vpc.vpc_id
  environment = "dev"
}

module "route-tables" {
  source      = "../../../networking/route-tables"
  vpc_id      = module.vpc.vpc_id
  igw_id      = module.igw.igw_id
  subnets     = var.subnets
  subnet_ids  = module.subnets.subnet_ids
  environment = "dev"
}

module "cluster-sg" {
  source      = "../../../networking/security-group"
  name        = "cluster-sg"
  vpc_id      = module.vpc.vpc_id
  environment = "dev"
  rules = [
    { cidr = "10.0.0.0/16", from_port = 443, to_port = 443 }
  ]
}
```

## Key Concepts for Beginners

- **VPC (Virtual Private Cloud)**: Your own isolated network in AWS. Nothing can get in or out unless you explicitly allow it.
- **Subnets**: Subdivisions of your VPC. **Public subnets** have a route to the internet; **private subnets** do not.
- **CIDR Block**: A notation like `10.0.0.0/16` that defines an IP address range. The `/16` means the first 16 bits are fixed, giving you 65,536 addresses.
- **Internet Gateway (IGW)**: The "door" that connects your VPC to the public internet. Only public subnets route traffic through it.
- **Route Table**: A set of rules (routes) that tell network traffic where to go. Public subnets have a route `0.0.0.0/0 -> IGW` (all internet traffic goes through the gateway).
- **Security Group**: A virtual firewall for your resources. You define which ports and IP ranges are allowed in (ingress) and out (egress).
- **`for_each`**: A Terraform feature that creates multiple copies of a resource from a map or set. Used here to create many subnets and ingress rules from a single block of code.
