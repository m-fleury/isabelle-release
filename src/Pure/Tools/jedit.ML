(*  Title:      Pure/Tools/jedit.ML
    Author:     Makarius

Support for Isabelle/jEdit.
*)

signature JEDIT =
sig
  val get_actions: unit -> string list
  val check_action: string * Position.T -> string
end;

structure JEdit: JEDIT =
struct

(* parse XML *)

fun parse_named a (XML.Elem ((b, props), _)) =
      (case Properties.get props "NAME" of
        SOME name => if a = b then [name] else []
      | NONE => [])
  | parse_named _ _ = [];

fun parse_actions (XML.Elem (("ACTIONS", _), body)) = maps (parse_named "ACTION") body
  | parse_actions _ = [];

fun parse_dockables (XML.Elem (("DOCKABLES", _), body)) =
      maps (parse_named "DOCKABLE") body
      |> maps (fn a => [a, a ^ "-toggle", a ^ "-float"])
  | parse_dockables _ = [];


(* XML resources *)

val xml_file = XML.parse o File.read;

fun xml_resource name =
  let val script = "unzip -p \"$JEDIT_HOME/dist/jedit.jar\" " ^ Bash.string name in
    (case Isabelle_System.bash_output script of
      (txt, 0) => XML.parse txt
    | (_, rc) => error ("Cannot unzip jedit.jar\nreturn code = " ^ string_of_int rc))
  end;


(* actions *)

val lazy_actions =
  Lazy.lazy (fn () =>
    (parse_actions (xml_file \<^file>\<open>~~/src/Tools/jEdit/src/actions.xml\<close>) @
      parse_dockables (xml_file \<^file>\<open>~~/src/Tools/jEdit/src/dockables.xml\<close>) @
      parse_actions (xml_resource "org/gjt/sp/jedit/actions.xml") @
      parse_dockables (xml_resource "org/gjt/sp/jedit/dockables.xml"))
    |> sort_strings);

fun get_actions () = Lazy.force lazy_actions;

fun check_action (name, pos) =
  if member (op =) (get_actions ()) name then
    let
      val ((bg1, bg2), en) =
        YXML.output_markup_elem
          (Active.make_markup Markup.jedit_actionN {implicit = false, properties = []});
      val msg = "Invoke " ^ bg1 ^ name ^ bg2 ^ name ^ en ^ " jEdit action";
    in writeln (msg ^ Position.here pos); name end
  else
    let
      val completion_report =
        Completion.make_report (name, pos)
          (fn completed =>
            get_actions ()
            |> filter completed
            |> sort_strings
            |> map (fn a => (a, ("action", a))));
    in error ("Bad jEdit action " ^ quote name ^ Position.here pos ^ completion_report) end;

val _ =
  Theory.setup
    (Thy_Output.antiquotation_verbatim_embedded \<^binding>\<open>action\<close> (Scan.lift Args.embedded_position)
      (fn ctxt => fn (name, pos) =>
        let
          val _ =
            if Context_Position.is_reported ctxt pos
            then ignore (check_action (name, pos))
            else ();
        in name end));

end;
