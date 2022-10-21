/*This section applies the concepts reviewed in Sections 3 and 4 via SAS code using the 
SESUGDTA.raw_non_sum_file dataset. The following code creates three new numeric features 
derived from the Raw_Categorical_Input_4 feature. However, before applying these concepts, 
you will need to do some pre-processing first to set up the data. 

First, you need to create a list of unique Transaction_ID values for the train dataset. The 
Train column contains the train dataset indicator. */
 
proc sql;
create table transaction_ID_list as select
distinct Transaction_Id, 
Target

from SESUGDTA.raw_non_sum_file
 
where Train=1 

order by Target;
run;

/*The next step assigns the fold IDs to the transaction_ID_list dataset using PROC 
SURVEYSELECT. The GROUP= option specifies the value of k. The STRATA statement 
stratifies the folds by the Target column. The RENAME= option renames the output column 
containing the fold assignments from groupid to Train_Fold. */

proc surveyselect data=transaction_ID_list group=5  seed=220401
out=strat_kfold (RENAME=(groupid=Train_Fold )); 
strata Target; 
run;

/*The following step maps the strat_kfold dataset with the fold assignments back to the 
original SESUGDTA.raw_non_sum_file dataset using the Transaction_ID as the key. */

proc sql;
create table raw_data_w_folds as select
a.*,
b.Train_Fold

from SESUGDTA.raw_non_sum_file as a left join strat_kfold as b on a.Transaction_Id = b.Transaction_Id; 
quit;

/*The next code block is where the new feature engineering methodology begins. It first creates
a concatenated string column that combines the values of the Transaction_ID and 
Raw_Categorical_Input_4 columns. The raw_data_w_folds dataset then gets split into 
train (raw_train_w_kfolds) and validation (raw_validation_w_kfolds) datasets.*/
 
data raw_train_w_kfolds raw_validation_w_kfolds ;
	set raw_data_w_folds;
Trans_ID_Raw_Categorical_Input_4 = CATX("~", Transaction_Id, Raw_Categorical_Input_4); 
if Train = 1 then output raw_train_w_kfolds; 
else output raw_validation_w_kfolds;
run;

/*Here is where the loop for k-fold target encoding begins. It creates a column containing the 
original values of the Raw_Categorical_Input_4 column by splitting the concatenated string 
column Trans_ID_Raw_Categorical_Input_4. The code then creates the target indicator 
column on the data from four out of the five folds and drops all observations where the 
input value does not have a target hit. 
A PROC SQL statement creates a macro variable (tot_train_cf) before summarizing the 
data to the values of Raw_Categorical_Input_4, which contains the sum of the 
Raw_Categorical_Input_4_TH column.*/

%macro kfold(fold);
 
proc sql;
create table raw_categorical_input_dedup as select
Trans_ID_Raw_Categorical_Input_4,
substr(Trans_ID_Raw_Categorical_Input_4, index(Trans_ID_Raw_Categorical_Input_4, '~') +1) 
as Raw_Categorical_Input_4, 
case when sum(Target) > 0 then 1
	else 0 end as Raw_Categorical_Input_4_TH 
from raw_train_w_Kfolds
 
where Train_Fold ne &fold 
 
group by Trans_ID_Raw_Categorical_Input_4 
 
having Raw_Categorical_Input_4_TH > 0;  
quit;
 
proc sql; 
select sum(Raw_Categorical_Input_4_TH) 
into :tot_train_cf 
from raw_categorical_input_dedup;
quit;

/*The next code block summarizes the raw_categorical_input_dedup dataset to the values
of Raw_Categorical_Input_4 using the data from k - 1 folds. It then maps to the dataset 
containing the fold left out by the WHERE statement using Raw_Categorical_Input_4 as the 
key. Please note that the columns calculated for this new dataset are only for 
observations where the Raw_Categorical_Input_4 had a Fraud value of 1.*/

proc sql;
create table Raw_Categorical_Input_4_f_&fold as select 
a.Transaction_Id,
a.Raw_Categorical_Input_4,
case when b.Tot_Raw_Categorical_Input_4_TH > 0 then 1
else 0 end as Raw_Categorical_Input_4_TH,
b.Raw_Categorical_Input_4_Sum_Rep

from (select Trans_ID_Raw_Categorical_Input_4,
			substr(Trans_ID_Raw_Categorical_Input_4, 
 			index(Trans_ID_Raw_Categorical_Input_4, '~') +1) as Raw_Categorical_Input_4,
 			scan(Trans_ID_Raw_Categorical_Input_4,1,'~') as Transaction_Id,
 			count(*) as total_line_items
 			from raw_train_w_Kfolds 

 			where Train_Fold = &fold 
 			
			group by Trans_ID_Raw_Categorical_Input_4) as a left join (select Raw_Categorical_Input_4,
																		sum(Raw_Categorical_Input_4_TH) as 
																		Tot_Raw_Categorical_Input_4_TH, 
																		sum(Raw_Categorical_Input_4_TH)/&tot_train_cf. as Raw_Categorical_Input_4_Sum_Rep

																		from raw_categorical_input_dedup 

																		group by Raw_Categorical_Input_4 ) as b on a.Raw_Categorical_Input_4 = b.Raw_Categorical_Input_4 
having Raw_Categorical_Input_4_TH > 0; 
quit;
 
%mend;
%kfold(1);
%kfold(2);
%kfold(3);
%kfold(4);
%kfold(5);


/*This step appends all five datasets created by the macro.*/
 
data raw_categorical_input_4_train;
	set raw_categorical_input_4_f_1 
		raw_categorical_input_4_f_2
		raw_categorical_input_4_f_3
		raw_categorical_input_4_f_4
		raw_categorical_input_4_f_5;  
run;

/*The code then summarizes the raw_categorical_input_4_train dataset to the unique 
values found in the Raw_Categorical_Input_4 input. It calculates the target representation
and target indicator columns using data from all five folds. */

proc sql;
create table Raw_Categorical_Input_4_trn_avg as select
Raw_Categorical_Input_4,
mean(Raw_Categorical_Input_4_Sum_Rep) as Mean_Categorical_Input_4_Sum_Rep, 
case when sum(Raw_Categorical_Input_4_TH) >0 then 1
	else 0 end as Raw_Categorical_Input_4_TH_Ind 

from raw_categorical_input_4_train

group by Raw_Categorical_Input_4 

having Raw_Categorical_Input_4_TH_Ind ne 0;
quit;

/*Then, the Raw_Categorical_Input_4_trn_avg dataset maps to the train and validation
datasets using Raw_Categorical_Input_4 as the key.*/
 
proc sql;
create table categorical_input_init_train as select
a.Transaction_Id,
a.Raw_Categorical_Input_4,
b.Mean_Categorical_Input_4_Sum_Rep,
b.Raw_Categorical_Input_4_TH_Ind

from (select Trans_ID_Raw_Categorical_Input_4,
			substr(Trans_ID_Raw_Categorical_Input_4,index(Trans_ID_Raw_Categorical_Input_4,'~') +1) as Raw_Categorical_Input_4,
			scan(Trans_ID_Raw_Categorical_Input_4,1,'~') as Transaction_Id,
			count(*) as Total_Line_Products

			from raw_train_w_Kfolds 

			group by Trans_ID_Raw_Categorical_Input_4) as a left join Raw_Categorical_Input_4_trn_avg as b on a.Raw_Categorical_Input_4 = b.Raw_Categorical_Input_4 

where b.Raw_Categorical_Input_4_TH_Ind > 0;
quit;

proc sql;
create table categorical_input_init_val as select
a.Transaction_Id,
a.Raw_Categorical_Input_4,
b.Mean_Categorical_Input_4_Sum_Rep,
b.Raw_Categorical_Input_4_TH_Ind
from (select Trans_ID_Raw_Categorical_Input_4,
			substr(Trans_ID_Raw_Categorical_Input_4,
			index(Trans_ID_Raw_Categorical_Input_4,'~')+1) as Raw_Categorical_Input_4,
			scan(Trans_ID_Raw_Categorical_Input_4,1,'~') as Transaction_Id,
			count(*) as Total_Line_Products
 
			from raw_validation_w_Kfolds 

			group by Trans_ID_Raw_Categorical_Input_4) as a left join Raw_Categorical_Input_4_trn_avg as b on a.Raw_Categorical_Input_4 = b.Raw_Categorical_Input_4 

where b.Raw_Categorical_Input_4_TH_Ind > 0;
quit;

/*Finally, the last two PROC SQL statements summarizes the raw train and validation
datasets to the Transaction_ID level, creating the final datasets
(sum_categorical_input_4_train  and sum_categorical_input_4_val). You will use 
these datasets to train machine learning models.*/ 

proc sql;
create table sum_categorical_input_4_train as select 
Transaction_Id,
sum(Raw_Categorical_Input_4_TH_Ind) as Categorical_Input_4_Tot_TH,
sum(Mean_Categorical_Input_4_Sum_Rep) as Categorical_Input_4_Sum_Tgt_Rep,
case when calculated Categorical_Input_4_Tot_TH > 0 then calculated Categorical_Input_4_Tot_TH * calculated Categorical_Input_4_Sum_Tgt_Rep
 	else 0 end as Categorical_Input_4_Enc_Prod
 
from categorical_input_init_train 

group by Transaction_Id; 
quit;

proc sql;
create table sum_categorical_input_4_val as select 
Transaction_Id,
sum(Raw_Categorical_Input_4_TH_Ind) as Categorical_Input_4_Tot_TH,
sum(Mean_Categorical_Input_4_Sum_Rep) as Categorical_Input_4_Sum_Tgt_Rep,
case when calculated Categorical_Input_4_Tot_TH > 0 then calculated Categorical_Input_4_Tot_TH * calculated Categorical_Input_4_Sum_Tgt_Rep
	else 0 end as Categorical_Input_4_Enc_Prod

from categorical_input_init_val 

group by Transaction_Id; 
quit;

proc datasets; delete transaction_ID_list strat_kfold
raw_data_w_folds raw_categorical_input_dedup 
raw_categorical_input_4_f_1 raw_categorical_input_4_f_2
raw_categorical_input_4_f_3 raw_categorical_input_4_f_4
raw_categorical_input_4_f_5 raw_categorical_input_4_train 
raw_train_w_Kfolds raw_validation_w_Kfolds
categorical_input_init_train
categorical_input_init_val;
quit;