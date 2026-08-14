#  table2_kappa_dev_and_validation.R

library(readxl); library(dplyr); library(stringr)

# 4 file paths aths 
dev_ai  <- "/Users/wangyuqi/Desktop/30 test_/meta_analysis_run1.csv"
dev_man <- "/Users/wangyuqi/Desktop/30 test_/data_extraction_Kinsley.xlsx"
val_ai  <- "/Users/wangyuqi/Desktop/20test_/test_set_20_results.csv"
val_man <- "/Users/wangyuqi/Desktop/data_extraction_Alexa.xlsx"

single <- c("intervention_level_3","control_type_level_1","control_type_level_2")
norm  <- function(x) tolower(trimws(as.character(x)))
deacc <- function(x) tolower(str_replace_all(iconv(x,to="ASCII//TRANSLIT"),"[^A-Za-z]",""))
mode1 <- function(v){v<-norm(v);v<-v[!is.na(v)];if(!length(v))return(NA_character_);names(sort(table(v),decreasing=TRUE))[1]}
kappa <- function(a,b){n<-length(a);po<-mean(a==b);cats<-union(a,b)
pe<-sum(vapply(cats,function(c)mean(a==c)*mean(b==c),numeric(1)));(po-pe)/(1-pe)}
kci <- function(A,B){set.seed(1);n<-length(A);k0<-kappa(A,B)
bs<-replicate(2000,{i<-sample(n,n,replace=TRUE);kappa(A[i],B[i])})
ci<-quantile(bs,c(.025,.975),na.rm=TRUE);sprintf("%.2f (%.2f, %.2f)",k0,ci[1],ci[2])}

# Development-set matching 
ai_d<-read.csv(dev_ai,stringsAsFactors=FALSE,check.names=FALSE)
man_d<-read_excel(dev_man,sheet="data_extraction")
man_d<-man_d%>%mutate(fw=deacc(str_extract(author,"^[A-Za-zÀ-ÿ]+")),yr=as.character(year))
uq<-man_d%>%distinct(study_ID,fw,yr)%>%group_by(fw,yr)%>%filter(n()==1)%>%ungroup()
lk<-setNames(uq$study_ID,paste(uq$fw,uq$yr)); ovd<-c("Campbell_2017.pdf"=190L,"Campbell_2017（Dose）.pdf"=265L)
ai_d<-ai_d%>%mutate(fw=deacc(str_extract(paper_id,"^[A-Za-z]+")),yr=str_extract(paper_id,"\\d{4}"),
                    study_ID=as.integer(ifelse(paper_id%in%names(ovd),ovd[paper_id],lk[paste(fw,yr)])))
man_d$study_ID<-as.integer(man_d$study_ID)

# Validation-set matching (filename ID-N, a few manual; Alexa workbook skip=1)
ai_v<-read.csv(val_ai,stringsAsFactors=FALSE,check.names=FALSE)
man_v<-read_excel(val_man,sheet="data_extraction",skip=1)
mm<-c("2008_Woodcocketal.pdf"=6,"Aviron_07"=2668,"Blümel_24"=1358,"Jacot_07"=2617,
      "Magagnoli_24"=790,"Schubert_22"=1473,"paper23_sydenham2023.pdf"=1583,"von Königslöw_2022.pdf"=407)
mv<-function(p){id<-str_match(p,"ID-(\\d+)")[,2];if(!is.na(id))return(as.integer(id))
for(k in names(mm))if(startsWith(p,k)||p==k)return(as.integer(mm[[k]]));NA_integer_}
ai_v$study_ID<-vapply(ai_v$paper_id,mv,integer(1)); man_v$study_ID<-as.integer(man_v$study_ID)

tab<-function(ai,man){cm<-sort(intersect(unique(ai$study_ID[!is.na(ai$study_ID)]),unique(man$study_ID)))
sapply(single,function(f){A<-sapply(cm,function(k)mode1(ai[[f]][ai$study_ID==k]))
B<-sapply(cm,function(k)mode1(man[[f]][man$study_ID==k]));ok<-!is.na(A)&!is.na(B);kci(A[ok],B[ok])})}

Table2<-data.frame(Moderator=single, Development=tab(ai_d,man_d), Validation=tab(ai_v,man_v))
print(Table2, row.names=FALSE)

