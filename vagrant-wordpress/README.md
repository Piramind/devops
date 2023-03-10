Vagrant поднимает несколько виртуальных машин с установленным и настроенным софтом:
- `wp` - nginx + php-fpm + wordpress (можно указать количество машин в servers.yaml)
- `db` - mysql server
- `lb` - nginx load balancer

## Параметры:
- `name`    - Имя виртуальной машины
- `nics`    - Описание сетевых интерфейсов
  - `type`  - Тип сети может быть `private_network` или `public_network`
  - `ip`    - IP адрес
- `ram`     - объем оперативной памяти
- `count`   - Количество виртуальных машин (работает только для машин с WordPress)
- `files`   - Файлы, которые будут помещены внутрь виртуальной машины
  - `source`- Путь к файлу
- `scripts` - Скрипты для провижнинга
  - `path`  - Путь к скрипту
- `dbuser`  - Пользователь базы данных mysql
- `dbpassword` - Пароль пользователя `dbuser`
- `dbname`  - Имя базы данных mysql

## Использование
```
git clone https://github.com/Piramind/devops.git
cd vagrant-wordpress
vagrant up
```
