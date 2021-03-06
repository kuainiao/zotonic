%% @author Marc Worrell <marc@worrell.nl>
%% @copyright 2009 Marc Worrell
%% @doc Overview of all members of a group.

%% Copyright 2009 Marc Worrell
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%% 
%%     http://www.apache.org/licenses/LICENSE-2.0
%% 
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.

-module(resource_admin_group_members).
-author("Marc Worrell <marc@worrell.nl>").

-export([
    is_authorized/2,
    resource_exists/2
]).

-include_lib("resource_html.hrl").

is_authorized(ReqData, Context) ->
    z_auth:wm_is_authorized(ReqData, Context).


resource_exists(ReqData, Context) ->
    Context1 = ?WM_REQ(ReqData, Context),
    Context2 = z_context:ensure_all(Context1),
    Id = z_context:get_q("id", Context2),
    try
        IdN = list_to_integer(Id),
        Context3 = z_context:set(id, IdN, Context2),
        ?WM_REPLY(m_rsc:exists(IdN, Context3) andalso m_rsc:is_a(IdN, group, Context), Context3)
    catch
        _:_ -> ?WM_REPLY(false, Context2)
    end.

html(Context) ->
    Vars = [
        {page_admin_group, true},
        {id, z_context:get(id, Context)}
    ],
	Html = z_template:render("admin_group_members.tpl", Vars, Context),
	z_context:output(Html, Context).
