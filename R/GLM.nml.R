# ------Helper functions for interacting with glm.nml files-----
# ------Jordan and Luke 2013

read.nml	<-	function(fileName='glm.nml',folder='../Data/'){
	# skip all commented lines, return all variables and associated values
	# requires NO return line variables (all variables must be completely defined on a single line)
	fileN	<-	paste(c(folder,fileName),collapse="")
	c <- file(fileN,"r") 
	fileLines <- readLines(c)
	close(c)
	lineStart	<-	substr(fileLines,1,1)
	ignoreLn	<-	lineStart=='!' | fileLines==""
	lineStart	<-	lineStart[!ignoreLn]
	fileLines	<-	fileLines[!ignoreLn]
	# find all lines which start with "&" * requires FIRST char to be value
	
	
	lineIdx		<- seq(1,length(lineStart))
	blckOpen	<-	lineIdx[lineStart=="&"]
	blckClse	<-	lineIdx[lineStart=="/"]
	
	
	nml <- list()
	for (i in 1:length(blckOpen)){
		blckName	<-	substr(fileLines[blckOpen[i]],2,nchar(fileLines[blckOpen[i]]))
		oldNms	<-	names(nml)
		nml[[i]]	<-	list()
		names(nml)	<-	c(oldNms,blckName)
    
    carryover = ''
    
		for (j in (blckOpen[i]+1):(blckClse[i]-1)){
      
			textLine	<-	paste(carryover, gsub("\t","",gsub(" ","",fileLines[j])), sep='')
      #cat(textLine,'\n')
      #browser()
			if(substr(textLine,1,1)!='!'){
        # Add a check here, sometimes, if there is a hanging comma, 
        #and only sumtimes that means add next row
        if(substr(textLine,nchar(textLine), nchar(textLine)) == ',' && 
             j+1 <= length(fileLines) && !any(grep("=",fileLines[j+1])) && !any(grep("/",fileLines[j+1]))){
          
          carryover = textLine
          next
        }else{
          carryover = ''
        }
				# else, line is commented out
				lineVal	<-	buildVal(textLine)
				nml[[i]]	<-	c(nml[[i]],lineVal)
				}
		}
	}
	return(nml)
}

# private function
buildVal	<-	function(textLine){
	#-----function appends nml list with new values-----
	# remove all text after comment string
	textLine	<-	strsplit(textLine,'!')[[1]][1]
  
	if (!any(grep("=",textLine))){stop(c("no hanging lines allowed in .nml, used ",textLine))}
	params	<-	strsplit(textLine,"=") # break text at "="
	parNm	<-	params[[1]][1]
	parVl	<-	params[[1]][2]
	# figure out what parval is...if string, remove quotes and keep as string
	# ***for boolean text, use "indentical" so that 0!= FALSE
	# can be: string, number, comma-sep-numbers, or boolean
	
	# special case for date:
	if (nchar(parVl>17) & substr(parVl,14,14)==':' & substr(parVl,17,17)==':'){
		parVl<-paste(c(substr(parVl,1,11),' ',substr(parVl,12,nchar(parVl))),collapse='')
		}
	if (any(grep("'",parVl))){
		parVl	<-	gsub("'","",parVl)
	}else if (any(grep(".true.",parVl))){
		parVl	<-	TRUE
	}else if (any(grep(".false.",parVl))){
		parVl	<-	FALSE
	}else if (any(grep(",",parVl))){	# comma-sep-nums
		parVl	<-	c(as.numeric(unlist(strsplit(parVl,","))))
	}else {	# test for number
		parVl	<-	as.numeric(parVl)
	}
	lineVal	<-	list(parVl)
	names(lineVal)	<-	parNm
	return(lineVal)
}

# private function
findBlck	<-	function(nml,argName){
	
  # test for argName being a string
  if (!is.character(argName)){stop(c("parameter name must be a string"))}
  fau <- " "
  fault.string <- rep(fau,100) # names fault matrix, only returned when empty match
	blockNames	<-	names(nml)
	blckI	<-	NULL
	for (i in 1:length(blockNames)){
		if (any(argName %in% names(nml[[i]]))){
			blckI	<- i
			break
		} else {
      one.i <- which(fault.string==fau)[1]
		  fault.string[one.i:(one.i+length(names(nml[[i]]))-1)]=names(nml[[i]])
		}
    
	}
  fault.string <- fault.string[!fault.string==fau] # is empty if found
  # test to see if a block match was made
	if (is.null(blckI)){stop(c("parameter name ",argName," not found in nml. Possible names:",paste(fault.string,collapse=', ')))}
	return(blckI)
}

# private function
setnmlList <- function(nml,argList){
  if (!is.list(argList)){stop("argList must be a list")}
  
  argNames  <-	names(argList)
  for (i in 1:length(argNames)){
    nml <- set.nml(nml,argName=argNames[i],argVal=argList[[i]])
  }
  return(nml)
}

set.nml	<-	function(nml,argName,argVal,argList=NULL){
  # nml is a list (as created by read.nml)
  # argName is a string
  # argVal is a numeric vector, character, or logical 
  # argList is a list with argName(s) and argValue(s)
  
  if (missing(argName)){
    return(setnmlList(nml,argList))
  }
  
  if (!is.null(argList) & argName %in% names(argList)){
    warning(c("duplicate names given to argName and argList.", 
            " argName and argVal values will overwrite duplicate argList values."))
    nml <- setnmlList(nml,argList)
  }
  
	# get appropriate block to place val within ** assumes no duplicate param names in other blocks **
	blckI	<-	findBlck(nml,argName)
	
	currVal	<-	nml[[blckI]][[argName]]
	typeError	<-	"input must be of same data type as current value"
	if (is.logical(currVal) & !is.logical(argVal)){
		stop(c(typeError,' (logical)'))
	} else if (is.character(currVal) & !is.character(argVal)){
		stop(c(typeError,' (character)'))
	} else if (is.numeric(currVal) & !is.numeric(argVal)){
		stop(c(typeError,' (numeric)'))
	}
	
	nml[[blckI]][[argName]]	<- argVal
	return(nml)
}

get.nml	<-	function(nml,argName,argVal){

	blckI	<-	findBlck(nml,argName)
	
	val	<-	nml[[blckI]][[argName]]
	return(val)
}

write.nml	<-	function(nml,fileName='glm.nml',folder='../Data/'){
	sink(paste(c(folder,fileName),collapse=''))
	
  pretty.nml(nml)
	sink()
}

pretty.nml <- function(nml){
  for (i in 1:length(names(nml))){ # these are the blocks
    blckNm	<-	names(nml)[i]
    cat("&")
    cat(blckNm)
    cat('\n')
    blckList	<-	nml[[i]]
    for (j in 1:length(names(blckList))){
      cat('   ')
      cat(names(blckList)[j])
      cat(' = ')
      if (length(blckList[[j]])>1){
        writer	<-	paste(c(blckList[[j]]),collapse=', ')
      } else if (is.character(blckList[[j]])) {
        charText	<-	strsplit(blckList[[j]],',')
        writer	<-	paste(c("'",paste(c(charText[[1]]),collapse="','"),"'"),collapse='')
      } else if (is.logical(blckList[[j]]) & blckList[[j]]){
        writer	<-	".true."
      } else if (is.logical(blckList[[j]]) & !blckList[[j]]){
        writer	<-	".false."
      } else {
        writer	<-	blckList[[j]]
      }
      cat(writer)
      cat('\n')
    }
    cat('/\n')
  }	
}

