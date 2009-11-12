%% @author Marc Worrell <marc@worrell.nl>
%% @copyright 2009 Marc Worrell
%%
%% Based on code (c) 2008-2009 Rusty Klophaus

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

-module(scomp_base_button).
-behaviour(gen_scomp).

-export([init/1, varies/2, terminate/2, render/4]).

-include("zotonic.hrl").

init(_Args) -> {ok, []}.
varies(_Params, _Context) -> undefined.
terminate(_State, _Context) -> ok.

render(Params, _Vars, Context, _State) ->
    Postback  = proplists:get_value(postback, Params),
	Delegate  = proplists:get_value(delegate, Params),
    Text      = proplists:get_value(text, Params, <<"Submit">>),
    Id        = z_ids:optid(proplists:get_value(id, Params)),
    Class     = proplists:get_all_values(class, Params),
    Style     = proplists:get_value(style, Params),
    Type      = proplists:get_value(type, Params),
    Title     = proplists:get_value(title, Params),
    Disabled  = proplists:get_value(disabled, Params, false),
    Actions   = proplists:get_all_values(action, Params),

    Options   = [{action,X} || X <- Actions],
    Options1  = case Postback of
                	undefined -> Options;
                	Postback  -> [{postback,Postback} | Options]
                end,

    Context1 = case Options1 of
                    [] -> Context;
                    _  -> 
					    Options2  = case Delegate of
										undefined -> Options1;
										_ -> [{delegate, Delegate} | Options1]
									end,
						z_render:wire(Id, {event,[{type,click}|Options2]}, Context)
               end,

    Attrs = [
        {<<"id">>,    Id},
        {<<"name">>,  case proplists:is_defined(id, Params) of true -> Id; false -> "" end},
        {<<"style">>, Style},
        {<<"title">>, Title}
    ],
    
    {Class1, Attrs1} = case z_convert:to_bool(Disabled) of
        false -> {Class, Attrs};
        true -> { ["disabled"|Class], [ {<<"disabled">>,"disabled"}|Attrs] }
    end,
    
    Attrs2 = case Type of
        undefined -> Attrs1;
        _ -> [ {<<"type">>, Type} | Attrs1 ]
    end,
    
    Context2 = z_tags:render_tag(
                        <<"button">>,
                        [{<<"class">>,Class1}|Attrs2],
                    	Text,
                    	Context1),
    {ok, Context2}.

