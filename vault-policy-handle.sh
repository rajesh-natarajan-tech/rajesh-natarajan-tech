#!/bin/bash

# Prompt for Vault address, username, and password

read -p "Username (PROD AD USER): " VAULT_USER
read -s -p "Password: " VAULT_PASS
echo ""

vault_urls=("https://vault.dev.e2open.com" "https://vault.e2open.com")

echo "Select Vault URL:"
select selected_url in "${vault_urls[@]}"; do
    if [[ -n "$selected_url" ]]; then
        VAULT_ADDR="$selected_url"
        break
    else
        echo "Invalid selection."
    fi
done


# Attempt to login to Vault using userpass method
LOGIN_RESPONSE=$(curl -s --request POST \
    --data "{\"password\": \"$VAULT_PASS\"}" \
    "$VAULT_ADDR/v1/auth/ldap/login/$VAULT_USER")

# Extract token using jq (JSON parser)
VAULT_TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r .auth.client_token)

if [ "$VAULT_TOKEN" != "null" ]; then
    echo "Login successful!"
    echo "Vault Token: $VAULT_TOKEN"
    # Optionally export token for future use
    export VAULT_TOKEN
else
    echo "Login failed. Please check your credentials."
fi

if [[ $VAULT_ADDR == "https://vault.dev.e2open.com" ]] ;then
    echo "You are using the DEV Vault instance."
    site_ids=("in7-dev" "sv4-dev")
    echo "Select site_id:"
    select site_id in "${site_ids[@]}"; do
        if [[ -n "$site_id" ]]; then
            site_id="${site_id}"
            echo "Listing clusters from the Site ID: $site_id"
            vault auth list  |grep $site_id |awk '{print $1}' 

            read -p "Enter the cluster name: " CLUSTER_NAME
            echo "Namespaces List for the cluster: $CLUSTER_NAME" 
            vault kv list platform/infrastructure/"$site_id"/"$CLUSTER_NAME"
            read -p "Enter the namespace: " NAMESPACE
            read -p "List the user list for the namespace access: (comma separated) " USER_LIST
            for user in $(echo $USER_LIST | tr "," "\n")
            do
            echo "reading the existing policy for the user: $user"
            vault 
            read -p "Enter the cluster name: " CLUSTER_NAME
         
            else
            echo "Invalid selection."
        fi
    done


fi

elif [ $VAULT_ADDR == "https://vault.e2open.com" ]; then
 
 if [[ $VAULT_ADDR == "https://vault.dev.e2open.com" ]] ;then
    echo "You are using the DEV Vault instance."
    site_ids=("sv4s" "sv1p" "fr8s" "fr8p")
    echo "Select site_id:"
    select site_id in "${site_ids[@]}"; do
        if [[ -n "$site_id" ]]; then
            site_id="${site_id}"
            else
            echo "Invalid selection."
        fi
    done
fi
else
    echo "Unknown Vault instance."
fi
