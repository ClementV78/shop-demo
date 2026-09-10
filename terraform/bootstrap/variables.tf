variable "aws_region" {
  description = "Region AWS principale. Toutes les ressources regionales du projet y sont creees."
  type        = string
  default     = "eu-west-1"

  validation {
    condition     = startswith(var.aws_region, "eu-")
    error_message = "La region doit etre europeenne, par coherence avec la SCP deny-regions-outside-eu livree en S2-T4."
  }
}

variable "project" {
  description = "Nom du projet, utilise comme prefixe de nommage et comme valeur du tag Project."
  type        = string
  default     = "shopdemo"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,20}$", var.project))
    error_message = "Le nom de projet doit etre en minuscules, chiffres et tirets, entre 3 et 21 caracteres, contrainte compatible avec le nommage des buckets S3."
  }
}

variable "environment" {
  description = "Environnement porte par ce state. Le state bootstrap est permanent, contrairement au state workload."
  type        = string
  default     = "bootstrap"

  validation {
    condition     = contains(["bootstrap", "staging", "prod", "sandbox"], var.environment)
    error_message = "Environnement inconnu. Valeurs attendues : bootstrap, staging, prod, sandbox."
  }
}

variable "owner" {
  description = "Valeur du tag Owner. Volontairement generique : aucune information personnelle ne doit etre versionnee."
  type        = string
  default     = "shopdemo"
}

variable "aws_account_id" {
  description = "Identifiant du compte management. Volontairement sans valeur par defaut : il n'est jamais versionne et doit etre fourni par un terraform.tfvars local."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "Un identifiant de compte AWS compte exactement douze chiffres."
  }
}

variable "aws_profile" {
  description = "Profil AWS CLI a utiliser. Laisser null pour s'en remettre a la variable d'environnement AWS_PROFILE."
  type        = string
  default     = null
}
