#!/bin/bash
username = input("Enter PROD AD Username: ")
password = getpass.getpass("Enter PROD Password: ")

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
print(auth_path)
mount_point = auth_path
secret_path = input("Enter the path to list within the mount (e.g., 'dev/database', or leave blank for root): ").strip()

print(f"\nAttempting to list secrets at '{mount_point}/{secret_path}'...")
print("=" * 30)

    # 3. Automatically detect the KV engine version
    # This is the most reliable way to handle both v1 and v2
try:
    mount_config = client.sys.read_mount_configuration(path=mount_point)
    version = mount_config['data']['options'].get('version')
    if not version:
        # If version option is not set, it's a v1 engine
        version = '1'
    print(f"Detected KV Version: {version}")
except InvalidPath:
    print(f"Error: The mount point '{mount_point}' does not exist.")
    return

    # 4. Use the correct hvac client based on the detected version
if version == '2':
    list_method = client.secrets.kv.v2.list_secrets
elif version == '1':
    list_method = client.secrets.kv.v1.list_secrets
else:
    print(f"Error: Unknown KV version '{version}' detected for mount '{mount_point}'.")
    return

    # 5. Call the list method and process the response
response = list_method(path=secret_path, mount_point=mount_point)
key_list = response.get('data', {}).get('keys', [])

if not key_list:
    print(f"No secrets or sub-paths found at '{mount_point}/{secret_path}'.")
else:
    print(f"Found the following items:")
    for key in key_list:
        if key.endswith('/'):
            print(f"  - {key}  (sub-path/folder)")
        else:
            print(f"  - {key}  (secret)")

namespace_name = input("Enter Namespace Name: ")

policy_name = f"userpolicy-{site_id}-{clustername}-{namespace_name}"


# Check if policy already exists
try:
    existing_policy = client.sys.read_policy(policy_name)
except hvac.exceptions.InvalidPath:
    print(f"Policy '{policy_name}' not found. Proceeding with creation...")
    policy_create(client, policy_name, site_id, clustername, namespace_name)
user_manage(client, policy_name)
