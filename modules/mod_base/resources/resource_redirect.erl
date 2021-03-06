%% @author Marc Worrell <marc@worrell.nl>
%% @copyright 2009 Marc Worrell
%% @doc Redirect to a defined other url.

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

-module(resource_redirect).
-author("Marc Worrell <marc@worrell.nl>").

-export([
	init/1,
	service_available/2,
	resource_exists/2,
	previously_existed/2,
	moved_temporarily/2
]).

-include_lib("webmachine_resource.hrl").
-include_lib("include/zotonic.hrl").


init(DispatchArgs) -> {ok, DispatchArgs}.

service_available(ReqData, DispatchArgs) when is_list(DispatchArgs) ->
    Context  = z_context:new(ReqData, ?MODULE),
    Context1 = z_context:set(DispatchArgs, Context),
    ?WM_REPLY(true, Context1).

resource_exists(ReqData, Context) ->
	{false, ReqData, Context}.

previously_existed(ReqData, Context) ->
	{true, ReqData, Context}.

moved_temporarily(ReqData, Context) ->
	Location = case z_context:get(url, Context) of
		undefined ->
			case z_context:get(dispatch, Context) of
				undefined ->
					case z_context:get(id, Context) of
						undefined -> "/";
						Id -> m_rsc:p(Id, page_url, Context)
					end;
				Dispatch -> 
					%% @todo add, on demand, qargs into the dispatch arg list.
					Args = z_context:get_all(Context),
					Args1 = proplists:delete(dispatch, Args),
					z_dispatcher:url_for(Dispatch, Args1, Context)
			end;
		Url ->
			Url
	end,
	{{true, z_context:abs_url(Location, Context)}, ReqData, Context}.
