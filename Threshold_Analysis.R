library(data.table)
library(tools)
library(ggplot2)
library(lubridate)
library(leaps)

root = 'C:/Users/cmeri/OneDrive - Dartmouth College/Math_76/FinalProject/Math76_FinalProject'

latitudes = data.table(Latitude=c(68.632100,68.356460,67.947201,68.889200,68.948500), ID=c("s002","s003","s004","s015","s019"))

files = list.files(paste0(root,'/Output'),pattern='csv',full.names = T)
ManualData = rbindlist(lapply(files[1:5],fread))

ManualData = ManualData[,ID:=substr(`File Name`,100,103)]
ManualData = ManualData[,Date:=as.Date(substr(basename(`File Name`),5,14))]
setnames(ManualData, 'Estimated Area', 'ManualArea')

# Normalize Data
ManualData = ManualData[,c('year','month'):=.(year(Date),month(Date))]
ManualData =unique(ManualData,by=c('ID','Date'))
ManualData = ManualData[,MaxArea:=max(ManualArea),by=c('ID')]
ManualData = ManualData[,NormalizedArea:=ManualArea/MaxArea]

NDVIData = fread(files[6])
NDVIData = NDVIData[,Area:=Pixels*100/1000000]
setnames(NDVIData,'Year','year')
setnames(NDVIData,'Month','month')

ThresholdData = fread(files[7])
ThresholdData = ThresholdData[,Area:=Pixels*100/1000000]

NoMask = fread(files[8])
NoMask = NoMask[,Area:=Pixels*100/1000000]

Data = merge(NDVIData,ManualData[,c('ManualArea','ID','Date')], by=c('ID','Date'))

#### Visualize Data ####
# Growth by slump
ggplot()+
  facet_wrap(vars(ID), scales = 'free')+
  geom_point(data=Data,aes(Date,Area,color=Threshold))+
  geom_point(data=Data,aes(Date,ManualArea),color='red')+
  theme_bw()

# Size by season
ggplot()+
  facet_wrap(vars(ID), scales = 'free')+
  geom_point(data=Data,aes(month(Date), ManualArea, color=year(Date)))+
  theme_bw()

ggplot()+
  geom_point(data=ManualData,aes(month, NormalizedArea, color=year(Date)))+
  theme_bw()

#### Best Subset Selection ####

# Add Latitude
ManualData = merge(ManualData, latitudes, by='ID')

# Generate polynomial terms
ManualData$month2 = ManualData$month^2
ManualData$year2 = ManualData$year^2

predictors <- ManualData[,c("month", "month2", "year", "year2", "Latitude")]
response <- ManualData$NormalizedArea

# Perform best subset selection
best_subset <- regsubsets(response ~ ., data = predictors, nbest = 1, nvmax = NULL, method = "exhaustive")
subset_summary = summary(best_subset)

# Plot the selection criteria
plot(best_subset, scale = "adjr2")
plot(best_subset, scale = "bic")

# Extract the best model coefficients based on BIC
best_bic_index <- which.min(subset_summary$bic)
best_model_coef <- coef(best_subset, best_bic_index)
print(best_model_coef)

#Fit Best Model
best_model_formula <- as.formula(paste("NormalizedArea ~", paste(names(best_model_coef[-1]), collapse = " + ")))
best_model <- lm(best_model_formula, data = ManualData)

# Visualize Model
ManualData$ModelValue <- predict(best_model, newdata = ManualData)

ggplot()+
  geom_function(fun = function(x) x)+
  geom_point(data=ManualData,aes(NormalizedArea, ModelValue, color=ID))+
  labs(x='Normalized Failure Area', y='Predicted Normalized Failure Area')+
  annotate('text',label='1:1 Line', x = 0.5, y=0.45)+
  theme_bw()

#### Growth Rate ####
ThresholdValidation = merge(ThresholdData,ManualData[,c('ManualArea','ID','Date')], by=c('ID','Date'))
ThresholdValidation = ThresholdValidation[,Error:=Area - ManualArea]
ThresholdValidation = ThresholdValidation[,RMSE:=sqrt((Error^2)/.N), by=c('ID','Threshold')]
ThresholdValidation = ThresholdValidation[,.SD[RMSE==min(RMSE)],by='ID']

ThresholdSubset = ThresholdData[Threshold==0.53]

# Rates 
ggplot()+
  facet_wrap(vars(ID), scales = 'free')+
  geom_point(data=ThresholdSubset,aes(Date,Area))+
  theme_bw()

ThresholdSubset = ThresholdSubset[,c('Rate','Growth'):=.((max(Area) - first(Area))/(2024-2019), max(Area) - first(Area)), by='ID']
Rates = unique(ThresholdSubset,by='Rate')

