import hvac
client = hvac.Client()


list_response = client.secrets.kv.v2.list_secrets(
    mount='sv4-dev/sv4-dev-poc3' ,
)
list_secrets(path, mount_point='secret')
print(list_response)
print('The following paths are available under "hvac" prefix: {keys}'.format(
    keys=','.join(list_response['data']['keys']),
))
