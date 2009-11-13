%% @author Marc Worrell <marc@worrell.nl>
%% @copyright 2009 Marc Worrell
%% @date 2009-03-03
%% @doc Generate media urls and html for viewing media, based on the filename, size and optional filters.
%% Does not generate media previews itself, this is done when fetching the image.
%%
%% Typical urls are like: 
%% /image/2007/03/31/wedding.jpg(300x300)(crop-center)(a3ab6605e5c8ce801ac77eb76289ac12).jpg
%% /media/inline/2007/03/31/wedding.jpg
%% /media/attachment/2007/03/31/wedding.jpg

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

-module(z_media_tag).
-author("Marc Worrell <marc@worrell.nl").

%% interface functions
-export([
    viewer/3,
    tag/3,
    url/3,
    props2url/1,
    url2props/2
]).

-include_lib("zotonic.hrl").


%% @spec media_viewer(MediaReference, Options, Context) -> {ok, HtmlFragMent} | {error, Reason}
%%   MediaReference = Filename | RscId | MediaPropList
%% @doc Generate a html fragment for displaying a medium.  This can generate audio or video player html.
viewer(undefined, _Options, _Context) ->
    {ok, []};
viewer([], _Options, _Context) ->
    {ok, []};
viewer(Id, Options, Context) when is_integer(Id) ->
    viewer(m_media:get(Id, Context), Options, Context);
viewer([{_Prop, _Value}|_] = Props, Options, Context) ->
    case z_convert:to_list(proplists:get_value(filename, Props)) of
        None when None == []; None == undefined ->
            viewer1(Props, undefined, Options, Context);
        Filename ->
            FilePath = filename_to_filepath(Filename, Context),
            viewer1(Props, FilePath, Options, Context)
    end;
viewer(Filename, Options, Context) when is_binary(Filename) ->
    viewer(binary_to_list(Filename), Options, Context);
viewer(Filename, Options, Context) when is_list(Filename) ->
    FilePath = filename_to_filepath(Filename, Context),
    case z_media_identify:identify(FilePath) of
        {ok, Props} ->
            viewer1(Props, FilePath, Options, Context);
        {error, _} -> 
            % Unknown content type, we just can't display it.
            {ok, []}
    end.

    
    %% @doc Try to generate Html for the media reference.  First check if a module can do this, then 
    %% check the normal image tag.
    viewer1(Props, FilePath, Options, Context) ->
        case z_notifier:first({media_viewer, Props, FilePath, Options}, Context) of
            {ok, Html} -> {ok, Html};
            undefined -> tag(Props, Options, Context)
        end.


%% @spec tag(MediaReference, Options, Context) -> {ok, TagString} | {error, Reason}
%%   MediaReference = Filename | RscId | MediaPropList
%% @doc Generate a HTML image tag for the image with the filename and options. The medium _must_ be in
%% a format for which we can generate a preview.  Note that this will never generate video or audio.
tag(undefined, _Options, _Context) ->
    {ok, []};
tag([], _Options, _Context) ->
    {ok, []};
tag(Id, Options, Context) when is_integer(Id) ->
    tag(m_media:get(Id, Context), Options, Context);
tag([{_Prop, _Value}|_] = Props, Options, Context) ->
    case z_convert:to_list(proplists:get_value(filename, Props)) of
        None when None == undefined; None == <<>>; None == [] -> 
            case z_notifier:first({media_stillimage, Props}, Context) of
                {ok, Filename} -> tag1(Props, Filename, Options, Context);
                _ -> {ok, []}
            end;
        Filename -> 
            tag1(Props, Filename, Options, Context)
    end;
tag(Filename, Options, Context) when is_binary(Filename) ->
    tag(binary_to_list(Filename), Options, Context);
tag(Filename, Options, Context) when is_list(Filename) ->
    FilePath = filename_to_filepath(Filename, Context),
    tag1(FilePath, Filename, Options, Context).
    

    tag1(MediaRef, Filename, Options, Context) ->
        {url, Url, TagOpts, ImageOpts} = url1(Filename, Options, Context),
        % Calculate the real size of the image using the options
        TagOpts1 = case z_media_preview:size(MediaRef, ImageOpts, Context) of
                        {size, Width, Height, _Mime} ->
                            [{width,Width},{height,Height}|TagOpts];
                        _ ->
                            TagOpts
                    end,
        % Make sure the required alt tag is present
        TagOpts2 =  case proplists:get_value(alt, TagOpts1) of
                        undefined -> [{alt,""}|TagOpts1];
                        _ -> TagOpts1
                    end,
        {ok, z_tags:render_tag("img", [{src,Url}|TagOpts2])}.


%% @doc Give the filepath for the filename being served.
%% @todo Ensure the file is really in the given directory (ie. no ..'s)
filename_to_filepath(Filename, #context{host=Host} = Context) ->
    case Filename of
        "/" ++ _ ->
            Filename;
        "lib/" ++ _ -> 
            case z_module_indexer:find(lib, Filename, Context) of
                {ok, Libfile} -> Libfile;
                _ -> Filename
            end;
        _ ->
            filename:join([code:lib_dir(zotonic, priv), "sites", Host, "files", "archive", Filename])
    end.


%% @doc Give the base url for the filename being served
%% @todo Use the dispatch rules to find the correct image path (when we want that...)
filename_to_urlpath(Filename) ->
    filename:join("/image/", Filename).


%% @spec url(MediaRef, Options, Context) -> {ok, Url} | {error, Reason}
%% @doc Generate the url for the image with the filename and options
url(undefined, _Options, _Context) ->
    {error, enoent};
url(Id, Options, Context) when is_integer(Id) ->
    url(m_media:get(Id, Context), Options, Context);
url([{_Prop, _Value}|_] = Props, Options, Context) ->
    case z_convert:to_list(proplists:get_value(filename, Props)) of
        None when None == undefined; None == <<>>; None == [] -> 
            case z_notifier:first({media_stillimage, Props}, Context) of
                {ok, Filename} ->
                    {url, Url, _TagOptions, _ImageOptions} = url1(Filename, Options, Context),
                    {ok, Url};
                _ ->
                    {ok, []}
            end;
        Filename -> 
            {url, Url, _TagOptions, _ImageOptions} = url1(Filename, Options, Context),
            {ok, Url}
    end;
url(Filename, Options, Context) ->
    {url, Url, _TagOptions, _ImageOptions} = url1(Filename, Options, Context),
    {ok, Url}.


%% @spec url1(Filename, Options, Context) -> {url, Url, TagOptions, ImageOpts} | {error, Reason}
%% @doc Creates an url for the given filename and filters.  This does not check the filename or if it is convertible.
url1(Filename, Options, Context) ->
    {TagOpts, ImageOpts} = lists:partition(fun is_tagopt/1, Options),
    % Map all ImageOpts to an opt string
    UrlProps = props2url(ImageOpts),
	MimeFile = z_media_identify:guess_mime(Filename),
	{_Mime,Extension} = z_media_preview:out_mime(MimeFile, ImageOpts),
    Checksum = z_utils:checksum([Filename,UrlProps,Extension], Context),
    PropCheck = mochiweb_util:quote_plus(lists:flatten([UrlProps,$(,Checksum,$)])),
    {url, list_to_binary(filename_to_urlpath(lists:flatten([Filename,PropCheck,Extension]))), 
          TagOpts,
          ImageOpts}.


is_tagopt({alt,   _}) -> true;
is_tagopt({title, _}) -> true;
is_tagopt({class, _}) -> true;
is_tagopt({style, _}) -> true;
is_tagopt(_) -> false.


props2url(Props) -> 
    props2url(Props, undefined, undefined, []).

props2url([], Width, Height, Acc) ->
    Size =  case {Width,Height} of
                {undefined,undefined} -> [];
                {_W,undefined} -> [integer_to_list(Width)] ++ "x";
                {undefined,_H} -> [$x|integer_to_list(Height)];
                {_W,_H} -> integer_to_list(Width) ++ [$x|integer_to_list(Height)]
            end,
    lists:flatten([$(, z_utils:combine(")(", [Size|lists:reverse(Acc)]), $)]);

props2url([{width,Width}|Rest], _Width, Height, Acc) ->
    props2url(Rest, z_convert:to_integer(Width), Height, Acc);
props2url([{height,Height}|Rest], Width, _Height, Acc) ->
    props2url(Rest, Width, z_convert:to_integer(Height), Acc);
props2url([{Prop}|Rest], Width, Height, Acc) ->
    props2url(Rest, Width, Height, [atom_to_list(Prop)|Acc]);
props2url([{Prop,true}|Rest], Width, Height, Acc) ->
    props2url(Rest, Width, Height, [atom_to_list(Prop)|Acc]);
props2url([{Prop,Value}|Rest], Width, Height, Acc) ->
    props2url(Rest, Width, Height, [[atom_to_list(Prop),$-,z_convert:to_list(Value)]|Acc]).


%% @spec url2props(Url, Context) -> {Filepath,PreviewPropList,Checksum,ChecksumBaseString}
%% @doc Translate an url of the format "image.jpg(300x300)(crop-center)(checksum).jpg" to parts
%% @todo Map the extension to the format of the preview (.jpg or .png)
url2props(Url, Context) ->
    {Filepath,Rest} = lists:splitwith(fun(C) -> C =/= $( end, Url),
    PropsRoot = filename:rootname(Rest),
    % Take the checksum from the string
    LastParen = string:rchr(PropsRoot, $(),
    {Props,[$(|Check]} = lists:split(LastParen-1, PropsRoot),
    Check1 = string:strip(Check, right, $)),
    PropList = string:tokens(Props, ")("),
	FileMime = z_media_identify:guess_mime(Rest),
	{_Mime, Extension} = z_media_preview:out_mime(FileMime, PropList),
    z_utils:checksum_assert([Filepath,Props,Extension], Check1, Context),
    PropList1       = case PropList of
                        [] -> [];
                        [Size|RestProps]->
                            {W,XH} = lists:splitwith(fun(C) -> C >= $0 andalso C =< $9 end, Size),
                            SizeProps = case {W,XH} of
                                            {"", "x"}            -> [];
                                            {"", ""}             -> [];
                                            {Width, ""}          -> [{width,list_to_integer(Width)}]; 
                                            {Width, "x"}         -> [{width,list_to_integer(Width)}]; 
                                            {"", [$x|Height]}    -> [{height,list_to_integer(Height)}]; 
                                            {Width, [$x|Height]} -> [{width,list_to_integer(Width)},{height,list_to_integer(Height)}]
                                        end,
                            SizeProps ++ url2props1(RestProps, [])
                      end,
    {Filepath,PropList1,Check1,Props}.

url2props1([], Acc) ->
    lists:reverse(Acc);
url2props1([P|Rest], Acc) ->
    {Prop,Arg} = lists:splitwith(fun(C) -> C =/= $- end, P),
    Arg1 =  case Arg of
                [$-|A] -> A;
                _ -> Arg
            end,
    Filter = z_media_preview:string2filter(Prop, Arg1),
    url2props1(Rest, [Filter|Acc]).


    