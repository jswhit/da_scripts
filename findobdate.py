import dateutils, sys
date=sys.argv[1]
datenext=date
yyyy,mm,dd,hh=dateutils.splitdate(datenext)
while hh not in [0,6,12,18]:
    datenext=dateutils.dateshift(datenext,1)
    yyyy,mm,dd,hh=dateutils.splitdate(datenext)
dateprev=date
dateprev=dateutils.dateshift(dateprev,-1)
yyyy,mm,dd,hh=dateutils.splitdate(dateprev)
while hh not in [0,6,12,18]:
    dateprev=dateutils.dateshift(dateprev,-1)
    yyyy,mm,dd,hh=dateutils.splitdate(dateprev)
datem3 = dateutils.dateshift(dateprev,-3)
datep3 = dateutils.dateshift(dateprev,3)
if date >= datem3 and date <= datep3:
    print(dateprev)
else:
    print(datenext)
