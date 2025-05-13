
# Full access to the namespace data path
path "sv4-dev/sv4-dev-ci/data/ci-apps" {
    capabilities = ["read", "write", "delete", "update", "list"]
}
path "sv4-dev/sv4-dev-ci" {
    capabilities = ["list"]
}


# List access for the site_id level
path "sv4-dev" {
    capabilities = ["list"]
}
