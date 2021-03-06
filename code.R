setwd("C:\\R Programming\\Spam SMS")
data<-read.csv("spam.csv",stringsAsFactors = FALSE)
library(tm)
library(SnowballC)
library(caTools)
library(dplyr)
library(textstem)
library(ngram)
Sys.setenv(JAVA_HOME='C:\\Program Files\\Java\\jre-10.0.2')
library(RWeka)

corpus = VCorpus(VectorSource(data$v2)) 
corpus = tm_map(corpus, content_transformer(tolower))
corpus = tm_map(corpus, removePunctuation)

#exceptions   <- c("not","too","bad","just","no","but")
#my_stopwords <- setdiff(stopwords("en"), exceptions)
corpus = tm_map(corpus, removeWords, stopwords("en"))
corpus <- tm_map(corpus, lemmatize_strings)
corpus <- tm_map(corpus, PlainTextDocument)
corpus = tm_map(corpus, stemDocument)


BigramTokenizer <- function(x) NGramTokenizer(x, Weka_control(min = 1, max = 3))
frequencies = DocumentTermMatrix(corpus,control = list(weighting = function(x) weightTfIdf(x, normalize = TRUE),tokenize = BigramTokenizer))


sparse = removeSparseTerms(frequencies, 0.97)
smsSparse = as.data.frame(as.matrix(sparse))
colnames(smsSparse) = make.names(colnames(smsSparse))


##Using 29 predictors
smsSparse$Class<-as.factor(data$v1)
set.seed(1)
library(caTools)
splits<-sample.split(smsSparse$Class,SplitRatio = 0.7)
train<-subset(smsSparse,splits==TRUE)
test<-subset(smsSparse,splits==FALSE)


##EDA
library(dplyr)
library(ggplot2)
explore<-train %>% group_by(Class) %>% summarise_all(mean)
print(explore)

names<-names(smsSparse[,1:29])
meansumham<-apply(subset(smsSparse[,1:29],as.character(smsSparse$Class)=="ham"), 2, sum)
meansumspam<-apply(subset(smsSparse[,1:29],as.character(smsSparse$Class)=="spam"), 2, sum)

dfham<-data.frame(names,meansumham)
dfspam<-data.frame(names,meansumspam)


ggplot(dfham,aes(y=meansumham,x=as.character(names)))+coord_flip()+geom_bar(stat="identity")

ggplot(dfspam,aes(y=meansumspam,x=as.character(names)))+coord_flip()+geom_bar(stat="identity")


##Feature Engineering
library(stringr)

noOfExclamation<-str_count(data$v2,"!")
containsWebsite<-str_count(data$v2,"www.")
noOfDigits<-str_count(data$v2,"[0-9]")
containgsPhoneNumber<-ifelse(grepl("[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]",data$v2),1,0)

##Normalizing noOfExclamation variable
noOfExclamation<-(noOfExclamation-min(noOfExclamation))/(max(noOfExclamation)-min(noOfExclamation))
##Let's see if there's any relation between my engineered variables and outcome(Class)
smsSparse$noOfExclamation<-noOfExclamation
smsSparse$containsWebsite<-containsWebsite
smsSparse$containgsPhoneNumber<-containgsPhoneNumber
smsSparse$noOfDigits<-noOfDigits

smsSparse$noOfDigits<-(smsSparse$noOfDigits-min(smsSparse$noOfDigits))/(max(smsSparse$noOfDigits)-min(smsSparse$noOfDigits))

splits<-sample.split(smsSparse$Class,SplitRatio = 0.7)
train<-subset(smsSparse,splits==TRUE)
test<-subset(smsSparse,splits==FALSE)

explore<- smsSparse %>% group_by(Class) %>% summarise(mean(noOfExclamation))
print(explore)

explore<- smsSparse %>% group_by(Class) %>% summarise(mean(containsWebsite))
print(explore)

explore<- smsSparse %>% group_by(Class) %>% summarise(mean(containgsPhoneNumber))
print(explore)

explore<- smsSparse %>% group_by(Class) %>% summarise(mean(noOfDigits))
print(explore)
##Clearly there is a trend between the engineered data and response variable.


##Data Modelling
library(caret)
library(nnet)
trControl<-trainControl(method="cv",number=5)
modelrpart<-train(Class~.,data=train,method="rpart",trControl=trControl)
predictionrpartTrain<-data.frame(predict(modelrpart,train,type="prob"))
predictionrpartTrain<-predictionrpartTrain[,2]

predictionrpart<-data.frame(predict(modelrpart,test,type="prob"))
predictionrpart<-predictionrpart[,2]
plot(modelrpart)

modelrf<-train(Class~.,data=train,method="rf",metric="Accuracy",trControl=trControl)
predictionrfTrain<-data.frame(predict(modelrf,train,type="prob"))
predictionrfTrain<-predictionrfTrain[,2]

predictionrf<-data.frame(predict(modelrf,test,type="prob"))
predictionrf<-predictionrf[,2]
plot(modelrf)


library(party)
modelctree<-train(Class~.,data=train,method="ctree",metric="Accuracy",trControl=trControl)
predictionctreeTrain<-data.frame(predict(modelctree,train,type="prob"))
predictionctreeTrain<-predictionctreeTrain[,2]

predictionctree<-data.frame(predict(modelctree,test,type="prob"))
predictionctree<-predictionctree[,2]
plot(modelctree)

modelgbm<-train(Class~.,data=train,method="gbm",metric="Accuracy",trControl=trControl)
predictiongbmTrain<-data.frame(predict(modelgbm,train,type="prob"))
predictiongbmTrain<-predictiongbmTrain[,2]

predictiongbm<-data.frame(predict(modelgbm,test,type="prob"))
predictiongbm<-predictiongbm[,2]
plot(modelgbm)

modelxgbtree<-train(Class~.,data=train,method="xgbTree",metric="Accuracy",trControl=trControl)
predictionxgbtreeTrain<-data.frame(predict(modelxgbtree,train,type="prob"))
predictionxgbtreeTrain<-predictionxgbtreeTrain[,2]

predictionxgbtree<-data.frame(predict(modelxgbtree,test,type="prob"))
predictionxgbtree<-predictionxgbtree[,2]
plot(modelxgbtree)

modelknn<-train(Class~.,data=train,method="knn",metric="Accuracy",trControl=trControl)
predictionknnTrain<-data.frame(predict(modelknn,train,type="prob"))
predictionknnTrain<-predictionknnTrain[,2]

predictionknn<-data.frame(predict(modelknn,test,type="prob"))
predictionknn<-predictionknn[,2]
plot(modelknn)

stackdf<-data.frame(a=predictionrpartTrain,b=predictionrfTrain,c=predictionctreeTrain,d=predictiongbmTrain,e=predictionknnTrain,Class=train$Class)
stackdftest<-data.frame(a=predictionrpart,b=predictionrf,c=predictionctree,d=predictiongbm,e=predictionknn)

model<-train(Class~.,data=stackdf,method="nnet",trControl=trControl)
predictions<-predict(model,stackdftest)

plot(model)
##Accuracy of ~97.6% on test set with stacking with 5 models

library(h2o)
Sys.setenv(JAVA_HOME='C:\\Program Files\\Java\\jre-10.0.2')
h2o.init()

h2otrain<-as.h2o(stackdf)
h2otest<-as.h2o(stackdftest)
modeldeeplearning<-h2o.deeplearning(x = 1:5 ,
                 y = "Class",
                 training_frame = h2otrain,
                 activation = "RectifierWithDropout",
                 l1 = 1.0e-5,l2 = 1.0e-5,
                 hidden=c(400, 400,400),
                 epochs = 200,
                 seed = 3.656455e+18)

h2opredictions<-as.data.frame(h2o.predict(modeldeeplearning,h2otest))
h2opredictions<-h2opredictions[,3]
table(h2opredictions>0.5,test$Class)
##Accuracy of ~ 97.9%