classdata <- read.table(
  "../data/classdata.txt",
  header=T)

lineagedata <- read.table(
  "../data/lineage_table.txt")
  
classdata$phylum <- lineagedata$V2
classdata$kingdom <- lineagedata$V3

classdata <- classdata[order(avgscore),]

#write.table(classdata,
#            ""
#)


###


plot(log(classdata$species/classdata$studies), classdata$consistency_index, 
         col="gray", xlab="log(species/studies) coverage", ylab="score")
points(log(classdata$species/classdata$studies), classdata$retention_index,
       col="orange")
points(log(classdata$species/classdata$studies), classdata$rescaled_consistency_index,
       col="black")


avgscore <- (classdata$consistency_index+classdata$retention_index+classdata$rescaled_consistency_index)/3
avgscore2 <- (classdata$retention_index+classdata$rescaled_consistency_index)/2


kingdomfactor <- factor(classdata$kingdom[classdata$kingdom != "Eukaryota"])

boxplot(classdata$consistency_index[classdata$kingdom != "Eukaryota"] ~ kingdomfactor, 
        border="gray", ylab="CI", boxwex=0.25 )

boxplot(classdata$rescaled_consistency_index[classdata$kingdom != "Eukaryota"] ~ kingdomfactor, 
        border="black", ylab="RC", boxwex=0.25 )

b <- boxplot(classdata$consistency_index[classdata$kingdom != "Eukaryota"] ~ kingdomfactor, 
             plot=0)
boxplot(classdata$retention_index[classdata$kingdom != "Eukaryota"] ~ kingdomfactor, 
        names=paste(b$names, "\n( n = ", b$n, ")"),
        border="orange", ylab="RI", boxwex=0.25 )


plot(classdata$kingdom, avgscore,
     col="gray", ylab="avg CI/RI/RC")
plot(classdata$kingdom, avgscore2,
     col="gray", ylab="avg RI/RC")

plot(factor(classdata$phylum[classdata$kingdom != "Eukaryota"]), classdata$rescaled_consistency_index[classdata$kingdom != "Eukaryota"],
     col=factor(classdata$kingdom[classdata$kingdom != "Eukaryota"]), 
     ylab="avg RI/RC")


plot(classdata$rescaled_consistency_index ~ log(classdata$characters))
plot(classdata$rescaled_consistency_index ~ log(classdata$species))
plot(classdata$rescaled_consistency_index ~ log(classdata$studies))