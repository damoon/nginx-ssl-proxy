# nginx-ssl-proxy
This repository is used to build a Docker image that acts as an HTTP [reverse proxy](http://en.wikipedia.org/wiki/Reverse_proxy) with optional (but strongly encouraged) support for acting as an [SSL termination proxy](http://en.wikipedia.org/wiki/SSL_termination_proxy). The proxy can also be configured to enforce [HTTP basic access authentication](http://en.wikipedia.org/wiki/Basic_access_authentication). Nginx is the HTTP server, and its SSL configuration is included (and may be modified to suit your needs) at `nginx/proxy_ssl.conf` in this repository.

## Configuration

| Environment Variable | Default | Required | Example | Effect |
| -------------------- | ------- | -------- | ------- | ------ |
| TARGET_SERVICE       | -       | yes      | 127.0.0.1:8080 | the service to proxy to |
| ENABLE_BASIC_AUTH    | false   | no       | true    | enables basic authentication, uses auth_basic_user_file=/etc/secrets/htpasswd to read logins |
| BASIC_AUTH_BASE64    | -       | no       | IyB0ZXN0OnRlc3QKdGVzdDokYX ByMSRidWN0akk2diRpaWkyY25O bTRsdUpNc3E4YWN2UXYuCg== (created via `cat testing/passwords | base64 -w 0`)    | base64 encoded list of credentials to be placed in /etc/secrets/htpasswd |
| ENABLE_SSL           | false   | no       | true    | enables https, redirects from http to https, uses ssl_certificate=/etc/secrets/proxycert, ssl_certificate_key=/etc/secrets/proxykey and  ssl_dhparam=/etc/secrets/dhparam to read the ssl cert |
| INCLUDE              | -       | no       | /etc/secrets/exta.conf | adds $INCLUDE as include to the proxy vhost |
| ALLOW_INTRANET       | false   | no       | true    | forces ALLOW_DENY_FALLBACK=deny, allows access to ipranges 10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,127.0.0.0/8,169.254.0.0/16 |
| SATISFY_ANY          | false   | no       | true    | allows access if ip is allowed or login credentials are provided |
| ALLOW                | -       | no       | 192.168.0.1 | allows access for ip |
| DENY                 | -       | no       | 192.168.0.1 | denys access for ip |
| ALLOW_DENY_FALLBACK  | -       | no       | deny    | if not defined by other config, ip gets allow/deny via default fallback behavior |
| SET_REAL_IP_FROM_INTRANET  | - | no       | true    | trust intranet proxies to provide a valid user ip |
| SET_REAL_IP_FROM     | -       | no       | 192.168.0.1 | trust an reverse proxy to provide a valid user ip |
| REAL_IP_HEADER       | X-Forwarded-For | no | X-Real-IP | header to read to get the user ip |
| REAL_IP_RECURSIVE    | on      | no       | off     | use the trusted proxy, closest to the user, to provide the user ip |
| HTTP_PORT            | 80      | no       | 8080    | sets the http port to listen on |
| HTTPS_PORT           | 443     | no       | 8443    | sets the https port to listen on |
| ENABLE_ACCESS_LOG    | false   | no       | true    | enables access log to stdout |


## Building the Image
Build the image yourself by cloning this repository then running:

```shell
docker build -t nginx-ssl-proxy .
```

## Using with Kubernetes
This image is optimized for use in a Kubernetes cluster to provide SSL termination for other services in the cluster. It should be deployed as a [Kubernetes replication controller](https://github.com/GoogleCloudPlatform/kubernetes/blob/master/docs/replication-controller.md) with a [service and public load balancer](https://github.com/GoogleCloudPlatform/kubernetes/blob/master/docs/services.md) in front of it. SSL certificates, keys, and other secrets are managed via the [Kubernetes Secrets API](https://github.com/GoogleCloudPlatform/kubernetes/blob/master/docs/design/secrets.md).

Here's how the replication controller and service would function terminating SSL for Jenkins in a Kubernetes cluster:

![](img/architecture.png)

See [https://github.com/GoogleCloudPlatform/kube-jenkins-imager](https://github.com/GoogleCloudPlatform/kube-jenkins-imager) for a complete tutorial that uses the `nginx-ssl-proxy` in Kubernetes.

## Run an SSL Termination Proxy from the CLI
To run an SSL termination proxy you must have an existing SSL certificate and key. These instructions assume they are stored at /path/to/secrets/ and named `cert.crt` and `key.pem`. You'll need to change those values based on your actual file path and names.

1. **Create a DHE Param**

    The nginx SSL configuration for this image also requires that you generate your own DHE parameter. It's easy and takes just a few minutes to complete:

    ```shell
    openssl dhparam -out /path/to/secrets/dhparam.pem 2048
    ```

2. **Launch a Container**

    Modify the below command to include the actual address or host name you want to proxy to, as well as the correct /path/to/secrets for your certificate, key, and dhparam:

    ```shell
    docker run \
      -e ENABLE_SSL=true \
      -e TARGET_SERVICE=THE_ADDRESS_OR_HOST_YOU_ARE_PROXYING_TO \
      -v /path/to/secrets/cert.crt:/etc/secrets/proxycert \
      -v /path/to/secrets/key.pem:/etc/secrets/proxykey \
      -v /path/to/secrets/dhparam.pem:/etc/secrets/dhparam \
      nginx-ssl-proxy
    ```
    The really important thing here is that you map in your cert to `/etc/secrets/proxycert`, your key to `/etc/secrets/proxykey`, and your dhparam to `/etc/secrets/dhparam` as shown in the command above.

3. **Enable Basic Access Authentication**

    Create an htpaddwd file:

    ```shell
    htpasswd -nb YOUR_USERNAME SUPER_SECRET_PASSWORD > /path/to/secrets/htpasswd
    ```

    Launch the container, enabling the feature and mapping in the htpasswd file:

    ```shell
    docker run \
      -e ENABLE_SSL=true \
      -e ENABLE_BASIC_AUTH=true \
      -e TARGET_SERVICE=THE_ADDRESS_OR_HOST_YOU_ARE_PROXYING_TO \
      -v /path/to/secrets/cert.crt:/etc/secrets/proxycert \
      -v /path/to/secrets/key.pem:/etc/secrets/proxykey \
      -v /path/to/secrets/dhparam.pem:/etc/secrets/dhparam \
      -v /path/to/secrets/htpasswd:/etc/secrets/htpasswd \
      nginx-ssl-proxy
    ```
4. **Add additional nginx config**

   All *.conf from [nginx/extra](nginx/extra) are added during *built* to **/etc/nginx/extra-conf.d** and get included on startup of the container. Using volumes you can overwrite them on *start* of the container:

    ```shell
    docker run \
      -e ENABLE_SSL=true \
      -e TARGET_SERVICE=THE_ADDRESS_OR_HOST_YOU_ARE_PROXYING_TO \
      -v /path/to/secrets/cert.crt:/etc/secrets/proxycert \
      -v /path/to/secrets/key.pem:/etc/secrets/proxykey \
      -v /path/to/secrets/dhparam.pem:/etc/secrets/dhparam \
      -v /path/to/additional-nginx.conf:/etc/nginx/extra-conf.d/additional_proxy.conf \
      nginx-ssl-proxy
    ```

   That way it is possible to setup additional proxies or modifying the nginx configuration.
