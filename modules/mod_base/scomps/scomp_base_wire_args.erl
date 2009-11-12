%% @author Marc Worrell <marc@worrell.nl>
%% @copyright 2009 Marc Worrell
%% @doc Wire an action to an element, adding all non-scomp arguments to the actions before rendering them.

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

-module(scomp_base_wire_args).
-behaviour(gen_scomp).

-export([init/1, varies/2, terminate/2, render/4]).

-include("zotonic.hrl").

init(_Args) -> {ok, []}.
varies(_Params, _Context) -> undefined.
terminate(_State, _Context) -> ok.

render(Params, _Vars, Context, _State) ->
    Id        = proplists:get_value(id, Params, <<>>),
    Type      = proplists:get_value(type,Params,click),
    TargetId  = proplists:get_value(target,Params,Id),
    Actions   = proplists:get_all_values(action,Params),
    Postback  = proplists:get_value(postback,Params),
    Delegate  = proplists:get_value(delegate,Params),

    Args = proplists:delete(id, 
                proplists:delete(type, 
                    proplists:delete(target,
                        proplists:delete(action, 
                            proplists:delete(postback,
                                proplists:delete(delegate, Params)))))), 

    Actions1  = lists:flatten(Actions),
    Options   = [{action, append_args(X, Args)} || X <- Actions1, X =/= undefined ],
    Options1  = case Postback of
                	undefined -> Options;
                	Postback  -> [{postback,Postback} | Options]
                end,

    Delegate1 = case Delegate of
        undefined -> undefined;
        _ -> z_convert:to_atom(Delegate)
    end,

    case Options1 of
        [_|_] -> {ok, z_render:wire(Id, TargetId, {event,[{type,Type},{delegate,Delegate1}|Options1]}, Context)};
        _ -> {ok, Context}
    end.

append_args({Action, ActionArgs}, Args) ->
    {Action, ActionArgs ++ Args}.
