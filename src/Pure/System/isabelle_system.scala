/*  Title:      Pure/System/isabelle_system.scala
    Author:     Makarius

Fundamental Isabelle system environment: quasi-static module with
optional init operation.
*/

package isabelle


import java.io.{File => JFile, IOException, BufferedReader, InputStreamReader}
import java.nio.file.{Path => JPath, Files, SimpleFileVisitor, FileVisitResult}
import java.nio.file.attribute.BasicFileAttributes

import scala.collection.mutable


object Isabelle_System
{
  /** bootstrap information **/

  def jdk_home(): String =
  {
    val java_home = System.getProperty("java.home", "")
    val home = new JFile(java_home)
    val parent = home.getParent
    if (home.getName == "jre" && parent != null &&
        (new JFile(new JFile(parent, "bin"), "javac")).exists) parent
    else java_home
  }

  private def find_cygwin_root(cygwin_root0: String = ""): String =
  {
    require(Platform.is_windows)

    val cygwin_root1 = System.getenv("CYGWIN_ROOT")
    val cygwin_root2 = System.getProperty("cygwin.root")

    if (cygwin_root0 != null && cygwin_root0 != "") cygwin_root0
    else if (cygwin_root1 != null && cygwin_root1 != "") cygwin_root1
    else if (cygwin_root2 != null && cygwin_root2 != "") cygwin_root2
    else error("Cannot determine Cygwin root directory")
  }



  /** implicit settings environment **/

  @volatile private var _settings: Option[Map[String, String]] = None

  def settings(): Map[String, String] =
  {
    if (_settings.isEmpty) init()  // unsynchronized check
    _settings.get
  }

  /*
    Isabelle home precedence:
      (1) isabelle_home as explicit argument
      (2) ISABELLE_HOME process environment variable (e.g. inherited from running isabelle tool)
      (3) isabelle.home system property (e.g. via JVM application boot process)
  */
  def init(
      isabelle_home: String = "",
      cygwin_root: String = "",
      progress: Progress = Ignore_Progress): Unit = synchronized {
    if (_settings.isEmpty) {
      import scala.collection.JavaConversions._

      def set_cygwin_root()
      {
        if (Platform.is_windows)
          _settings = Some(_settings.getOrElse(Map.empty) +
            ("CYGWIN_ROOT" -> find_cygwin_root(cygwin_root)))
      }

      set_cygwin_root()

      def default(env: Map[String, String], entry: (String, String)): Map[String, String] =
        if (env.isDefinedAt(entry._1) || entry._2 == "") env
        else env + entry

      val env =
      {
        val temp_windows =
        {
          val temp = System.getenv("TEMP")
          if (temp != null && temp.contains('\\')) temp else ""
        }
        val user_home = System.getProperty("user.home", "")
        val isabelle_app = System.getProperty("isabelle.app", "")

        default(
          default(
            default(sys.env + ("ISABELLE_JDK_HOME" -> File.standard_path(jdk_home())),
              "TEMP_WINDOWS" -> temp_windows),
            "HOME" -> user_home),
          "ISABELLE_APP" -> "true")
      }

      val system_home =
        if (isabelle_home != null && isabelle_home != "") isabelle_home
        else
          env.get("ISABELLE_HOME") match {
            case None | Some("") =>
              val path = System.getProperty("isabelle.home", "")
              if (path == "") error("Unknown Isabelle home directory")
              else path
            case Some(path) => path
          }

      val settings =
      {
        val dump = JFile.createTempFile("settings", null)
        dump.deleteOnExit
        try {
          val shell_prefix =
            if (Platform.is_windows) List(find_cygwin_root(cygwin_root) + "\\bin\\bash", "-l")
            else Nil
          val cmdline =
            shell_prefix ::: List(system_home + "/bin/isabelle", "getenv", "-d", dump.toString)
          val (output, rc) = process_output(progress, raw_execute(null, env, true, cmdline: _*))
          if (rc != 0) error(output)

          val entries =
            (for (entry <- File.read(dump) split "\u0000" if entry != "") yield {
              val i = entry.indexOf('=')
              if (i <= 0) entry -> ""
              else entry.substring(0, i) -> entry.substring(i + 1)
            }).toMap
          entries + ("PATH" -> entries("PATH_JVM")) - "PATH_JVM"
        }
        finally { dump.delete }
      }
      _settings = Some(settings)
      set_cygwin_root()
    }
  }


  /* getenv */

  def getenv(name: String): String = settings.getOrElse(name, "")

  def getenv_strict(name: String): String =
  {
    val value = getenv(name)
    if (value != "") value
    else error("Undefined Isabelle environment variable: " + quote(name))
  }

  def get_cygwin_root(): String = getenv_strict("CYGWIN_ROOT")



  /** file-system operations **/

  /* source files of Isabelle/ML bootstrap */

  def source_file(path: Path): Option[Path] =
  {
    def check(p: Path): Option[Path] = if (p.is_file) Some(p) else None

    if (path.is_absolute || path.is_current) check(path)
    else {
      check(Path.explode("~~/src/Pure") + path) orElse
        (if (getenv("ML_SOURCES") == "") None
         else check(Path.explode("$ML_SOURCES") + path))
    }
  }


  /* mkdirs */

  def mkdirs(path: Path): Unit =
    if (!path.is_dir) {
      bash("perl -e \"use File::Path make_path; make_path(" + File.shell_path(path) + ");\"")
      if (!path.is_dir) error("Failed to create directory: " + quote(File.platform_path(path)))
    }



  /** external processes **/

  /* raw execute for bootstrapping */

  def raw_execute(cwd: JFile, env: Map[String, String], redirect: Boolean, args: String*): Process =
  {
    val cmdline = new java.util.LinkedList[String]
    for (s <- args) cmdline.add(s)

    val proc = new ProcessBuilder(cmdline)
    if (cwd != null) proc.directory(cwd)
    if (env != null) {
      proc.environment.clear
      for ((x, y) <- env) proc.environment.put(x, y)
    }
    proc.redirectErrorStream(redirect)
    proc.start
  }

  def process_output(progress: Progress, proc: Process): (String, Int) =
  {
    proc.getOutputStream.close

    val output =
    {
      val lines = new mutable.ListBuffer[String]

      val stdout = new BufferedReader(new InputStreamReader(proc.getInputStream, UTF8.charset))
      try {
        var line = stdout.readLine
        while (line != null) {
          progress.echo(line)
          lines += line
          line = stdout.readLine
        }
      }
      finally { stdout.close }

      cat_lines(lines.toList)
    }

    val rc =
      try { proc.waitFor }
      finally {
        proc.getInputStream.close
        proc.getErrorStream.close
        proc.destroy
        Thread.interrupted
      }

    (output, rc)
  }


  /* plain execute */

  def execute_env(cwd: JFile, env: Map[String, String], redirect: Boolean, args: String*): Process =
  {
    val cmdline =
      if (Platform.is_windows) List(get_cygwin_root() + "\\bin\\env.exe") ::: args.toList
      else args
    val env1 = if (env == null) settings else settings ++ env
    raw_execute(cwd, env1, redirect, cmdline: _*)
  }

  def execute(redirect: Boolean, args: String*): Process =
    execute_env(null, null, redirect, args: _*)


  /* tmp files */

  private def isabelle_tmp_prefix(): JFile =
  {
    val path = Path.explode("$ISABELLE_TMP_PREFIX")
    path.file.mkdirs  // low-level mkdirs
    File.platform_file(path)
  }

  def tmp_file[A](name: String, ext: String = ""): JFile =
  {
    val suffix = if (ext == "") "" else "." + ext
    val file = Files.createTempFile(isabelle_tmp_prefix().toPath, name, suffix).toFile
    file.deleteOnExit
    file
  }

  def with_tmp_file[A](name: String, ext: String = "")(body: JFile => A): A =
  {
    val file = tmp_file(name, ext)
    try { body(file) } finally { file.delete }
  }


  /* tmp dirs */

  def rm_tree(root: JFile)
  {
    root.delete
    if (root.isDirectory) {
      Files.walkFileTree(root.toPath,
        new SimpleFileVisitor[JPath] {
          override def visitFile(file: JPath, attrs: BasicFileAttributes): FileVisitResult =
          {
            Files.delete(file)
            FileVisitResult.CONTINUE
          }

          override def postVisitDirectory(dir: JPath, e: IOException): FileVisitResult =
          {
            if (e == null) {
              Files.delete(dir)
              FileVisitResult.CONTINUE
            }
            else throw e
          }
        }
      )
    }
  }

  def tmp_dir(name: String): JFile =
  {
    val dir = Files.createTempDirectory(isabelle_tmp_prefix().toPath, name).toFile
    dir.deleteOnExit
    dir
  }

  def with_tmp_dir[A](name: String)(body: JFile => A): A =
  {
    val dir = tmp_dir(name)
    try { body(dir) } finally { rm_tree(dir) }
  }


  /* kill */

  def kill(signal: String, group_pid: String): (String, Int) =
  {
    val bash =
      if (Platform.is_windows) List(get_cygwin_root() + "\\bin\\bash.exe")
      else List("/usr/bin/env", "bash")
    val cmdline = bash ::: List("-c", "kill -" + signal + " -" + group_pid)
    process_output(Ignore_Progress, raw_execute(null, null, true, cmdline: _*))
  }


  /* bash */

  private class Limited_Progress(proc: Bash.Process, progress_limit: Option[Long])
  {
    private var count = 0L
    def apply(progress: String => Unit)(line: String): Unit = synchronized {
      progress(line)
      count = count + line.length + 1
      progress_limit match {
        case Some(limit) if count > limit => proc.terminate
        case _ =>
      }
    }
  }

  def bash_env(cwd: JFile, env: Map[String, String], script: String,
    progress_stdout: String => Unit = (_: String) => (),
    progress_stderr: String => Unit = (_: String) => (),
    progress_limit: Option[Long] = None,
    strict: Boolean = true): Bash.Result =
  {
    with_tmp_file("isabelle_script") { script_file =>
      File.write(script_file, script)
      val proc = Bash.process(cwd, env, false, "bash", File.standard_path(script_file))
      proc.stdin.close

      val limited = new Limited_Progress(proc, progress_limit)
      val (_, stdout) =
        Simple_Thread.future("bash_stdout") {
          File.read_lines(proc.stdout, limited(progress_stdout))
        }
      val (_, stderr) =
        Simple_Thread.future("bash_stderr") {
          File.read_lines(proc.stderr, limited(progress_stderr))
        }

      val rc =
        try { proc.join }
        catch { case Exn.Interrupt() => proc.terminate; Exn.Interrupt.return_code }
      if (strict && rc == Exn.Interrupt.return_code) throw Exn.Interrupt()

      Bash.Result(stdout.join, stderr.join, rc)
    }
  }

  def bash(script: String): Bash.Result = bash_env(null, null, script)


  /* system tools */

  def isabelle_tool(name: String, args: String*): (String, Int) =
  {
    Path.split(getenv_strict("ISABELLE_TOOLS")).find { dir =>
      val file = (dir + Path.basic(name)).file
      try {
        file.isFile && file.canRead && file.canExecute &&
          !name.endsWith("~") && !name.endsWith(".orig")
      }
      catch { case _: SecurityException => false }
    } match {
      case Some(dir) =>
        val file = File.standard_path(dir + Path.basic(name))
        process_output(Ignore_Progress, execute(true, (List(file) ::: args.toList): _*))
      case None => ("Unknown Isabelle tool: " + name, 2)
    }
  }

  def open(arg: String): Unit =
    bash("exec \"$ISABELLE_OPEN\" '" + arg + "' >/dev/null 2>/dev/null &")

  def pdf_viewer(arg: Path): Unit =
    bash("exec \"$PDF_VIEWER\" '" + File.standard_path(arg) + "' >/dev/null 2>/dev/null &")

  def hg(cmd_line: String, cwd: Path = Path.current): Bash.Result =
    bash("cd " + File.shell_path(cwd) + " && \"${HG:-hg}\" " + cmd_line)


  /** Isabelle resources **/

  /* components */

  def components(): List[Path] =
    Path.split(getenv_strict("ISABELLE_COMPONENTS"))


  /* logic images */

  def find_logics_dirs(): List[Path] =
  {
    val ml_ident = Path.explode("$ML_IDENTIFIER").expand
    Path.split(getenv_strict("ISABELLE_PATH")).map(_ + ml_ident)
  }

  def find_logics(): List[String] =
    (for {
      dir <- find_logics_dirs()
      files = dir.file.listFiles() if files != null
      file <- files.toList if file.isFile } yield file.getName).sorted

  def default_logic(args: String*): String =
  {
    args.find(_ != "") match {
      case Some(logic) => logic
      case None => Isabelle_System.getenv_strict("ISABELLE_LOGIC")
    }
  }
}
