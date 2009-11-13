%% @author Marc Worrell <marc@worrell.nl>
%% @copyright 2009 Marc Worrell
%% @date 2009-04-27

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

-module(action_base_dialog).
-author("Marc Worrell <marc@worrell.nl").

%% interface functions
-export([
    render_action/4
]).

-include("zotonic.hrl").

render_action(_TriggerId, _TargetId, Args, Context) -> 
    Title  = proplists:get_value(title, Args, ""),
    Text   = proplists:get_value(text, Args, ""),
	Script = [<<"z_dialog_open(\"">>,
	          z_utils:js_escape(Title), $", $,, $",
	          z_utils:js_escape(Text), $", $), $; ],
	{Script, Context}.