%% @author Marc Worrell <marc@worrell.nl>
%% @copyright 2009 Marc Worrell
%% @date 2009-03-02
%%
%% @doc Identify files, fetch metadata about an image
%% @todo Recognize more files based on magic number, think of office files etc.

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

-module(z_media_identify).
-author("Marc Worrell <marc@worrell.nl").

%% interface functions
-export([
    identify/2,
	identify/3,
	identify_file/2,
	identify_file/3,
    extension/1,
	guess_mime/1
]).

-include_lib("zotonic.hrl").


%% @spec identify(File, Context) -> {ok, Meta} | {error, Error}
%% @doc Caching version of identify/1. Fetches information about an image, returns width, height, type, etc.
identify(File, Context) ->
	identify(File, File, Context).
identify(File, OriginalFilename, Context) ->
    F = fun() ->
            case m_media:identify(File, Context) of
                {ok, _Props} = Result -> Result;
                {error, _Reason} -> identify_file(File, OriginalFilename, Context)
            end
    end,
    z_depcache:memo(F, {media_identify, File}, ?DAY, [media_identify], Context).
    


%% @spec identify(File, Context) -> {ok, PropList} | {error, Reason}
%% @doc Fetch information about a file, returns mime, width, height, type, etc.
identify_file(File, Context) ->
	identify_file(File, File, Context).
identify_file(File, OriginalFilename, Context) ->
    case z_notifier:first({media_identify_file, File}, Context) of
        {ok, Props} ->
			{ok, Props};
        undefined -> 
            {OsFamily, _} = os:type(),
			case identify_file_os(OsFamily, File, OriginalFilename) of
				{error, _} ->
					%% Last resort, give ImageMagick a try
					identify_file_imagemagick(File);
				{ok, Props} ->
					%% Images, pdf and ps are further investigated by ImageMagick
					case proplists:get_value(mime, Props) of
						"image/" ++ _ -> identify_file_imagemagick(File);
						"application/pdf" -> identify_file_imagemagick(File);
						"application/postscript" -> identify_file_imagemagick(File);
						_Mime -> {ok, Props}
					end
			end
	end.

%% @spec identify_file_os(OsFamily::atom(), File::string(), OriginalFilename::string()) -> {ok, PropList} | {error, Reason}
%% @doc Identify the mime type of a file using the unix "file" command.
identify_file_os(win32, File, _OriginalFilename) ->
    {ok, [{mime, guess_mime(File)}]};

identify_file_os(unix, File, OriginalFilename) ->
	SafeFile = z_utils:os_filename(File),
	Mime = z_string:trim(os:cmd("file -b --mime-type "++SafeFile)),
	case re:run(Mime, "^[a-zA-Z0-9_\\-\\.]+/[a-zA-Z0-9\\.\\-_]+$") of
		nomatch -> 
			{error, Mime};
		{match, _} ->
			case Mime of
				"text/x-c" ->
					%% "file" does a lousy job recognizing files with curly braces in them.
					Mime2 = case guess_mime(OriginalFilename) of
						"text/" ++ _ = MimeFilename -> MimeFilename;
						"application/x-" ++ _ = MimeFilename -> MimeFilename;
						"application/json" -> "application/json";
						_ -> "text/plain"
					end,
					{ok, [{mime, Mime2}]};
				"application/x-gzip" ->
					%% Special case for the often used extension ".tgz" instead of ".tar.gz"
					case filename:extension(OriginalFilename) of
						".tgz" -> {ok, [{mime, "application/x-gzip+tar"}]};
						_ -> {ok, [{mime, "application/x-gzip"}]}
					end;
				_ ->
					{ok, [{mime, Mime}]}
			end
	end.


%% @spec identify(ImageFile) -> {ok, PropList} | {error, Reason}
%% @doc Try to identify the file using image magick
identify_file_imagemagick(ImageFile) ->
    CleanedImageFile = z_utils:os_filename(ImageFile ++ "[0]"),
    Result    = os:cmd("identify -quiet " ++ CleanedImageFile),
    % ["test/a.jpg","JPEG","3440x2285","3440x2285+0+0","8-bit","DirectClass","2.899mb"]
    % sometimes:
    % test.jpg[0]=>test.jpg JPEG 2126x1484 2126x1484+0+0 DirectClass 8-bit 836.701kb 0.130u 0:02
    [Line1|_] = string:tokens(Result, "\r\n"),
    Words = string:tokens(Line1, " "),
    WordCount = length(Words),
    Words1 = if
        WordCount > 4 -> 
            {A,_B} = lists:split(4, Words),
            A;
        true -> 
            Words
    end,
    try 
        [_Path, Type, Dim, _Dim2] = Words1,
        Mime = mime(Type),
        [Width,Height] = string:tokens(Dim, "x"),
        Props1 = [{width, list_to_integer(Width)},
                  {height, list_to_integer(Height)},
                  {mime, Mime}],
        Props2 = case Mime of
                     "image/" ++ _ ->
                         [{orientation, exif_orientation(ImageFile)} | Props1];
                     _ -> Props1
                 end,
        {ok, Props2}
    catch
        _:_ ->
            ?LOG("identify of ~p failed - ~p", [CleanedImageFile, Line1]),
            {error, "unknown result from 'identify': '"++Line1++"'"}
    end.


%% @spec mime(String) -> MimeType
%% @doc Map the type returned by ImageMagick to a mime type
%% @todo Add more imagemagick types, check the mime types
mime("JPEG") -> "image/jpeg";
mime("GIF") -> "image/gif";
mime("TIFF") -> "image/tiff";
mime("BMP") -> "image/bmp";
mime("PDF") -> "application/pdf";
mime("PS") -> "application/postscript";
mime("PS2") -> "application/postscript";
mime("PS3") -> "application/postscript";
mime("PNG") -> "image/png";
mime("PNG8") -> "image/png";
mime("PNG24") -> "image/png";
mime("PNG32") -> "image/png";
mime(Type) -> "image/" ++ string:to_lower(Type).


%% @doc Return the extension for a known mime type.
extension(B) when is_binary(B) -> 
	extension(binary_to_list(B));
extension(Mime) ->
	case lists:keysearch(Mime, 2, extension_mime()) of
		{value,{Ext,_Mime}} -> Ext;
		false -> ".bin"
	end.


%% @spec guess_mime(string()) -> string()
%% @doc  Guess the mime type of a file by the extension of its filename.
guess_mime(File) when is_binary(File) ->
	guess_mime(binary_to_list(File));
guess_mime(File) ->
    case lists:keysearch(filename:extension(File), 1, extension_mime()) of
		{value,{_Ext,Mime}} -> 
			Mime;
		false ->
			"application/octet-stream"
	end.


% @doc Return a list of mime-type with their extension.
extension_mime() ->
	[
		% Preferred extension/mime-type mapping
		{".aiff", "audio/x-aiff"},
		{".asf", "video/x-ms-asf"},
		{".au", "audio/basic"},
		{".avi", "video/msvideo"},
		{".bin", "application/octet-stream"},
		{".bmp", "image/bmp"},
		{".bz2", "application/x-bzip2"},
		{".c", "text/x-c"},
		{".csh", "application/x-csh"},
		{".css", "text/css"},
		{".diff", "text/x-diff"},
		{".doc", "application/msword"},
		{".dot", "application/x-dot"},
		{".dvi", "application/x-dvi"},
		{".dwg", "application/acad"},
		{".gif", "image/gif"},
		{".gz", "application/x-gzip"},
		{".hqx", "application/mac-binhex40"},
		{".htc", "text/x-component"},
		{".html", "text/html"},
		{".ico", "image/vnd.microsoft.icon"},
		{".jar", "application/java-archive"},
		{".jpeg", "image/jpeg"},
		{".jpg", "image/jpeg"},
		{".js", "application/x-javascript"},
		{".json", "application/json"},
		{".latex", "application/x-latex"},
		{".manifest", "text/cache-manifest"},
		{".mdb", "application/x-msaccess"},
		{".midi", "audio/midi"},
		{".mov", "video/quicktime"},
		{".mp3", "audio/mpeg"},
		{".mp4", "video/mp4"},
		{".mpg", "video/mpeg"},
		{".mpp", "application/vnd.ms-project"},
		{".patch", "text/patch"},
		{".pdf", "application/pdf"},
		{".php", "text/x-php"},
		{".png", "image/png"},
		{".ppt", "application/vnd.ms-powerpoint"},
		{".ps", "application/postscript"},
		{".sh", "text/x-shellscript"},
		{".sit", "application/x-stuffit"},
		{".svg", "image/svg+xml"},
		{".swf", "application/x-shockwave-flash"},
		{".tar", "application/x-tar"},
		{".tgz", "application/x-gzip+tar"},
		{".tif", "image/tiff"},
		{".tpl", "text/html"},
		{".txt", "text/plain"},
		{".wav", "audio/x-wav"},
		{".wmf", "application/x-msmetafile"},
		{".xhtml", "application/xhtml+xml"},
		{".xls", "application/vnd.ms-excel"},
		{".xml", "application/xml"},
		{".z", "application/x-compress"},
		{".zip", "application/zip"},
		
		% Alternative mime mappings
		{".ai", "application/postscript"},
		{".aif", "audio/x-aiff"},
		{".aifc", "audio/x-aiff"},
		{".eps", "application/postscript"},
		{".erl", "text/plain"},
		{".gzip", "application/x-gzip"},
		{".htm", "text/html"},
		{".js", "text/javascript"},
		{".js", "text/x-javascript"},
		{".mid", "audio/midi"},
		{".mpeg", "video/mpeg"},
		{".pps", "application/vnd.ms-powerpoint"},
		{".ps", "application/ps"},
		{".qt", "video/quicktime"},
		{".rtf", "application/msword"},
		{".sh", "application/x-sh"},
		{".tiff", "image/tiff"}
	].


%% Detect the exif rotation in an image and swaps width/height accordingly.
exif_orientation(InFile) ->
    %% FIXME - don't depend on external command
    case os:cmd("exif -m -t Orientation " ++ z_utils:os_filename(InFile)) of
        "top - left\n" -> 1;
        "top - right\n" -> 2;
        "bottom - right\n" -> 3;
        "bottom - left\n" -> 4;
        "left - top\n" -> 5;
        "right - top\n" -> 6;
        "right - bottom\n" -> 7;
        "left - bottom\n" -> 8;
        _ -> 1
    end.

