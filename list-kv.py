import os
import hvac
from hvac.exceptions import InvalidPath, Forbidden, VaultError

def list_secrets_in_vault(mount_point: str, secret_path: str):
    """
    Connects to Vault and lists secrets at a specific mount and path,
    automatically handling KV v1 vs v2.

    Args:
        mount_point: The mount point of the KV secrets engine (e.g., 'sv4-dev').
        secret_path: The path within the mount to list (e.g., 'sv4-dev-poc3/').
    """
    try:
        # 1. Standard Vault client setup from environment variables
        vault_addr = os.getenv('VAULT_ADDR')
        vault_token = os.getenv('VAULT_TOKEN')

        if not vault_addr or not vault_token:
            print("Error: Please set VAULT_ADDR and VAULT_TOKEN environment variables.")
            return

        client = hvac.Client(url=vault_addr, token=vault_token)

        if not client.is_authenticated():
            print(f"Error: Authentication failed for Vault at {vault_addr}.")
            return

        print(f"Successfully authenticated to Vault at: {vault_addr}")
        print(f"Attempting to list secrets at '{mount_point}/{secret_path}'...")
        print("=" * 50)

        # 2. Automatically detect the KV engine version for the mount point
        try:
            mount_config = client.sys.read_mount_configuration(path=mount_point)
            # The 'version' option is only present for v2. Defaults to '1' if not found.
            version = mount_config['data']['options'].get('version', '1')
            print(f"Detected KV Version: {version}")
        except InvalidPath:
            print(f"Error: The mount point '{mount_point}' does not exist.")
            return

        # 3. Use the correct hvac method based on the detected version
        if version == '2':
            list_method = client.secrets.kv.v2.list_secrets
        elif version == '1':
            list_method = client.secrets.kv.v1.list_secrets
        else:
            print(f"Error: Unknown KV version '{version}' for mount '{mount_point}'.")
            return

        # 4. Call the list method and process the response
        response = list_method(path=mount_point mount_point=mount_point)
        key_list = response.get('data', {}).get('keys', [])

        if not key_list:
            print(f"No secrets or sub-paths found at '{mount_point}'.")
        else:
            print(f"Found the following items at '{mount_point}/':")
            for key in sorted(key_list): # Sort for consistent output
                if key.endswith('/'):
                    print(f"  - {key}  (sub-path/folder)")
                else:
                    print(f"  - {key}  (secret)")

    except InvalidPath:
        print(f"\nError: The path '{mount_point}/{secret_path}' is invalid or does not exist.")
    except Forbidden:
        print(f"\nError: Permission denied. Your token does not have 'list' capabilities on the path 'auth/{mount_point}/list/{secret_path}'.")
    except VaultError as e:
        print(f"An error occurred while communicating with Vault: {e}")
    except Exception as e:
        print(f"An unexpected error occurred: {e}")

if __name__ == "__main__":
    # --- This is where we specify the path from your command ---
    TARGET_MOUNT_POINT = "sv4-dev/sv4-dev-poc3"
    TARGET_SECRET_PATH = ""

    list_secrets_in_vault(
        mount_point=TARGET_MOUNT_POINT,
        secret_path=TARGET_SECRET_PATH
    )
