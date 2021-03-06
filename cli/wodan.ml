open Lwt.Infix

let _ = Printexc.record_backtrace true

module Unikernel1 = Unikernel.Client(Block)

(* Implementations *)

type copts = { disk : string; }

let dump copts _prefix =
  Lwt_main.run (
    Block.connect copts.disk
    >>= fun bl ->
    Nocrypto_entropy_lwt.initialize ()
    >>= fun _nc ->
    Unikernel1.dump bl)

let restore copts =
  Lwt_main.run (
    Block.connect copts.disk
    >>= fun bl ->
    Nocrypto_entropy_lwt.initialize ()
    >>= fun _nc ->
    Unikernel1.restore bl)

let format copts =
  Lwt_main.run (
    Block.connect copts.disk
    >>= fun bl ->
    Nocrypto_entropy_lwt.initialize ()
    >>= fun _nc ->
    Unikernel1.format bl)

let help _copts man_format cmds topic = match topic with
| None -> `Help (`Pager, None) (* help about the program. *)
| Some topic ->
    let topics = "topics" :: cmds in
    let conv, _ = Cmdliner.Arg.enum (List.rev_map (fun s -> (s, s)) topics) in
    match conv topic with
    | `Error e -> `Error (false, e)
    | `Ok t when t = "topics" -> List.iter print_endline topics; `Ok ()
    | `Ok t when List.mem t cmds -> `Help (man_format, Some t)
    | `Ok _t ->
        let page = (topic, 7, "", "", ""), [`S topic; `P "Placeholder";] in
        `Ok (Cmdliner.Manpage.print man_format Format.std_formatter page)

open Cmdliner

(* Options common to all commands *)

let copts disk = { disk; }
let copts_t =
  let docs = Manpage.s_common_options in
  let disk =
    let doc = "Disk to operate on." in
    Arg.(required & pos 0 (some string) None & info [] ~docv:"DISK" ~docs ~doc)
  in
  Term.(const copts $ disk)

(* Commands *)

let dump_cmd =
  let prefix = Arg.(value & pos 1 (some string) None & info [] ~docv:"PREFIX") in
  let doc = "dump filesystem to standard output" in
  let exits = Term.default_exits in
  let man = [
    `S Manpage.s_description;
    `P "Dumps the current filesystem to standard output.
        Format is base64-encoded tab-separated values.";
    ]
  in
  Term.(const dump $ copts_t $ prefix),
  Term.info "dump" ~doc ~sdocs:Manpage.s_common_options ~exits ~man

let restore_cmd =
  let doc = "load filesystem contents from standard input" in
  let exits = Term.default_exits in
  let man =
    [`S Manpage.s_description;
     `P "Loads dump output from standard input, inserts it
         as filesystem contents.";
  ]
  in
  Term.(const restore $ copts_t),
  Term.info "restore" ~doc ~sdocs:Manpage.s_common_options ~exits ~man

let format_cmd =
  let doc = "Format a zeroed filesystem" in
  let exits = Term.default_exits in
  let man =
    [`S Manpage.s_description;
     `P "Format a filesystem that has been zeroed beforehand.";
  ]
  in
  Term.(const format $ copts_t),
  Term.info "format" ~doc ~sdocs:Manpage.s_common_options ~exits ~man

let help_cmd =
  let topic =
    let doc = "The topic to get help on. `topics' lists the topics." in
    Arg.(value & pos 0 (some string) None & info [] ~docv:"TOPIC" ~doc)
  in
  let doc = "display help about wodan and wodan commands" in
  let man =
    [`S Manpage.s_description;
     `P "Prints help about wodan commands and other subjects...";
    ]
  in
  Term.(ret
          (const help $ copts_t $ Arg.man_format $ Term.choice_names $topic)),
  Term.info "help" ~doc ~exits:Term.default_exits ~man

let default_cmd =
  let doc = "CLI for Wodan filesystems" in
  let sdocs = Manpage.s_common_options in
  let exits = Term.default_exits in
  Term.(ret (const (fun _ -> `Help (`Pager, None)) $ copts_t)),
  Term.info "wodan" ~doc ~sdocs ~exits

let cmds = [restore_cmd; dump_cmd; format_cmd; help_cmd]

let () =
  Term.(exit @@ eval_choice default_cmd cmds)

