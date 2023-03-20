from venv import create
import hvac
import json
import random

client = hvac.Client(url='http://localhost:8200')
token = client.auth.token.create(policies=['root'], ttl='1h')
#client.auth.login(token)

# enable userpass method
client.sys.enable_auth_method(
    method_type='userpass',
    path='userpass-hvac',
)


# password generation
lower = string.ascii_lowercase
upper = string.ascii_uppercase
num = string.digits
symbols = string.punctuation
all = string.ascii_letters + string.digits + string.punctuation
temp = random.sample(all, 8)
pass_word = "".join(temp)

# login with password
client.auth.userpass.login(
    username= input(),
    password=pass_word,
)

#print(f" Is client authenticated: {client.is_authenticated()}") # auntification


create_response = client.secrets.kv.v2.create_or_update_secret(path='secret', secret=dict(foo="bar"))
create_response = client.secrets.kv.v2.create_or_update_secret(path='hello', secret=dict(foo="bar"))
print(json.dumps(create_response, indent=4, sort_keys=True))


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
