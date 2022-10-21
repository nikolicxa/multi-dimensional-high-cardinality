/************************************************************************/
/* Preliminary notes */
/************************************************************************/
/* To create the recall summary chart found in the COMPARING THE PERFORMANCE 
OF MACHINE LEARNING MODELS WITH AND WITHOUT NEWLY CREATED FEATURES section, 
you will need to have access to SAS Viya 3.5 or above, and load the model_train 
and model_train_val datasets into a SAS directory.
*/
/************************************************************************/
/* Assigning libname and opening a CAS session */
/************************************************************************/

libname SESUGDTA ''; ***** Insert path to where datasets are stored *****;

%let outdir = ; ***** Insert path to where you want to store models fitted by proc treesplit, 
					proc logselect, and proc nnet *****;

***** Create a CAS session *****;
cas mySession sessopts=(caslib=casuser timeout=1800 locale="en_US");
caslib _all_ assign;

/************************************************************************/
/*		Creating macro variables containing input lists for 	    */
/*		model comparisons					    */
/************************************************************************/

%let all = Categorical_Input_1_Enc_Prod Numeric_Input_1 Categorical_Input_2_Sum_Tgt_Rep Numeric_Input_2 
				Categorical_Input_3_Enc_Prod Numeric_Input_3 Numeric_Input_4 Numeric_Input_5 Numeric_Input_6 Numeric_Input_7 
			Numeric_Input_8 Numeric_Input_9 Numeric_Input_10 Categorical_Input_4_Sum_Tgt_Rep Numeric_Input_11 Numeric_Input_12;

%let noenc = Numeric_Input_1 Numeric_Input_2 Numeric_Input_3 Numeric_Input_4 Numeric_Input_5 Numeric_Input_6 Numeric_Input_7 
			Numeric_Input_8 Numeric_Input_9 Numeric_Input_10 Numeric_Input_11 Numeric_Input_12;

/************************************************************************/
/*		Loading model_train and model_train_val datasets into    */
/*		memory				                           */	
/************************************************************************/

data casuser.model_train;
	set SESUGDTA.model_train;
run;

data casuser.model_train_val;
	set SESUGDTA.model_train_val;
run;

/************************************************************************/
/*		Training five different models for both input lists 	     */
/************************************************************************/

%macro varlist(list,name);

***** Decision Tree *****;
proc treesplit data= casuser.model_Train;
   class Target;
   model Target = &list;
   code file="&outdir./DT_Model_&name..sas"; 
run;

data casuser.scored_DT_&name (keep=P_Target1 P_Target0 Target Train);
  set casuser.model_Train_val (keep=&list Target Train);
  %include "&outdir./DT_Model_&name..sas";
run;

***** Logistic Regression *****;
proc logselect data=casuser.model_Train;
   model Target(event='1')= &list;
   code file="&outdir./LR_Model_&name..sas" pcatall;
run;

data casuser.scored_LR_&name (keep=P_Target1 P_Target0 Target Train);
  set casuser.model_Train_val (keep=&list Target Train);
  %include "&outdir./LR_Model_&name..sas";
run;

***** Random Forest *****;
proc forest data=casuser.model_Train outmodel=casuser.RF_&name;
	input &list/ level = interval;
    Target Target/ level = nominal;
run;

proc forest data=casuser.model_Train_val inmodel=casuser.RF_&name;
  output out=casuser.scored_RF_&name copyvars=(_ALL_);
run;

***** Gradient Boosting *****;
proc gradboost data=casuser.model_Train  outmodel=casuser.GB_&name;
  input  &list   / level = interval;
  Target Target/ level=nominal;
run;

proc gradboost  data=casuser.model_Train_val   inmodel=casuser.GB_&name noprint;
  output out=casuser.scored_GB_&name copyvars=(_ALL_);
run;

***** Neural Network *****;
proc nnet data=casuser.model_Train;
  Target Target/ level=nom;
  input &list / level=int;
	hidden 3;
  Train outmodel=casuser.nnet_model;
  ods exclude OptIterHistory;
  code file="&outdir./NN_&name..sas";
run;

data casuser.scored_NN_&name (keep=P_Target1 P_Target0 Target Train);
  set casuser.model_Train_val  (keep=&list Target Train);
  %include "&outdir./NN_&name..sas";
run;

%mend;

%varlist(&all,W_ENC);
%varlist(&noenc,WO_ENC); 

/************************************************************************/
/*		Calculating recall at the highest scored percentile      */
/*		on the validation dataset                                */
/************************************************************************/

/* Please note that the recall statistics will be slightly different 
compared to Table 2 for tree-based models */

%macro dataset(name, model, list);

	proc rank data=casuser.scored_&name out=ranked_&name groups=100 descending;
	var p_target1;
	ranks target_score_rank;
	where train = 0; /* Change to 1 to calculate train data performance metrics */
	run;

	proc sql; 
 	select sum(target) 
	into :tot_val_cf 
	from ranked_&name;
	quit; 

	proc sql;
	create table top_1_pct_rank_&name (drop=target_score_rank) as select
	target_score_rank,
	&model as Model,
	sum(target)  as Tot_target_recall_&list,
calculated Tot_target_recall_&list/&tot_val_cf. as Pct_target_recall_&list format percent8.1 

	from ranked_&name

	where target_score_rank = 0

	group by target_score_rank;
	quit;
%mend;

%dataset(DT_W_ENC, 'Decision Tree', W_ENC);
%dataset(DT_WO_ENC, 'Decision Tree', WO_ENC);
%dataset(LR_W_ENC, 'Logistic Regression', W_ENC);
%dataset(LR_WO_ENC, 'Logistic Regression', WO_ENC);
%dataset(RF_W_ENC, 'Random Forest', W_ENC);
%dataset(RF_WO_ENC, 'Random Forest', WO_ENC);
%dataset(GB_W_ENC, 'Gradient Boosting', W_ENC);
%dataset(GB_WO_ENC, 'Gradient Boosting', WO_ENC);
%dataset(NN_W_ENC, 'Neural Network', W_ENC);
%dataset(NN_WO_ENC, 'Neural Network', WO_ENC);

/************************************************************************/
/*		Appending and joining recall datasets		            */	
/*		to create final comparison dataset   			     */		 
/************************************************************************/

data top_1_pct_recall_stats_w_enc;
format Model $32.;
set top_1_pct_rank_DT_w_Enc
		top_1_pct_rank_LR_w_Enc
		top_1_pct_rank_RF_w_Enc
		top_1_pct_rank_GB_w_Enc
		top_1_pct_rank_NN_w_Enc;
run;

data top_1_pct_recall_stats_wo_enc;
format Model $32.;
	set top_1_pct_rank_DT_wo_Enc
		top_1_pct_rank_LR_wo_Enc
		top_1_pct_rank_RF_wo_Enc
		top_1_pct_rank_GB_wo_Enc
		top_1_pct_rank_NN_wo_Enc;
run;

proc sql;
create table top_1_pct_recall_summary as select
a.Model,
a.Tot_target_recall_w_Enc,
a.Pct_target_recall_w_Enc,
b.Tot_target_recall_wo_Enc,
b.Pct_target_recall_wo_Enc

from top_1_pct_recall_stats_w_enc as a left join top_1_pct_recall_stats_wo_enc as b on a.model = b.model;
quit;

proc datasets; delete top_1_pct_rank_DT_w_Enc top_1_pct_rank_LR_w_Enc top_1_pct_rank_RF_w_Enc 
			top_1_pct_rank_GB_w_Enc top_1_pct_rank_NN_w_Enc top_1_pct_rank_DT_wo_Enc
			top_1_pct_rank_LR_wo_Enc top_1_pct_rank_RF_wo_Enc top_1_pct_rank_GB_wo_Enc
			top_1_pct_rank_NN_wo_Enc ranked_DT_W_ENC ranked_DT_WO_ENC ranked_LR_W_ENC
ranked_LR_WO_ENC ranked_RF_W_ENC ranked_RF_WO_ENC ranked_GB_W_ENC ranked_GB_WO_ENC ranked_NN_W_ENC ranked_NN_WO_ENC top_1_pct_recall_stats_w_enc top_1_pct_recall_stats_wo_enc; 
run;





