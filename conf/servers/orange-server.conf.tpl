access_by_lua_file /usr/local/nginx/conf/waf/waf.lua;
server {
    listen 80;
    server_name orange-xiaowu.org;                            # modify
    charset utf-8;

    # gzip config.
    gzip on;
    gzip_min_length 1k;
    gzip_comp_level 2;
    gzip_types text/plain application/javascript application/x-javascript text/css application/xml text/javascript image/jpeg image/gif image/png application/json;
    gzip_vary on;

    ###  Config frontend static resource. Include default page,html resource no cache settings,static resource.

    # favicon.ico default request does not log
    location = /favicon.ico {
        log_not_found off;
        access_log off;
    }

    # website portal.
    location / {
        rewrite_by_lua_block {
            local orange = context.orange
            orange.redirect()
            orange.rewrite()
        }

        access_by_lua_block {
            local orange = context.orange
            orange.access()
        }

        # proxy
        proxy_set_header Host $host;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Scheme $scheme;
        proxy_set_header X-Forwarded-Host $server_name;
        proxy_pass http://orange_upstream;                   # modify

        header_filter_by_lua_block {
            local orange = context.orange
            orange.header_filter()
        }

        body_filter_by_lua_block {
            local orange = context.orange
            orange.body_filter()
        }

        log_by_lua_block {
            local orange = context.orange
            orange.log()
        }
    }

    # robot not allowed.
    location /robots.txt {
        return 200 'User-agent: *\nDisallow: /';
    }
}
