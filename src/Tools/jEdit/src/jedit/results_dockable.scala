/*
 * Dockable window with rendered state output
 *
 * @author Fabian Immler, TU Munich
 * @author Johannes Hölzl, TU Munich
 */

package isabelle.jedit


import isabelle.XML

import scala.swing.{BorderPanel, Component}

import java.io.StringReader
import java.awt.{BorderLayout, Dimension}
import javax.swing.{JButton, JPanel, JScrollPane}
import java.util.logging.{Logger, Level}

import org.lobobrowser.html.parser._
import org.lobobrowser.html.test._
import org.lobobrowser.html.gui._
import org.lobobrowser.html._
import org.lobobrowser.html.style.CSSUtilities
import org.lobobrowser.html.domimpl.{HTMLDocumentImpl, HTMLStyleElementImpl, NodeImpl}

import org.gjt.sp.jedit.jEdit
import org.gjt.sp.jedit.View
import org.gjt.sp.jedit.gui.DockableWindowManager
import org.gjt.sp.jedit.textarea.AntiAlias

import scala.io.Source


class Results_Dockable(view : View, position : String) extends BorderPanel
{
  // outer panel

  if (position == DockableWindowManager.FLOATING)
    preferredSize = new Dimension(500, 250)


  // global logging
  
  Logger.getLogger("org.lobobrowser").setLevel(Level.WARNING)


  // document template with styles

  private def try_file(name: String): String =
  {
    val file = Isabelle.system.platform_file(name)
    if (file.exists) Source.fromFile(file).mkString else ""
  }


  // HTML panel

  val panel = new HtmlPanel
  val ucontext = new SimpleUserAgentContext
  val rcontext = new SimpleHtmlRendererContext(panel, ucontext)
  val doc = {
    val builder = new DocumentBuilderImpl(ucontext, rcontext)
    builder.parse(new InputSourceImpl(new StringReader(
      """<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<style media="all" type="text/css">
""" +
  try_file("$ISABELLE_HOME/lib/html/isabelle.css") + "\n" +
"""
body {
  font-family: IsabelleText;
  font-size: 14pt;
}
""" +
  try_file("$ISABELLE_HOME_USER/etc/isabelle.css") + "\n" +
"""
</style>
</head>
</html>
""")))
  }

  val empty_body = XML.document_node(doc, XML.elem(HTML.BODY))
  doc.appendChild(empty_body)

  panel.setDocument(doc, rcontext)

  add(Component.wrap(panel), BorderPanel.Position.Center)

  
  // register for state-view
  Isabelle.plugin.state_update += (cmd => {
    val theory_view = Isabelle.prover_setup(view.getBuffer).get.theory_view

    Swing_Thread.later {
      val node =
        if (cmd == null) empty_body
        else {
          val xml = XML.elem(HTML.BODY,
            cmd.results(theory_view.current_document).
              map((t: XML.Tree) => XML.elem(HTML.PRE, HTML.spans(t))))
          XML.document_node(doc, xml)
        }
      doc.removeChild(doc.getLastChild())
      doc.appendChild(node)
      panel.delayedRelayout(node.asInstanceOf[NodeImpl])
    }
  })
}
