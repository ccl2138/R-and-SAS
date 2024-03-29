## Libraries ##
library(gdata)
library(sas7bdat)
library(ggplot2)
library(gplots)
library(grid)
library(reshape)
library(plyr)
library(car)
library(lattice)
library(plotrix)
library(zoo)
library(stats)
library(epicalc)
library(car)

################

## Bring in MRI_count data
#DATA REMOVED#

colnames(mri) <-  tolower(gsub('_', '.', colnames(mri)))
ll(mri)

mri.sub <- subset(mri, (grepl("P", mri$idnum)==TRUE) | grepl("3D", mri$idnum)==TRUE | 
    (grepl("P", mri$idnum)==FALSE & grepl("D", mri$idnum)==FALSE))
mri.sub$age.yr <- mri.sub$age.at.scan/365.25
ll(mri.sub)

table(mri.sub$mri.number)
table(mri.sub$mritypemain)
# age.at.scan in days?
summary(mri$age.at.scan)

## add regression line of growth to plot
hip.grow <- lm(right.vol ~ log(age.at.scan), data=mri.sub)
hip.grid <- with(mri.sub, expand.grid(
    age.at.scan = seq(min(na.omit(age.at.scan)), max(na.omit(age.at.scan)), by = 1)
    ))
hip.grid$right.vol <- stats::predict(hip.grow, newdata=hip.grid)

#qplot(age.at.scan, right.vol, data=hip.grid)

qplot(age.at.scan, right.vol, data=subset(mri.sub, age.at.scan <3300 ), group=idnum, 
      geom=  "line")

# using ggplot
ggplot(data=subset(mri.sub, age.at.scan < 3300), aes(x=(age.at.scan/365.25), y=right.vol)) + 
    geom_line(aes(group=idnum)) + 
    geom_smooth(method="lm", formula= y~log(x), se=FALSE)

## EEEKKKK IT WORKED!

## Look at change in volume between one year and five year ##
ggplot(data=subset(mri.sub, mritypemain == 2 | mritypemain == 7), aes(x=age.at.scan/365.25, y=right.vol)) +
    geom_line(aes(group=idnum)) 

    ## Left
ggplot(data=subset(mri.sub, mritypemain == 2 | mritypemain == 7), aes(x=age.at.scan/365.25, y=left.vol)) +
    geom_line(aes(group=idnum)) 


## Who has vol > 3500 at age 10 on right side? ##
subset(mri.sub[,c('idnum', 'mritypemain', 'age.yr', 'right.vol', 'left.vol')], right.vol > 3500)


## Change in volume between baseline and one year -- should log transform? 
ggplot(data=subset(mri.sub, mritypemain == 1 | mritypemain == 2), aes(x=age.at.scan/365.25, y=right.vol)) +
    geom_line(aes(group=idnum))

    # with transform
    ggplot(data=subset(mri.sub, mritypemain == 1 | mritypemain == 2), aes(x=log(age.at.scan/365.25), y=right.vol)) +
        geom_line(aes(group=idnum))


########################################################
##  Plot segments ## 

mri.sub <- ddply(mri.sub, .(idnum), transform, lag.right.vol = c(NA, right.vol[-length(right.vol)]))
mri.sub <- ddply(mri.sub, .(idnum), transform, lag.left.vol = c(NA, left.vol[-length(left.vol)]))
mri.sub <- ddply(mri.sub, .(idnum), transform, lag.mri.num = c(NA, mri.number[-length(mri.number)]))
mri.sub <- ddply(mri.sub, .(idnum), transform, lag.age.yr = c(NA, age.yr[-length(age.yr)]))

# Colors for plot segments 
    # acute - second MRI - Red
    # second - any subsequent MRI - gray
mri.sub$seg.color<- ifelse(mri.sub$lag.mri.num == 1, 'acute', 'nonacute')


## AAAAHHHHHH AMAZING. ##
    # I think its true then, that most growth is happening between the acute and 1 yr follow up MRI #
ggplot(mri.sub, aes(data=mri.sub, group = idnum)) +
    geom_segment(aes(x=lag.age.yr, xend=age.yr, y=lag.right.vol, yend=right.vol, color=seg.color))

# same plot but with a random subset of IDNUMs #
mri.sub.rand <- subset(mri.sub, idnum%in%sample(levels(idnum), 50))

ggplot(mri.sub.rand, aes(data=mri.sub.rand, group = idnum)) +
    geom_segment(aes(x=lag.age.yr, xend=age.yr, y=lag.right.vol, yend=right.vol, color=seg.color))

#################################################################################
## Age at 5 yr MRI
five.yr.age <- mri.sub$age.at.scan[mri.sub$mritypemain==7]/365.25 

boxplot(five.yr.age, main="Age at time of five-year MRI", ylab = "Age in Years", xlab = "n = 58")
boxplot.n((age.at.scan/365.25)~mritypemain, data=subset(mri.sub, mritypemain == 1 | mritypemain == 2 |
                                                        mritypemain == 7), ylim=c(-1, 11),
          names=c("Baseline MRI", "1 Year Follow Up MRI", "5 Year Follow Up MRI"))

#################################################################################
## PERCENT CHANGE FUNCTION ##

perc.change <- function(start.val, end.val){
    delta <- ((end.val - start.val)/start.val)*100
    return(delta)
}
#################################################################################
    ## CCL-- taking out 3D001 b/c its an outlier... not sure why but had 150% growth...


five.growth <- reshape(subset(mri.sub, (mritypemain == 1 | mritypemain == 2 | mritypemain == 7)), 
                       idvar = "idnum", timevar="mritypemain", direction = "wide")

    # Calc percent change in hippocampal volume between acute and 1 yr # 
five.growth$growth.acute.right <- perc.change(five.growth$right.vol.1, five.growth$right.vol.2)
five.growth$growth.acute.left <- perc.change(five.growth$left.vol.1, five.growth$left.vol.2)
    # Calc percent change in hippocampal volume between 1 yr and five yr #
five.growth$growth.fu.right <- perc.change(five.growth$right.vol.2, five.growth$right.vol.7)
five.growth$growth.fu.left <- perc.change(five.growth$left.vol.2, five.growth$left.vol.7)
    # Change in age from 1 year to 5 year # 
five.growth$delta.age <- five.growth$age.yr.7 - five.growth$age.yr.2

subset(mri.sub, idnum %in% c("3D001", "4P009"), select = c(idnum, mri.number, mritypemain, right.vol, left.vol))


## What is the average % change for the 'acute' period vs the 'five yr follow up'?
summary(subset(five.growth[, c('growth.acute.right','growth.acute.left','growth.fu.right', 'growth.fu.left')], idnum)

                    #####   PLOTS   #####
#############################################################################
## Plot histograms of growth for acute to 1 yr and 1 yr to 5 yr ##
hist(five.growth$growth.acute.right, col=rgb(1, 0, 0, 0.5), xlim=c(-40, 120))
hist(five.growth$growth.fu.right, col=rgb(0, 0, 1, 0.5), add=T)


summary(five.growth$growth.acute.right)
summary(five.growth$growth.fu.right)
ggplot(five.growth, aes(x=growth.acute.right)) + geom_histogram(colour="black", fill="white")
ggplot(five.growth, aes(x=growth.fu.right)) + geom_histogram(colour="black", fill="white")

#############################################################################
    # Age at 1 year MRI and percent change from ACUTE MRI #
qplot(age.yr.1, c(growth.acute.right, growth.acute.left), data=five.growth, pch = c(15, 17), ylim = c(-40, 150),
      main = "Percent Change in Hippocampal Volume from Acute MRI to One Year FU MRI and Age at FU",
      ylab = "Percent Change in Volume", xlab = "Age at Baseline [in years]", bg = 'white', 
      cex = 2) + theme_bw()
#qplot(age.yr.7, growth.acute.left, data=five.growth, pch = 17)

# Age at 1 Year MRI and percent change from one year MRI to five year MRI
qplot(age.yr.2, c(growth.fu.right, growth.fu.left), data=five.growth, pch = c(15, 17), ylim = c(-30, 140),
      main = "Percent Change in Hippocampal Volume from One Year MRI to Five Year FU MRI and Age at 1YR Follow up",
      ylab = "Percent Change in Volume", xlab = "Age at One Year Follow Up [in years]", bg = 'white', 
      cex = 2) + theme_bw()

## SOMETHING IS UP WITH 4P009 and 3D001... ###
subset(five.growth[,c('idnum', 'growth.acute.right', 'growth.fu.right')], growth.acute.right > 90)
subset(five.growth[,c('idnum', 'growth.acute.right', 'growth.fu.right')], growth.fu.right > 90)

## Regression + reg diagnostics
acute.nt <- lm(growth.acute.right~age.yr.2, data=subset(five.growth, idnum != "3D001"))
summary(acute.nt)
    qqPlot(acute.nt, main = "QQ Plot)")
    leveragePlot(acute.nt)
    influencePlot(acute.nt, id.method="identify")

ll(five.growth)
subset(five.growth, idnum %in% c("4P009", "3D001"), select=c('idnum','age.yr.1', 'age.yr.2', 'right.vol.1', 'right.vol.2', 'growth.acute.right') )

acute.t <- glm(growth.acute.right~log(age.yr.2), data=five.growth)
summary(five.growth$growth.acute.right[five.growth$idnum != "4P009"])


lrtest(acute.nt, acute.t)


    # Age at 5 year MRI and percent change from ONE YEAR FU MRI #
qplot(age.yr.7, growth.fu.right, data=five.growth)
qplot(age.yr.7, growth.fu.left, data = five.growth)

    # Percent change in volume from 1 year to 5 year and TIME BETWEEN MRIs #
qplot(delta.age, growth.fu.right, data = five.growth)
qplot(delta.age, growth.fu.left, data = five.growth)

## What if the change is really just a function of their baseline age?
    ## ie if you're younger initially, you're going to grow more just as a function
qplot(age.yr.1, growth.fu.right, data = five.growth)
qplot(age.yr.1, growth.fu.left, data = five.growth)

## relationship between age & change in age and percent change in volume
summary(lm(growth.fu.right~age.at.scan.7, data=five.growth))

# is all the change happening between acute and 1 year ?
summary(lm(growth.acute.right~age.at.scan.7, data=five.growth))

summary(lm(growth.fu.right~age.at.scan.2, data=five.growth))
summary(lm(growth.fu.right~delta.age, data=five.growth))


## Finding 3D001 as outlier... 
five.growth[c(five.growth$perc.growth.right > 100 & is.na(five.growth$perc.growth.right)==FALSE), ]

#################################################################################
plot(hip.grid)

summary(hip.grow)
x <- seq(0, 500, by=1)

qplot(age.at.scan, right.vol, data = mri.sub)
qplot(log(age.at.scan), right.vol, data=mri.sub)
abline(lm(log(right.vol)~age.at.scan, data=mri.sub))

plot(hip.grid)
plot(lm(right.vol ~ age.at.scan + age.at.scan^2, data = mri.sub))

