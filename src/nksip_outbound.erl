%% -------------------------------------------------------------------
%%
%% Copyright (c) 2013 Carlos Gonzalez Florido.  All Rights Reserved.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%% -------------------------------------------------------------------

%% @doc Outbound support
-module(nksip_outbound).
-author('Carlos Gonzalez <carlosj.gf@gmail.com>').

-export([make_contact/3, proxy_route/2, registrar/2]).

-include("nksip.hrl").


%% ===================================================================
%% Types
%% ===================================================================

%% @private
-spec make_contact(nksip:request(), nksip:uri(), nksip_lib:proplist()) ->
    nksip:uri().

make_contact(#sipmsg{class={req, 'REGISTER'}}=Req, Contact, Opts) ->
    case 
        nksip_sipmsg:supported(Req, <<"outbound">>) andalso 
        nksip_lib:get_integer(reg_id, Opts)
    of
        RegId when is_integer(RegId), RegId>0 -> 
            #uri{ext_opts=CExtOpts} = Contact,
            CExtOpts1 = [{<<"reg-id">>, nksip_lib:to_binary(RegId)}|CExtOpts],
            Contact#uri{ext_opts=CExtOpts1};
        _ ->
            Contact
    end;

% 'ob' parameter means we want to use the same flow for in-dialog requests
make_contact(Req, Contact, _Opts) ->
    case 
        nksip_sipmsg:supported(Req, <<"outbound">>) 
        andalso nksip_sipmsg:is_dialog_forming(Req)
    of
        true ->
            #uri{opts=COpts} = Contact,
            Contact#uri{opts=nksip_lib:store_value(<<"ob">>, COpts)};
        false ->
            Contact
    end.


%% @private
%% Adds record_flow and route_flow options
-spec proxy_route(nksip:request(), nksip_lib:proplist()) ->
    {ok, nksip_lib:proplist()} | {error, Error}
    when Error :: flow_failed | forbidden.

proxy_route(#sipmsg{class={req, 'REGISTER'}}=Req, Opts) ->
    #sipmsg{
        app_id = AppId,
        vias = Vias, 
        transport = Transp, 
        contacts = Contacts
    } = Req,
    Supported = nksip_lib:get_value(supported, Opts, ?SUPPORTED),
    Opts1 = case 
        lists:member(make_path, Opts) andalso
        nksip_sipmsg:supported(Req, <<"path">>) andalso 
        lists:member(<<"outbound">>, Supported) andalso
        Contacts
    of
        [#uri{ext_opts=ContactOpts}] ->
            case lists:keymember(<<"reg-id">>, 1, ContactOpts) of
                true ->
                    case nksip_transport:get_connected(AppId, Transp) of
                        [{Transp, Pid}|_] ->
                            case length(Vias)==1 of
                                true -> [{record_flow, {Pid, ob}}|Opts];
                                false -> [{record_flow, Pid}|Opts]
                            end;
                        _ -> 
                            Opts
                    end;
                false ->
                    Opts
            end;
        _ ->
            Opts
    end,
    {ok, Opts1};

proxy_route(Req, Opts) ->
    #sipmsg{app_id=AppId, routes=Routes, contacts=Contacts, transport=Transp} = Req,
    Supported = nksip_lib:get_value(supported, Opts, ?SUPPORTED),
    case 
        nksip_sipmsg:supported(Req, <<"outbound">>) andalso 
        lists:member(<<"outbound">>, Supported)
    of
        true ->
            case do_proxy_routes(Req, Opts, Routes) of
                {ok, Opts1} ->
                    case 
                        not lists:keymember(record_flow, 1, Opts1) andalso
                        Contacts
                    of
                       [#uri{opts=COpts}|_] ->
                            case lists:member(<<"ob">>, COpts) of
                                true ->
                                    Opts2 = case 
                                        nksip_transport:get_connected(AppId, Transp) 
                                    of
                                        [{_, Pid}|_] -> [{record_flow, Pid}|Opts1];
                                        _ -> Opts1
                                    end,
                                    {ok, Opts2};
                                false ->
                                    {ok, Opts1}
                            end;
                        _ ->
                            {ok, Opts1}
                    end;
                {error, Error} ->
                    {error, Error}
            end;
        false ->
            {ok, Opts}
    end.


%% @private
do_proxy_routes(_Req, Opts, []) ->
    {ok, Opts};

do_proxy_routes(Req, Opts, [Route|RestRoutes]) ->
    #sipmsg{app_id=AppId, transport=Transp} = Req,
    case nksip_transport:is_local(AppId, Route) andalso Route of
        #uri{user = <<"NkF", Token/binary>>, opts=RouteOpts} ->
            case catch binary_to_term(base64:decode(Token)) of
                Pid when is_pid(Pid) ->
                    case catch nksip_connection:get_transport(Pid) of
                        {ok, FlowTransp} -> 
                            Opts1 = case flow_type(Transp, FlowTransp) of
                                outcoming -> 
                                    % Came from the same flow
                                    [{record_flow, Pid}|Opts];
                                incoming ->
                                    [{route_flow, {FlowTransp, Pid}} |
                                        case lists:member(<<"ob">>, RouteOpts) of
                                            true -> [{record_flow, Pid}|Opts];
                                            false -> Opts
                                        end]
                            end,
                            {ok, Opts1};
                        _ ->
                            {error, flow_failed}
                    end;
                _ ->
                    ?notice(AppId, "Received invalid flow token", []),
                    {error, forbidden}
            end;
        #uri{opts=RouteOpts} ->
            case lists:member(<<"ob">>, RouteOpts) of
                true ->
                    Opts1 = case nksip_transport:get_connected(AppId, Transp) of
                        [{_, Pid}|_] -> [{record_flow, Pid}|Opts];
                        _ -> Opts
                    end,
                    {ok, Opts1};
                false ->
                    do_proxy_routes(Req, Opts, RestRoutes)
            end;
        false -> 
            {ok, Opts}
    end.


%% @private
flow_type(#transport{proto=Proto, remote_ip=Ip, remote_port=Port, resource=Res}, 
          #transport{proto=Proto, remote_ip=Ip, remote_port=Port, resource=Res}) ->
    outcoming;

flow_type(_, _) ->
    incoming.


%% @private
%% Add registrar_otbound
-spec registrar(nksip:request(), nksip_lib:proplist()) ->
    {nksip:request(), nksip_lib:proplist()}.

registrar(Req, Opts) ->
    #sipmsg{app_id=AppId, vias=Vias, transport=Transp} = Req,
    AppSupp = nksip_lib:get_value(supported, Opts, ?SUPPORTED),
    case 
        lists:member(<<"outbound">>, AppSupp) andalso
        nksip_sipmsg:supported(Req, <<"outbound">>)
    of
        true when length(Vias)==1 ->     % We are the first host
            #transport{
                proto = Proto, 
                listen_ip = ListenIp, 
                listen_port = ListenPort
            } = Transp,
            case nksip_transport:get_connected(AppId, Transp) of
                [{_, Pid}|_] ->
                    Flow = base64:encode(term_to_binary(Pid)),
                    Host = nksip_transport:get_listenhost(ListenIp, Opts),
                    Path = nksip_transport:make_route(sip, Proto, Host, ListenPort, 
                                                      <<"NkF", Flow/binary>>, 
                                                      [<<"lr">>, <<"ob">>]),
                    Headers1 = nksip_headers:update(Req, 
                                                [{before_single, <<"Path">>, Path}]),
                    Req1 = Req#sipmsg{headers=Headers1},
                    {ok, Req1, [{registrar_outbound, true}|Opts]};
                [] ->
                    {ok, Req, [{registrar_outbound, false}|Opts]}
            end;
        true ->
            case nksip_sipmsg:header(Req, <<"Path">>, uris) of
                error ->
                    {error, {invalid_request, <<"Invalid Path">>}};
                [] ->
                    {ok, Req, [{registrar_outbound, false}|Opts]};
                Paths ->
                    [#uri{opts=PathOpts}|_] = lists:reverse(Paths),
                    Ob = lists:member(<<"ob">>, PathOpts),
                    {ok, Req, [{registrar_outbound, Ob}|Opts]}
            end;
        false ->
            {ok, Req, Opts}
    end.

