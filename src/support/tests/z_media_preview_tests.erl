-module(z_media_preview_tests).

-include_lib("eunit/include/eunit.hrl").


cmd_args_jpeg_test() ->
    Props = [{width,100}, {height,66}, {mime,"image/jpeg"}, {orientation,1}],
    Filters = [{crop,center}, {width,80}, {height,80}],
    {_W,_H,Args} = z_media_preview:cmd_args(Props, Filters),
    CmdArgs = lists:flatten(z_utils:combine(32, Args)),
    ?assertEqual("-background \"white\" -layers \"flatten\"   -gravity West -extent 122x80 -thumbnail 122x80\\! -gravity NorthWest -crop 80x80+21+0 +repage -colorspace \"RGB\"   -unsharp 0.3x0.7  -quality 99",
                 CmdArgs).


cmd_args_gif_test() ->
    Props = [{width,100}, {height,66}, {mime,"image/gif"}, {orientation,1}],
    Filters = [{crop,center}, {width,80}, {height,80}],
    {_W,_H,Args} = z_media_preview:cmd_args(Props, Filters),
    CmdArgs = lists:flatten(z_utils:combine(32, Args)),
    ?assertEqual("-coalesce   -gravity West -extent 122x80 -thumbnail 122x80\\! -gravity NorthWest -crop 80x80+21+0 +repage -colorspace \"RGB\"   -quality 99",
                 CmdArgs).

