(*  Title:      Sequents/LK/Quantifiers.thy
    Author:     Lawrence C Paulson, Cambridge University Computer Laboratory
    Copyright   1992  University of Cambridge

Classical sequent calculus: examples with quantifiers.
*)

theory Quantifiers
imports "../LK"
begin

lemma "|- (\<forall>x. P) \<longleftrightarrow> P"
  by fast

lemma "|- (\<forall>x y. P(x,y)) \<longleftrightarrow> (\<forall>y x. P(x,y))"
  by fast

lemma "\<forall>u. P(u), \<forall>v. Q(v) |- \<forall>u v. P(u) \<and> Q(v)"
  by fast


text "Permutation of existential quantifier."

lemma "|- (\<exists>x y. P(x,y)) \<longleftrightarrow> (\<exists>y x. P(x,y))"
  by fast

lemma "|- (\<forall>x. P(x) \<and> Q(x)) \<longleftrightarrow> (\<forall>x. P(x)) \<and> (\<forall>x. Q(x))"
  by fast

(*Converse is invalid*)
lemma "|- (\<forall>x. P(x)) \<or> (\<forall>x. Q(x)) \<longrightarrow> (\<forall>x. P(x) \<or> Q(x))"
  by fast


text "Pushing \<forall>into an implication."

lemma "|- (\<forall>x. P \<longrightarrow> Q(x)) \<longleftrightarrow> (P \<longrightarrow> (\<forall>x. Q(x)))"
  by fast

lemma "|- (\<forall>x. P(x) \<longrightarrow> Q) \<longleftrightarrow> ((\<exists>x. P(x)) \<longrightarrow> Q)"
  by fast

lemma "|- (\<exists>x. P)  \<longleftrightarrow>  P"
  by fast


text "Distribution of \<exists>over disjunction."

lemma "|- (\<exists>x. P(x) \<or> Q(x)) \<longleftrightarrow> (\<exists>x. P(x)) \<or> (\<exists>x. Q(x))"
  by fast

(*Converse is invalid*)
lemma "|- (\<exists>x. P(x) \<and> Q(x)) \<longrightarrow> (\<exists>x. P(x)) \<and> (\<exists>x. Q(x))"
  by fast


text "Harder examples: classical theorems."

lemma "|- (\<exists>x. P \<longrightarrow> Q(x)) \<longleftrightarrow> (P \<longrightarrow> (\<exists>x. Q(x)))"
  by fast

lemma "|- (\<exists>x. P(x) \<longrightarrow> Q) \<longleftrightarrow> (\<forall>x. P(x)) \<longrightarrow> Q"
  by fast

lemma "|- (\<forall>x. P(x)) \<or> Q \<longleftrightarrow> (\<forall>x. P(x) \<or> Q)"
  by fast


text "Basic test of quantifier reasoning"

lemma "|- (\<exists>y. \<forall>x. Q(x,y)) \<longrightarrow> (\<forall>x. \<exists>y. Q(x,y))"
  by fast

lemma "|- (\<forall>x. Q(x)) \<longrightarrow> (\<exists>x. Q(x))"
  by fast


text "The following are invalid!"

(*INVALID*)
lemma "|- (\<forall>x. \<exists>y. Q(x,y)) \<longrightarrow> (\<exists>y. \<forall>x. Q(x,y))"
  apply fast?
  apply (rule _)
  oops

(*INVALID*)
lemma "|- (\<exists>x. Q(x)) \<longrightarrow> (\<forall>x. Q(x))"
  apply fast?
  apply (rule _)
  oops

(*INVALID*)
schematic_goal "|- P(?a) \<longrightarrow> (\<forall>x. P(x))"
  apply fast?
  apply (rule _)
  oops

(*INVALID*)
schematic_goal "|- (P(?a) \<longrightarrow> (\<forall>x. Q(x))) \<longrightarrow> (\<forall>x. P(x) \<longrightarrow> Q(x))"
  apply fast?
  apply (rule _)
  oops


text "Back to things that are provable..."

lemma "|- (\<forall>x. P(x) \<longrightarrow> Q(x)) \<and> (\<exists>x. P(x)) \<longrightarrow> (\<exists>x. Q(x))"
  by fast

(*An example of why exR should be delayed as long as possible*)
lemma "|- (P \<longrightarrow> (\<exists>x. Q(x))) \<and> P \<longrightarrow> (\<exists>x. Q(x))"
  by fast


text "Solving for a Var"

schematic_goal "|- (\<forall>x. P(x) \<longrightarrow> Q(f(x))) \<and> (\<forall>x. Q(x) \<longrightarrow> R(g(x))) \<and> P(d) \<longrightarrow> R(?a)"
  by fast


text "Principia Mathematica *11.53"

lemma "|- (\<forall>x y. P(x) \<longrightarrow> Q(y)) \<longleftrightarrow> ((\<exists>x. P(x)) \<longrightarrow> (\<forall>y. Q(y)))"
  by fast


text "Principia Mathematica *11.55"

lemma "|- (\<exists>x y. P(x) \<and> Q(x,y)) \<longleftrightarrow> (\<exists>x. P(x) \<and> (\<exists>y. Q(x,y)))"
  by fast


text "Principia Mathematica *11.61"

lemma "|- (\<exists>y. \<forall>x. P(x) \<longrightarrow> Q(x,y)) \<longrightarrow> (\<forall>x. P(x) \<longrightarrow> (\<exists>y. Q(x,y)))"
  by fast


(*21 August 88: loaded in 45.7 secs*)
(*18 September 2005: loaded in 0.114 secs*)

end
