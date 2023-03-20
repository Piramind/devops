from venv import create
import hvac
import json


token = client.auth.token.create(policies=['root'], ttl='1h')
client.token = token
client = hvac.Client(url='http://localhost:8200')
#client.auth.login(token)


def init_server():
    print(f" Is client authenticated: {client.is_authenticated()}")
init_server()


def create_secret():
    create_response = client.secrets.kv.v2.create_or_update_secret(path='hello', secret=dict(foo="bar"))
    print(json.dumps(create_response, indent=4, sort_keys=True))
create_secret()


def create_policy():
    policy = '''
        path "secret/*" {
            capabilities = ["read"]
        }

        path "secret/foo" {
            capabilities = ["create", "read", "update", "delete", "list"]
        }
    '''
    client.sys.create_or_update_policy(
        name='secret-writer',
        policy=policy,
    )
create_policy()
