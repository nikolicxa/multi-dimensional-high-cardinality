# Don't be so One-Dimensional: How to Engineer Multi-Dimensional High Cardinality Categorical Inputs for Machine Learning

### Materials from a paper/talk for [Southeast SAS User Group Conference](https://www.sesug.org/SESUG2022/index.php), held on October 23-25, 2022 in Mobile, AL. 

Materials provided:

- [Full conference paper](https://github.com/nikolicxa/multi-dimensional-high-cardinality/files/9825992/How.to.Engineer.Multi-Dimensional.High.Cardinality.Categorical.Inputs.for.Machine.Learning.pdf)

- [Slides](https://github.com/nikolicxa/multi-dimensional-high-cardinality/files/9826053/Presentation_SESGUG2022_199_Final.pdf) used in presentation

- Two Demonstrations:
  * Demonstration 1 - An implementation of calculating target representation using k-fold cross validation from Section 5 of the paper in [.sas](https://github.com/nikolicxa/multi-dimensional-high-cardinality/blob/main/Code%20used%20in%20demonstrations/SESGUG2022_199_Demonstration_1.sas) format and Python (coming soon). 
  * Demonstration 2 - Model trianing and evaluation from Appendix B of the paper in [.sas](https://github.com/nikolicxa/multi-dimensional-high-cardinality/blob/main/Code%20used%20in%20demonstrations/SESGUG2022_199_Demonstration_2.sas) format and Python (coming soon).
  
- Three datasets:
  * raw_non_sum_file - Used in Demonstration 1 in [.sas](https://github.com/nikolicxa/multi-dimensional-high-cardinality/blob/main/Data%20used%20in%20demonstrations/raw_non_sum_file%20-%20sas.zip) and [csv](https://github.com/nikolicxa/multi-dimensional-high-cardinality/blob/main/Data%20used%20in%20demonstrations/raw_non_sum_file%20-%20csv.zip) formats
  * model_train - Used in Demonstration 2 in [.sas](https://github.com/nikolicxa/multi-dimensional-high-cardinality/blob/main/Data%20used%20in%20demonstrations/model_train%20-%20sas.zip) and [csv](https://github.com/nikolicxa/multi-dimensional-high-cardinality/blob/main/Data%20used%20in%20demonstrations/model_train%20-%20csv.zip) formats
  * model_train_val - Used in Demonstration 2 in [.sas](https://github.com/nikolicxa/multi-dimensional-high-cardinality/blob/main/Data%20used%20in%20demonstrations/model_train_val%20-%20sas.zip) and [csv](https://github.com/nikolicxa/multi-dimensional-high-cardinality/blob/main/Data%20used%20in%20demonstrations/model_train_val%20-%20csv.zip) formats
  
## Prerequisites

The .sas example file for Demonstration 1 should work in any relatively recent installation of SAS® 9.4 with SAS/STAT. The .sas example file for Demonstration 2 will only work in SAS Viya™ versions 3.5 and above.   

## Authors

* [nikolicxa](https://github.com/nikolicxa)


## Disclaimer

This project is in no way affiliated with SAS Institute Inc.
