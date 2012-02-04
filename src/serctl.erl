%% Copyright (c) 2011-2012, Michael Santos <michael.santos@gmail.com>
%% All rights reserved.
%%
%% Redistribution and use in source and binary forms, with or without
%% modification, are permitted provided that the following conditions
%% are met:
%%
%% Redistributions of source code must retain the above copyright
%% notice, this list of conditions and the following disclaimer.
%%
%% Redistributions in binary form must reproduce the above copyright
%% notice, this list of conditions and the following disclaimer in the
%% documentation and/or other materials provided with the distribution.
%%
%% Neither the name of the author nor the names of its contributors
%% may be used to endorse or promote products derived from this software
%% without specific prior written permission.
%%
%% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
%% "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
%% LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
%% FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
%% COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
%% INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
%% BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
%% LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
%% CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
%% LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
%% ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
%% POSSIBILITY OF SUCH DAMAGE.
-module(serctl).
-include("serctl.hrl").

-export([
        open/1,
        close/1,

        read/2,
        write/2,

        tcgetattr/1,
        tcsetattr/3,

        cfsetispeed/2,
        cfsetospeed/2,

        constant/0, constant/1,

        termios/1,

        setflag/2,
        getflag/3,
        flow/1, flow/2,
        mode/1,
        ispeed/1, ispeed/2,
        ospeed/1, ospeed/2,
        baud/1,

        getfd/1,

        offset/2,
        wordalign/1, wordalign/2
    ]).
-export([
        init/0
    ]).


-on_load(on_load/0).


%%--------------------------------------------------------------------
%%% NIF Stubs
%%--------------------------------------------------------------------
init() ->
    on_load().

on_load() ->
    erlang:load_nif(progname(), []).

open(_) ->
    erlang:error(not_implemented).

close(_) ->
    erlang:error(not_implemented).

read(_,_) ->
    erlang:error(not_implemented).

write(_,_) ->
    erlang:error(not_implemented).

tcgetattr(_) ->
    erlang:error(not_implemented).

tcsetattr(FD, Action, Termios) when is_list(Action) ->
    Option = lists:foldl(fun(X,N) -> constant(X) bxor N end, 0, Action),
    tcsetattr(FD, Option, Termios);
tcsetattr(FD, Action, Termios) when is_atom(Action) ->
    tcsetattr(FD, constant(Action), Termios);
tcsetattr(FD, Action, #termios{} = Termios) ->
    tcsetattr(FD, Action, termios(Termios));
tcsetattr(FD, Action, Termios) ->
    tcsetattr_nif(FD, Action, Termios).

tcsetattr_nif(_,_,_) ->
    erlang:error(not_implemented).

cfsetispeed(#termios{} = Termios, Speed) ->
    cfsetispeed(termios(Termios), Speed);
cfsetispeed(Termios, Speed) when is_atom(Speed) ->
    cfsetispeed(termios(Termios), constant(Speed));
cfsetispeed(Termios, Speed) ->
    cfsetispeed_nif(Termios, Speed).

cfsetispeed_nif(_,_) ->
    erlang:error(not_implemented).

cfsetospeed(#termios{} = Termios, Speed) ->
    cfsetospeed(termios(Termios), Speed);
cfsetospeed(Termios, Speed) when is_atom(Speed) ->
    cfsetospeed(termios(Termios), constant(Speed));
cfsetospeed(Termios, Speed) ->
    cfsetospeed_nif(Termios, Speed).

cfsetospeed_nif(_,_) ->
    erlang:error(not_implemented).

constant() ->
    erlang:error(not_implemented).

constant(_) ->
    erlang:error(not_implemented).

getfd(_) ->
    erlang:error(not_implemented).


%%--------------------------------------------------------------------
%%% API
%%--------------------------------------------------------------------
setflag(Termios, Opt) when is_binary(Termios) ->
    setflag(termios(Termios), Opt);
setflag(#termios{
        cflag = Cflag0,
        lflag = Lflag0,
        iflag = Iflag0,
        oflag = Oflag0
    } = Termios, Opt) when is_list(Opt) ->
    Cflag = setflag_1(Cflag0, proplists:get_value(cflag, Opt)),
    Lflag = setflag_1(Lflag0, proplists:get_value(lflag, Opt)),
    Iflag = setflag_1(Iflag0, proplists:get_value(iflag, Opt)),
    Oflag = setflag_1(Oflag0, proplists:get_value(oflag, Opt)),

    Termios#termios{
        cflag = Cflag,
        lflag = Lflag,
        iflag = Iflag,
        oflag = Oflag
    }.

setflag_1(Val, undefined) ->
    Val;
setflag_1(Val, []) ->
    Val;
setflag_1(Bin, [{Offset, Val}|Rest]) when is_binary(Bin), Offset >= 0, Val >= 0 ->
    setflag_1(offset(Bin, {Offset, Val}), Rest);
setflag_1(Val, [{Key, false}|Rest]) ->
    Val1 = Val band bnot constant(Key),
    setflag_1(Val1, Rest);
setflag_1(Val, [{Key, true}|Rest]) ->
    Val1 = Val bor constant(Key),
    setflag_1(Val1, Rest);
setflag_1(Val, [Key|Rest]) when is_atom(Key) ->
    setflag_1(Val, [{Key, true}|Rest]).


getflag(Termios, Flag, Opt) when is_binary(Termios) ->
    getflag(termios(Termios), Flag, Opt);
getflag(#termios{} = Termios, Flag, Opt) ->
    getflag_1(Termios, Flag, Opt).

getflag_1(#termios{cflag = Flag}, cflag, Opt) ->
    getflag_2(Flag, Opt);
getflag_1(#termios{lflag = Flag}, lflag, Opt) ->
    getflag_2(Flag, Opt);
getflag_1(#termios{iflag = Flag}, iflag, Opt) ->
    getflag_2(Flag, Opt);
getflag_1(#termios{oflag = Flag}, oflag, Opt) ->
    getflag_2(Flag, Opt).

getflag_2(Flag, Opt) ->
    N = constant(Opt),
    N == Flag band N.

flow(Termios) ->
    getflag(Termios, cflag, crtscts).
flow(Termios, Bool) when Bool == true; Bool == false ->
    setflag(Termios, [{cflag, [{crtscts, Bool}]}]).

mode(raw) ->
    #termios{
        cc = lists:foldl(
            fun({Offset, Val}, Bin) ->
                    offset(Bin, {Offset, Val})
            end,
            <<0:(constant(nccs)*8)>>,   % zero'ed bytes
            [
                {constant(vmin), 1},    % Minimum number of characters
                {constant(vtime), 0}    % Timeout in deciseconds
            ]),

        iflag = constant(ignpar),       % ignore (discard) parity errors

        cflag = constant(cs8)
        bor constant(clocal)
        bor constant(crtscts)
        bor constant(cread)
    }.

ispeed(Speed) when is_binary(Speed) ->
    ispeed(termios(Speed));
ispeed(#termios{ispeed = Speed}) ->
    Speed.

ispeed(Termios, Speed) when is_binary(Termios) ->
    ispeed(termios(Termios), Speed);
ispeed(Termios, Speed) when is_atom(Speed) ->
    ispeed(Termios, constant(Speed));
ispeed(#termios{} = Termios, Speed) when is_integer(Speed) ->
    Termios#termios{ispeed = Speed}.

ospeed(Speed) when is_binary(Speed) ->
    ospeed(termios(Speed));
ospeed(#termios{ospeed = Speed}) ->
    Speed.

ospeed(Termios, Speed) when is_binary(Termios) ->
    ospeed(termios(Termios), Speed);
ospeed(Termios, Speed) when is_atom(Speed) ->
    ospeed(Termios, constant(Speed));
ospeed(#termios{} = Termios, Speed) when is_integer(Speed) ->
    Termios#termios{ospeed = Speed}.

baud(Speed) when is_integer(Speed) ->
    constant(list_to_atom("b" ++ integer_to_list(Speed))).


%% Terminal interface structure
%%
%% struct termios is used to control the behaviour of
%% the serial port. We pass the actual struct between
%% Erlang and C. Sending junk might cause the C side
%% to crash if there is a bug in the terminal lib. Using
%% a NIF resource would help but would require moving
%% some of the logic from Erlang to C (this would help
%% with portability though).
%%
%% Only the first 4 fields of the struct are standardized.
%% A simple way of handling portablity would be to parse
%% the first 4 fields and leave the rest as a binary.
%%
%% Linux:
%% #define NCCS 32
%% struct termios
%%   { 
%%           tcflag_t c_iflag;       /* input mode flags */
%%           tcflag_t c_oflag;       /* output mode flags */
%%           tcflag_t c_cflag;       /* control mode flags */
%%           tcflag_t c_lflag;       /* local mode flags */
%%           cc_t c_line;            /* line discipline */
%%           cc_t c_cc[NCCS];        /* control characters */
%%           speed_t c_ispeed;       /* input speed */
%%           speed_t c_ospeed;       /* output speed */
%%  #define _HAVE_STRUCT_TERMIOS_C_ISPEED 1
%%  #define _HAVE_STRUCT_TERMIOS_C_OSPEED 1
%%  };
%%
%% BSD (Max OS X, FreeBSD):
%% #define NCCS 20
%% struct termios {
%%         tcflag_t    c_iflag;    /* input flags */
%%         tcflag_t    c_oflag;    /* output flags */
%%         tcflag_t    c_cflag;    /* control flags */
%%         tcflag_t    c_lflag;    /* local flags */
%%         cc_t        c_cc[NCCS]; /* control chars */
%%         speed_t     c_ispeed;   /* input speed */
%%         speed_t     c_ospeed;   /* output speed */
%% };
termios(<<
    Iflag:?UINT32,          % input mode flags
    Oflag:?UINT32,          % output mode flags
    Cflag:?UINT32,          % control mode flags
    Lflag:?UINT32,          % local mode flags
    Rest/binary>>) ->

    LineSz = case os() of
        linux -> 8;
        bsd -> 0
    end,

    NCCS = constant(nccs),
    <<
    Line:LineSz,            % line discipline
    Cc:NCCS/bytes,          % control characters
    Rest1/binary
    >> = Rest,

    Pad = wordalign(LineSz div 8 + NCCS, 4),
    <<
    _:Pad,
    Ispeed:?UINT32,         % input speed
    Ospeed:?UINT32          % output speed
    >> = Rest1,
    #termios{
        iflag = Iflag,
        oflag = Oflag,
        cflag = Cflag,
        lflag = Lflag,
        line = Line,
        cc = Cc,
        ispeed = Ispeed,
        ospeed = Ospeed
    };
termios(#termios{
        iflag = Iflag,
        oflag = Oflag,
        cflag = Cflag,
        lflag = Lflag,
        line = Line,
        cc = Cc,
        ispeed = Ispeed,
        ospeed = Ospeed
    }) ->

    LineSz = case os() of
        linux -> 8;
        bsd -> 0
    end,

    NCCS = constant(nccs),

    Cc1 = case Cc of
        <<>> -> <<0:(NCCS*8)>>;
        _ -> Cc
    end,

    Pad = wordalign(LineSz div 8 + NCCS, 4),
    <<
    Iflag:?UINT32,
    Oflag:?UINT32,
    Cflag:?UINT32,
    Lflag:?UINT32,
    Line:LineSz,
    Cc1/binary,
    0:Pad,
    Ispeed:?UINT32,
    Ospeed:?UINT32
    >>.


%%--------------------------------------------------------------------
%%% Internal functions
%%--------------------------------------------------------------------
progname() ->
    filename:join([
            filename:dirname(code:which(?MODULE)),
            "..",
            "priv",
            ?MODULE
        ]).


% Return pad size in bits
wordalign(Offset) ->
    wordalign(Offset, erlang:system_info({wordsize, external})).
wordalign(Offset, Align) ->
    ((Align - (Offset rem Align)) rem Align) * 8.


offset(Cc, {Offset, Val}) when is_binary(Cc) ->
    tuple_to_binary(
        setelement(
            Offset,
            binary_to_tuple(Cc),
            Val
        )
    ).


binary_to_tuple(N) when is_binary(N) ->
    list_to_tuple(binary_to_list(N)).
tuple_to_binary(N) when is_tuple(N) ->
    list_to_binary(tuple_to_list(N)).


os() ->
    case os:type() of
        {unix, linux} -> linux;
        {unix, freebsd} -> bsd;
        {unix, darwin} -> bsd
    end.