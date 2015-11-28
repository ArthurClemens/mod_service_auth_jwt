# JWT authentication module for Zotonic

Provides [JSON Web Token](https://en.wikipedia.org/wiki/JSON_Web_Token) authentication for Zotonic API calls.


## Installation

* Download and place this module in `your_zotonic_site/user/modules/`
* Add the dependency [jwt-erl](https://github.com/marianoguerra/jwt-erl) to `~/.zotonic/your_zotonic_version/zotonic.config`:

~~~erl
{jwt, ".*", {git, "git@github.com:marianoguerra/jwt-erl.git", {branch, "master"}}}
~~~

* In the Zotonic root folder, run `make` to install the dependencies
* Activate this module in Admin > System > Modules


## Settings

### JWT settings

Add to your site's config:

```
%%% JWT setting
   {jwt_secret, "your-super-long-key-string"},
   {jwt_expiration_offset, 24}
```

You can grab a good key from https://www.grc.com/passwords.htm

Note that this key should not change anymore.

The default expiration offset is 24 hours (expires 24 hours after creation).


### CORS settings

If the app resides on a different server you need to enable Cross-Origin Resource Sharing:

```
%%% CORS settings
   {service_api_cors, true},
   {'Access-Control-Allow-Headers', "authorization, X-Requested-With, Content-Type"}
```

See also the [Zotonic documentation on CORS](http://zotonic.com/docs/latest/manuals/services.html?highlight=cors#enabling-cross-origin-resource-sharing-cors).


### HTTPS

This authentication method can only be trusted over a HTTPS connection, because regular HTTP traffic can be intercepted with a [man-in-the-middle attack](https://en.wikipedia.org/wiki/Man-in-the-middle_attack).


## Usage

### Signing in

When a user signs in to the server, return a JWT token for next requests. For instance:

~~~erlang
% Return a JWT token if successful
logon(Context) ->
    Args = z_context:get_q_all(Context),
    ContextAuth = controller_logon:logon(Args, [], Context),
    User = z_acl:user(ContextAuth),
    case User of
        undefined -> {error, not_authenticated};
        _ ->
            Token = mod_service_auth_jwt:createToken(User, ContextAuth),
            [Token]
    end.
~~~

The token is typically returned through a [service request](http://zotonic.com/docs/latest/manuals/services.html).

### Passing the token

When accessing a protected resource, pass the JWT token using the Bearer schema. The content of the header should look like:

```
Authorization: Bearer <token>
```

For instance:

~~~javascript
xhr.setRequestHeader('Authorization', 'Bearer ' + token);
~~~

Note that XHR does not work with `jsonp`.

When the token is valid:

* Access is granted to the protected resource (provided sufficient access rights)
* Response status 200 is be returned

In case of error (no token, expired or invalid token), a 401 status is returned, together with the reason.


## Testing

In the Zotonic shell:

~~~erlang
io_lib:format("~s", [mod_service_auth_jwt:createToken(1, Context)]).
~~~

Copy the token string.

In a new terminal window:

~~~bash
curl 'your_zotonic_site/api/base/info?id=1' -H 'Authorization : Bearer copied_token' -v
~~~

This should result in

```
...
< HTTP/1.1 200 OK
...
```

## Error messages

Possible responseText messages sent with a 401 error status:

* `no_jwt_received`
* `jwt_empty`
* `jwt_expired`
* `jwt_error`
* `no_valid_user`


## Licence

MIT
