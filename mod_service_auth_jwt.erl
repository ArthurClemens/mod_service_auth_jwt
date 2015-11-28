%% @author Arthur Clemens
%% @copyright 2015 Arthur Clemens

%% @doc Provides JSON Web Token authentication for Zotonic API calls.

-module(mod_service_auth_jwt).
-author("Arthur Clemens").

-mod_title("JWT API service authentication").
-mod_description("Provides JSON Web Token authentication for Zotonic API calls.").
-mod_prio(500).

-include_lib("zotonic.hrl").
-include_lib("jwt/include/jwt.hrl").

-export([
    observe_service_authorize/2,
    createToken/2
]).


observe_service_authorize(#service_authorize{}, Context) ->
    case z_context:get_req_header("authorization", Context) of
        "Bearer " ++ Jwt ->
            process_jwt(Jwt, Context);
        _ ->
            return_error("no_jwt_received", Context)
    end.


process_jwt(Jwt, Context) ->
    case Jwt of
        "" -> return_error("jwt_empty", Context);
        _ ->
            Secret = secret_key(Context),
            JwtBin = list_to_binary(Jwt),
            decode_jwt(JwtBin, Secret, Context)
    end.


decode_jwt(Jwt, Secret, Context) ->
    case jwt:decode(Jwt, Secret) of
        {error, {expired,_}} ->
            return_error("jwt_expired", Context);
        {error, _} ->
            return_error("jwt_error", Context);
        {ok, Decoded} ->
            {struct, Data} = mochijson2:decode(Decoded#jwt.body),
            UserId = proplists:get_value(<<"id">>, Data),
            maybe_login_user(UserId, Context);
        _ -> return_error("jwt_error", Context)
    end.


maybe_login_user(UserId, Context) ->
    case m_identity:is_user(UserId, Context) of
        false ->
            return_error("no_valid_user", Context);
        true ->
            AuthContext = z_acl:logon(UserId, Context),
            ReqData = z_context:get_reqdata(Context),
            {true, ReqData, AuthContext}
    end.


return_error(Reason, Context) ->
    ReqData = z_context:get_reqdata(Context),
    ReqData1 = wrq:set_resp_body(Reason ++ "\n", ReqData),
    {{halt, 401}, ReqData1, Context}.


secret_key(Context) ->
    {ok, SiteConfigs} = z_sites_manager:get_site_config(z_context:site(Context)),
    case proplists:get_value(jwt_secret, SiteConfigs) of
        false -> <<>>;
        Secret -> list_to_binary(Secret)
    end.


createToken(Id, Context) ->
    Secret = secret_key(Context),
    Props = case expiration_offset(Context) of
        undefined -> [];
        Offset ->
            Expires = now_secs() + Offset,
            [{exp, Expires}]
    end,
    {ok, Jwt} = jwt:encode(hs512, [
        {id, Id}
    ], Secret, Props),
    Jwt.


expiration_offset(Context) ->
    {ok, SiteConfigs} = z_sites_manager:get_site_config(z_context:site(Context)),
    case proplists:get_value(jwt_expiration_offset, SiteConfigs) of
        Hours when is_integer(Hours)-> Hours * 3600;
        _ -> undefined
    end.


now_secs() ->
    {MegaSecs, Secs, _MicroSecs} = os:timestamp(),
    (MegaSecs * 1000000 + Secs).
