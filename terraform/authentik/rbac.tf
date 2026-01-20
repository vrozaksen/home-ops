## RBAC Configuration

# Role for LDAP service accounts that need full directory search
resource "authentik_rbac_role" "ldap-searcher" {
  name = "LDAP Directory Searcher"
}

# Grant the LDAP search permission to the role
resource "authentik_rbac_permission_role" "ldap-search" {
  role       = authentik_rbac_role.ldap-searcher.id
  permission = "authentik_providers_ldap.search_full_directory"
}

# Group for LDAP service accounts - has the searcher role
resource "authentik_group" "ldap-service-accounts" {
  name  = "LDAP Service Accounts"
  roles = [authentik_rbac_role.ldap-searcher.id]
}
