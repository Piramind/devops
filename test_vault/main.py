from venv import create
import hvac
import json
import random
import string

# password generation
lower = string.ascii_lowercase
upper = string.ascii_uppercase
num = string.digits
symbols = string.punctuation
all = string.ascii_letters + string.digits + string.punctuation
temp = random.sample(all, 8)
pass_word = "".join(temp)


client = hvac.Client(url='http://localhost:8200', token = 'hvs.S2eZbgoUrc68ef52rOG2rQic')

print(f" Is client authenticated: {client.is_authenticated()}")

token = client.auth.token.create(policies=['root'], ttl='1h')
print(token)

# enable userpass method
#client.sys.enable_auth_method('userpass', path='customuserpass')

client.userpass.create_or_update_user(pass_word)
client.auth.login(token)


create_response = client.secrets.kv.v2.create_or_update_secret(path='secret', secret={foo:"bar"})
create_response = client.secrets.kv.v2.create_or_update_secret(path='hello', secret={foo:"bar"})
print(json.dumps(create_response, indent=4, sort_keys=True))


def create_policy(): # сделать 2 политики
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
