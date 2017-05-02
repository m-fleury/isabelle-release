/*  Title:      Pure/Admin/build_log.scala
    Author:     Makarius

Management of build log files and database storage.
*/

package isabelle


import java.io.{File => JFile}
import java.time.ZoneId
import java.time.format.{DateTimeFormatter, DateTimeParseException}
import java.util.Locale
import java.sql.PreparedStatement

import scala.collection.immutable.SortedMap
import scala.collection.mutable
import scala.util.matching.Regex


object Build_Log
{
  /** content **/

  /* properties */

  object Prop
  {
    val build_tags = SQL.Column.string("build_tags")  // lines
    val build_args = SQL.Column.string("build_args")  // lines
    val build_group_id = SQL.Column.string("build_group_id")
    val build_id = SQL.Column.string("build_id")
    val build_engine = SQL.Column.string("build_engine")
    val build_host = SQL.Column.string("build_host")
    val build_start = SQL.Column.date("build_start")
    val build_end = SQL.Column.date("build_end")
    val isabelle_version = SQL.Column.string("isabelle_version")
    val afp_version = SQL.Column.string("afp_version")

    val all_props: List[SQL.Column] =
      List(build_tags, build_args, build_group_id, build_id, build_engine,
        build_host, build_start, build_end, isabelle_version, afp_version)
  }


  /* settings */

  object Settings
  {
    val ISABELLE_BUILD_OPTIONS = SQL.Column.string("ISABELLE_BUILD_OPTIONS")
    val ML_PLATFORM = SQL.Column.string("ML_PLATFORM")
    val ML_HOME = SQL.Column.string("ML_HOME")
    val ML_SYSTEM = SQL.Column.string("ML_SYSTEM")
    val ML_OPTIONS = SQL.Column.string("ML_OPTIONS")

    val ml_settings = List(ML_PLATFORM, ML_HOME, ML_SYSTEM, ML_OPTIONS)
    val all_settings = ISABELLE_BUILD_OPTIONS :: ml_settings

    type Entry = (String, String)
    type T = List[Entry]

    object Entry
    {
      def unapply(s: String): Option[Entry] =
        s.indexOf('=') match {
          case -1 => None
          case i =>
            val a = s.substring(0, i)
            val b = Library.perhaps_unquote(s.substring(i + 1))
            Some((a, b))
        }
      def apply(a: String, b: String): String = a + "=" + quote(b)
      def getenv(a: String): String = apply(a, Isabelle_System.getenv(a))
    }

    def show(): String =
      cat_lines(
        List(Entry.getenv(ISABELLE_BUILD_OPTIONS.name), "") :::
        ml_settings.map(c => Entry.getenv(c.name)))
  }


  /* file names */

  def log_date(date: Date): String =
    String.format(Locale.ROOT, "%s.%05d",
      DateTimeFormatter.ofPattern("yyyy-MM-dd").format(date.rep),
      new java.lang.Long((date.time - date.midnight.time).ms / 1000))

  def log_subdir(date: Date): Path =
    Path.explode("log") + Path.explode(date.rep.getYear.toString)

  def log_filename(engine: String, date: Date, more: List[String] = Nil): Path =
    Path.explode((engine :: log_date(date) :: more).mkString("", "_", ".log"))



  /** log file **/

  def print_date(date: Date): String = Log_File.Date_Format(date)

  object Log_File
  {
    /* log file */

    def plain_name(name: String): String =
    {
      List(".log", ".log.gz", ".log.xz", ".gz", ".xz").find(name.endsWith(_)) match {
        case Some(s) => Library.try_unsuffix(s, name).get
        case None => name
      }
    }

    def apply(name: String, lines: List[String]): Log_File =
      new Log_File(plain_name(name), lines)

    def apply(name: String, text: String): Log_File =
      Log_File(name, Library.trim_split_lines(text))

    def apply(file: JFile): Log_File =
    {
      val name = file.getName
      val text =
        if (name.endsWith(".gz")) File.read_gzip(file)
        else if (name.endsWith(".xz")) File.read_xz(file)
        else File.read(file)
      apply(name, text)
    }

    def apply(path: Path): Log_File = apply(path.file)


    /* log file collections */

    def is_log(file: JFile,
      prefixes: List[String] =
        List(Build_History.log_prefix, Identify.log_prefix, Isatest.log_prefix,
          AFP_Test.log_prefix, Jenkins.log_prefix),
      suffixes: List[String] = List(".log", ".log.gz", ".log.xz")): Boolean =
    {
      val name = file.getName

      prefixes.exists(name.startsWith(_)) &&
      suffixes.exists(name.endsWith(_)) &&
      name != "isatest.log" &&
      name != "afp-test.log" &&
      name != "main.log"
    }

    def find_files(dirs: Iterable[Path]): List[JFile] =
      dirs.iterator.flatMap(dir => File.find_files(dir.file, is_log(_))).toList


    /* date format */

    val Date_Format =
    {
      val fmts =
        Date.Formatter.variants(
          List("EEE MMM d HH:mm:ss O yyyy", "EEE MMM d HH:mm:ss VV yyyy"),
          List(Locale.ENGLISH, Locale.GERMAN)) :::
        List(
          DateTimeFormatter.RFC_1123_DATE_TIME,
          Date.Formatter.pattern("EEE MMM d HH:mm:ss yyyy").withZone(ZoneId.of("Europe/Berlin")))

      def tune_timezone(s: String): String =
        s match {
          case "CET" | "MET" => "GMT+1"
          case "CEST" | "MEST" => "GMT+2"
          case "EST" => "Europe/Berlin"
          case _ => s
        }
      def tune_weekday(s: String): String =
        s match {
          case "Die" => "Di"
          case "Mit" => "Mi"
          case "Don" => "Do"
          case "Fre" => "Fr"
          case "Sam" => "Sa"
          case "Son" => "So"
          case _ => s
        }

      def tune(s: String): String =
        Word.implode(
          Word.explode(s) match {
            case a :: "M\uFFFDr" :: bs => tune_weekday(a) :: "Mär" :: bs.map(tune_timezone(_))
            case a :: bs => tune_weekday(a) :: bs.map(tune_timezone(_))
            case Nil => Nil
          }
        )

      Date.Format.make(fmts, tune)
    }


    /* inlined content */

    def print_props(marker: String, props: Properties.T): String =
      marker + YXML.string_of_body(XML.Encode.properties(Properties.encode_lines(props)))
  }

  class Log_File private(val name: String, val lines: List[String])
  {
    log_file =>

    override def toString: String = name

    def text: String = cat_lines(lines)

    def err(msg: String): Nothing =
      error("Error in log file " + quote(name) + ": " + msg)


    /* date format */

    object Strict_Date
    {
      def unapply(s: String): Some[Date] =
        try { Some(Log_File.Date_Format.parse(s)) }
        catch { case exn: DateTimeParseException => log_file.err(exn.getMessage) }
    }


    /* inlined content */

    def find[A](f: String => Option[A]): Option[A] =
      lines.iterator.map(f).find(_.isDefined).map(_.get)

    def find_line(marker: String): Option[String] =
      find(Library.try_unprefix(marker, _))

    def find_match(regex: Regex): Option[String] =
      lines.iterator.map(regex.unapplySeq(_)).find(res => res.isDefined && res.get.length == 1).
        map(res => res.get.head)


    /* settings */

    def get_setting(a: String): Option[Settings.Entry] =
      lines.find(_.startsWith(a + "=")) match {
        case Some(line) => Settings.Entry.unapply(line)
        case None => None
      }

    def get_all_settings: Settings.T =
      for { c <- Settings.all_settings; entry <- get_setting(c.name) }
      yield entry


    /* properties (YXML) */

    val xml_cache = new XML.Cache()

    def parse_props(text: String): Properties.T =
      xml_cache.props(Properties.decode_lines(XML.Decode.properties(YXML.parse_body(text))))

    def filter_props(marker: String): List[Properties.T] =
      for {
        line <- lines
        s <- Library.try_unprefix(marker, line)
        if YXML.detect(s)
      } yield parse_props(s)

    def find_props(marker: String): Option[Properties.T] =
      find_line(marker) match {
        case Some(text) if YXML.detect(text) => Some(parse_props(text))
        case _ => None
      }


    /* parse various formats */

    def parse_meta_info(): Meta_Info = Build_Log.parse_meta_info(log_file)

    def parse_build_info(ml_statistics: Boolean = false): Build_Info =
      Build_Log.parse_build_info(log_file, ml_statistics)

    def parse_session_info(
        command_timings: Boolean = false,
        ml_statistics: Boolean = false,
        task_statistics: Boolean = false): Session_Info =
      Build_Log.parse_session_info(log_file, command_timings, ml_statistics, task_statistics)
  }



  /** digested meta info: produced by Admin/build_history in log.xz file **/

  object Meta_Info
  {
    val empty: Meta_Info = Meta_Info(Nil, Nil)

    val log_name = SQL.Column.string("log_name", primary_key = true)
    val table =
      SQL.Table("isabelle_build_log_meta_info", log_name :: Prop.all_props ::: Settings.all_settings)
  }

  sealed case class Meta_Info(props: Properties.T, settings: Settings.T)
  {
    def is_empty: Boolean = props.isEmpty && settings.isEmpty

    def get(c: SQL.Column): Option[String] =
      Properties.get(props, c.name) orElse
      Properties.get(settings, c.name)

    def get_date(c: SQL.Column): Option[Date] =
      get(c).map(Log_File.Date_Format.parse(_))
  }

  object Identify
  {
    val log_prefix = "isabelle_identify_"

    def engine(log_file: Log_File): String =
      if (log_file.name.startsWith(Jenkins.log_prefix)) "jenkins_identify"
      else "identify"

    def content(date: Date, isabelle_version: Option[String], afp_version: Option[String]): String =
      terminate_lines(
        List("isabelle_identify: " + Build_Log.print_date(date), "") :::
        isabelle_version.map("Isabelle version: " + _).toList :::
        afp_version.map("AFP version: " + _).toList)

    val Start = new Regex("""^isabelle_identify: (.+)$""")
    val No_End = new Regex("""$.""")
    val Isabelle_Version = new Regex("""^Isabelle version: (\S+)$""")
    val AFP_Version = new Regex("""^AFP version: (\S+)$""")
  }

  object Isatest
  {
    val log_prefix = "isatest-makeall-"
    val engine = "isatest"
    val Start = new Regex("""^------------------- starting test --- (.+) --- (.+)$""")
    val End = new Regex("""^------------------- test (?:successful|FAILED) --- (.+) --- .*$""")
    val Isabelle_Version = new Regex("""^Isabelle version: (\S+)$""")
    val No_AFP_Version = new Regex("""$.""")
  }

  object AFP_Test
  {
    val log_prefix = "afp-test-devel-"
    val engine = "afp-test"
    val Start = new Regex("""^Start test(?: for .+)? at ([^,]+), (.*)$""")
    val Start_Old = new Regex("""^Start test(?: for .+)? at ([^,]+)$""")
    val End = new Regex("""^End test on (.+), .+, elapsed time:.*$""")
    val Isabelle_Version = new Regex("""^Isabelle version: .* -- hg id (\S+)$""")
    val AFP_Version = new Regex("""^AFP version: .* -- hg id (\S+)$""")
    val Bad_Init = new Regex("""^cp:.*: Disc quota exceeded$""")
  }

  object Jenkins
  {
    val log_prefix = "jenkins_"
    val engine = "jenkins"
    val Host = new Regex("""^Building remotely on (\S+) \((\S+)\).*$""")
    val Start = new Regex("""^(?:Started by an SCM change|Started from command line by admin|).*$""")
    val Start_Date = new Regex("""^Build started at (.+)$""")
    val No_End = new Regex("""$.""")
    val Isabelle_Version =
      new Regex("""^(?:Build for Isabelle id |Isabelle id |ISABELLE_CI_REPO_ID=")(\w+).*$""")
    val AFP_Version =
      new Regex("""^(?:Build for AFP id |AFP id |ISABELLE_CI_AFP_ID=")(\w+).*$""")
    val CONFIGURATION = "=== CONFIGURATION ==="
    val BUILD = "=== BUILD ==="
  }

  private def parse_meta_info(log_file: Log_File): Meta_Info =
  {
    def parse(engine: String, host: String, start: Date,
      End: Regex, Isabelle_Version: Regex, AFP_Version: Regex): Meta_Info =
    {
      val build_id =
      {
        val prefix = if (host != "") host else if (engine != "") engine else ""
        (if (prefix == "") "build" else prefix) + ":" + start.time.ms
      }
      val build_engine = if (engine == "") Nil else List(Prop.build_engine.name -> engine)
      val build_host = if (host == "") Nil else List(Prop.build_host.name -> host)

      val start_date = List(Prop.build_start.name -> print_date(start))
      val end_date =
        log_file.lines.last match {
          case End(log_file.Strict_Date(end_date)) =>
            List(Prop.build_end.name -> print_date(end_date))
          case _ => Nil
        }

      val isabelle_version =
        log_file.find_match(Isabelle_Version).map(Prop.isabelle_version.name -> _)
      val afp_version =
        log_file.find_match(AFP_Version).map(Prop.afp_version.name -> _)

      Meta_Info((Prop.build_id.name -> build_id) :: build_engine ::: build_host :::
          start_date ::: end_date ::: isabelle_version.toList ::: afp_version.toList,
        log_file.get_all_settings)
    }

    log_file.lines match {
      case line :: _ if line.startsWith(Build_History.META_INFO_MARKER) =>
        Meta_Info(log_file.find_props(Build_History.META_INFO_MARKER).get,
          log_file.get_all_settings)

      case Identify.Start(log_file.Strict_Date(start)) :: _ =>
        parse(Identify.engine(log_file), "", start, Identify.No_End,
          Identify.Isabelle_Version, Identify.AFP_Version)

      case Isatest.Start(log_file.Strict_Date(start), host) :: _ =>
        parse(Isatest.engine, host, start, Isatest.End,
          Isatest.Isabelle_Version, Isatest.No_AFP_Version)

      case AFP_Test.Start(log_file.Strict_Date(start), host) :: _ =>
        parse(AFP_Test.engine, host, start, AFP_Test.End,
          AFP_Test.Isabelle_Version, AFP_Test.AFP_Version)

      case AFP_Test.Start_Old(log_file.Strict_Date(start)) :: _ =>
        parse(AFP_Test.engine, "", start, AFP_Test.End,
          AFP_Test.Isabelle_Version, AFP_Test.AFP_Version)

      case Jenkins.Start() :: _ =>
        log_file.lines.dropWhile(_ != Jenkins.BUILD) match {
          case Jenkins.BUILD :: _ :: Jenkins.Start_Date(log_file.Strict_Date(start)) :: _ =>
            val host =
              log_file.lines.takeWhile(_ != Jenkins.CONFIGURATION).collectFirst({
                case Jenkins.Host(a, b) => a + "." + b
              }).getOrElse("")
            parse(Jenkins.engine, host, start.to(ZoneId.of("Europe/Berlin")), Jenkins.No_End,
              Jenkins.Isabelle_Version, Jenkins.AFP_Version)
          case _ => Meta_Info.empty
        }

      case line :: _ if line.startsWith("\u0000") => Meta_Info.empty
      case List(Isatest.End(_)) => Meta_Info.empty
      case _ :: AFP_Test.Bad_Init() :: _ => Meta_Info.empty
      case Nil => Meta_Info.empty

      case _ => log_file.err("cannot detect log file format")
    }
  }



  /** build info: toplevel output of isabelle build or Admin/build_history **/

  val ML_STATISTICS_MARKER = "\fML_statistics = "
  val SESSION_NAME = "session_name"

  object Session_Status extends Enumeration
  {
    val existing, finished, failed, cancelled = Value
  }

  object Session_Entry
  {
    val empty: Session_Entry = Session_Entry()
  }

  sealed case class Session_Entry(
    chapter: String = "",
    groups: List[String] = Nil,
    threads: Option[Int] = None,
    timing: Timing = Timing.zero,
    ml_timing: Timing = Timing.zero,
    heap_size: Option[Long] = None,
    status: Option[Session_Status.Value] = None,
    ml_statistics: List[Properties.T] = Nil)
  {
    def proper_chapter: Option[String] = if (chapter == "") None else Some(chapter)
    def proper_groups: Option[String] = if (groups.isEmpty) None else Some(cat_lines(groups))
    def finished: Boolean = status == Some(Session_Status.finished)
  }

  object Build_Info
  {
    val session_name = SQL.Column.string("session_name", primary_key = true)
    val chapter = SQL.Column.string("chapter")
    val groups = SQL.Column.string("groups")
    val threads = SQL.Column.int("threads")
    val timing_elapsed = SQL.Column.long("timing_elapsed")
    val timing_cpu = SQL.Column.long("timing_cpu")
    val timing_gc = SQL.Column.long("timing_gc")
    val ml_timing_elapsed = SQL.Column.long("ml_timing_elapsed")
    val ml_timing_cpu = SQL.Column.long("ml_timing_cpu")
    val ml_timing_gc = SQL.Column.long("ml_timing_gc")
    val heap_size = SQL.Column.long("heap_size")
    val status = SQL.Column.string("status")
    val ml_statistics = SQL.Column.bytes("ml_statistics")

    val sessions_table =
      SQL.Table("isabelle_build_log_sessions",
        List(Meta_Info.log_name, session_name, chapter, groups, threads, timing_elapsed, timing_cpu,
          timing_gc, ml_timing_elapsed, ml_timing_cpu, ml_timing_gc, heap_size, status))
    val ml_statistics_table =
      SQL.Table("isabelle_build_log_ml_statistics",
        List(Meta_Info.log_name, session_name, ml_statistics))
  }

  sealed case class Build_Info(sessions: Map[String, Session_Entry])
  {
    def session(name: String): Session_Entry = sessions(name)
    def get_session(name: String): Option[Session_Entry] = sessions.get(name)

    def get_default[A](name: String, f: Session_Entry => A, x: A): A =
      get_session(name) match {
        case Some(entry) => f(entry)
        case None => x
      }

    def finished_sessions: List[String] = sessions.keySet.iterator.filter(finished(_)).toList
    def finished(name: String): Boolean = get_default(name, _.finished, false)
    def timing(name: String): Timing = get_default(name, _.timing, Timing.zero)
    def ml_timing(name: String): Timing = get_default(name, _.ml_timing, Timing.zero)
    def ml_statistics(name: String): ML_Statistics =
      get_default(name, entry => ML_Statistics(name, entry.ml_statistics), ML_Statistics.empty)
  }

  private def parse_build_info(log_file: Log_File, parse_ml_statistics: Boolean): Build_Info =
  {
    object Chapter_Name
    {
      def unapply(s: String): Some[(String, String)] =
        space_explode('/', s) match {
          case List(chapter, name) => Some((chapter, name))
          case _ => Some(("", s))
        }
    }

    val Session_No_Groups = new Regex("""^Session (\S+)$""")
    val Session_Groups = new Regex("""^Session (\S+) \((.*)\)$""")
    val Session_Finished1 =
      new Regex("""^Finished (\S+) \((\d+):(\d+):(\d+) elapsed time, (\d+):(\d+):(\d+) cpu time.*$""")
    val Session_Finished2 =
      new Regex("""^Finished (\S+) \((\d+):(\d+):(\d+) elapsed time.*$""")
    val Session_Timing =
      new Regex("""^Timing (\S+) \((\d+) threads, (\d+\.\d+)s elapsed time, (\d+\.\d+)s cpu time, (\d+\.\d+)s GC time.*$""")
    val Session_Started = new Regex("""^(?:Running|Building) (\S+) \.\.\.$""")
    val Session_Failed = new Regex("""^(\S+) FAILED""")
    val Session_Cancelled = new Regex("""^(\S+) CANCELLED""")
    val Heap = new Regex("""^Heap (\S+) \((\d+) bytes\)$""")

    var chapter = Map.empty[String, String]
    var groups = Map.empty[String, List[String]]
    var threads = Map.empty[String, Int]
    var timing = Map.empty[String, Timing]
    var ml_timing = Map.empty[String, Timing]
    var started = Set.empty[String]
    var failed = Set.empty[String]
    var cancelled = Set.empty[String]
    var heap_sizes = Map.empty[String, Long]
    var ml_statistics = Map.empty[String, List[Properties.T]]

    def all_sessions: Set[String] =
      chapter.keySet ++ groups.keySet ++ threads.keySet ++ timing.keySet ++ ml_timing.keySet ++
      failed ++ cancelled ++ started ++ heap_sizes.keySet ++ ml_statistics.keySet


    for (line <- log_file.lines) {
      line match {
        case Session_No_Groups(Chapter_Name(chapt, name)) =>
          chapter += (name -> chapt)
          groups += (name -> Nil)

        case Session_Groups(Chapter_Name(chapt, name), grps) =>
          chapter += (name -> chapt)
          groups += (name -> Word.explode(grps))

        case Session_Started(name) =>
          started += name

        case Session_Finished1(name,
            Value.Int(e1), Value.Int(e2), Value.Int(e3),
            Value.Int(c1), Value.Int(c2), Value.Int(c3)) =>
          val elapsed = Time.hms(e1, e2, e3)
          val cpu = Time.hms(c1, c2, c3)
          timing += (name -> Timing(elapsed, cpu, Time.zero))

        case Session_Finished2(name,
            Value.Int(e1), Value.Int(e2), Value.Int(e3)) =>
          val elapsed = Time.hms(e1, e2, e3)
          timing += (name -> Timing(elapsed, Time.zero, Time.zero))

        case Session_Timing(name,
            Value.Int(t), Value.Double(e), Value.Double(c), Value.Double(g)) =>
          val elapsed = Time.seconds(e)
          val cpu = Time.seconds(c)
          val gc = Time.seconds(g)
          ml_timing += (name -> Timing(elapsed, cpu, gc))
          threads += (name -> t)

        case Heap(name, Value.Long(size)) =>
          heap_sizes += (name -> size)

        case _
        if parse_ml_statistics && line.startsWith(ML_STATISTICS_MARKER) && YXML.detect(line) =>
          val (name, props) =
            Library.try_unprefix(ML_STATISTICS_MARKER, line).map(log_file.parse_props(_)) match {
              case Some((SESSION_NAME, session_name) :: props) => (session_name, props)
              case _ => log_file.err("malformed ML_statistics " + quote(line))
            }
          ml_statistics += (name -> (props :: ml_statistics.getOrElse(name, Nil)))

        case _ =>
      }
    }

    val sessions =
      Map(
        (for (name <- all_sessions.toList) yield {
          val status =
            if (failed(name)) Session_Status.failed
            else if (cancelled(name)) Session_Status.cancelled
            else if (timing.isDefinedAt(name) || ml_timing.isDefinedAt(name))
              Session_Status.finished
            else if (started(name)) Session_Status.failed
            else Session_Status.existing
          val entry =
            Session_Entry(
              chapter = chapter.getOrElse(name, ""),
              groups = groups.getOrElse(name, Nil),
              threads = threads.get(name),
              timing = timing.getOrElse(name, Timing.zero),
              ml_timing = ml_timing.getOrElse(name, Timing.zero),
              heap_size = heap_sizes.get(name),
              status = Some(status),
              ml_statistics = ml_statistics.getOrElse(name, Nil).reverse)
          (name -> entry)
        }):_*)
    Build_Info(sessions)
  }



  /** session info: produced by isabelle build as session log.gz file **/

  sealed case class Session_Info(
    session_timing: Properties.T,
    command_timings: List[Properties.T],
    ml_statistics: List[Properties.T],
    task_statistics: List[Properties.T])

  private def parse_session_info(
    log_file: Log_File,
    command_timings: Boolean,
    ml_statistics: Boolean,
    task_statistics: Boolean): Session_Info =
  {
    Session_Info(
      session_timing = log_file.find_props("\fTiming = ") getOrElse Nil,
      command_timings = if (command_timings) log_file.filter_props("\fcommand_timing = ") else Nil,
      ml_statistics = if (ml_statistics) log_file.filter_props(ML_STATISTICS_MARKER) else Nil,
      task_statistics = if (task_statistics) log_file.filter_props("\ftask_statistics = ") else Nil)
  }



  /** persistent store **/

  def store(options: Options): Store = new Store(options)

  class Store private[Build_Log](options: Options) extends Properties.Store
  {
    def open_database(
      user: String = options.string("build_log_database_user"),
      password: String = options.string("build_log_database_password"),
      database: String = options.string("build_log_database_name"),
      host: String = options.string("build_log_database_host"),
      port: Int = options.int("build_log_database_port"),
      ssh_host: String = options.string("build_log_ssh_host"),
      ssh_user: String = options.string("build_log_ssh_user"),
      ssh_port: Int = options.int("build_log_ssh_port")): PostgreSQL.Database =
    {
      PostgreSQL.open_database(
        user = user, password = password, database = database, host = host, port = port,
        ssh =
          if (ssh_host == "") None
          else Some(SSH.init_context(options).open_session(ssh_host, ssh_user, port)),
        ssh_close = true)
    }

    def update_meta_info(db: SQL.Database, log_file: Log_File)
    {
      val meta_info = log_file.parse_meta_info()
      val table = Meta_Info.table

      db.transaction {
        using(db.delete(table, Meta_Info.log_name.sql_where_equal(log_file.name)))(_.execute)
        using(db.insert(table))(stmt =>
        {
          db.set_string(stmt, 1, log_file.name)
          for ((c, i) <- table.columns.tail.zipWithIndex) {
            if (c.T == SQL.Type.Date)
              db.set_date(stmt, i + 2, meta_info.get_date(c))
            else
              db.set_string(stmt, i + 2, meta_info.get(c))
          }
          stmt.execute()
        })
      }
    }

    def update_sessions(db: SQL.Database, log_file: Log_File)
    {
      val build_info = log_file.parse_build_info()
      val table = Build_Info.sessions_table

      db.transaction {
        using(db.delete(table, Meta_Info.log_name.sql_where_equal(log_file.name)))(_.execute)
        using(db.insert(table))(stmt =>
        {
          val entries_iterator =
            if (build_info.sessions.isEmpty) Iterator("" -> Session_Entry.empty)
            else build_info.sessions.iterator
          for ((session_name, session) <- entries_iterator) {
            db.set_string(stmt, 1, log_file.name)
            db.set_string(stmt, 2, session_name)
            db.set_string(stmt, 3, session.proper_chapter)
            db.set_string(stmt, 4, session.proper_groups)
            db.set_int(stmt, 5, session.threads)
            db.set_long(stmt, 6, session.timing.elapsed.proper_ms)
            db.set_long(stmt, 7, session.timing.cpu.proper_ms)
            db.set_long(stmt, 8, session.timing.gc.proper_ms)
            db.set_long(stmt, 9, session.ml_timing.elapsed.proper_ms)
            db.set_long(stmt, 10, session.ml_timing.cpu.proper_ms)
            db.set_long(stmt, 11, session.ml_timing.gc.proper_ms)
            db.set_long(stmt, 12, session.heap_size)
            db.set_string(stmt, 13, session.status.map(_.toString))
            stmt.execute()
          }
        })
      }
    }

    def update_ml_statistics(db: SQL.Database, log_file: Log_File)
    {
      val build_info = log_file.parse_build_info(ml_statistics = true)
      val table = Build_Info.ml_statistics_table

      db.transaction {
        using(db.delete(table, Meta_Info.log_name.sql_where_equal(log_file.name)))(_.execute)
        using(db.insert(table))(stmt =>
        {
          val ml_stats: List[(String, Option[Bytes])] =
            Par_List.map[(String, Session_Entry), (String, Option[Bytes])](
              { case (a, b) => (a, compress_properties(b.ml_statistics).proper) },
              build_info.sessions.iterator.filter(p => p._2.ml_statistics.nonEmpty).toList)
          val entries = if (ml_stats.nonEmpty) ml_stats else List("" -> None)
          for ((session_name, ml_statistics) <- entries) {
            db.set_string(stmt, 1, log_file.name)
            db.set_string(stmt, 2, session_name)
            db.set_bytes(stmt, 3, ml_statistics)
            stmt.execute()
          }
        })
      }
    }

    def write_info(db: SQL.Database, files: List[JFile], ml_statistics: Boolean = false)
    {
      class Table_Status(table: SQL.Table, update_db: (SQL.Database, Log_File) => Unit)
      {
        private var known: Set[String] =
        {
          db.create_table(table)
          val key = Meta_Info.log_name
          using(db.select(table, List(key), distinct = true))(
            stmt => SQL.iterator(stmt.executeQuery)(db.string(_, key)).toSet)
        }
        def required(file: JFile): Boolean = !known(Log_File.plain_name(file.getName))
        def update(log_file: Log_File)
        {
          if (!known(log_file.name)) {
            update_db(db, log_file)
            known += log_file.name
          }
        }
      }
      val status =
        List(
          new Table_Status(Meta_Info.table, update_meta_info _),
          new Table_Status(Build_Info.sessions_table, update_sessions _),
          new Table_Status(Build_Info.ml_statistics_table,
            if (ml_statistics) update_ml_statistics _
            else (_: SQL.Database, _: Log_File) => ()))

      for (file_group <- files.filter(file => status.exists(_.required(file))).grouped(100)) {
        val log_files = Par_List.map[JFile, Log_File](Log_File.apply _, file_group)
        db.transaction { log_files.foreach(log_file => status.foreach(_.update(log_file))) }
      }
    }

    def read_meta_info(db: SQL.Database, log_name: String): Option[Meta_Info] =
    {
      val table = Meta_Info.table
      val columns = table.columns.tail
      using(db.select(table, columns, Meta_Info.log_name.sql_where_equal(log_name)))(stmt =>
      {
        val rs = stmt.executeQuery
        if (!rs.next) None
        else {
          val results =
            columns.map(c => c.name ->
              (if (c.T == SQL.Type.Date)
                db.get(rs, c, db.date _).map(Log_File.Date_Format(_))
               else
                db.get(rs, c, db.string _)))
          val n = Prop.all_props.length
          val props = for ((x, Some(y)) <- results.take(n)) yield (x, y)
          val settings = for ((x, Some(y)) <- results.drop(n)) yield (x, y)
          Some(Meta_Info(props, settings))
        }
      })
    }

    def read_build_info(
      db: SQL.Database,
      log_name: String,
      session_names: List[String] = Nil,
      ml_statistics: Boolean = false): Build_Info =
    {
      val table1 = Build_Info.sessions_table
      val table2 = Build_Info.ml_statistics_table

      val where_log_name =
        Meta_Info.log_name(table1).sql_where_equal(log_name) + " AND " +
          Build_Info.session_name(table1).sql + " <> ''"
      val where =
        if (session_names.isEmpty) where_log_name
        else
          where_log_name + " AND " +
          session_names.map(a => Build_Info.session_name(table1).sql + " = " + SQL.string(a)).
            mkString("(", " OR ", ")")

      val columns1 = table1.columns.tail.map(_.apply(table1))
      val (columns, from) =
        if (ml_statistics) {
          val columns = columns1 ::: List(Build_Info.ml_statistics(table2))
          val join =
            SQL.join_outer(table1, table2,
              Meta_Info.log_name(table1).sql + " = " +
              Meta_Info.log_name(table2).sql + " AND " +
              Build_Info.session_name(table1).sql + " = " +
              Build_Info.session_name(table2).sql)
          (columns, SQL.enclose(join))
        }
        else (columns1, table1.sql)

      val sessions =
        using(db.statement(SQL.select(columns) + from + " " + where))(stmt =>
        {
          SQL.iterator(stmt.executeQuery)(rs =>
          {
            val session_name = db.string(rs, Build_Info.session_name)
            val session_entry =
              Session_Entry(
                chapter = db.string(rs, Build_Info.chapter),
                groups = split_lines(db.string(rs, Build_Info.groups)),
                threads = db.get(rs, Build_Info.threads, db.int _),
                timing =
                  Timing(Time.ms(db.long(rs, Build_Info.timing_elapsed)),
                    Time.ms(db.long(rs, Build_Info.timing_cpu)),
                    Time.ms(db.long(rs, Build_Info.timing_gc))),
                ml_timing =
                  Timing(Time.ms(db.long(rs, Build_Info.ml_timing_elapsed)),
                    Time.ms(db.long(rs, Build_Info.ml_timing_cpu)),
                    Time.ms(db.long(rs, Build_Info.ml_timing_gc))),
                heap_size = db.get(rs, Build_Info.heap_size, db.long _),
                status =
                  db.get(rs, Build_Info.status, db.string _).
                    map(Session_Status.withName(_)),
                ml_statistics =
                  if (ml_statistics) uncompress_properties(db.bytes(rs, Build_Info.ml_statistics))
                  else Nil)
            session_name -> session_entry
          }).toMap
        })
      Build_Info(sessions)
    }
  }


  /* full view on build_log data */

  // WARNING: This may cause performance problems, e.g. with sqlitebrowser

  val full_view: SQL.View =
    SQL.View("isabelle_build_log",
      Meta_Info.table.columns :::
        Build_Info.sessions_table.columns.tail.map(_.copy(primary_key = false)))

  def create_full_view(db: SQL.Database)
  {
    if (!db.tables.contains(full_view.name)) {
      val table1 = Meta_Info.table
      val table2 = Build_Info.sessions_table
      db.create_view(full_view,
        SQL.select(Meta_Info.log_name(table1) :: full_view.columns.tail) +
        SQL.join(table1, table2,
          Meta_Info.log_name(table1).sql + " = " + Meta_Info.log_name(table2).sql))
    }
  }


  /* main operations */

  def database_update(store: Store, db: SQL.Database, dirs: List[Path],
    ml_statistics: Boolean = false, full_view: Boolean = false)
  {
    val files = Log_File.find_files(dirs)
    store.write_info(db, files, ml_statistics = ml_statistics)
    if (full_view) Build_Log.create_full_view(db)
  }
}
