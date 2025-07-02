import unittest
from unittest.mock import patch, MagicMock
from manage_vault_access import policy_create, main

class TestManageVaultAccess(unittest.TestCase):

    @patch('manage_vault_access.hvac.Client')
    def test_policy_create(self, mock_client):
        mock_client_instance = mock_client.return_value
        policy_name = "test-policy"
        site_id = "sv4-dev"
        clustername = "test-cluster"
        namespace_name = "test-namespace"

        policy_create(mock_client_instance, policy_name, site_id, clustername, namespace_name)

        expected_policy = f"""
        # Full access to the namespace data path
        path "{site_id}/{clustername}/data/{namespace_name}" {{
            capabilities = ["read", "write", "delete", "update", "list"]
        }}

        # List access for the site_id level
        path "{site_id}" {{
            capabilities = ["list"]
        }}
        """
        mock_client_instance.sys.create_or_update_policy.assert_called_once_with(
            name=policy_name, policy=expected_policy
        )

    @patch('manage_vault_access.input', side_effect=["testuser", "https://vault.dev.e2open.com", "1", "test-cluster", "test-namespace"])
    @patch('manage_vault_access.getpass.getpass', return_value="password")
    @patch('manage_vault_access.hvac.Client')
    def test_main(self, mock_client, mock_getpass, mock_input):
        mock_client_instance = mock_client.return_value
        mock_client_instance.auth.ldap.login.return_value = True
        mock_client_instance.is_authenticated.return_value = True
        mock_client_instance.sys.read_policy.return_value = {"data": {"rules": "existing rules"}}

        with patch('builtins.print') as mock_print:
            main()

            mock_client_instance.auth.ldap.login.assert_called_once_with(
                username="testuser", password="password"
            )
            mock_client_instance.sys.read_policy.assert_called_once()
            mock_print.assert_any_call("Successfully authenticated as testuser using LDAP!")
            mock_print.assert_any_call("Policy 'userpolicy-sv4-dev-test-cluster-test-namespace' already exists in Vault.")

if __name__ == '__main__':
    unittest.main()