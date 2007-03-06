(* "$Id$" *)
(*                                                    *)
(* Formalisation of the chapter on Logical Relations  *)
(* and a Case Study in Equivalence Checking           *)
(* by Karl Crary from the book on Advanced Topics in  *)
(* Types and Programming Languages, MIT Press 2005    *)

(* The formalisation was done by Julien Narboux and   *)
(* Christian Urban                                    *)

(*<*)
theory Crary
  imports "../Nominal"
begin

(* We put this def here because of some incompatibility of LatexSugar and Nominal *)

syntax (Rule output)
  "==>" :: "prop \<Rightarrow> prop \<Rightarrow> prop"
  ("\<^raw:\mbox{}\inferrule{\mbox{>_\<^raw:}}>\<^raw:{\mbox{>_\<^raw:}}>")

  "_bigimpl" :: "asms \<Rightarrow> prop \<Rightarrow> prop"
  ("\<^raw:\mbox{}\inferrule{>_\<^raw:}>\<^raw:{\mbox{>_\<^raw:}}>")

  "_asms" :: "prop \<Rightarrow> asms \<Rightarrow> asms" 
  ("\<^raw:\mbox{>_\<^raw:}\\>/ _")

  "_asm" :: "prop \<Rightarrow> asms" ("\<^raw:\mbox{>_\<^raw:}>")

syntax (IfThen output)
  "==>" :: "prop \<Rightarrow> prop \<Rightarrow> prop"
  ("\<^raw:{\rmfamily\upshape\normalsize{}>If\<^raw:\,}> _/ \<^raw:{\rmfamily\upshape\normalsize \,>then\<^raw:\,}>/ _.")
  "_bigimpl" :: "asms \<Rightarrow> prop \<Rightarrow> prop"
  ("\<^raw:{\rmfamily\upshape\normalsize{}>If\<^raw:\,}> _ /\<^raw:{\rmfamily\upshapce\normalsize \,>then\<^raw:\,}>/ _.")
  "_asms" :: "prop \<Rightarrow> asms \<Rightarrow> asms" ("\<^raw:\mbox{>_\<^raw:}> /\<^raw:{\rmfamily\upshape\normalsize \,>and\<^raw:\,}>/ _")
  "_asm" :: "prop \<Rightarrow> asms" ("\<^raw:\mbox{>_\<^raw:}>")

syntax (IfThenNoBox output)
  "==>" :: "prop \<Rightarrow> prop \<Rightarrow> prop"
  ("\<^raw:{\rmfamily\upshape\normalsize{}>If\<^raw:\,}> _/ \<^raw:{\rmfamily\upshape\normalsize \,>then\<^raw:\,}>/ _.")
  "_bigimpl" :: "asms \<Rightarrow> prop \<Rightarrow> prop"
  ("\<^raw:{\rmfamily\upshape\normalsize{}>If\<^raw:\,}> _ /\<^raw:{\rmfamily\upshape\normalsize \,>then\<^raw:\,}>/ _.")
  "_asms" :: "prop \<Rightarrow> asms \<Rightarrow> asms" ("_ /\<^raw:{\rmfamily\upshape\normalsize \,>and\<^raw:\,}>/ _")
  "_asm" :: "prop \<Rightarrow> asms" ("_")


(*>*)

text {* 
\section{Definition of the language} 
\subsection{Definition of the terms and types} 

First we define the type of atom names which will be used for binders.
Each atom type is infinitely many atoms and equality is decidable. *}

atom_decl name 

text {* We define the datatype representing types. Although, It does not contain any binder we still use the \texttt{nominal\_datatype} command because the Nominal datatype package will prodive permutation functions and useful lemmas. *}

nominal_datatype ty = TBase 
                    | TUnit 
                    | Arrow "ty" "ty" ("_\<rightarrow>_" [100,100] 100)

text {* The datatype of terms contains a binder. The notation @{text "\<guillemotleft>name\<guillemotright> trm"} means that the name is bound inside trm. *}

nominal_datatype trm = Unit
                     | Var "name"
                     | Lam "\<guillemotleft>name\<guillemotright>trm" ("Lam [_]._" [100,100] 100)
                     | App "trm" "trm"
                     | Const "nat"

text {* As the datatype of types does not contain any binder, the application of a permutation is the identity function. In the future, this will be automatically derived by the package. *}

lemma perm_ty[simp]: 
  fixes T::"ty"
  and   pi::"name prm"
  shows "pi\<bullet>T = T"
  by (induct T rule: ty.induct_weak) (simp_all)

lemma fresh_ty[simp]:
  fixes x::"name" 
  and   T::"ty"
  shows "x\<sharp>T"
  by (simp add: fresh_def supp_def)

lemma ty_cases:
  fixes T::ty
  shows "(\<exists> T\<^isub>1 T\<^isub>2. T=T\<^isub>1\<rightarrow>T\<^isub>2) \<or> T=TUnit \<or> T=TBase"
by (induct T rule:ty.induct_weak) (auto)

text {* 
\subsection{Size functions}

We define size functions for types and terms. As Isabelle allows overloading we can use the same notation for both functions.

These function are automatically generated for non nominal datatypes. In the future, we need to extend the package to generate size function for nominal datatypes as well.
 *} 

instance ty :: size ..

nominal_primrec
  "size (TBase) = 1"
  "size (TUnit) = 1"
  "size (T\<^isub>1\<rightarrow>T\<^isub>2) = size T\<^isub>1 + size T\<^isub>2"
by (rule TrueI)+

instance trm :: size ..

nominal_primrec 
  "size (Unit) = 1"
  "size (Var x) = 1"
  "size (Lam [x].t) = size t + 1"
  "size (App t1 t2) = size t1 + size t2"
  "size (Const n) = 1"
apply(finite_guess)+
apply(rule TrueI)+
apply(simp add: fresh_nat)+
apply(fresh_guess)+
done

lemma ty_size_greater_zero[simp]:
  fixes T::"ty"
  shows "size T > 0"
by (nominal_induct rule:ty.induct) (simp_all)

text {* 
\subsection{Typing}

\subsubsection{Typing contexts}

This section contains the definition and some properties of a typing context. As the concept of context often appears in the litterature and is general, we should in the future provide these lemmas in a library.

\paragraph{Definition of the Validity of contexts}\strut\\

First we define what valid contexts are. Informally a context is valid is it does not contains twice the same variable.

We use the following two inference rules: *}

(*<*)
inductive2
  valid :: "(name \<times> 'a::pt_name) list \<Rightarrow> bool"
where
    v_nil[intro]:  "valid []"
  | v_cons[intro]: "\<lbrakk>valid \<Gamma>;a\<sharp>\<Gamma>\<rbrakk> \<Longrightarrow> valid ((a,\<sigma>)#\<Gamma>)"
(*>*)

text {*
\begin{center}
\isastyle
@{thm[mode=Rule] v_nil[no_vars]}{\sc{v\_nil}}
\qquad
@{thm[mode=Rule] v_cons[no_vars]}{\sc{v\_cons}}
\end{center}
*} 

text{* We generate the equivariance lemma for the relation \texttt{valid}. *}

nominal_inductive valid

text{* We obtain a lemma called \texttt{valid\_eqvt}:
\begin{center} 
@{thm[mode=IfThen] valid_eqvt}
\end{center}
*}


text{* We generate the inversion lemma for non empty lists. We add the \texttt{elim} attribute to tell the automated tactics to use it.
 *}

inductive_cases2  
  valid_cons_elim_auto[elim]:"valid ((x,T)#\<Gamma>)"

text{*
The generated theorem is the following:
\begin{center}
@{thm "valid_cons_elim_auto"[no_vars] }
\end{center}
*}

text{* \paragraph{Lemmas about valid contexts} 
 Now, we can prove two useful lemmas about valid contexts. 
*}

lemma fresh_context: 
  fixes  \<Gamma> :: "(name\<times>ty) list"
  and    a :: "name"
  assumes "a\<sharp>\<Gamma>"
  shows "\<not>(\<exists>\<tau>::ty. (a,\<tau>)\<in>set \<Gamma>)"
using assms by (induct \<Gamma>, auto simp add: fresh_prod fresh_list_cons fresh_atm)

lemma type_unicity_in_context:
  fixes  \<Gamma> :: "(name\<times>ty)list"
  and    pi:: "name prm"
  and    a :: "name"
  and    \<tau> :: "ty"
  assumes "valid \<Gamma>" and "(x,T\<^isub>1) \<in> set \<Gamma>" and "(x,T\<^isub>2) \<in> set \<Gamma>"
  shows "T\<^isub>1=T\<^isub>2"
using assms by (induct \<Gamma>, auto dest!: fresh_context)

text {* \paragraph{Definition of sub-contexts}

The definition of sub context is standard. We do not use the subset definition to prevent the need for unfolding the definition. We include validity in the definition to shorten the statements.
 *}


abbreviation
  "sub" :: "(name\<times>ty) list \<Rightarrow> (name\<times>ty) list \<Rightarrow> bool" (" _ \<lless> _ " [55,55] 55)
where
  "\<Gamma>\<^isub>1 \<lless> \<Gamma>\<^isub>2 \<equiv> (\<forall>a \<sigma>. (a,\<sigma>)\<in>set \<Gamma>\<^isub>1 \<longrightarrow> (a,\<sigma>)\<in>set \<Gamma>\<^isub>2) \<and> valid \<Gamma>\<^isub>2"

text {* 
\subsubsection{Definition of the typing relation}

Now, we can define the typing judgements for terms. The rules are given in figure~\ref{typing}. *}

(*<*)

inductive2
  typing :: "(name\<times>ty) list\<Rightarrow>trm\<Rightarrow>ty\<Rightarrow>bool" (" _ \<turnstile> _ : _ " [60,60,60] 60) 
where
  t_Var[intro]:   "\<lbrakk>valid \<Gamma>; (x,T)\<in>set \<Gamma>\<rbrakk>\<Longrightarrow> \<Gamma> \<turnstile> Var x : T"
| t_App[intro]:   "\<lbrakk>\<Gamma> \<turnstile> e\<^isub>1 : T\<^isub>1\<rightarrow>T\<^isub>2; \<Gamma> \<turnstile> e\<^isub>2 : T\<^isub>1\<rbrakk>\<Longrightarrow> \<Gamma> \<turnstile> App e\<^isub>1 e\<^isub>2 : T\<^isub>2"
| t_Lam[intro]:   "\<lbrakk>x\<sharp>\<Gamma>; (x,T\<^isub>1)#\<Gamma> \<turnstile> t : T\<^isub>2\<rbrakk> \<Longrightarrow> \<Gamma> \<turnstile> Lam [x].t : T\<^isub>1\<rightarrow>T\<^isub>2"
| t_Const[intro]: "valid \<Gamma> \<Longrightarrow> \<Gamma> \<turnstile> Const n : TBase"
| t_Unit[intro]:  "valid \<Gamma> \<Longrightarrow> \<Gamma> \<turnstile> Unit : TUnit"
(*>*)

text {* 
\begin{figure}
\begin{center}
\isastyle %smaller fonts
@{thm[mode=Rule] t_Var[no_vars]}{\sc{t\_Var}}\qquad
@{thm[mode=Rule] t_App[no_vars]}{\sc{t\_App}}\\
@{thm[mode=Rule] t_Lam[no_vars]}{\sc{t\_Lam}}\\
@{thm[mode=Rule] t_Const[no_vars]}{\sc{t\_Const}} \qquad
@{thm[mode=Rule] t_Unit[no_vars]}{\sc{t\_Unit}}
\end{center}
\caption{Typing rules\label{typing}}
\end{figure}
*}

lemma typing_valid:
  assumes "\<Gamma> \<turnstile> t : T"
  shows "valid \<Gamma>"
  using assms by (induct)(auto)

nominal_inductive typing

text {* 
\subsubsection{Inversion lemmas for the typing relation}

We generate some inversion lemmas for 
the typing judgment and add them as elimination rules for the automatic tactics.
During the generation of these lemmas, we need the injectivity properties of the constructor of the nominal datatypes. These are not added by default in the set of simplification rules to prevent unwanted simplifications in the rest of the development. In the future, the \texttt{inductive\_cases} will be reworked to allow to use its own set of rules instead of the whole 'simpset'.
*}

declare trm.inject [simp add]
declare ty.inject  [simp add]

inductive_cases2 t_Lam_elim_auto[elim]: "\<Gamma> \<turnstile> Lam [x].t : T"
inductive_cases2 t_Var_elim_auto[elim]: "\<Gamma> \<turnstile> Var x : T"
inductive_cases2 t_App_elim_auto[elim]: "\<Gamma> \<turnstile> App x y : T"
inductive_cases2  t_Const_elim_auto[elim]: "\<Gamma> \<turnstile> Const n : T"
inductive_cases2  t_Unit_elim_auto[elim]: "\<Gamma> \<turnstile> Unit : TUnit"

declare trm.inject [simp del]
declare ty.inject [simp del]

text {* 
\subsubsection{Strong induction principle}

Now, we define a strong induction principle. This induction principle allow us to avoid some terms during the induction. The bound variable The avoided terms ($c$)  *}

lemma typing_induct_strong
  [consumes 1, case_names t_Var t_App t_Lam t_Const t_Unit]:
    fixes  P::"'a::fs_name \<Rightarrow> (name\<times>ty) list \<Rightarrow> trm \<Rightarrow> ty \<Rightarrow>bool"
    and    x :: "'a::fs_name"
    assumes a: "\<Gamma> \<turnstile> e : T"
    and a1: "\<And>\<Gamma> x T c. \<lbrakk>valid \<Gamma>; (x,T)\<in>set \<Gamma>\<rbrakk> \<Longrightarrow> P c \<Gamma> (Var x) T"
    and a2: "\<And>\<Gamma> e\<^isub>1 T\<^isub>1 T\<^isub>2 e\<^isub>2 c. \<lbrakk>\<And>c. P c \<Gamma> e\<^isub>1 (T\<^isub>1\<rightarrow>T\<^isub>2); \<And>c. P c \<Gamma> e\<^isub>2 T\<^isub>1\<rbrakk> 
             \<Longrightarrow> P c \<Gamma> (App e\<^isub>1 e\<^isub>2) T\<^isub>2"
    and a3: "\<And>x \<Gamma> T\<^isub>1 t T\<^isub>2 c.\<lbrakk>x\<sharp>(\<Gamma>,c); \<And>c. P c ((x,T\<^isub>1)#\<Gamma>) t T\<^isub>2\<rbrakk>
             \<Longrightarrow> P c \<Gamma> (Lam [x].t) (T\<^isub>1\<rightarrow>T\<^isub>2)"
    and a4: "\<And>\<Gamma> n c. valid \<Gamma> \<Longrightarrow> P c \<Gamma> (Const n) TBase"
    and a5: "\<And>\<Gamma> c. valid \<Gamma> \<Longrightarrow> P c \<Gamma> Unit TUnit"
    shows "P c \<Gamma> e T"
proof -
  from a have "\<And>(pi::name prm) c. P c (pi\<bullet>\<Gamma>) (pi\<bullet>e) (pi\<bullet>T)"
  proof (induct)
    case (t_Var \<Gamma> x T pi c)
    have "valid \<Gamma>" by fact
    then have "valid (pi\<bullet>\<Gamma>)" by (simp only: eqvt)
    moreover
    have "(x,T)\<in>set \<Gamma>" by fact
    then have "pi\<bullet>(x,T)\<in>pi\<bullet>(set \<Gamma>)" by (simp only: pt_set_bij[OF pt_name_inst, OF at_name_inst])  
    then have "(pi\<bullet>x,T)\<in>set (pi\<bullet>\<Gamma>)" by (simp add: eqvt)
    ultimately show "P c (pi\<bullet>\<Gamma>) (pi\<bullet>(Var x)) (pi\<bullet>T)" using a1 by simp
  next
    case (t_App \<Gamma> e\<^isub>1 T\<^isub>1 T\<^isub>2 e\<^isub>2 pi c)
    thus "P c (pi\<bullet>\<Gamma>) (pi\<bullet>(App e\<^isub>1 e\<^isub>2)) (pi\<bullet>T\<^isub>2)" using a2 
      by (simp only: eqvt) (blast)
  next
    case (t_Lam x \<Gamma> T\<^isub>1 t T\<^isub>2 pi c)
    obtain y::"name" where fs: "y\<sharp>(pi\<bullet>x,pi\<bullet>\<Gamma>,pi\<bullet>t,c)" by (erule exists_fresh[OF fs_name1])
    let ?sw = "[(pi\<bullet>x,y)]"
    let ?pi' = "?sw@pi"
    have f0: "x\<sharp>\<Gamma>" by fact
    have f1: "(pi\<bullet>x)\<sharp>(pi\<bullet>\<Gamma>)" using f0 by (simp add: fresh_bij)
    have f2: "y\<sharp>?pi'\<bullet>\<Gamma>" by (auto simp add: pt_name2 fresh_left calc_atm perm_pi_simp)
      have ih1: "\<And>c. P c (?pi'\<bullet>((x,T\<^isub>1)#\<Gamma>)) (?pi'\<bullet>t) (?pi'\<bullet>T\<^isub>2)" by fact
    then have "P c (?pi'\<bullet>\<Gamma>) (Lam [y].(?pi'\<bullet>t)) (T\<^isub>1\<rightarrow>T\<^isub>2)" using fs f2 a3
      by (simp add: calc_atm)
    then have "P c (?sw\<bullet>pi\<bullet>\<Gamma>) (?sw\<bullet>(Lam [(pi\<bullet>x)].(pi\<bullet>t))) (T\<^isub>1\<rightarrow>T\<^isub>2)" 
      by (simp del: append_Cons add: calc_atm pt_name2)
    moreover have "(?sw\<bullet>pi\<bullet>\<Gamma>) = (pi\<bullet>\<Gamma>)"
      by (rule perm_fresh_fresh) (simp_all add: fs f1)
    moreover have "(?sw\<bullet>(Lam [(pi\<bullet>x)].(pi\<bullet>t))) = Lam [(pi\<bullet>x)].(pi\<bullet>t)"
      by (rule perm_fresh_fresh) (simp_all add: fs f1 fresh_atm abs_fresh)
    ultimately show "P c (pi\<bullet>\<Gamma>) (pi\<bullet>(Lam [x].t)) (pi\<bullet>T\<^isub>1\<rightarrow>T\<^isub>2)" by simp
  next
    case (t_Const \<Gamma> n pi c)
    thus "P c (pi\<bullet>\<Gamma>) (pi\<bullet>(Const n)) (pi\<bullet>TBase)" using a4 by (simp, blast intro: valid_eqvt)
  next
    case (t_Unit \<Gamma> pi c)
    thus "P c (pi\<bullet>\<Gamma>) (pi\<bullet>Unit) (pi\<bullet>TUnit)" using a5 by (simp, blast intro: valid_eqvt)
  qed 
  then have "P c (([]::name prm)\<bullet>\<Gamma>) (([]::name prm)\<bullet>e) (([]::name prm)\<bullet>T)" by blast
  then show "P c \<Gamma> e T" by simp
qed

text {* 
\subsection{Capture-avoiding substitutions}

In this section we define parallel substitution. The usual substitution will be derived as a special case of parallel substitution. But first we define a function to lookup for the term corresponding to a type in an association list. Note that if the term does not appear in the list then we return a variable of that name.\\
Should we return Some or None and put that in a library ?
 *}


fun
  lookup :: "(name\<times>trm) list \<Rightarrow> name \<Rightarrow> trm"   
where
  "lookup [] X        = Var X"
  "lookup ((Y,T)#\<theta>) X = (if X=Y then T else lookup \<theta> X)"

lemma lookup_eqvt[eqvt]:
  fixes pi::"name prm"
  and   \<theta>::"(name\<times>trm) list"
  and   X::"name"
  shows "pi\<bullet>(lookup \<theta> X) = lookup (pi\<bullet>\<theta>) (pi\<bullet>X)"
by (induct \<theta>) (auto simp add: perm_bij)

lemma lookup_fresh:
  fixes z::"name"
  assumes "z\<sharp>\<theta>" "z\<sharp>x"
  shows "z\<sharp> lookup \<theta> x"
using assms 
by (induct rule: lookup.induct) (auto simp add: fresh_list_cons)

lemma lookup_fresh':
  assumes "z\<sharp>\<theta>"
  shows "lookup \<theta> z = Var z"
using assms 
by (induct rule: lookup.induct)
   (auto simp add: fresh_list_cons fresh_prod fresh_atm)

text {* \subsubsection{Parallel substitution} *}

consts
  psubst :: "(name\<times>trm) list \<Rightarrow> trm \<Rightarrow> trm"  ("_<_>" [60,100] 100)
 
nominal_primrec
  "\<theta><(Var x)> = (lookup \<theta> x)"
  "\<theta><(App t\<^isub>1 t\<^isub>2)> = App (\<theta><t\<^isub>1>) (\<theta><t\<^isub>2>)"
  "x\<sharp>\<theta> \<Longrightarrow> \<theta><(Lam [x].t)> = Lam [x].(\<theta><t>)"
  "\<theta><(Const n)> = Const n"
  "\<theta><(Unit)> = Unit"
apply(finite_guess)+
apply(rule TrueI)+
apply(simp add: abs_fresh)+
apply(fresh_guess)+
done


text {* \subsubsection{Substitution} 

The substitution function is defined just as a special case of parallel substitution. 

*}

abbreviation 
 subst :: "trm \<Rightarrow> name \<Rightarrow> trm \<Rightarrow> trm" ("_[_::=_]" [100,100,100] 100)
where
  "t[x::=t']  \<equiv> ([(x,t')])<t>" 

lemma subst[simp]:
  shows "(Var x)[y::=t'] = (if x=y then t' else (Var x))"
  and   "(App t\<^isub>1 t\<^isub>2)[y::=t'] = App (t\<^isub>1[y::=t']) (t\<^isub>2[y::=t'])"
  and   "x\<sharp>(y,t') \<Longrightarrow> (Lam [x].t)[y::=t'] = Lam [x].(t[y::=t'])"
  and   "Const n[y::=t'] = Const n"
  and   "Unit [y::=t'] = Unit"
  by (simp_all add: fresh_list_cons fresh_list_nil)

lemma subst_eqvt[eqvt]:
  fixes pi::"name prm" 
  and   t::"trm"
  shows "pi\<bullet>(t[x::=t']) = (pi\<bullet>t)[(pi\<bullet>x)::=(pi\<bullet>t')]"
  by (nominal_induct t avoiding: x t' rule: trm.induct)
     (perm_simp add: fresh_bij)+

text {* \subsubsection{Lemmas about freshness and substitutions} *}

lemma subst_rename: 
  fixes c::"name"
  and   t1::"trm"
  assumes a: "c\<sharp>t\<^isub>1"
  shows "t\<^isub>1[a::=t\<^isub>2] = ([(c,a)]\<bullet>t\<^isub>1)[c::=t\<^isub>2]"
  using a
  apply(nominal_induct t\<^isub>1 avoiding: a c t\<^isub>2 rule: trm.induct)
  apply(simp add: trm.inject calc_atm fresh_atm abs_fresh perm_nat_def)+
  done

lemma fresh_psubst: 
  fixes z::"name"
  and   t::"trm"
  assumes "z\<sharp>t" "z\<sharp>\<theta>"
  shows "z\<sharp>(\<theta><t>)"
using assms
by (nominal_induct t avoiding: z \<theta> t rule: trm.induct)
   (auto simp add: abs_fresh lookup_fresh)

lemma fresh_subst'':
  fixes z::"name"
  and   t1::"trm"
  and   t2::"trm"
  assumes "z\<sharp>t\<^isub>2"
  shows "z\<sharp>t\<^isub>1[z::=t\<^isub>2]"
using assms 
by (nominal_induct t\<^isub>1 avoiding: t\<^isub>2 z rule: trm.induct)
   (auto simp add: abs_fresh fresh_nat fresh_atm)

lemma fresh_subst':
  fixes z::"name"
  and   t1::"trm"
  and   t2::"trm"
  assumes "z\<sharp>[y].t\<^isub>1" "z\<sharp>t\<^isub>2"
  shows "z\<sharp>t\<^isub>1[y::=t\<^isub>2]"
using assms 
by (nominal_induct t\<^isub>1 avoiding: y t\<^isub>2 z rule: trm.induct)
   (auto simp add: abs_fresh fresh_nat fresh_atm)

lemma fresh_subst:
  fixes z::"name"
  and   t1::"trm"
  and   t2::"trm"
  assumes "z\<sharp>t\<^isub>1" "z\<sharp>t\<^isub>2"
  shows "z\<sharp>t\<^isub>1[y::=t\<^isub>2]"
using assms fresh_subst'
by (auto simp add: abs_fresh) 

lemma fresh_psubst_simpl:
  assumes "x\<sharp>t"
  shows "(x,u)#\<theta><t> = \<theta><t>" 
using assms
proof (nominal_induct t avoiding: x u \<theta> rule: trm.induct)
  case (Lam y t x u)
  have fs: "y\<sharp>\<theta>" "y\<sharp>x" "y\<sharp>u" by fact
  moreover have "x\<sharp> Lam [y].t" by fact 
  ultimately have "x\<sharp>t" by (simp add: abs_fresh fresh_atm)
  moreover have ih:"\<And>n T. n\<sharp>t \<Longrightarrow> ((n,T)#\<theta>)<t> = \<theta><t>" by fact
  ultimately have "(x,u)#\<theta><t> = \<theta><t>" by auto
  moreover have "(x,u)#\<theta><Lam [y].t> = Lam [y]. ((x,u)#\<theta><t>)" using fs 
    by (simp add: fresh_list_cons fresh_prod)
  moreover have " \<theta><Lam [y].t> = Lam [y]. (\<theta><t>)" using fs by simp
  ultimately show "(x,u)#\<theta><Lam [y].t> = \<theta><Lam [y].t>" by auto
qed (auto simp add: fresh_atm abs_fresh)

lemma forget: 
  fixes x::"name"
  and   L::"trm"
  assumes a: "x\<sharp>L" 
  shows "L[x::=P] = L"
  using a
by (nominal_induct L avoiding: x P rule: trm.induct)
   (auto simp add: fresh_atm abs_fresh)

lemma subst_fun_eq:
  fixes u::trm
  assumes h:"[x].t\<^isub>1 = [y].t\<^isub>2"
  shows "t\<^isub>1[x::=u] = t\<^isub>2[y::=u]"
proof -
  { 
    assume "x=y" and "t\<^isub>1=t\<^isub>2"
    then have ?thesis using h by simp
  }
  moreover 
  {
    assume h1:"x \<noteq> y" and h2:"t\<^isub>1=[(x,y)] \<bullet> t\<^isub>2" and h3:"x \<sharp> t\<^isub>2"
    then have "([(x,y)] \<bullet> t\<^isub>2)[x::=u] = t\<^isub>2[y::=u]" by (simp add: subst_rename)
    then have ?thesis using h2 by simp 
  }
  ultimately show ?thesis using alpha h by blast
qed

lemma psubst_empty[simp]:
  shows "[]<t> = t"
  by (nominal_induct t rule: trm.induct) (auto simp add: fresh_list_nil)

lemma psubst_subst_psubst:
  assumes h:"c\<sharp>\<theta>"
  shows "\<theta><t>[c::=s] = (c,s)#\<theta><t>"
  using h
by (nominal_induct t avoiding: \<theta> c s rule: trm.induct)
   (auto simp add: fresh_list_cons fresh_atm forget lookup_fresh lookup_fresh' fresh_psubst)

lemma subst_fresh_simpl:
  assumes a: "x\<sharp>\<theta>"
  shows "\<theta><Var x> = Var x"
using a
by (induct \<theta> arbitrary: x, auto simp add:fresh_list_cons fresh_prod fresh_atm)

lemma psubst_subst_propagate: 
  assumes "x\<sharp>\<theta>" 
  shows "\<theta><t[x::=u]> = \<theta><t>[x::=\<theta><u>]"
using assms
proof (nominal_induct t avoiding: x u \<theta> rule: trm.induct)
  case (Var n x u \<theta>)
  { assume "x=n"
    moreover have "x\<sharp>\<theta>" by fact 
    ultimately have "\<theta><Var n[x::=u]> = \<theta><Var n>[x::=\<theta><u>]" using subst_fresh_simpl by auto
  }
  moreover 
  { assume h:"x\<noteq>n"
    then have "x\<sharp>Var n" by (auto simp add: fresh_atm) 
    moreover have "x\<sharp>\<theta>" by fact
    ultimately have "x\<sharp>\<theta><Var n>" using fresh_psubst by blast
    then have " \<theta><Var n>[x::=\<theta><u>] =  \<theta><Var n>" using forget by auto
    then have "\<theta><Var n[x::=u]> = \<theta><Var n>[x::=\<theta><u>]" using h by auto
  }
  ultimately show ?case by auto  
next
  case (Lam n t x u \<theta>)
  have fs:"n\<sharp>x" "n\<sharp>u" "n\<sharp>\<theta>" "x\<sharp>\<theta>" by fact
  have ih:"\<And> y s \<theta>. y\<sharp>\<theta> \<Longrightarrow> ((\<theta><(t[y::=s])>) = ((\<theta><t>)[y::=(\<theta><s>)]))" by fact
  have "\<theta> <(Lam [n].t)[x::=u]> = \<theta><Lam [n]. (t [x::=u])>" using fs by auto
  then have "\<theta> <(Lam [n].t)[x::=u]> = Lam [n]. \<theta><t [x::=u]>" using fs by auto
  moreover have "\<theta><t[x::=u]> = \<theta><t>[x::=\<theta><u>]" using ih fs by blast
  ultimately have "\<theta> <(Lam [n].t)[x::=u]> = Lam [n].(\<theta><t>[x::=\<theta><u>])" by auto
  moreover have "Lam [n].(\<theta><t>[x::=\<theta><u>]) = (Lam [n].\<theta><t>)[x::=\<theta><u>]" using fs fresh_psubst by auto
  ultimately have "\<theta><(Lam [n].t)[x::=u]> = (Lam [n].\<theta><t>)[x::=\<theta><u>]" using fs by auto
  then show "\<theta><(Lam [n].t)[x::=u]> = \<theta><Lam [n].t>[x::=\<theta><u>]" using fs by auto
qed (auto)

text {* 
\section{Equivalence}
\subsection{Definition of the equivalence relation}
 *}

(*<*)
inductive2
  equiv_def :: "(name\<times>ty) list\<Rightarrow>trm\<Rightarrow>trm\<Rightarrow>ty\<Rightarrow>bool" ("_ \<turnstile> _ \<equiv> _ : _" [60,60] 60) 
where
  Q_Refl[intro]:  "\<Gamma> \<turnstile> t : T \<Longrightarrow> \<Gamma> \<turnstile> t \<equiv> t : T"
| Q_Symm[intro]:  "\<Gamma> \<turnstile> t \<equiv> s : T \<Longrightarrow> \<Gamma> \<turnstile> s \<equiv> t : T"
| Q_Trans[intro]: "\<lbrakk>\<Gamma> \<turnstile> s \<equiv> t : T; \<Gamma> \<turnstile> t \<equiv> u : T\<rbrakk> \<Longrightarrow>  \<Gamma> \<turnstile> s \<equiv> u : T"
| Q_Abs[intro]:   "\<lbrakk>x\<sharp>\<Gamma>; (x,T\<^isub>1)#\<Gamma> \<turnstile> s\<^isub>2 \<equiv> t\<^isub>2 : T\<^isub>2\<rbrakk> \<Longrightarrow> \<Gamma> \<turnstile> Lam [x]. s\<^isub>2 \<equiv>  Lam [x]. t\<^isub>2 : T\<^isub>1 \<rightarrow> T\<^isub>2"
| Q_App[intro]:   "\<lbrakk>\<Gamma> \<turnstile> s\<^isub>1 \<equiv> t\<^isub>1 : T\<^isub>1 \<rightarrow> T\<^isub>2 ; \<Gamma> \<turnstile> s\<^isub>2 \<equiv> t\<^isub>2 : T\<^isub>1\<rbrakk> \<Longrightarrow>  \<Gamma> \<turnstile> App s\<^isub>1 s\<^isub>2 \<equiv> App t\<^isub>1 t\<^isub>2 : T\<^isub>2"
| Q_Beta[intro]:  "\<lbrakk>x\<sharp>(\<Gamma>,s\<^isub>2,t\<^isub>2); (x,T\<^isub>1)#\<Gamma> \<turnstile> s12 \<equiv> t12 : T\<^isub>2 ; \<Gamma> \<turnstile> s\<^isub>2 \<equiv> t\<^isub>2 : T\<^isub>1\<rbrakk> 
                   \<Longrightarrow>  \<Gamma> \<turnstile> App (Lam [x]. s12) s\<^isub>2 \<equiv>  t12[x::=t\<^isub>2] : T\<^isub>2"
| Q_Ext[intro]:   "\<lbrakk>x\<sharp>(\<Gamma>,s,t); (x,T\<^isub>1)#\<Gamma> \<turnstile> App s (Var x) \<equiv> App t (Var x) : T\<^isub>2\<rbrakk> 
                   \<Longrightarrow> \<Gamma> \<turnstile> s \<equiv> t : T\<^isub>1 \<rightarrow> T\<^isub>2"
(*>*)

text {* 
\begin{center}
\isastyle
@{thm[mode=Rule] Q_Refl[no_vars]}{\sc{Q\_Refl}}\qquad
@{thm[mode=Rule] Q_Symm[no_vars]}{\sc{Q\_Symm}}\\
@{thm[mode=Rule] Q_Trans[no_vars]}{\sc{Q\_Trans}}\\
@{thm[mode=Rule] Q_App[no_vars]}{\sc{Q\_App}}\\
@{thm[mode=Rule] Q_Abs[no_vars]}{\sc{Q\_Abs}}\\
@{thm[mode=Rule] Q_Beta[no_vars]}{\sc{Q\_Beta}}\\
@{thm[mode=Rule] Q_Ext[no_vars]}{\sc{Q\_Ext}}\\
\end{center}
*}

text {* It is now a tradition, we derive the lemma about validity, and we generate the equivariance lemma. *}

lemma equiv_def_valid:
  assumes "\<Gamma> \<turnstile> t \<equiv> s : T"
  shows "valid \<Gamma>"
using assms by (induct,auto elim:typing_valid)

nominal_inductive equiv_def

text{*
\subsection{Strong induction principle for the equivalence relation}
*}

lemma equiv_def_strong_induct
  [consumes 1, case_names Q_Refl Q_Symm Q_Trans Q_Abs Q_App Q_Beta Q_Ext]:
  fixes c::"'a::fs_name"
  assumes a0: "\<Gamma> \<turnstile> s \<equiv> t : T" 
  and     a1: "\<And>\<Gamma> t T c.  \<Gamma> \<turnstile> t : T  \<Longrightarrow> P c \<Gamma> t t T"
  and     a2: "\<And>\<Gamma> t s T c. \<lbrakk>\<And>d. P d \<Gamma> t s T\<rbrakk> \<Longrightarrow>  P c \<Gamma> s t T"
  and     a3: "\<And>\<Gamma> s t T u c. \<lbrakk>\<And>d. P d \<Gamma> s t T; \<And>d. P d \<Gamma> t u T\<rbrakk> 
               \<Longrightarrow> P c \<Gamma> s u T"
  and     a4: "\<And>x \<Gamma> T\<^isub>1 s\<^isub>2 t\<^isub>2 T\<^isub>2 c. \<lbrakk>x\<sharp>\<Gamma>; x\<sharp>c; \<And>d. P d ((x,T\<^isub>1)#\<Gamma>) s\<^isub>2 t\<^isub>2 T\<^isub>2\<rbrakk>
               \<Longrightarrow> P c \<Gamma> (Lam [x].s\<^isub>2) (Lam [x].t\<^isub>2) (T\<^isub>1\<rightarrow>T\<^isub>2)"
  and     a5: "\<And>\<Gamma> s\<^isub>1 t\<^isub>1 T\<^isub>1 T\<^isub>2 s\<^isub>2 t\<^isub>2 c. \<lbrakk>\<And>d. P d \<Gamma> s\<^isub>1 t\<^isub>1 (T\<^isub>1\<rightarrow>T\<^isub>2); \<And>d. P d \<Gamma> s\<^isub>2 t\<^isub>2 T\<^isub>1\<rbrakk> 
               \<Longrightarrow> P c \<Gamma> (App s\<^isub>1 s\<^isub>2) (App t\<^isub>1 t\<^isub>2) T\<^isub>2"
  and     a6: "\<And>x \<Gamma> T\<^isub>1 s12 t12 T\<^isub>2 s\<^isub>2 t\<^isub>2 c.
               \<lbrakk>x\<sharp>(\<Gamma>,s\<^isub>2,t\<^isub>2); x\<sharp>c; \<And>d. P d ((x,T\<^isub>1)#\<Gamma>) s12 t12 T\<^isub>2; \<And>d. P d \<Gamma> s\<^isub>2 t\<^isub>2 T\<^isub>1\<rbrakk> 
               \<Longrightarrow> P c \<Gamma> (App (Lam [x].s12) s\<^isub>2) (t12[x::=t\<^isub>2]) T\<^isub>2"
  and     a7: "\<And>x \<Gamma> s t T\<^isub>1 T\<^isub>2 c.
               \<lbrakk>x\<sharp>(\<Gamma>,s,t); \<And>d. P d ((x,T\<^isub>1)#\<Gamma>) (App s (Var x)) (App t (Var x)) T\<^isub>2\<rbrakk>
               \<Longrightarrow> P c \<Gamma> s t (T\<^isub>1\<rightarrow>T\<^isub>2)"
 shows "P c \<Gamma>  s t T"
proof -
  from a0 have "\<And>(pi::name prm) c. P c (pi\<bullet>\<Gamma>) (pi\<bullet>s) (pi\<bullet>t) (pi\<bullet>T)" 
    proof(induct)
      case (Q_Refl \<Gamma> t T pi c)
      then show "P c (pi\<bullet>\<Gamma>) (pi\<bullet>t) (pi\<bullet>t) (pi\<bullet>T)" using a1 by (simp only: eqvt)
    next
      case (Q_Symm \<Gamma> t s T pi c)
      then show "P c (pi\<bullet>\<Gamma>) (pi\<bullet>s) (pi\<bullet>t) (pi\<bullet>T)" using a2 by (simp only: equiv_def_eqvt)
    next
      case (Q_Trans \<Gamma> s t T u pi c)
      then show " P c (pi\<bullet>\<Gamma>) (pi\<bullet>s) (pi\<bullet>u) (pi\<bullet>T)" using a3 by (blast intro: equiv_def_eqvt)
    next
      case (Q_App \<Gamma> s\<^isub>1 t\<^isub>1 T\<^isub>1 T\<^isub>2 s\<^isub>2 t\<^isub>2 pi c)
      then show "P c (pi\<bullet>\<Gamma>) (pi\<bullet>App s\<^isub>1 s\<^isub>2) (pi\<bullet>App t\<^isub>1 t\<^isub>2) (pi\<bullet>T\<^isub>2)" using a5 
	by (simp only: eqvt) (blast)
    next
      case (Q_Ext x \<Gamma> s t T\<^isub>1 T\<^isub>2 pi c)
      then show "P c (pi\<bullet>\<Gamma>) (pi\<bullet>s) (pi\<bullet>t) (pi\<bullet>T\<^isub>1\<rightarrow>T\<^isub>2)"  
	by (auto intro!: a7 simp add: fresh_bij)
    next
      case (Q_Abs x \<Gamma> T\<^isub>1 s\<^isub>2 t\<^isub>2 T\<^isub>2 pi c)
      obtain y::"name" where fs: "y\<sharp>(pi\<bullet>x,pi\<bullet>s\<^isub>2,pi\<bullet>t\<^isub>2,pi\<bullet>\<Gamma>,c)" by (rule exists_fresh[OF fs_name1])
      let ?sw="[(pi\<bullet>x,y)]"
      let ?pi'="?sw@pi"
      have f1: "x\<sharp>\<Gamma>" by fact
      have f2: "(pi\<bullet>x)\<sharp>(pi\<bullet>\<Gamma>)" using f1 by (simp add: fresh_bij)
      have f3: "y\<sharp>?pi'\<bullet>\<Gamma>" using f1 by (auto simp add: pt_name2 fresh_left calc_atm perm_pi_simp)
      have ih1: "\<And>c. P c (?pi'\<bullet>((x,T\<^isub>1)#\<Gamma>)) (?pi'\<bullet>s\<^isub>2) (?pi'\<bullet>t\<^isub>2) (?pi'\<bullet>T\<^isub>2)" by fact
      then have "\<And>c. P c ((y,T\<^isub>1)#(?pi'\<bullet>\<Gamma>)) (?pi'\<bullet>s\<^isub>2) (?pi'\<bullet>t\<^isub>2) T\<^isub>2" by (simp add: calc_atm)
      then have "P c  (?pi'\<bullet>\<Gamma>) (?pi'\<bullet>Lam [x].s\<^isub>2) (?pi'\<bullet>Lam [x].t\<^isub>2) (T\<^isub>1\<rightarrow>T\<^isub>2)" using a4 f3 fs
	by (simp add: calc_atm)
      then have "P c (?sw\<bullet>pi\<bullet>\<Gamma>) (?sw\<bullet>Lam [(pi\<bullet>x)].(pi\<bullet>s\<^isub>2)) (?sw\<bullet>Lam [(pi\<bullet>x)].(pi\<bullet>t\<^isub>2)) (T\<^isub>1\<rightarrow>T\<^isub>2)" 
	by (simp del: append_Cons add: calc_atm pt_name2)
      moreover have "(?sw\<bullet>(pi\<bullet>\<Gamma>)) = (pi\<bullet>\<Gamma>)" 
	by (rule perm_fresh_fresh) (simp_all add: fs f2)
      moreover have "(?sw\<bullet>(Lam [(pi\<bullet>x)].(pi\<bullet>s\<^isub>2))) = Lam [(pi\<bullet>x)].(pi\<bullet>s\<^isub>2)" 
	by (rule perm_fresh_fresh) (simp_all add: fs f2 abs_fresh)
      moreover have "(?sw\<bullet>(Lam [(pi\<bullet>x)].(pi\<bullet>t\<^isub>2))) = Lam [(pi\<bullet>x)].(pi\<bullet>t\<^isub>2)" 
	by (rule perm_fresh_fresh) (simp_all add: fs f2 abs_fresh)
      ultimately have "P c (pi\<bullet>\<Gamma>) (Lam [(pi\<bullet>x)].(pi\<bullet>s\<^isub>2)) (Lam [(pi\<bullet>x)].(pi\<bullet>t\<^isub>2)) (T\<^isub>1\<rightarrow>T\<^isub>2)" by simp
      then show  "P c (pi\<bullet>\<Gamma>) (pi\<bullet>Lam [x].s\<^isub>2) (pi\<bullet>Lam [x].t\<^isub>2) (pi\<bullet>T\<^isub>1\<rightarrow>T\<^isub>2)" by simp 
    next 
      case (Q_Beta x \<Gamma> s\<^isub>2 t\<^isub>2 T\<^isub>1 s12 t12 T\<^isub>2 pi c) 
      obtain y::"name" where fs: "y\<sharp>(pi\<bullet>x,pi\<bullet>s12,pi\<bullet>t12,pi\<bullet>s\<^isub>2,pi\<bullet>t\<^isub>2,pi\<bullet>\<Gamma>,c)" 
	by (rule exists_fresh[OF fs_name1])
      let ?sw="[(pi\<bullet>x,y)]"
      let ?pi'="?sw@pi"
      have f1: "x\<sharp>(\<Gamma>,s\<^isub>2,t\<^isub>2)" by fact 
      have f2: "(pi\<bullet>x)\<sharp>(pi\<bullet>(\<Gamma>,s\<^isub>2,t\<^isub>2))" using f1 by (simp add: fresh_bij)
      have f3: "y\<sharp>(?pi'\<bullet>(\<Gamma>,s\<^isub>2,t\<^isub>2))" using f1 
	by (auto simp add: pt_name2 fresh_left calc_atm perm_pi_simp fresh_prod)
      have ih1: "\<And>c. P c (?pi'\<bullet>((x,T\<^isub>1)#\<Gamma>)) (?pi'\<bullet>s12) (?pi'\<bullet>t12) (?pi'\<bullet>T\<^isub>2)" by fact
      then have "\<And>c. P c ((y,T\<^isub>1)#(?pi'\<bullet>\<Gamma>)) (?pi'\<bullet>s12) (?pi'\<bullet>t12) (?pi'\<bullet>T\<^isub>2)" by (simp add: calc_atm)
      moreover
      have ih2: "\<And>c. P c (?pi'\<bullet>\<Gamma>) (?pi'\<bullet>s\<^isub>2) (?pi'\<bullet>t\<^isub>2) (?pi'\<bullet>T\<^isub>1)" by fact
      ultimately have "P c  (?pi'\<bullet>\<Gamma>) (?pi'\<bullet>(App (Lam [x].s12) s\<^isub>2)) (?pi'\<bullet>(t12[x::=t\<^isub>2])) (?pi'\<bullet>T\<^isub>2)" 
	using a6 f3 fs by (force simp add: subst_eqvt calc_atm del: perm_ty)
      then have "P c (?sw\<bullet>pi\<bullet>\<Gamma>) (?sw\<bullet>(App (Lam [(pi\<bullet>x)].(pi\<bullet>s12)) (pi\<bullet>s\<^isub>2))) 
	(?sw\<bullet>((pi\<bullet>t12)[(pi\<bullet>x)::=(pi\<bullet>t\<^isub>2)])) T\<^isub>2" 
	by (simp del: append_Cons add: calc_atm pt_name2 subst_eqvt)
      moreover have "(?sw\<bullet>(pi\<bullet>\<Gamma>)) = (pi\<bullet>\<Gamma>)" 
	by (rule perm_fresh_fresh) (simp_all add: fs[simplified] f2[simplified])
      moreover have "(?sw\<bullet>(App (Lam [(pi\<bullet>x)].(pi\<bullet>s12)) (pi\<bullet>s\<^isub>2))) = App (Lam [(pi\<bullet>x)].(pi\<bullet>s12)) (pi\<bullet>s\<^isub>2)" 
	by (rule perm_fresh_fresh) (simp_all add: fs[simplified] f2[simplified] abs_fresh)
      moreover have "(?sw\<bullet>((pi\<bullet>t12)[(pi\<bullet>x)::=(pi\<bullet>t\<^isub>2)])) = ((pi\<bullet>t12)[(pi\<bullet>x)::=(pi\<bullet>t\<^isub>2)])" 
	by (rule perm_fresh_fresh) 
	   (simp_all add: fs[simplified] f2[simplified] fresh_subst fresh_subst'')
      ultimately have "P c (pi\<bullet>\<Gamma>) (App (Lam [(pi\<bullet>x)].(pi\<bullet>s12)) (pi\<bullet>s\<^isub>2)) ((pi\<bullet>t12)[(pi\<bullet>x)::=(pi\<bullet>t\<^isub>2)]) T\<^isub>2"
	by simp
      then show "P c (pi\<bullet>\<Gamma>) (pi\<bullet>App (Lam [x].s12) s\<^isub>2) (pi\<bullet>t12[x::=t\<^isub>2]) (pi\<bullet>T\<^isub>2)" by (simp add: subst_eqvt)
    qed
  then have "P c (([]::name prm)\<bullet>\<Gamma>) (([]::name prm)\<bullet>s) (([]::name prm)\<bullet>t) (([]::name prm)\<bullet>T)" by blast
  then show "P c \<Gamma> s t T" by simp
qed


text {* \section{Type-driven equivalence algorithm} 

We follow the original presentation. The algorithm is described using inference rules only.

*}

text {* \subsection{Weak head reduction} *}

(*<*)
inductive2
  whr_def :: "trm\<Rightarrow>trm\<Rightarrow>bool" ("_ \<leadsto> _" [80,80] 80) 
where
  QAR_Beta[intro]: "App (Lam [x]. t12) t\<^isub>2 \<leadsto> t12[x::=t\<^isub>2]"
| QAR_App[intro]: "t1 \<leadsto> t1' \<Longrightarrow> App t1 t\<^isub>2 \<leadsto> App t1' t\<^isub>2"
(*>*)

text {* 
\begin{figure}
\begin{center}
\isastyle
@{thm[mode=Rule] QAR_Beta[no_vars]}{\sc{QAR\_Beta}} \qquad
@{thm[mode=Rule] QAR_App[no_vars]}{\sc{QAR\_App}}
\end{center}
\end{figure}
*}

text {* \subsubsection{Inversion lemma for weak head reduction} *}

declare trm.inject  [simp add]
declare ty.inject  [simp add]

inductive_cases2 whr_Gen[elim]: "t \<leadsto> t'"
inductive_cases2 whr_Lam[elim]: "Lam [x].t \<leadsto> t'"
inductive_cases2 whr_App_Lam[elim]: "App (Lam [x].t12) t2 \<leadsto> t"
inductive_cases2 whr_Var[elim]: "Var x \<leadsto> t"
inductive_cases2 whr_Const[elim]: "Const n \<leadsto> t"
inductive_cases2 whr_App[elim]: "App p q \<leadsto> t"
inductive_cases2 whr_Const_Right[elim]: "t \<leadsto> Const n"
inductive_cases2 whr_Var_Right[elim]: "t \<leadsto> Var x"
inductive_cases2 whr_App_Right[elim]: "t \<leadsto> App p q"

declare trm.inject  [simp del]
declare ty.inject  [simp del]

nominal_inductive whr_def

text {* 
\subsection{Weak head normalization} 
\subsubsection{Definition of the normal form}
*}

abbreviation 
 nf :: "trm \<Rightarrow> bool" ("_ \<leadsto>|" [100] 100)
where
  "t\<leadsto>|  \<equiv> \<not>(\<exists> u. t \<leadsto> u)" 

text{* \subsubsection{Definition of weak head normal form} *}

(*<*)
inductive2
  whn_def :: "trm\<Rightarrow>trm\<Rightarrow>bool" ("_ \<Down> _" [80,80] 80) 
where
  QAN_Reduce[intro]: "\<lbrakk>s \<leadsto> t; t \<Down> u\<rbrakk> \<Longrightarrow> s \<Down> u"
| QAN_Normal[intro]: "t\<leadsto>|  \<Longrightarrow> t \<Down> t"

(*>*)

text {* 
\begin{center}
@{thm[mode=Rule] QAN_Reduce[no_vars]}{\sc{QAN\_Reduce}}\qquad
@{thm[mode=Rule] QAN_Normal[no_vars]}{\sc{QAN\_Normal}}
\end{center}
*}

lemma whn_eqvt[eqvt]:
  fixes pi::"name prm"
  assumes a: "t \<Down> t'"
  shows "(pi\<bullet>t) \<Down> (pi\<bullet>t')"
using a
apply(induct)
apply(rule QAN_Reduce)
apply(rule whr_def_eqvt)
apply(assumption)+
apply(rule QAN_Normal)
apply(auto)
apply(drule_tac pi="rev pi" in whr_def_eqvt)
apply(perm_simp)
done

text {* \subsection{Algorithmic term equivalence and algorithmic path equivalence} *}

(*<*)
inductive2
  alg_equiv :: "(name\<times>ty) list\<Rightarrow>trm\<Rightarrow>trm\<Rightarrow>ty\<Rightarrow>bool" ("_ \<turnstile> _ \<Leftrightarrow> _ : _" [60,60] 60) 
and
  alg_path_equiv :: "(name\<times>ty) list\<Rightarrow>trm\<Rightarrow>trm\<Rightarrow>ty\<Rightarrow>bool" ("_ \<turnstile> _ \<leftrightarrow> _ : _" [60,60] 60) 
where
  QAT_Base[intro]:  "\<lbrakk>s \<Down> p; t \<Down> q; \<Gamma> \<turnstile> p \<leftrightarrow> q : TBase \<rbrakk> \<Longrightarrow> \<Gamma> \<turnstile> s \<Leftrightarrow> t : TBase"
| QAT_Arrow[intro]: "\<lbrakk>x\<sharp>\<Gamma>; x\<sharp>s; x\<sharp>t; (x,T\<^isub>1)#\<Gamma> \<turnstile> App s (Var x) \<Leftrightarrow> App t (Var x) : T\<^isub>2\<rbrakk> 
                     \<Longrightarrow> \<Gamma> \<turnstile> s \<Leftrightarrow> t : T\<^isub>1 \<rightarrow> T\<^isub>2"
| QAT_One[intro]:   "valid \<Gamma> \<Longrightarrow> \<Gamma> \<turnstile> s \<Leftrightarrow> t : TUnit"
| QAP_Var[intro]:   "\<lbrakk>valid \<Gamma>;(x,T) \<in> set \<Gamma>\<rbrakk> \<Longrightarrow> \<Gamma> \<turnstile> Var x \<leftrightarrow> Var x : T"
| QAP_App[intro]:   "\<lbrakk>\<Gamma> \<turnstile> p \<leftrightarrow> q : T\<^isub>1 \<rightarrow> T\<^isub>2; \<Gamma> \<turnstile> s \<Leftrightarrow> t : T\<^isub>1 \<rbrakk> \<Longrightarrow> \<Gamma> \<turnstile> App p s \<leftrightarrow> App q t : T\<^isub>2"
| QAP_Const[intro]: "valid \<Gamma> \<Longrightarrow> \<Gamma> \<turnstile> Const n \<leftrightarrow> Const n : TBase"
(*>*)

text {* 
\begin{center}
@{thm[mode=Rule] QAT_Base[no_vars]}{\sc{QAT\_Base}}\\
@{thm[mode=Rule] QAT_Arrow[no_vars]}{\sc{QAT\_Arrow}}\\
@{thm[mode=Rule] QAP_Var[no_vars]}{\sc{QAP\_Var}}\\
@{thm[mode=Rule] QAP_App[no_vars]}{\sc{QAP\_App}}\\
@{thm[mode=Rule] QAP_Const[no_vars]}{\sc{QAP\_Const}}\\
\end{center}
*}

text {* Again we generate the equivariance lemma. *}

nominal_inductive  alg_equiv

text {* \subsubsection{Strong induction principle for algorithmic term and path equivalences} *}

lemma alg_equiv_alg_path_equiv_strong_induct
  [case_names QAT_Base QAT_Arrow QAT_One QAP_Var QAP_App QAP_Const]:
  fixes c::"'a::fs_name"
  assumes a1: "\<And>s p t q \<Gamma> c. \<lbrakk>s \<Down> p; t \<Down> q; \<Gamma> \<turnstile> p \<leftrightarrow> q : TBase; \<And>d. P2 d \<Gamma> p q TBase\<rbrakk> 
               \<Longrightarrow> P1 c \<Gamma> s t TBase"
  and     a2: "\<And>x \<Gamma> s t T\<^isub>1 T\<^isub>2 c.
               \<lbrakk>x\<sharp>\<Gamma>; x\<sharp>s; x\<sharp>t; x\<sharp>c; (x,T\<^isub>1)#\<Gamma> \<turnstile> App s (Var x) \<Leftrightarrow> App t (Var x) : T\<^isub>2;
               \<And>d. P1 d ((x,T\<^isub>1)#\<Gamma>) (App s (Var x)) (App t (Var x)) T\<^isub>2\<rbrakk>
               \<Longrightarrow> P1 c \<Gamma> s t (T\<^isub>1\<rightarrow>T\<^isub>2)"
  and     a3: "\<And>\<Gamma> s t c. valid \<Gamma> \<Longrightarrow> P1 c \<Gamma> s t TUnit"
  and     a4: "\<And>\<Gamma> x T c. \<lbrakk>valid \<Gamma>; (x,T) \<in> set \<Gamma>\<rbrakk> \<Longrightarrow> P2 c \<Gamma> (Var x) (Var x) T"
  and     a5: "\<And>\<Gamma> p q T\<^isub>1 T\<^isub>2 s t c.
               \<lbrakk>\<Gamma> \<turnstile> p \<leftrightarrow> q : T\<^isub>1\<rightarrow>T\<^isub>2; \<And>d. P2 d \<Gamma> p q (T\<^isub>1\<rightarrow>T\<^isub>2); \<Gamma> \<turnstile> s \<Leftrightarrow> t : T\<^isub>1; \<And>d. P1 d \<Gamma> s t T\<^isub>1\<rbrakk>
               \<Longrightarrow> P2 c \<Gamma> (App p s) (App q t) T\<^isub>2"
  and     a6: "\<And>\<Gamma> n c. valid \<Gamma> \<Longrightarrow> P2 c \<Gamma> (Const n) (Const n) TBase"
  shows "(\<Gamma> \<turnstile> s \<Leftrightarrow> t : T \<longrightarrow>P1 c \<Gamma> s t T) \<and> (\<Gamma>' \<turnstile> s' \<leftrightarrow> t' : T' \<longrightarrow> P2 c \<Gamma>' s' t' T')"
proof -
  have "(\<Gamma> \<turnstile> s \<Leftrightarrow> t : T \<longrightarrow> (\<forall>c (pi::name prm). P1 c (pi\<bullet>\<Gamma>) (pi\<bullet>s) (pi\<bullet>t) T)) \<and> 
        (\<Gamma>' \<turnstile> s' \<leftrightarrow> t' : T' \<longrightarrow> (\<forall>c (pi::name prm). P2 c (pi\<bullet>\<Gamma>') (pi\<bullet>s') (pi\<bullet>t') T'))"
  proof(induct rule: alg_equiv_alg_path_equiv.induct)
    case (QAT_Base s q t p \<Gamma>)
    then show "\<forall>c (pi::name prm). P1 c (pi\<bullet>\<Gamma>) (pi\<bullet>s) (pi\<bullet>t) TBase"
      apply(auto)
      apply(rule_tac p="pi\<bullet>q" and q="pi\<bullet>p" in  a1)
      apply(simp_all add: eqvt[simplified])
      done
  next
    case (QAT_Arrow x \<Gamma> s t T\<^isub>1 T\<^isub>2)
    show ?case
    proof (rule allI, rule allI)
      fix c::"'a::fs_name" and pi::"name prm"
      obtain y::"name" where fs: "y\<sharp>(pi\<bullet>s,pi\<bullet>t,pi\<bullet>\<Gamma>,c)" by (rule exists_fresh[OF fs_name1])
      let ?sw="[(pi\<bullet>x,y)]"
      let ?pi'="?sw@pi"
      have f0: "x\<sharp>\<Gamma>" "x\<sharp>s" "x\<sharp>t" by fact
      then have f1: "x\<sharp>(\<Gamma>,s,t)" by simp
      have f2: "(pi\<bullet>x)\<sharp>(pi\<bullet>(\<Gamma>,s,t))" using f1 by (simp add: fresh_bij)
      have f3: "y\<sharp>?pi'\<bullet>(\<Gamma>,s,t)" using f1 
	by (simp only: pt_name2 fresh_left, auto simp add: perm_pi_simp calc_atm)
      then have f3': "y\<sharp>?pi'\<bullet>\<Gamma>" "y\<sharp>?pi'\<bullet>s" "y\<sharp>?pi'\<bullet>t" by (auto simp add: fresh_prod)
      have pr1: "(x,T\<^isub>1)#\<Gamma> \<turnstile> App s (Var x) \<Leftrightarrow> App t (Var x) : T\<^isub>2" by fact
      then have "?pi'\<bullet> ((x,T\<^isub>1)#\<Gamma> \<turnstile> App s (Var x) \<Leftrightarrow> App t (Var x) : T\<^isub>2)" using perm_bool by simp
      then have "(?pi'\<bullet>((x,T\<^isub>1)#\<Gamma>)) \<turnstile> (?pi'\<bullet>(App s (Var x))) \<Leftrightarrow> (?pi'\<bullet>(App t (Var x))) : (?pi'\<bullet>T\<^isub>2)" 
	by (auto simp add: eqvt)
      then have "(y,T\<^isub>1)#(?pi'\<bullet>\<Gamma>) \<turnstile> (App (?pi'\<bullet>s) (Var y)) \<Leftrightarrow> (App (?pi'\<bullet>t) (Var y)) : T\<^isub>2" 
	by (simp add: calc_atm)
      moreover    
      have ih1: "\<forall>c (pi::name prm).  P1 c (pi\<bullet>((x,T\<^isub>1)#\<Gamma>)) (pi\<bullet>App s (Var x)) (pi\<bullet>App t (Var x)) T\<^isub>2"
	by fact
      then have "\<And>c.  P1 c (?pi'\<bullet>((x,T\<^isub>1)#\<Gamma>)) (?pi'\<bullet>App s (Var x)) (?pi'\<bullet>App t (Var x)) T\<^isub>2"
	by auto
      then have "\<And>c.  P1 c ((y,T\<^isub>1)#(?pi'\<bullet>\<Gamma>)) (App (?pi'\<bullet>s) (Var y)) (App (?pi'\<bullet>t) (Var y)) T\<^isub>2"
	by (simp add: calc_atm)     
      ultimately have "P1 c (?pi'\<bullet>\<Gamma>) (?pi'\<bullet>s) (?pi'\<bullet>t) (T\<^isub>1\<rightarrow>T\<^isub>2)" using a2 f3' fs by simp
      then have "P1 c (?sw\<bullet>pi\<bullet>\<Gamma>) (?sw\<bullet>pi\<bullet>s) (?sw\<bullet>pi\<bullet>t) (T\<^isub>1\<rightarrow>T\<^isub>2)" 
	by (simp del: append_Cons add: calc_atm pt_name2)
      moreover have "(?sw\<bullet>(pi\<bullet>\<Gamma>)) = (pi\<bullet>\<Gamma>)" 
	by (rule perm_fresh_fresh) (simp_all add: fs[simplified] f2[simplified])
      moreover have "(?sw\<bullet>(pi\<bullet>s)) = (pi\<bullet>s)" 
	by (rule perm_fresh_fresh) (simp_all add: fs[simplified] f2[simplified])
      moreover have "(?sw\<bullet>(pi\<bullet>t)) = (pi\<bullet>t)" 
	by (rule perm_fresh_fresh) (simp_all add: fs[simplified] f2[simplified])
      ultimately show "P1 c (pi\<bullet>\<Gamma>) (pi\<bullet>s) (pi\<bullet>t) (T\<^isub>1\<rightarrow>T\<^isub>2)" by (simp)
    qed
  next
    case (QAT_One \<Gamma> s t)
    then show "\<forall>c (pi::name prm). P1 c (pi\<bullet>\<Gamma>) (pi\<bullet>s) (pi\<bullet>t) TUnit"
      by (auto intro!: a3 simp add: valid_eqvt)
  next
    case (QAP_Var \<Gamma> x T)
    then show "\<forall>c (pi::name prm). P2 c (pi \<bullet> \<Gamma>) (pi \<bullet> Var x) (pi \<bullet> Var x) T"
      apply(auto intro!: a4 simp add: valid_eqvt)
      apply(simp add: set_eqvt[symmetric])
      apply(perm_simp add: pt_set_bij1a[OF pt_name_inst, OF at_name_inst])
      done
  next
    case (QAP_App \<Gamma> p q T\<^isub>1 T\<^isub>2 s t)
    then show "\<forall>c (pi::name prm). P2 c (pi\<bullet>\<Gamma>) (pi\<bullet>App p s) (pi\<bullet>App q t) T\<^isub>2"
      by (auto intro!: a5 simp add: eqvt[simplified])
  next
    case (QAP_Const \<Gamma> n)
    then show "\<forall>c (pi::name prm). P2 c (pi\<bullet>\<Gamma>) (pi\<bullet>Const n) (pi\<bullet>Const n) TBase"
      by (auto intro!: a6 simp add: eqvt)
  qed
  then have "(\<Gamma> \<turnstile> s \<Leftrightarrow> t : T \<longrightarrow> P1 c (([]::name prm)\<bullet>\<Gamma>) (([]::name prm)\<bullet>s) (([]::name prm)\<bullet>t) T) \<and> 
             (\<Gamma>' \<turnstile> s' \<leftrightarrow> t' : T' \<longrightarrow> P2 c (([]::name prm)\<bullet>\<Gamma>') (([]::name prm)\<bullet>s') (([]::name prm)\<bullet>t') T')"
    by blast
  then show ?thesis by simp
qed

(* post-processing of the strong induction principle proved above; *) 
(* the code extracts the strong_inducts-version from strong_induct *)
(*<*)
setup {*
  PureThy.add_thmss
    [(("alg_equiv_alg_path_equiv_strong_inducts",
      ProjectRule.projects (ProofContext.init (the_context())) [1,2]
        (thm "alg_equiv_alg_path_equiv_strong_induct")), [])] #> snd
*}
(*>*)

lemma alg_equiv_valid:
  shows  "\<Gamma> \<turnstile> s \<Leftrightarrow> t : T \<Longrightarrow> valid \<Gamma>" and  "\<Gamma> \<turnstile> s \<leftrightarrow> t : T \<Longrightarrow> valid \<Gamma>"
by (induct rule : alg_equiv_alg_path_equiv.inducts, auto)

text{* \subsubsection{Inversion lemmas for algorithmic term and path equivalences} *}

declare trm.inject  [simp add]
declare ty.inject  [simp add]

inductive_cases2 whn_inv_auto[elim]: "t \<Down> t'"

inductive_cases2 alg_equiv_Base_inv_auto[elim]: "\<Gamma> \<turnstile> s\<Leftrightarrow>t : TBase"
inductive_cases2 alg_equiv_Arrow_inv_auto[elim]: "\<Gamma> \<turnstile> s\<Leftrightarrow>t : T\<^isub>1 \<rightarrow> T\<^isub>2"

inductive_cases2 alg_path_equiv_Base_inv_auto[elim]: "\<Gamma> \<turnstile> s\<leftrightarrow>t : TBase"
inductive_cases2 alg_path_equiv_Unit_inv_auto[elim]: "\<Gamma> \<turnstile> s\<leftrightarrow>t : TUnit"
inductive_cases2 alg_path_equiv_Arrow_inv_auto[elim]: "\<Gamma> \<turnstile> s\<leftrightarrow>t : T\<^isub>1 \<rightarrow> T\<^isub>2"

inductive_cases2 alg_path_equiv_Var_left_inv_auto[elim]: "\<Gamma> \<turnstile> Var x \<leftrightarrow> t : T"
inductive_cases2 alg_path_equiv_Var_left_inv_auto'[elim]: "\<Gamma> \<turnstile> Var x \<leftrightarrow> t : T'"
inductive_cases2 alg_path_equiv_Var_right_inv_auto[elim]: "\<Gamma> \<turnstile> s \<leftrightarrow> Var x : T"
inductive_cases2 alg_path_equiv_Var_right_inv_auto'[elim]: "\<Gamma> \<turnstile> s \<leftrightarrow> Var x : T'"
inductive_cases2 alg_path_equiv_Const_left_inv_auto[elim]: "\<Gamma> \<turnstile> Const n \<leftrightarrow> t : T"
inductive_cases2 alg_path_equiv_Const_right_inv_auto[elim]: "\<Gamma> \<turnstile> s \<leftrightarrow> Const n : T"
inductive_cases2 alg_path_equiv_App_left_inv_auto[elim]: "\<Gamma> \<turnstile> App p s \<leftrightarrow> t : T"
inductive_cases2 alg_path_equiv_App_right_inv_auto[elim]: "\<Gamma> \<turnstile> s \<leftrightarrow> App q t : T"
inductive_cases2 alg_path_equiv_Lam_left_inv_auto[elim]: "\<Gamma> \<turnstile> Lam[x].s \<leftrightarrow> t : T"
inductive_cases2 alg_path_equiv_Lam_right_inv_auto[elim]: "\<Gamma> \<turnstile> t \<leftrightarrow> Lam[x].s : T"

declare trm.inject [simp del]
declare ty.inject [simp del]

text {* \section{Completeness of the algorithm} *}

lemma algorithmic_monotonicity:
  fixes \<Gamma>':: "(name\<times>ty) list"
  shows "\<Gamma> \<turnstile> s \<Leftrightarrow> t : T \<Longrightarrow> \<Gamma>\<lless>\<Gamma>' \<Longrightarrow> \<Gamma>' \<turnstile> s \<Leftrightarrow> t : T"
  and "\<Gamma> \<turnstile> s \<leftrightarrow> t : T \<Longrightarrow> \<Gamma>\<lless>\<Gamma>' \<Longrightarrow> \<Gamma>' \<turnstile> s \<leftrightarrow> t : T"
proof (nominal_induct \<Gamma> s t T and \<Gamma> s t T avoiding: \<Gamma>' rule: alg_equiv_alg_path_equiv_strong_inducts)
 case (QAT_Arrow x \<Gamma> s t T\<^isub>1 T\<^isub>2 \<Gamma>')
  have fs:"x\<sharp>\<Gamma>" "x\<sharp>s" "x\<sharp>t" by fact
  have h2:"\<Gamma>\<lless>\<Gamma>'" by fact
  have ih:"\<And>\<Gamma>'. \<lbrakk>(x,T\<^isub>1)#\<Gamma> \<lless> \<Gamma>'\<rbrakk>  \<Longrightarrow> \<Gamma>' \<turnstile> App s (Var x) \<Leftrightarrow> App t (Var x) : T\<^isub>2" by fact
  have "x\<sharp>\<Gamma>'" by fact
  then have sub:"(x,T\<^isub>1)#\<Gamma> \<lless> (x,T\<^isub>1)#\<Gamma>'" using h2 by auto
  then have "(x,T\<^isub>1)#\<Gamma>' \<turnstile> App s (Var x) \<Leftrightarrow> App t (Var x) : T\<^isub>2" using ih by auto
  then show "\<Gamma>' \<turnstile> s \<Leftrightarrow> t : T\<^isub>1\<rightarrow>T\<^isub>2" using sub fs by auto
qed (auto)

lemma valid_monotonicity[elim]:
 assumes "\<Gamma> \<lless> \<Gamma>'" and "x\<sharp>\<Gamma>'"
 shows "(x,T\<^isub>1)#\<Gamma> \<lless> (x,T\<^isub>1)#\<Gamma>'"
using assms by auto

lemma algorithmic_monotonicity_auto:
  fixes \<Gamma>':: "(name\<times>ty) list"
  shows "\<Gamma> \<turnstile> s \<Leftrightarrow> t : T \<Longrightarrow> \<Gamma>\<lless>\<Gamma>' \<Longrightarrow> \<Gamma>' \<turnstile> s \<Leftrightarrow> t : T"
  and "\<Gamma> \<turnstile> s \<leftrightarrow> t : T \<Longrightarrow> \<Gamma>\<lless>\<Gamma>' \<Longrightarrow> \<Gamma>' \<turnstile> s \<leftrightarrow> t : T"
by (nominal_induct \<Gamma> s t T and \<Gamma> s t T avoiding: \<Gamma>' rule: alg_equiv_alg_path_equiv_strong_inducts, auto simp add: valid_monotonicity)
 
text {* \subsection{Definition of the logical relation} *}

function log_equiv :: "((name\<times>ty) list \<Rightarrow> trm \<Rightarrow> trm \<Rightarrow> ty \<Rightarrow> bool)"   
                      ("_ \<turnstile> _ is _ : _" [60,60,60,60] 60) 
where    
   "\<Gamma> \<turnstile> s is t : TUnit = valid \<Gamma>"
 | "\<Gamma> \<turnstile> s is t : TBase = \<Gamma> \<turnstile> s \<Leftrightarrow> t : TBase"
 | "\<Gamma> \<turnstile> s is t : (T\<^isub>1 \<rightarrow> T\<^isub>2) =  
           (valid \<Gamma> \<and> (\<forall>\<Gamma>' s' t'. \<Gamma>\<lless>\<Gamma>' \<longrightarrow> \<Gamma>' \<turnstile> s' is t' : T\<^isub>1 \<longrightarrow>  (\<Gamma>' \<turnstile> (App s s') is (App t t') : T\<^isub>2)))"
apply (auto simp add: ty.inject)
apply (subgoal_tac "(\<exists>T\<^isub>1 T\<^isub>2. b=T\<^isub>1 \<rightarrow> T\<^isub>2) \<or> b=TUnit \<or> b=TBase" )
apply (force)
apply (rule ty_cases)
done

termination
apply(relation "measure (\<lambda>(_,_,_,T). size T)")
apply(auto)
done

lemma log_equiv_valid: 
  assumes "\<Gamma> \<turnstile> s is t : T"
  shows "valid \<Gamma>"
using assms 
by (induct rule: log_equiv.induct,auto elim: alg_equiv_valid)

text {* \subsubsection{Monotonicity of the logical equivalence relation} *}

lemma logical_monotonicity :
 fixes T::ty
 assumes "\<Gamma> \<turnstile> s is t : T" "\<Gamma>\<lless>\<Gamma>'" 
 shows "\<Gamma>' \<turnstile> s is t : T"
using assms
proof (induct arbitrary: \<Gamma>' rule: log_equiv.induct)
  case (2 \<Gamma> s t \<Gamma>')
  then show "\<Gamma>' \<turnstile> s is t : TBase" using algorithmic_monotonicity by auto
next
  case (3 \<Gamma> s t T\<^isub>1 T\<^isub>2 \<Gamma>')
  then show "\<Gamma>' \<turnstile> s is t : T\<^isub>1\<rightarrow>T\<^isub>2" by force 
qed (auto)

text {* If two terms are path equivalent then they are in normal form. *}

lemma path_equiv_implies_nf:
  assumes "\<Gamma> \<turnstile> s \<leftrightarrow> t : T"
  shows "s \<leadsto>|" and "t \<leadsto>|"
using assms
by (induct rule: alg_equiv_alg_path_equiv.inducts(2)) (simp, auto)

lemma main_lemma:
  shows "\<Gamma> \<turnstile> s is t : T \<Longrightarrow> \<Gamma> \<turnstile> s \<Leftrightarrow> t : T" and "\<Gamma> \<turnstile> p \<leftrightarrow> q : T \<Longrightarrow> \<Gamma> \<turnstile> p is q : T"
proof (nominal_induct T arbitrary: \<Gamma> s t p q rule:ty.induct)
  case (Arrow T\<^isub>1 T\<^isub>2)
  { 
    case (1 \<Gamma> s t)
    have ih1:"\<And>\<Gamma> s t. \<Gamma> \<turnstile> s is t : T\<^isub>2 \<Longrightarrow> \<Gamma> \<turnstile> s \<Leftrightarrow> t : T\<^isub>2" by fact
    have ih2:"\<And>\<Gamma> s t. \<Gamma> \<turnstile> s \<leftrightarrow> t : T\<^isub>1 \<Longrightarrow> \<Gamma> \<turnstile> s is t : T\<^isub>1" by fact
    have h:"\<Gamma> \<turnstile> s is t : T\<^isub>1\<rightarrow>T\<^isub>2" by fact
    obtain x::name where fs:"x\<sharp>(\<Gamma>,s,t)" by (erule exists_fresh[OF fs_name1])
    have "valid \<Gamma>" using h log_equiv_valid by auto
    then have v:"valid ((x,T\<^isub>1)#\<Gamma>)" using fs by auto
    then have "(x,T\<^isub>1)#\<Gamma> \<turnstile> Var x \<leftrightarrow> Var x : T\<^isub>1" by auto
    then have "(x,T\<^isub>1)#\<Gamma> \<turnstile> Var x is Var x : T\<^isub>1" using ih2 by auto
    then have "(x,T\<^isub>1)#\<Gamma> \<turnstile> App s (Var x) is App t (Var x) : T\<^isub>2" using h v by auto
    then have "(x,T\<^isub>1)#\<Gamma> \<turnstile> App s (Var x) \<Leftrightarrow> App t (Var x) : T\<^isub>2" using ih1 by auto
    then show "\<Gamma> \<turnstile> s \<Leftrightarrow> t : T\<^isub>1\<rightarrow>T\<^isub>2" using fs by (auto simp add: fresh_prod)
  next
    case (2 \<Gamma> p q)
    have h:"\<Gamma> \<turnstile> p \<leftrightarrow> q : T\<^isub>1\<rightarrow>T\<^isub>2" by fact
    have ih1:"\<And>\<Gamma> s t. \<Gamma> \<turnstile> s \<leftrightarrow> t : T\<^isub>2 \<Longrightarrow> \<Gamma> \<turnstile> s is t : T\<^isub>2" by fact
    have ih2:"\<And>\<Gamma> s t. \<Gamma> \<turnstile> s is t : T\<^isub>1 \<Longrightarrow> \<Gamma> \<turnstile> s \<Leftrightarrow> t : T\<^isub>1" by fact
    {
      fix \<Gamma>' s t
      assume "\<Gamma>\<lless>\<Gamma>'" and hl:"\<Gamma>' \<turnstile> s is t : T\<^isub>1"
      then have "\<Gamma>' \<turnstile> p \<leftrightarrow> q : T\<^isub>1 \<rightarrow> T\<^isub>2" using h algorithmic_monotonicity by auto
      moreover have "\<Gamma>' \<turnstile> s \<Leftrightarrow> t : T\<^isub>1" using ih2 hl by auto
      ultimately have "\<Gamma>' \<turnstile> App p s \<leftrightarrow> App q t : T\<^isub>2" by auto
      then have "\<Gamma>' \<turnstile> App p s is App q t : T\<^isub>2" using ih1 by auto
    }
    moreover have "valid \<Gamma>" using h alg_equiv_valid by auto
    ultimately show "\<Gamma> \<turnstile> p is q : T\<^isub>1\<rightarrow>T\<^isub>2"  by auto
  }
next
  case TBase
  { case 2
    have h:"\<Gamma> \<turnstile> s \<leftrightarrow> t : TBase" by fact
    then have "s \<leadsto>|" and "t \<leadsto>|" using path_equiv_implies_nf by auto
    then have "s \<Down> s" and "t \<Down> t" by auto
    then have "\<Gamma> \<turnstile> s \<Leftrightarrow> t : TBase" using h by auto
    then show "\<Gamma> \<turnstile> s is t : TBase" by auto
  }
qed (auto elim:alg_equiv_valid)

corollary corollary_main:
  assumes a: "\<Gamma> \<turnstile> s \<leftrightarrow> t : T"
  shows "\<Gamma> \<turnstile> s \<Leftrightarrow> t : T"
using a main_lemma by blast

lemma algorithmic_symmetry:
  shows "\<Gamma> \<turnstile> s \<Leftrightarrow> t : T \<Longrightarrow> \<Gamma> \<turnstile> t \<Leftrightarrow> s : T" 
  and   "\<Gamma> \<turnstile> s \<leftrightarrow> t : T \<Longrightarrow> \<Gamma> \<turnstile> t \<leftrightarrow> s : T"
by (induct rule: alg_equiv_alg_path_equiv.inducts) (auto)

lemma red_unicity : 
  assumes a: "x \<leadsto> a" 
  and     b: "x \<leadsto> b"
  shows "a=b"
  using a b
apply (induct arbitrary: b)
apply (erule whr_App_Lam)
apply (clarify)
apply (rule subst_fun_eq)
apply (simp)
apply (force)
apply (erule whr_App)
apply (blast)+
done

lemma nf_unicity :
  assumes "x \<Down> a" "x \<Down> b"
  shows "a=b"
  using assms 
proof (induct arbitrary: b)
  case (QAN_Reduce x t a b)
  have h:"x \<leadsto> t" "t \<Down> a" by fact
  have ih:"\<And>b. t \<Down> b \<Longrightarrow> a = b" by fact
  have "x \<Down> b" by fact
  then obtain t' where "x \<leadsto> t'" and hl:"t' \<Down> b" using h by auto
  then have "t=t'" using h red_unicity by auto
  then show "a=b" using ih hl by auto
qed (auto)

nominal_inductive alg_equiv

(* FIXME this lemma should not be here I am reinventing the wheel I guess *)
(*<*)
lemma perm_basic[simp]:
 fixes x y::"name"
shows "[(x,y)]\<bullet>y = x"
using assms using calc_atm by perm_simp
(*>*)

text{* \subsection{Strong inversion lemma for algorithmic equivalence} *}

lemma Q_Arrow_strong_inversion:
  assumes fs:"x\<sharp>\<Gamma>" "x\<sharp>t" "x\<sharp>u" and h:"\<Gamma> \<turnstile> t \<Leftrightarrow> u : T\<^isub>1\<rightarrow>T\<^isub>2"
  shows "(x,T\<^isub>1)#\<Gamma> \<turnstile> App t (Var x) \<Leftrightarrow> App u (Var x) : T\<^isub>2"
proof -
  obtain y where  fs2:"y\<sharp>\<Gamma>" "y\<sharp>u" "y\<sharp>t" and "(y,T\<^isub>1)#\<Gamma> \<turnstile> App t (Var y) \<Leftrightarrow> App u (Var y) : T\<^isub>2" 
    using h by auto
  then have "([(x,y)]\<bullet>((y,T\<^isub>1)#\<Gamma>)) \<turnstile> [(x,y)]\<bullet> App t (Var y) \<Leftrightarrow> [(x,y)]\<bullet> App u (Var y) : T\<^isub>2" 
    using  alg_equiv_eqvt[simplified] by blast
  then show ?thesis using fs fs2 by (perm_simp)
qed

text{* 
For the \texttt{algorithmic\_transitivity} lemma we need a unicity property.
But one has to be cautious, because this unicity property is true only for algorithmic path. 
Indeed the following lemma is \textbf{false}:\\
\begin{center}
@{prop "\<lbrakk> \<Gamma> \<turnstile> s \<Leftrightarrow> t : T ; \<Gamma> \<turnstile> s \<Leftrightarrow> u : T' \<rbrakk> \<Longrightarrow> T = T'"}
\end{center}
Here is the counter example :\\
\begin{center}
@{prop "\<Gamma> \<turnstile> Const n \<Leftrightarrow> Const n : Tbase"} and @{prop "\<Gamma> \<turnstile> Const n \<Leftrightarrow> Const n : TUnit"}
\end{center}
*}

(*
lemma algorithmic_type_unicity:
  shows "\<lbrakk> \<Gamma> \<turnstile> s \<Leftrightarrow> t : T ; \<Gamma> \<turnstile> s \<Leftrightarrow> u : T' \<rbrakk> \<Longrightarrow> T = T'"
  and "\<lbrakk> \<Gamma> \<turnstile> s \<leftrightarrow> t : T ; \<Gamma> \<turnstile> s \<leftrightarrow> u : T' \<rbrakk> \<Longrightarrow> T = T'"

Here is the counter example : 
\<Gamma> \<turnstile> Const n \<Leftrightarrow> Const n : Tbase and \<Gamma> \<turnstile> Const n \<Leftrightarrow> Const n : TUnit

*)

lemma algorithmic_path_type_unicity:
  shows "\<lbrakk> \<Gamma> \<turnstile> s \<leftrightarrow> t : T ; \<Gamma> \<turnstile> s \<leftrightarrow> u : T' \<rbrakk> \<Longrightarrow> T = T'"
proof (induct arbitrary:  u T' 
       rule: alg_equiv_alg_path_equiv.inducts(2) [of _ _ _ _ _  "%a b c d . True"    ])
  case (QAP_Var \<Gamma> x T u T')
  have "\<Gamma> \<turnstile> Var x \<leftrightarrow> u : T'" by fact
  then have "u=Var x" and "(x,T') \<in> set \<Gamma>" by auto
  moreover have "valid \<Gamma>" "(x,T) \<in> set \<Gamma>" by fact
  ultimately show "T=T'" using type_unicity_in_context by auto
next
  case (QAP_App \<Gamma> p q T\<^isub>1 T\<^isub>2 s t u T\<^isub>2')
  have ih:"\<And>u T. \<Gamma> \<turnstile> p \<leftrightarrow> u : T \<Longrightarrow> T\<^isub>1\<rightarrow>T\<^isub>2 = T" by fact
  have "\<Gamma> \<turnstile> App p s \<leftrightarrow> u : T\<^isub>2'" by fact
  then obtain r t T\<^isub>1' where "u = App r t"  "\<Gamma> \<turnstile> p \<leftrightarrow> r : T\<^isub>1' \<rightarrow> T\<^isub>2'" by auto
  then have "T\<^isub>1\<rightarrow>T\<^isub>2 = T\<^isub>1' \<rightarrow> T\<^isub>2'" by auto
  then show "T\<^isub>2=T\<^isub>2'" using ty.inject by auto
qed (auto)

lemma algorithmic_transitivity:
  shows "\<lbrakk> \<Gamma> \<turnstile> s \<Leftrightarrow> t : T ; \<Gamma> \<turnstile> t \<Leftrightarrow> u : T \<rbrakk> \<Longrightarrow> \<Gamma> \<turnstile> s \<Leftrightarrow> u : T"
  and  "\<lbrakk> \<Gamma> \<turnstile> s \<leftrightarrow> t : T ; \<Gamma> \<turnstile> t \<leftrightarrow> u : T \<rbrakk> \<Longrightarrow> \<Gamma> \<turnstile> s \<leftrightarrow> u : T"
proof (nominal_induct \<Gamma> s t T and \<Gamma> s t T avoiding: u rule: alg_equiv_alg_path_equiv_strong_inducts)
  case (QAT_Base s p t q \<Gamma> u)
  have h:"s \<Down> p" "t \<Down> q" by fact
  have ih:"\<And>u. \<Gamma> \<turnstile> q \<leftrightarrow> u : TBase \<Longrightarrow> \<Gamma> \<turnstile> p \<leftrightarrow> u : TBase" by fact
  have "\<Gamma> \<turnstile> t \<Leftrightarrow> u : TBase" by fact
  then obtain r q' where hl:"t \<Down> q'" "u \<Down> r" "\<Gamma> \<turnstile> q' \<leftrightarrow> r : TBase" by auto
  moreover have eq:"q=q'" using nf_unicity hl h by auto
  ultimately have "\<Gamma> \<turnstile> p \<leftrightarrow> r : TBase" using ih by auto
  then show "\<Gamma> \<turnstile> s \<Leftrightarrow> u : TBase" using hl h by auto
next
  case (QAT_Arrow  x \<Gamma> s t T\<^isub>1 T\<^isub>2 u)
  have fs:"x\<sharp>\<Gamma>" "x\<sharp>s" "x\<sharp>t" by fact
  moreover have h:"\<Gamma> \<turnstile> t \<Leftrightarrow> u : T\<^isub>1\<rightarrow>T\<^isub>2" by fact
  moreover then obtain y where "y\<sharp>\<Gamma>" "y\<sharp>t" "y\<sharp>u" and "(y,T\<^isub>1)#\<Gamma> \<turnstile> App t (Var y) \<Leftrightarrow> App u (Var y) : T\<^isub>2" 
    by auto
  moreover have fs2:"x\<sharp>u" by fact
  ultimately have "(x,T\<^isub>1)#\<Gamma> \<turnstile> App t (Var x) \<Leftrightarrow> App u (Var x) : T\<^isub>2" using Q_Arrow_strong_inversion by blast
  moreover have ih:"\<And> v. (x,T\<^isub>1)#\<Gamma> \<turnstile> App t (Var x) \<Leftrightarrow> v : T\<^isub>2 \<Longrightarrow> (x,T\<^isub>1)#\<Gamma> \<turnstile> App s (Var x) \<Leftrightarrow> v : T\<^isub>2" 
    by fact
  ultimately have "(x,T\<^isub>1)#\<Gamma> \<turnstile> App s (Var x) \<Leftrightarrow> App u (Var x) : T\<^isub>2" by auto
  then show "\<Gamma> \<turnstile> s \<Leftrightarrow> u : T\<^isub>1\<rightarrow>T\<^isub>2" using fs fs2 by auto
next
  case (QAP_App \<Gamma> p q T\<^isub>1 T\<^isub>2 s t u)
  have h1:"\<Gamma> \<turnstile> p \<leftrightarrow> q : T\<^isub>1\<rightarrow>T\<^isub>2" by fact
  have ih1:"\<And>u. \<Gamma> \<turnstile> q \<leftrightarrow> u : T\<^isub>1\<rightarrow>T\<^isub>2 \<Longrightarrow> \<Gamma> \<turnstile> p \<leftrightarrow> u : T\<^isub>1\<rightarrow>T\<^isub>2" by fact
  have "\<Gamma> \<turnstile> s \<Leftrightarrow> t : T\<^isub>1" by fact
  have ih2:"\<And>u. \<Gamma> \<turnstile> t \<Leftrightarrow> u : T\<^isub>1 \<Longrightarrow> \<Gamma> \<turnstile> s \<Leftrightarrow> u : T\<^isub>1" by fact
  have "\<Gamma> \<turnstile> App q t \<leftrightarrow> u : T\<^isub>2" by fact
  then obtain r T\<^isub>1' v where ha:"\<Gamma> \<turnstile> q \<leftrightarrow> r : T\<^isub>1'\<rightarrow>T\<^isub>2" and hb:"\<Gamma> \<turnstile> t \<Leftrightarrow> v : T\<^isub>1'" and eq:"u = App r v" 
    by auto
  moreover have "\<Gamma> \<turnstile> q \<leftrightarrow> p : T\<^isub>1\<rightarrow>T\<^isub>2" using h1 algorithmic_symmetry by auto
  ultimately have "T\<^isub>1'\<rightarrow>T\<^isub>2 = T\<^isub>1\<rightarrow>T\<^isub>2" using algorithmic_path_type_unicity by auto
  then have "T\<^isub>1' = T\<^isub>1" using ty.inject by auto
  then have "\<Gamma> \<turnstile> s \<Leftrightarrow> v : T\<^isub>1" "\<Gamma> \<turnstile> p \<leftrightarrow> r : T\<^isub>1\<rightarrow>T\<^isub>2" using ih1 ih2 ha hb by auto
  then show "\<Gamma> \<turnstile> App p s \<leftrightarrow> u : T\<^isub>2" using eq by auto
qed (auto)

lemma algorithmic_weak_head_closure:
  shows "\<lbrakk>\<Gamma> \<turnstile> s \<Leftrightarrow> t : T ; s' \<leadsto> s; t' \<leadsto> t\<rbrakk> \<Longrightarrow> \<Gamma> \<turnstile> s' \<Leftrightarrow> t' : T"
by (nominal_induct \<Gamma> s t T avoiding: s' t'  
    rule: alg_equiv_alg_path_equiv_strong_inducts(1) [of _ _ _ _ "%a b c d e. True"])
   (auto)

lemma logical_symmetry:
  assumes a: "\<Gamma> \<turnstile> s is t : T"
  shows "\<Gamma> \<turnstile> t is s : T"
using a 
by (nominal_induct arbitrary: \<Gamma> s t rule:ty.induct) (auto simp add: algorithmic_symmetry)

lemma logical_transitivity:
  assumes "\<Gamma> \<turnstile> s is t : T" "\<Gamma> \<turnstile> t is u : T" 
  shows "\<Gamma> \<turnstile> s is u : T"
using assms
proof (nominal_induct arbitrary: \<Gamma> s t u  rule:ty.induct)
  case TBase
  then show "\<Gamma> \<turnstile> s is u : TBase" by (auto elim:  algorithmic_transitivity)
next 
  case (Arrow T\<^isub>1 T\<^isub>2 \<Gamma> s t u)
  have h1:"\<Gamma> \<turnstile> s is t : T\<^isub>1 \<rightarrow> T\<^isub>2" by fact
  have h2:"\<Gamma> \<turnstile> t is u : T\<^isub>1 \<rightarrow> T\<^isub>2" by fact
  have ih1:"\<And>\<Gamma> s t u. \<lbrakk>\<Gamma> \<turnstile> s is t : T\<^isub>1; \<Gamma> \<turnstile> t is u : T\<^isub>1\<rbrakk> \<Longrightarrow> \<Gamma> \<turnstile> s is u : T\<^isub>1" by fact
  have ih2:"\<And>\<Gamma> s t u. \<lbrakk>\<Gamma> \<turnstile> s is t : T\<^isub>2; \<Gamma> \<turnstile> t is u : T\<^isub>2\<rbrakk> \<Longrightarrow> \<Gamma> \<turnstile> s is u : T\<^isub>2" by fact
  {
    fix \<Gamma>' s' u'
    assume hsub:"\<Gamma>\<lless>\<Gamma>'" and hl:"\<Gamma>' \<turnstile> s' is u' : T\<^isub>1"
    then have "\<Gamma>' \<turnstile> u' is s' : T\<^isub>1" using logical_symmetry by blast
    then have "\<Gamma>' \<turnstile> u' is u' : T\<^isub>1" using ih1 hl by blast
    then have "\<Gamma>' \<turnstile> App t u' is App u u' : T\<^isub>2" using h2 hsub by auto
    moreover have "\<Gamma>' \<turnstile>  App s s' is App t u' : T\<^isub>2" using h1 hsub hl by auto
    ultimately have "\<Gamma>' \<turnstile>  App s s' is App u u' : T\<^isub>2" using ih2 by blast
  }
  moreover have "valid \<Gamma>" using h1 alg_equiv_valid by auto
  ultimately show "\<Gamma> \<turnstile> s is u : T\<^isub>1 \<rightarrow> T\<^isub>2" by auto
qed (auto)

lemma logical_weak_head_closure:
  assumes "\<Gamma> \<turnstile> s is t : T" "s' \<leadsto> s" "t' \<leadsto> t"
  shows "\<Gamma> \<turnstile> s' is t' : T"
using assms algorithmic_weak_head_closure 
by (nominal_induct arbitrary: \<Gamma> s t s' t' rule:ty.induct) (auto, blast)

lemma logical_weak_head_closure':
  assumes "\<Gamma> \<turnstile> s is t : T" "s' \<leadsto> s" 
  shows "\<Gamma> \<turnstile> s' is t : T"
using assms
proof (nominal_induct arbitrary: \<Gamma> s t s' rule: ty.induct)
  case (TBase  \<Gamma> s t s')
  then show ?case by force
next
  case (TUnit \<Gamma> s t s')
  then show ?case by auto
next 
  case (Arrow T\<^isub>1 T\<^isub>2 \<Gamma> s t s')
  have h1:"s' \<leadsto> s" by fact
  have ih:"\<And>\<Gamma> s t s'. \<lbrakk>\<Gamma> \<turnstile> s is t : T\<^isub>2; s' \<leadsto> s\<rbrakk> \<Longrightarrow> \<Gamma> \<turnstile> s' is t : T\<^isub>2" by fact
  have h2:"\<Gamma> \<turnstile> s is t : T\<^isub>1\<rightarrow>T\<^isub>2" by fact
  then have hb:"\<forall>\<Gamma>' s' t'. \<Gamma>\<lless>\<Gamma>' \<longrightarrow> \<Gamma>' \<turnstile> s' is t' : T\<^isub>1 \<longrightarrow>  (\<Gamma>' \<turnstile> (App s s') is (App t t') : T\<^isub>2)" by auto
  {
    fix \<Gamma>' s\<^isub>2 t\<^isub>2
    assume "\<Gamma>\<lless>\<Gamma>'" and "\<Gamma>' \<turnstile> s\<^isub>2 is t\<^isub>2 : T\<^isub>1"
    then have "\<Gamma>' \<turnstile> (App s s\<^isub>2) is (App t t\<^isub>2) : T\<^isub>2" using hb by auto
    moreover have "(App s' s\<^isub>2)  \<leadsto> (App s s\<^isub>2)" using h1 by auto  
    ultimately have "\<Gamma>' \<turnstile> App s' s\<^isub>2 is App t t\<^isub>2 : T\<^isub>2" using ih by auto
  }
  moreover have "valid \<Gamma>" using h2 log_equiv_valid by auto
  ultimately show "\<Gamma> \<turnstile> s' is t : T\<^isub>1\<rightarrow>T\<^isub>2" by auto
qed 

abbreviation 
 log_equiv_subst :: "(name\<times>ty) list \<Rightarrow> (name\<times>trm) list \<Rightarrow>  (name\<times>trm) list \<Rightarrow> (name\<times>ty) list \<Rightarrow> bool"  
                     ("_ \<turnstile> _ is _ over _" [60,60] 60) 
where
  "\<Gamma>' \<turnstile> \<gamma> is \<delta> over \<Gamma> \<equiv> valid \<Gamma>' \<and> (\<forall>  x T. (x,T) \<in> set \<Gamma> \<longrightarrow> \<Gamma>' \<turnstile> \<gamma><Var x> is  \<delta><Var x> : T)"

lemma logical_pseudo_reflexivity:
  assumes "\<Gamma>' \<turnstile> t is s over \<Gamma>"
  shows "\<Gamma>' \<turnstile> s is s over \<Gamma>" 
proof -
  have "\<Gamma>' \<turnstile> t is s over \<Gamma>" by fact
  moreover then have "\<Gamma>' \<turnstile> s is t over \<Gamma>" using logical_symmetry by blast
  ultimately show "\<Gamma>' \<turnstile> s is s over \<Gamma>" using logical_transitivity by blast
qed

lemma logical_subst_monotonicity :
  fixes \<Gamma>::"(name\<times>ty) list"
  and   \<Gamma>'::"(name\<times>ty) list"
  and   \<Gamma>''::"(name\<times>ty) list"
  assumes "\<Gamma>' \<turnstile> s is t over \<Gamma>" "\<Gamma>'\<lless>\<Gamma>''"
  shows "\<Gamma>'' \<turnstile> s is t over \<Gamma>"
  using assms logical_monotonicity by blast

lemma equiv_subst_ext :
  assumes h1:"\<Gamma>' \<turnstile> \<gamma> is \<delta> over \<Gamma>" and h2:"\<Gamma>' \<turnstile> s is t : T" and fs:"x\<sharp>\<Gamma>"
  shows "\<Gamma>' \<turnstile> (x,s)#\<gamma> is (x,t)#\<delta> over (x,T)#\<Gamma>"
using assms
proof -
{
  fix y U
  assume "(y,U) \<in> set ((x,T)#\<Gamma>)"
  moreover
  { 
    assume "(y,U) \<in> set [(x,T)]"
    then have "\<Gamma>' \<turnstile> (x,s)#\<gamma><Var y> is (x,t)#\<delta><Var y> : U" by auto 
  }
  moreover
  {
    assume hl:"(y,U) \<in> set \<Gamma>"
    then have "\<not> y\<sharp>\<Gamma>" by (induct \<Gamma>) (auto simp add: fresh_list_cons fresh_atm fresh_prod)
    then have hf:"x\<sharp> Var y" using fs by (auto simp add: fresh_atm)
    then have "(x,s)#\<gamma><Var y> = \<gamma><Var y>" "(x,t)#\<delta><Var y> = \<delta><Var y>" using fresh_psubst_simpl by blast+ 
    moreover have  "\<Gamma>' \<turnstile> \<gamma><Var y> is \<delta><Var y> : U" using h1 hl by auto
    ultimately have "\<Gamma>' \<turnstile> (x,s)#\<gamma><Var y> is (x,t)#\<delta><Var y> : U" by auto
  }
  ultimately have "\<Gamma>' \<turnstile> (x,s)#\<gamma><Var y> is (x,t)#\<delta><Var y> : U" by auto
}
moreover have "valid \<Gamma>'" using h2 log_equiv_valid by blast
ultimately show "\<Gamma>' \<turnstile> (x,s)#\<gamma> is (x,t)#\<delta> over (x,T)#\<Gamma>" by auto
qed

theorem fundamental_theorem:
  assumes "\<Gamma> \<turnstile> t : T" "\<Gamma>' \<turnstile> \<gamma> is \<theta> over \<Gamma>"
  shows "\<Gamma>' \<turnstile> \<gamma><t> is \<theta><t> : T"   
using assms
proof (nominal_induct avoiding:\<Gamma>' \<gamma> \<theta>  rule: typing_induct_strong)
case (t_Lam x \<Gamma> T\<^isub>1 t\<^isub>2 T\<^isub>2 \<Gamma>' \<gamma> \<theta>)
have fs:"x\<sharp>\<gamma>" "x\<sharp>\<theta>" "x\<sharp>\<Gamma>" by fact
have h:"\<Gamma>' \<turnstile> \<gamma> is \<theta> over \<Gamma>" by fact
have ih:"\<And> \<Gamma>' \<gamma> \<theta>. \<Gamma>' \<turnstile> \<gamma> is \<theta> over (x,T\<^isub>1)#\<Gamma> \<Longrightarrow> \<Gamma>' \<turnstile> \<gamma><t\<^isub>2> is \<theta><t\<^isub>2> : T\<^isub>2" by fact
{
  fix \<Gamma>'' s' t'
  assume "\<Gamma>'\<lless>\<Gamma>''" and hl:"\<Gamma>''\<turnstile> s' is t' : T\<^isub>1"
  then have "\<Gamma>'' \<turnstile> \<gamma> is \<theta> over \<Gamma>" using logical_subst_monotonicity h by blast
  then have "\<Gamma>'' \<turnstile> (x,s')#\<gamma> is (x,t')#\<theta> over (x,T\<^isub>1)#\<Gamma>" using equiv_subst_ext hl fs by blast
  then have "\<Gamma>'' \<turnstile> (x,s')#\<gamma><t\<^isub>2> is (x,t')#\<theta><t\<^isub>2> : T\<^isub>2" using ih by auto
  then have "\<Gamma>''\<turnstile>\<gamma><t\<^isub>2>[x::=s'] is \<theta><t\<^isub>2>[x::=t'] : T\<^isub>2" using psubst_subst_psubst fs by simp
  moreover have "App (Lam [x].\<gamma><t\<^isub>2>) s' \<leadsto> \<gamma><t\<^isub>2>[x::=s']" by auto
  moreover have "App (Lam [x].\<theta><t\<^isub>2>) t' \<leadsto> \<theta><t\<^isub>2>[x::=t']" by auto
  ultimately have "\<Gamma>''\<turnstile> App (Lam [x].\<gamma><t\<^isub>2>) s' is App (Lam [x].\<theta><t\<^isub>2>) t' : T\<^isub>2" 
    using logical_weak_head_closure by auto
}
moreover have "valid \<Gamma>'" using h by auto
ultimately show "\<Gamma>' \<turnstile> \<gamma><Lam [x].t\<^isub>2> is \<theta><Lam [x].t\<^isub>2> : T\<^isub>1\<rightarrow>T\<^isub>2" using fs by auto 
qed (auto)

theorem fundamental_theorem_2:
  assumes h1: "\<Gamma> \<turnstile> s \<equiv> t : T" 
  and     h2: "\<Gamma>' \<turnstile> \<gamma> is \<theta> over \<Gamma>"
  shows "\<Gamma>' \<turnstile> \<gamma><s> is \<theta><t> : T"
using h1 h2
proof (nominal_induct \<Gamma> s t T avoiding: \<Gamma>' \<gamma> \<theta> rule: equiv_def_strong_induct)
  case (Q_Refl \<Gamma> t T \<Gamma>' \<gamma> \<theta>)
  have "\<Gamma> \<turnstile> t : T" by fact
  moreover have "\<Gamma>' \<turnstile> \<gamma> is \<theta> over \<Gamma>" by fact
  ultimately show "\<Gamma>' \<turnstile> \<gamma><t> is \<theta><t> : T" using fundamental_theorem by blast
next
  case (Q_Symm \<Gamma> t s T \<Gamma>' \<gamma> \<theta>)
  have "\<Gamma>' \<turnstile> \<gamma> is \<theta> over \<Gamma>" by fact
  moreover have ih:"\<And> \<Gamma>' \<gamma> \<theta>. \<Gamma>' \<turnstile> \<gamma> is \<theta> over \<Gamma> \<Longrightarrow> \<Gamma>' \<turnstile> \<gamma><t> is \<theta><s> : T" by fact
  ultimately show "\<Gamma>' \<turnstile> \<gamma><s> is \<theta><t> : T" using logical_symmetry by blast
next
  case (Q_Trans \<Gamma> s t T u \<Gamma>' \<gamma> \<theta>)
  have ih1:"\<And> \<Gamma>' \<gamma> \<theta>. \<Gamma>' \<turnstile> \<gamma> is \<theta> over \<Gamma> \<Longrightarrow> \<Gamma>' \<turnstile> \<gamma><s> is \<theta><t> : T" by fact
  have ih2:"\<And> \<Gamma>' \<gamma> \<theta>. \<Gamma>' \<turnstile> \<gamma> is \<theta> over \<Gamma> \<Longrightarrow> \<Gamma>' \<turnstile> \<gamma><t> is \<theta><u> : T" by fact
  have h:"\<Gamma>' \<turnstile> \<gamma> is \<theta> over \<Gamma>" by fact
  then have "\<Gamma>' \<turnstile> \<theta> is \<theta> over \<Gamma>" using logical_pseudo_reflexivity by auto
  then have "\<Gamma>' \<turnstile> \<theta><t> is \<theta><u> : T" using ih2 by auto
  moreover have "\<Gamma>' \<turnstile> \<gamma><s> is \<theta><t> : T" using ih1 h by auto
  ultimately show "\<Gamma>' \<turnstile> \<gamma><s> is \<theta><u> : T" using logical_transitivity by blast
next
  case (Q_Abs x \<Gamma> T\<^isub>1 s\<^isub>2 t\<^isub>2 T\<^isub>2 \<Gamma>' \<gamma> \<theta>)
  have fs:"x\<sharp>\<Gamma>" by fact
  have fs2: "x\<sharp>\<gamma>" "x\<sharp>\<theta>" by fact 
  have h2:"\<Gamma>' \<turnstile> \<gamma> is \<theta> over \<Gamma>" by fact
  have ih:"\<And>\<Gamma>' \<gamma> \<theta>. \<Gamma>' \<turnstile> \<gamma> is \<theta> over (x,T\<^isub>1)#\<Gamma> \<Longrightarrow> \<Gamma>' \<turnstile> \<gamma><s\<^isub>2> is \<theta><t\<^isub>2> : T\<^isub>2" by fact
  {
    fix \<Gamma>'' s' t'
    assume "\<Gamma>'\<lless>\<Gamma>''" and hl:"\<Gamma>''\<turnstile> s' is t' : T\<^isub>1"
    then have "\<Gamma>'' \<turnstile> \<gamma> is \<theta> over \<Gamma>" using h2 logical_subst_monotonicity by blast
    then have "\<Gamma>'' \<turnstile> (x,s')#\<gamma> is (x,t')#\<theta> over (x,T\<^isub>1)#\<Gamma>" using equiv_subst_ext hl fs by blast
    then have "\<Gamma>'' \<turnstile> (x,s')#\<gamma><s\<^isub>2> is (x,t')#\<theta><t\<^isub>2> : T\<^isub>2" using ih by blast
    then have "\<Gamma>''\<turnstile> \<gamma><s\<^isub>2>[x::=s'] is \<theta><t\<^isub>2>[x::=t'] : T\<^isub>2" using fs2 psubst_subst_psubst by auto
    moreover have "App (Lam [x]. \<gamma><s\<^isub>2>) s' \<leadsto>  \<gamma><s\<^isub>2>[x::=s']" 
              and "App (Lam [x].\<theta><t\<^isub>2>) t' \<leadsto> \<theta><t\<^isub>2>[x::=t']" by auto
    ultimately have "\<Gamma>'' \<turnstile> App (Lam [x]. \<gamma><s\<^isub>2>) s' is App (Lam [x].\<theta><t\<^isub>2>) t' : T\<^isub>2" 
      using logical_weak_head_closure by auto
  }
  moreover have "valid \<Gamma>'" using h2 by auto
  ultimately have "\<Gamma>' \<turnstile> Lam [x].\<gamma><s\<^isub>2> is Lam [x].\<theta><t\<^isub>2> : T\<^isub>1\<rightarrow>T\<^isub>2" by auto
  then show "\<Gamma>' \<turnstile> \<gamma><Lam [x].s\<^isub>2> is \<theta><Lam [x].t\<^isub>2> : T\<^isub>1\<rightarrow>T\<^isub>2" using fs2 by auto
next
  case (Q_App \<Gamma> s\<^isub>1 t\<^isub>1 T\<^isub>1 T\<^isub>2 s\<^isub>2 t\<^isub>2 \<Gamma>' \<gamma> \<theta>)
  then show "\<Gamma>' \<turnstile> \<gamma><App s\<^isub>1 s\<^isub>2> is \<theta><App t\<^isub>1 t\<^isub>2> : T\<^isub>2" by auto 
next
  case (Q_Beta x \<Gamma> T\<^isub>1 s12 t12 T\<^isub>2 s\<^isub>2 t\<^isub>2 \<Gamma>' \<gamma> \<theta>)
  have h:"\<Gamma>' \<turnstile> \<gamma> is \<theta> over \<Gamma>" by fact
  have fs:"x\<sharp>\<Gamma>" by fact
  have fs2:"x\<sharp>\<gamma>" "x\<sharp>\<theta>" by fact 
  have ih1:"\<And>\<Gamma>' \<gamma> \<theta>. \<Gamma>' \<turnstile> \<gamma> is \<theta> over \<Gamma> \<Longrightarrow> \<Gamma>' \<turnstile> \<gamma><s\<^isub>2> is \<theta><t\<^isub>2> : T\<^isub>1" by fact
  have ih2:"\<And>\<Gamma>' \<gamma> \<theta>. \<Gamma>' \<turnstile> \<gamma> is \<theta> over (x,T\<^isub>1)#\<Gamma> \<Longrightarrow> \<Gamma>' \<turnstile> \<gamma><s12> is \<theta><t12> : T\<^isub>2" by fact
  have "\<Gamma>' \<turnstile> \<gamma><s\<^isub>2> is \<theta><t\<^isub>2> : T\<^isub>1" using ih1 h by auto
  then have "\<Gamma>' \<turnstile> (x,\<gamma><s\<^isub>2>)#\<gamma> is (x,\<theta><t\<^isub>2>)#\<theta> over (x,T\<^isub>1)#\<Gamma>" using equiv_subst_ext h fs by blast
  then have "\<Gamma>' \<turnstile> (x,\<gamma><s\<^isub>2>)#\<gamma><s12> is (x,\<theta><t\<^isub>2>)#\<theta><t12> : T\<^isub>2" using ih2 by auto
  then have "\<Gamma>' \<turnstile> \<gamma><s12>[x::=\<gamma><s\<^isub>2>] is \<theta><t12>[x::=\<theta><t\<^isub>2>] : T\<^isub>2" using fs2 psubst_subst_psubst by auto
  then have "\<Gamma>' \<turnstile> \<gamma><s12>[x::=\<gamma><s\<^isub>2>] is \<theta><t12[x::=t\<^isub>2]> : T\<^isub>2" using fs2 psubst_subst_propagate by auto
  moreover have "App (Lam [x].\<gamma><s12>) (\<gamma><s\<^isub>2>) \<leadsto> \<gamma><s12>[x::=\<gamma><s\<^isub>2>]" by auto 
  ultimately have "\<Gamma>' \<turnstile> App (Lam [x].\<gamma><s12>) (\<gamma><s\<^isub>2>) is \<theta><t12[x::=t\<^isub>2]> : T\<^isub>2" 
    using logical_weak_head_closure' by auto
  then show "\<Gamma>' \<turnstile> \<gamma><App (Lam [x].s12) s\<^isub>2> is \<theta><t12[x::=t\<^isub>2]> : T\<^isub>2" using fs2 by simp
next
  case (Q_Ext x \<Gamma> s t T\<^isub>1 T\<^isub>2 \<Gamma>' \<gamma> \<theta>)
  have h2:"\<Gamma>' \<turnstile> \<gamma> is \<theta> over \<Gamma>" by fact
  have fs:"x\<sharp>\<Gamma>" "x\<sharp>s" "x\<sharp>t" by fact
  have ih:"\<And>\<Gamma>' \<gamma> \<theta>. \<Gamma>' \<turnstile> \<gamma> is \<theta> over (x,T\<^isub>1)#\<Gamma> \<Longrightarrow> \<Gamma>' \<turnstile> \<gamma><App s (Var x)> is \<theta><App t (Var x)> : T\<^isub>2" 
    by fact
   {
    fix \<Gamma>'' s' t'
    assume hsub:"\<Gamma>'\<lless>\<Gamma>''" and hl:"\<Gamma>''\<turnstile> s' is t' : T\<^isub>1"
    then have "\<Gamma>'' \<turnstile> \<gamma> is \<theta> over \<Gamma>" using h2 logical_subst_monotonicity by blast
    then have "\<Gamma>'' \<turnstile> (x,s')#\<gamma> is (x,t')#\<theta> over (x,T\<^isub>1)#\<Gamma>" using equiv_subst_ext hl fs by blast
    then have "\<Gamma>'' \<turnstile> (x,s')#\<gamma><App s (Var x)>  is (x,t')#\<theta><App t (Var x)> : T\<^isub>2" using ih by blast
    then have "\<Gamma>'' \<turnstile> App (((x,s')#\<gamma>)<s>) (((x,s')#\<gamma>)<(Var x)>) is App ((x,t')#\<theta><t>) ((x,t')#\<theta><(Var x)>) : T\<^isub>2"
      by auto
    then have "\<Gamma>'' \<turnstile> App ((x,s')#\<gamma><s>) s'  is App ((x,t')#\<theta><t>) t' : T\<^isub>2" by auto
    then have "\<Gamma>'' \<turnstile> App (\<gamma><s>) s' is App (\<theta><t>) t' : T\<^isub>2" using fs fresh_psubst_simpl by auto
  }
  moreover have "valid \<Gamma>'" using h2 by auto
  ultimately show "\<Gamma>' \<turnstile> \<gamma><s> is \<theta><t> : T\<^isub>1\<rightarrow>T\<^isub>2" by auto
qed


theorem completeness:
  assumes "\<Gamma> \<turnstile> s \<equiv> t : T"
  shows   "\<Gamma> \<turnstile> s \<Leftrightarrow> t : T"
using assms
proof -
  {
    fix x T
    assume "(x,T) \<in> set \<Gamma>" "valid \<Gamma>"
    then have "\<Gamma> \<turnstile> Var x is Var x : T" using main_lemma by blast
  }
  moreover have "valid \<Gamma>" using equiv_def_valid assms by auto
  ultimately have "\<Gamma> \<turnstile> [] is [] over \<Gamma>" by auto 
  then have "\<Gamma> \<turnstile> []<s> is []<t> : T" using fundamental_theorem_2 assms by blast
  then have "\<Gamma> \<turnstile> s is t : T" by simp
  then show  "\<Gamma> \<turnstile> s \<Leftrightarrow> t : T" using main_lemma by simp
qed

text{*
\section{About soundness}
*}

text {* We leave soundness as an exercise - like in the book :-) \\ 
 @{prop[mode=IfThen] "\<lbrakk>\<Gamma> \<turnstile> s \<Leftrightarrow> t : T; \<Gamma> \<turnstile> t : T; \<Gamma> \<turnstile> s : T\<rbrakk> \<Longrightarrow> \<Gamma> \<turnstile> s \<equiv> t : T"} \\
 @{prop "\<lbrakk>\<Gamma> \<turnstile> s \<leftrightarrow> t : T; \<Gamma> \<turnstile> t : T; \<Gamma> \<turnstile> s : T\<rbrakk> \<Longrightarrow> \<Gamma> \<turnstile> s \<equiv> t : T"} 
*}

end

