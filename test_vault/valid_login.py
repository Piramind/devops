import hvac

# Подключиться к хранилищу
client = hvac.Client(url='http://localhost:8200', token = 'hvs.P6D3HN3dZiGMvACB97RQ6dIS')
print(f" Is client authenticated: {client.is_authenticated()}")

# Создать пользователя
username = input()
password = ''
client.write('auth/userpass/users/' +  username, password=password)

# Войдите как новый пользователь
user_client = hvac.Client(url='localhost:8200')
user_client.auth_userpass(username, password)
