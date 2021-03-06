# Вводная
Есть кластер k8s и доменные имена, которые обслуживает панель *ISPManager Бизнес*

Необходимо при запуске в нашем кластере нового приложения, не только сгенерить ему правильные ssl сертификат (благо, обычно, это делается втроенными службами самого кластера), но и создать субдоменное имя и прописать ему минимум две записи, которые будут смотреть на наши nginx в кластере.
Т.к. панель ISPManager имеет более менее вменяемый API, собственно и был собран следующий сервис.

Итак, стоит задача поднять в нашем кластере бложик.
Есть доменное имя `domain.ru`, а наш бложик будет висеть на `blog.domain.ru`
План выполнения: поднимаем сам деплоймент, нужные ему ингрессы, генерим tls запись и выставляем собственно все это наружу, а далее создаем джобу, которая дернет API у панели с доменами и пропишет нужные нам записи.

Собственно описание работы последней ниже по тексту.

# Работа с доменами с контейнера
Готовый контейнер для работы с записями конкретного домена - `vasyakrg/ispmgr-api`
Может пригодиться как для простого управления записями через скрипты, так и при использовании автозаписей в k8s (пример ниже)

что бы создавать\удалять записи в конкретном домене, нужно:
- знать свой сервер,
- иметь логин и пароль от учетки, которая имеет право работать с доменом

> работает так:
{.is-success}

создаем конфиг файл .env с содержимым:

```
DNS_SERVER=isp.domain.ru
DNS_LOGIN=root
DNS_PASSWORD=password
DOMAIN_NAME=domain1.com
DNS_SETNAME=test1
DNS_VALUE_TYPE=A
DNS_VALUE=5.5.5.5
DNS_TTL=600
```

`DNS_VALUE_TYPE` - может быть типа `А` или `CNAME`
`DNS_VALUE` - соответственно, либо равно `ip-адресу`, либо полному доменному имени с точкой на конце (например, api.domain.com.)

> запускаем контейнер:
{.is-success}

чтобы создать
`docker run --rm -it --env-file=.env vasyakrg/ispmgr-api /bin/bash -c "./ispmgr.sh create"`

чтобы удалить:
`docker run --rm -it --env-file=.env vasyakrg/ispmgr-api /bin/bash -c "./ispmgr.sh delete"`

### Замечания
- при создании проверяется, существует ли уже запись, и если существует - просто информирует, что запись уже есть
- при удалении (из-за ограниченности API сервиса ISP) наличие записи не проверяется
- в обоих случаях проверяется логин\пароль и корневой домен, ошибки выводятся, и не проверяется сам сервер - тут уж пишите без ошибок и проверяется сервер на его работоспособность (может быть доведу до ума позже)

# Работа с доменами в кластере k8s
так же, можно использоваться сразу в кластере, создавая доменное имя при поднятии деплоймента

вот так может выглядеть джоба:

```
# kubetpl:syntax:go-template

apiVersion: batch/v1
kind: Job
metadata:
  name: ispmgr-dns-job-lb1
spec:
  ttlSecondsAfterFinished: 300
  template:
    spec:
      containers:
      - name: ispmgr-dns-api-call
        image: vasyakrg/ispmgr-api
        command: ["bash", "-c", "./ispmgr.sh {{ .DNS_API_COMMAND }}"]
        env:
        - name: DNS_SERVER
          valueFrom:
            secretKeyRef:
              name: dns-service-secrets
              key: dns-server
        - name: DNS_LOGIN
          valueFrom:
            secretKeyRef:
              name: dns-service-secrets
              key: dns-login
        - name: DNS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: dns-service-secrets
              key: dns-password
        - name: DOMAIN_NAME
          value: {{ .DOMAIN_NAME }}
        - name: DNS_SETNAME
          value: {{ .DNS_SETNAME }}
        - name: DNS_VALUE_TYPE
          value: {{ .DNS_VALUE_TYPE }}
        - name: DNS_VALUE
          value: {{ .DNS_VALUE }}
        - name: DNS_TTL
          value: {{ .DNS_TTL }}

      restartPolicy: Never
  backoffLimit: 2
---
```

соответственно, передаем `DNS_API_COMMAND`, которая принимает вид `create` или `delete`, а так же `все` переменные, по примеру запуска таска в контейнере.

я обычно использую две такие джобы, которые создают две записи по айпишникам `LB_IP1` и `LB_IP2`, которые смотрят на две ноды нашего кластера
а при удалении деплоймента, запускаю две новые джобы с переменной `DNS_API_COMMAND=delete`, что бы не плодить в домене кучу мертвых записей.

проверить, что джоба на удаление отработалась можно простым методом ожидания
```
kubectl -n ${NS} wait --for=condition=complete --timeout=600s jobs/ispmgr-dns-job-lb1
```
после чего можно удалять весь деплой, либо же весь неймспейс полностью.

# Сами методы
создать запись A:
```
curl -ks "https://${DNS_SERVER}/ispmgr?authinfo=${DNS_LOGIN}:${DNS_PASSWORD}&out=sjson&sok=ok&func=domain.record.edit&plid=${DOMAIN_NAME}&ip=${DNS_SETIP}&name=${DNS_SETNAME}&rtype=a&ttl=3600"
```
создать запись CNAME:
```
curl -ks "https://${DNS_SERVER}/ispmgr?authinfo=${DNS_LOGIN}:${DNS_PASSWORD}&out=sjson&sok=ok&func=domain.record.edit&plid=${DOMAIN_NAME}&ip=&name=${DNS_SETNAME}&domain=${DNS_VALUE}&rtype=${DNS_VALUE_TYPE}&ttl=${DNS_TTL}"
```

удалить запись A:
```
curl -ks "https://${DNS_SERVER}/ispmgr?authinfo=${DNS_LOGIN}:${DNS_PASSWORD}&out=sjson&sok=ok&func=domain.record.delete&plid=${DOMAIN_NAME}&elid=${DNS_SETNAME}.${DOMAIN_NAME}.%20A%20%20${DNS_SETIP}"
```

удалить запись CNAME:
```
curl -ks "https://${DNS_SERVER}/ispmgr?authinfo=${DNS_LOGIN}:${DNS_PASSWORD}&out=sjson&sok=ok&func=domain.record.delete&plid=${DOMAIN_NAME}&elid=${DNS_SETNAME}.${DOMAIN_NAME}.%20CNAME%20%20${DNS_VALUE}"
```

##### Автор
- **Vassiliy Yegorov** - *Initial work* - [vasyakrg](https://github.com/vasyakrg)
- [сайт](https://vk.com/realmanual)
- [youtube](https://youtube.com/realmanual)
