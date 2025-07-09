#!/usr/bin/python3.9
import hvac
import getpass
import os

# Function to check if a policy exists
# Function to create policy


def cluster_list(client,site_id):
    print(list)    


def policy_create(client, policy_name, site_id, clustername, namespace_name):
    """ Creates a new Vault policy if it doesn't exist """
    vault_policy = f"""
    # Full access to the namespace data path
    path "{site_id}/{clustername}/data/{namespace_name}" {{
        capabilities = ["read", "create", "delete", "update", "list"]
    }}

    # List access for the site_id level
    path "{site_id}" {{
        capabilities = ["list"]
    }}
    """

    client.sys.create_or_update_policy(name=policy_name, policy=vault_policy)
    print(f"Vault policy '{policy_name}' has been successfully created.")
    
def user_manage(client, policy_name):
    usernames = input("Enter usernames (comma-separated): ").strip().split(',')
    for ldap_user in usernames:
        ldap_user = ldap_user.strip()  # Ensure clean input
        user_policy_path = f"auth/ldap/users/{ldap_user}"

        # Read existing policies
        existing_policies = client.read(user_policy_path)

        if existing_policies and "policies" in existing_policies["data"]:
            current_policies = existing_policies["data"]["policies"]
            print(f"Current policies for {ldap_user}: {current_policies}")
        else:
            current_policies = []
            print(f"No existing policies found for {ldap_user}.")

    # Add new policy while preserving existing ones
        updated_policies = list(set(current_policies + [policy_name]))  # Ensure unique policies
        client.write(user_policy_path, policies=updated_policies)

# Main script execution
def main():
    # Prompt user for inputs

    username = input("Enter LDAP Username: ")
    password = getpass.getpass("Enter LDAP Password: ") 
    
    available_vault_urls = [ "https://vault.dev.e2open.com" , "https://vault.e2open.com" ]
    for i, url in enumerate(available_vault_urls, start=1):
        print(f"{i}. {url}")

    # Prompt user to select a site ID by index
    while True:
        try:
            url_index = int(input("Select URL (Enter number): "))
            if 1 <= url_index <= len(available_vault_urls):
                vault_url  = available_vault_urls[url_index - 1]
                break
            else:
                print("Invalid selection. Please choose a number from the list.")
        except ValueError:
            print("Invalid input. Please enter a number.")

    print(vault_url)
    if vault_url == "https://vault.dev.e2open.com":
       available_site_ids =  [ "in7-dev", "sv4-dev" ]
    else: 
       available_site_ids  = [ "sv4-stg",  "sv1-prod", "fr8-stg",  "fr8-prod", "de2-prod", "ac7-prod",  "b732-prod" ]
    print("Available Site IDs:")
    for i, site in enumerate(available_site_ids, start=1):
        print(f"{i}. {site}")

    # Prompt user to select a site ID by index
    while True:
        try:
            site_index = int(input("Select Site ID (Enter number): "))
            if 1 <= site_index <= len(available_site_ids):
                site_id = available_site_ids[site_index - 1]
                break
            else:
                print("Invalid selection. Please choose a number from the list.")
        except ValueError:
            print("Invalid input. Please enter a number.")

    print(site_id)
    search_string = site_id + "/" 
    # Initialize Vault client
    # Initialize Vault client
    client = hvac.Client(url=vault_url)

    # Authenticate using LDAP
    auth_response = client.auth.ldap.login(
        username=username,
        password=password
    )   
    if auth_response and client.is_authenticated():
        print(f"Successfully authenticated as {username} using LDAP!")
    else:
        print("Vault LDAP authentication failed. Please check your credentials.")
    
    auth_methods_response = client.sys.list_auth_methods()
    enabled_methods = auth_methods_response['data']

    print("List of Clusters:")
    print("=" * 30)

    if not enabled_methods:
       print("No authentication methods are enabled.")
       return



    for path, details in enabled_methods.items():
        # Search case-insensitively if the term is in the path name
        if search_string in path.lower():
           found_match = True
           print(f"Path:          {path}")
           print("-" * 20)


    clustername = input("Enter Cluster Name: ")
    
    auth_path = (search_string + clustername)
#    print(auth_path)
#    mount_point = "platform/infrastructure/" + auth_path
#    secret_path = input("Enter the path to list within the mount (e.g., 'dev/database', or leave blank for root): ").strip()
    roles = client.secrets.auth_path.list_roles()

    print(f"\nAttempting to list secrets {roles}'...")
    print("=" * 30)

    namespace_name = input("Enter Namespace Name: ")

    policy_name = f"userpolicy-{site_id}-{clustername}-{namespace_name}"


    # Check if policy already exists
    try:
        existing_policy = client.sys.read_policy(policy_name)
    except hvac.exceptions.InvalidPath:
        print(f"Policy '{policy_name}' not found. Proceeding with creation...")
        policy_create(client, policy_name, site_id, clustername, namespace_name)
    user_manage(client, policy_name)

  
if __name__ == "__main__":
    main()







