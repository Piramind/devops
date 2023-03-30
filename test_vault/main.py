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


# Подключиться к хранилищу
client = hvac.Client(url='http://localhost:8200', token = 'hvs.P6D3HN3dZiGMvACB97RQ6dIS')
print(f" Is client authenticated: {client.is_authenticated()}")

# Создать пользователя
username = input()
password = pass_word
client.write('auth/userpass/users/' +  username, password=password)

# Войдите как новый пользователь
user_client = hvac.Client(url='localhost:8200')
user_client.auth_userpass(username, password)

token = client.auth.token.create(policies=['root'], ttl='1h')


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
