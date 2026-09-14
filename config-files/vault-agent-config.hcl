pid_file = "./pidfile"

auto_auth {
  method "token" {
    config = {
      token = "root" # Uses the root token defined in your compose environment
    }
  }
}

# Vault Agent fetches secrets and renders them into an environment file
template {
  contents = <<EOF
POSTGRES_USER={{ with secret "secret/data/db" }}{{ .Data.data.username }}{{ end }}
POSTGRES_PASSWORD={{ with secret "secret/data/db" }}{{ .Data.data.password }}{{ end }}
KC_DB_USERNAME={{ with secret "secret/data/db" }}{{ .Data.data.username }}{{ end }}
KC_DB_PASSWORD={{ with secret "secret/data/db" }}{{ .Data.data.password }}{{ end }}
KEYCLOAK_ADMIN={{ with secret "secret/data/keycloak" }}{{ .Data.data.admin_user }}{{ end }}
KEYCLOAK_ADMIN_PASSWORD={{ with secret "secret/data/keycloak" }}{{ .Data.data.admin_password }}{{ end }}
EOF
  destination = "/env/secrets.env"
}