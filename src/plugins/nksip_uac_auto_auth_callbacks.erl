%% -------------------------------------------------------------------
%%
%% Copyright (c) 2019 Carlos Gonzalez Florido.  All Rights Reserved.
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

%% @doc NkSIP Registrar Plugin Callbacks
-module(nksip_uac_auto_auth_callbacks).
-author('Carlos Gonzalez <carlosj.gf@gmail.com>').

-include("nksip.hrl").
-include("nksip_call.hrl").


-export([nksip_parse_uac_opts/2, nksip_uac_response/4]).


%% ===================================================================
%% Core SIP callbacks
%% ===================================================================


%% @doc Called to parse specific UAC options
-spec nksip_parse_uac_opts(nksip:request(), nksip:optslist()) ->
    {continue, list()} | {error, term()}.

nksip_parse_uac_opts(Req, Opts) ->
    case nklib_config:parse_config(Opts, nksip_uac_auto_auth:syntax()) of
        {ok, Opts2, _Rest} ->
            {continue, [Req, nklib_util:store_values(Opts2, Opts)]};
        {error, Error} ->
            {error, Error}
    end.


% @doc Called after the UAC processes a response
-spec nksip_uac_response(nksip:request(), nksip:response(),
                        nksip_call:trans(), nksip:call()) ->
    continue | {ok, nksip:call()}.

nksip_uac_response(Req, Resp, UAC, Call) ->
    nksip_uac_auto_auth:check_auth(Req, Resp, UAC, Call).


