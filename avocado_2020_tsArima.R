#options(warn = -1)
library(tidyverse)
library(lubridate)
library(hrbrthemes)
library(ggthemes)
library(tseries)
library(forecast)
library(anytime)
library(repr)
library(gridExtra)
library(knitr)
library(ggfortify)

options(scipen=10000)
#********************************Data Grooming for the Analysis*********************************
#read in the data file containing Hass Avocados
#
avocado_dfs <- read.csv("avocado.csv", sep = ",", header = T, stringsAsFactors = F)

#Drop the unrelvant data
#
avocado_dfs <- avocado_dfs[,-1] 

#Reassign the column names to be more informative
#
colnames(avocado_dfs) <- c("Date", "AvgPrice", "TotalVolume", 
                           "SmHassAvocado", "MdHassAvocado", "LgHassAvocado", 
                           "TotalBags","SmallBags", "MediumBags", "LargeBags",
                           "AvocadoLabel","Year","Region")

#convert the "Date" column to an approprirate POSIXct format
#
avocado_dfs$Date<- anytime::anytime(avocado_dfs$Date)

# changing the "Year" column to factor type
#
avocado_dfs$Year <- as.Date(as.character(avocado_dfs$Year), format = "%Y")
avocado_dfs$Year <- lubridate::year(avocado_dfs$Year)
avocado_dfs$Year <- as.factor(avocado_dfs$Year)

# extracting the "Month" from the "Date" column and then adding that as a new column
#
avocado_dfs$Month <- factor(months(avocado_dfs$Date), levels = month.name)

str(avocado_dfs) #look data types after changes

#Compare the price difference between the label from year to year
# 
#Sort original dataframe by year
#
avocado_dfs <- avocado_dfs[order(as.Date(avocado_dfs$Date)),]

#*******************************Visulizing Volume and Average Pricing of Avocados From Data***********************
#group the year, month, and label
#
group.year_mon_lab <- avocado_dfs %>% 
            group_by(Year, Month, AvocadoLabel) %>%
            select(Year, Month, AvocadoLabel, AvgPrice) %>%
            dplyr::summarise(avg_priceMean= mean(AvgPrice))

#Plot the Average price of both Avocados with respect to 12 months, for years 2015-2018
#
ggplot2::ggplot(data = group.year_mon_lab, aes(x= Month, y= avg_priceMean, colour= Year, group= Year)) +
          labs(title= "Average Monthly Price by Labels for Years", x= "Months", y= "Average Price",colour= "Year") +
          geom_line() +
          theme(plot.title = element_text(hjust = 0.5), legend.position = "right", axis.text.x = element_text(angle = 45, hjust = 1))+
          scale_color_brewer(palette = "Dark2") + 
          facet_grid(.~group.year_mon_lab$AvocadoLabel)

#group the year, region, price, for CONVENTIONAL
#
group.year_regio_prce_con <-  avocado_dfs %>%
                              select(Year, AvgPrice, AvocadoLabel, Region) %>%
                              filter(AvocadoLabel == "conventional")

minimum_con_price <- round(min(group.year_regio_prce_con$AvgPrice),2)- 0.1
maximum_con_price <- round(max(group.year_regio_prce_con$AvgPrice),2)+ 0.1


#Plot the Average price of CONVENTIONAL label for each region by year
#
ggplot2::ggplot(group.year_regio_prce_con, aes(x= Region, y= AvgPrice, colour = Year)) +
          labs(title = "Average Yearly Prices of Conventional Label by Regions for Years", x= "Regions", y= "Average Price", colour = "Year") +
          geom_tufteboxplot() +
          coord_flip() +
          theme(plot.title = element_text(hjust = 0.5), axis.text.x = element_text(angle = 90, vjust = 0)) +
          scale_color_brewer(palette = "Dark2")+
          facet_grid(.~group.year_regio_prce_con$Year, scales = "free")+
          scale_y_continuous(breaks = c(seq(minimum_con_price, maximum_con_price, 0.2)), limits = c(minimum_con_price, maximum_con_price))
          

#group the year, region, price, for ORGANIC
#
group.year_regio_prce_org <-  avocado_dfs %>%
  select(Year, AvgPrice, AvocadoLabel, Region) %>%
  filter(AvocadoLabel == "organic")

minimum_org_price <- round(min(group.year_regio_prce_org$AvgPrice),2)-0.1
maximum_org_price <- round(max(group.year_regio_prce_org$AvgPrice),2)+0.1

#Plot the Average price of ORGANIC label for each region by year
# 
ggplot2::ggplot(group.year_regio_prce_org, aes(x= Region, y= AvgPrice, colour = Year)) +
          labs(title = "Average Yearly Prices of Organic Label by Regions for Years", x= "Regions", y= "Average Price", colour = "Year") +
          geom_tufteboxplot() +
          coord_flip() +
          theme(plot.title = element_text(hjust = 0.5), axis.text.x = element_text(angle = 90, vjust = 0)) +
          scale_color_brewer(palette = "Dark2")+
          facet_grid(.~group.year_regio_prce_org$Year, scales = "free")+
          scale_y_continuous(breaks = c(seq(minimum_org_price, maximum_org_price, 0.2)), limits = c(minimum_org_price, maximum_org_price))


#*********************************Forecasting the Volume and Average Price to 2020 w/ ARIMA, and Time Series******************************************

#Putting Lables and its associated info together because they are independent attributes in the data sets
#
sum_conventional <- avocado_dfs %>%
                      filter(AvocadoLabel == "conventional") %>%
                      group_by(Date) %>%
                      dplyr::summarise(AveragePr= mean(AvgPrice), AverageVol= mean(TotalVolume))

sum_organic <- avocado_dfs %>%
                  filter(AvocadoLabel == "organic") %>%
                  group_by(Date) %>%
                  dplyr::summarise(AveragePr= mean(AvgPrice), AverageVol= mean(TotalVolume))

avgprice_con <- sum_conventional[,-3] #store date and price column
totvol_con <- sum_conventional[,-2] #store date and volume column

avgprice_org <-sum_organic[,-3] 
totvol_org <- sum_organic[,-2]

# Time series prep for both labels
#
ts_avgprice_con <- stats::ts(avgprice_con, start = c(2015,1), frequency = 52)
ts_totvol_con <- stats::ts(totvol_con, start = c(2015, 1), frequency = 52)

ts_avgprice_org <- stats::ts(avgprice_org, start = c(2015,1), frequency = 52)
ts_totvol_org <- stats::ts(totvol_org, start = c(2015, 1), frequency = 52)

#plot the time series graph for the price portion of the conventional label
#
ggplot2::autoplot(ts_avgprice_con[,2], xlab= "Continous Yearly Data", ylab= "Average Price",main= "Time Series of Pricing\nConventional Label", colour = "#a9ab3a")

#plot the time series graph for the volume portion of the conventional label
#
ggplot2::autoplot(ts_totvol_con[,2],xlab= "Continous Yearly Data", ylab= "Total Volume(tons)",main= "Time Series of Volume\nConventional Label", colour = "#a9ab3a")

#plot the time series graph for the price portion of the organic label
#
ggplot2::autoplot(ts_avgprice_org[,2], xlab= "Continous Yearly Data", ylab= "Average Price", main= "Time Series of Pricing\nOrganic Label", colour = "#4fa839")

#plot the time series graph for the volume portion of the organic label
#
ggplot2::autoplot(ts_totvol_org[,2], xlab= "Continous Yearly Data", ylab= "Total Volume(tons)",main= "Time Series of Volume\nOrganic Label", colour = "#4fa839")

#Pridicting the volume, average pricing for both labels through Auto Regressive Integrated Moving Average (ARIMA)
#
#Creating the  ARIMA variable for the Arima model plot for forecasting
#References: 
# (1)  https://datascienceplus.com/time-series-analysis-using-arima-model-in-r/
# (2)  https://rpubs.com/riazakhan94/arima_with_example
# (3)  https://www.youtube.com/watch?v=Y5T3ZEMZZKs 
# (4)  https://www.dummies.com/programming/r/how-to-predict-new-data-values-with-r/

# Creating ARIMA variables for forecasting the VOLUME in future years for CONVENTIONAL LABEL
#
best_arima_model <- auto.arima(ts_totvol_con[,2], d=1, D=1, stepwise=FALSE, approximation=FALSE, trace=TRUE) #find the best ARIMA Fit
forecast_model <- forecast(best_arima_model, h=140) #then forcast

ggplot2::autoplot(forecast_model, include=60, colour = "#a9ab3a") +
            theme(plot.title=element_text(hjust=0.5),
                  legend.position="bottom", 
                  legend.background = element_rect(fill="#FFF9F5",size=0.5, linetype="solid", colour ="black")) + 
            labs(title="Forecasting Volume of \n Conventional Avocados Towards 2021", x="Year", y="Total Volume(tons)")


# Creating ARIMA variables for forecasting the PRICE in future years for CONVENTIONAL LABEL
#
best_arima_model <- auto.arima(ts_avgprice_con[,2], d=1, D=1, stepwise=FALSE, approximation=FALSE, trace=TRUE) #find the best ARIMA Fit
forecast_model <- forecast(best_arima_model, h=140) #then forcast

ggplot2::autoplot(forecast_model, include=60, colour = "#a9ab3a") +
            theme(plot.title=element_text(hjust=0.5),
                  legend.position="bottom", 
                  legend.background = element_rect(fill="#FFF9F5",size=0.5, linetype="solid", colour ="black")) + 
            labs(title="Forecasting Prices of \n Conventional Avocados Towards 2021", x="Year", y="Price")

# Creating ARIMA variables for forecasting the VOLUME in future years for ORGANIC LABEL
#
best_arima_model <- auto.arima(ts_totvol_org[,2], d=1, D=1, stepwise=FALSE, approximation=FALSE, trace=TRUE) #find the best ARIMA Fit
forecast_model <- forecast(best_arima_model, h=140) #then forcast

ggplot2::autoplot(forecast_model, include=60, colour = "#4fa839") +
            theme(plot.title=element_text(hjust=0.5),
                  legend.position="bottom", 
                  legend.background = element_rect(fill="#FFF9F5",size=0.5, linetype="solid", colour ="black")) + 
            labs(title="Forecasting Volume of \n Organic Avocados Towards 2021", x="Year", y="Total Volume(tons)")


# Creating ARIMA variables for forecasting the PRICE in future years for ORGANIC LABEL
#
best_arima_model <- auto.arima(ts_avgprice_org[,2], d=1, D=1, stepwise=FALSE, approximation=FALSE, trace=TRUE) #find the best ARIMA Fit
forecast_model <- forecast(best_arima_model, h=140) #then forcast

ggplot2::autoplot(forecast_model, include=60, colour = "#4fa839") +
            theme(plot.title=element_text(hjust=0.5),
                  legend.position="bottom", 
                  legend.background = element_rect(fill="#FFF9F5",size=0.5, linetype="solid", colour ="black")) + 
            labs(title="Forecasting Prices of \n Organic Avocados Towards 2021", x="Year", y="Price")

