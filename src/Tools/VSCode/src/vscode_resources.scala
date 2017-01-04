/*  Title:      Tools/VSCode/src/vscode_resources.scala
    Author:     Makarius

Resources for VSCode Language Server: file-system access and global state.
*/

package isabelle.vscode


import isabelle._

import java.io.{File => JFile}

import scala.util.parsing.input.{Reader, CharSequenceReader}


object VSCode_Resources
{
  /* internal state */

  sealed case class State(
    models: Map[JFile, Document_Model] = Map.empty,
    pending_input: Set[JFile] = Set.empty,
    pending_output: Set[JFile] = Set.empty)
}

class VSCode_Resources(
    val options: Options,
    val text_length: Text.Length,
    loaded_theories: Set[String],
    known_theories: Map[String, Document.Node.Name],
    base_syntax: Outer_Syntax,
    log: Logger = No_Logger)
  extends Resources(loaded_theories, known_theories, base_syntax, log)
{
  private val state = Synchronized(VSCode_Resources.State())


  /* document node name */

  def node_file(name: Document.Node.Name): JFile = new JFile(name.node)

  def node_name(file: JFile): Document.Node.Name =
  {
    val node = file.getPath
    val theory = Thy_Header.thy_name_bootstrap(node).getOrElse("")
    val master_dir = if (theory == "") "" else file.getParent
    Document.Node.Name(node, master_dir, theory)
  }

  override def append(dir: String, source_path: Path): String =
  {
    val path = source_path.expand
    if (dir == "" || path.is_absolute) File.platform_path(path)
    else if (path.is_current) dir
    else if (path.is_basic && !dir.endsWith("/") && !dir.endsWith(JFile.separator))
      dir + JFile.separator + File.platform_path(path)
    else if (path.is_basic) dir + File.platform_path(path)
    else new JFile(dir + JFile.separator + File.platform_path(path)).getCanonicalPath
  }

  override def with_thy_reader[A](name: Document.Node.Name, f: Reader[Char] => A): A =
  {
    val file = node_file(name)
    get_model(file) match {
      case Some(model) =>
        f(new CharSequenceReader(model.doc.make_text))
      case None if file.isFile =>
        val reader = Scan.byte_reader(file)
        try { f(reader) } finally { reader.close }
      case None =>
        error("No such file: " + quote(file.toString))
    }
  }


  /* document models */

  def get_model(file: JFile): Option[Document_Model] = state.value.models.get(file)
  def get_model(name: Document.Node.Name): Option[Document_Model] = get_model(node_file(name))

  def update_model(session: Session, file: JFile, text: String)
  {
    state.change(st =>
      {
        val model = st.models.getOrElse(file, Document_Model.init(session, node_name(file)))
        val model1 = (model.update_text(text) getOrElse model).external(false)
        st.copy(
          models = st.models + (file -> model1),
          pending_input = st.pending_input + file)
      })
  }

  def close_model(file: JFile): Option[Document_Model] =
    state.change_result(st =>
      st.models.get(file) match {
        case None => (None, st)
        case Some(model) =>
          (Some(model), st.copy(models = st.models + (file -> model.external(true))))
      })

  def sync_models(changed_files: Set[JFile]): Boolean =
    state.change_result(st =>
      {
        val changed_models =
          (for {
            (file, model) <- st.models.iterator
            if changed_files(file) && model.external_file
            model1 <-
              (try { model.update_text(File.read(file)) }
               catch { case ERROR(_) => None })
          } yield (file, model1)).toList
        if (changed_models.isEmpty) (false, st)
        else (true,
          st.copy(
            models = (st.models /: changed_models)(_ + _),
            pending_input = (st.pending_input /: changed_models.iterator.map(_._1))(_ + _)))
      })


  /* resolve dependencies */

  val thy_info = new Thy_Info(this)

  def resolve_dependencies(session: Session): Boolean =
  {
    state.change_result(st =>
      {
        val thys =
          (for ((_, model) <- st.models.iterator if model.is_theory)
           yield (model.node_name, Position.none)).toList

        val loaded_models =
          (for {
            dep <- thy_info.dependencies("", thys).deps.iterator
            file = node_file(dep.name)
            if !st.models.isDefinedAt(file)
            text <-
              try { Some(File.read(file)) }
              catch { case ERROR(_) => None }
          }
          yield {
            val model = Document_Model.init(session, node_name(file))
            val model1 = (model.update_text(text) getOrElse model).external(true)
            (file, model1)
          }).toList

        if (loaded_models.isEmpty) (false, st)
        else
          (true,
            st.copy(
              models = st.models ++ loaded_models,
              pending_input = st.pending_input ++ loaded_models.iterator.map(_._1)))
      })
  }


  /* pending input */

  def flush_input(session: Session)
  {
    state.change(st =>
      {
        val changed_models =
          (for {
            file <- st.pending_input.iterator
            model <- st.models.get(file)
            (edits, model1) <- model.flush_edits
          } yield (edits, (file, model1))).toList

        session.update(Document.Blobs.empty, changed_models.flatMap(_._1))
        st.copy(
          models = (st.models /: changed_models.iterator.map(_._2))(_ + _),
          pending_input = Set.empty)
      })
  }


  /* pending output */

  def update_output(changed_nodes: List[JFile]): Unit =
    state.change(st => st.copy(pending_output = st.pending_output ++ changed_nodes))

  def flush_output(channel: Channel)
  {
    state.change(st =>
      {
        val changed_iterator =
          for {
            file <- st.pending_output.iterator
            model <- st.models.get(file)
            rendering = model.rendering()
            (diagnostics, model1) <- model.publish_diagnostics(rendering)
          } yield {
            channel.diagnostics(file, rendering.diagnostics_output(diagnostics))
            (file, model1)
          }
        st.copy(
          models = (st.models /: changed_iterator)(_ + _),
          pending_output = Set.empty)
      }
    )
  }
}
