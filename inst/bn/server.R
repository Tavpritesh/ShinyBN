library('bnlearn')
library('networkD3')
library('rhandsontable')
library('shiny')
library('shinydashboard')
library('dplyr')
source('error.bar.R')

shinyServer(function(input, output,session) {
  options(shiny.maxRequestSize=30*1024^2)
  D = readRDS('iris.Rdata')
  DiscreteData <<- D
  bn.hc.boot <<- boot.strength(data = DiscreteData,R = 100,m =ceiling(nrow(DiscreteData)*0.7) ,algorithm = "hc")
  bn.hc.boot.pruned <<- bn.hc.boot[bn.hc.boot$strength > 0.5 & bn.hc.boot$direction >0.4,]
  bn.hc.boot.average <<- cextend(averaged.network(bn.hc.boot.pruned))
  bn.hc.boot.fit <<- bn.fit(bn.hc.boot.average,DiscreteData[,names(bn.hc.boot.average$nodes)],method = 'bayes')
  NetworkGraph <<- data.frame(directed.arcs(bn.hc.boot.average))
  nodeNames <<- names(bn.hc.boot.average$nodes)
  inserted  <<- c()
  insertedV <<- c()
  EventNode <<- nodeNames[1]
  EvidenceNode <<- c()
  updateSelectInput(session,'event',choices = nodeNames)
  rvs <<- reactiveValues(evidence = list(),values = list(),evidenceObserve = list(),valueObserve = list())
  networkData <<- NetworkGraph[,1:2]
  selectedNodes <<- nodeNames
  src <- NetworkGraph$from
  target <- NetworkGraph$to
  nodes <- data.frame(name = selectedNodes)
  nodes$id <- 0:(nrow(nodes) - 1)
  colnames(networkData) = c("src","target")
  edges <- networkData %>%
    left_join(nodes, by = c("src" = "name")) %>%
    select(-src) %>%
    rename(source = id) %>%
    left_join(nodes, by = c("target" = "name")) %>%
    select(-target) %>%
    rename(target = id)

  edges$width <- 1

  nodes$group <- "not in use"
  nodes[which(nodes$name %in% EvidenceNode),3] = "Evidence"
  nodes[which(nodes$name == EventNode),3] = "Event"
  ColourScale <- 'd3.scaleOrdinal().domain(["not in use","Event","Evidence"]).range(["#0E5AE8", "#50E80E","#FF0000"]);'
  output$structPlot <- networkD3::renderForceNetwork({
    networkD3::forceNetwork(Links = edges, Nodes = nodes,
                            Source = "source",
                            Target = "target",
                            NodeID ="name",
                            Group = "group",
                            Value = "width",
                            opacity = 0.9,
                            arrows = TRUE,
                            opacityNoHover = 0.9,
                            legend = T,
                            colourScale = JS(ColourScale),
                            zoom = TRUE)
  })

  # Get the data selection from user
  observeEvent(input$dataFile,

               {# Get the uploaded file from user
                 inFile <- input$dataFile
                 if (is.null(inFile))
                 {
                   #DiscreteData <<- NULL
                   print("Data File is empty")
                 }
                 else
                 {
                   tryCatch({
                     #print("c")
                     DiscreteData <<- readRDS(inFile$datapath)
                     #print("cc")
                     check = 0
                     for(p in colnames(DiscreteData))
                     {
                       #print(p)
                       if(is.numeric(DiscreteData[,p]))
                       {
                         #print(check)
                         check = check + 1
                       }
                     }
                     #print(check)
                     if(check > 0){
                       tryCatch({
                         for(k in colnames(DiscreteData[,sapply(DiscreteData,is.integer)]))
                         {
                           DiscreteData[,k] = as.numeric(DiscreteData[,k])
                         }
                         tryCatch({
                           print("test")
                           DiscreteData <<- as.data.frame(bnlearn::discretize(data.frame(DiscreteData),method="interval"))
                         },error = function(e){
                           print("error -2")

                           DiscreteData <<- as.data.frame(apply(DiscreteData,2,as.factor))

                         })

                         DiscreteData[,which(mapply(nlevels,DiscreteData[,sapply(DiscreteData,is.factor)])<2)] = NULL
                         DiscreteData <<- droplevels(DiscreteData)

                       },error = function(e){
                         print("error -1")
                         output$structPlot<- renderForceNetwork({validate("Error:Data uploaded was not discrete, tried discretization but failed please upload discrete data frame as single object")})

                       })
                     }
                     else
                     {
                       print("d")
                       DiscreteData[,which(mapply(nlevels,DiscreteData[,sapply(DiscreteData,is.factor)])<2)] = NULL
                       DiscreteData <<- droplevels(DiscreteData)
                     }

                   },error = function(e){
                     print("error-3")
                     output$structPlot<- renderForceNetwork({validate("Error:Data uploaded was not discrete or corrupted, tried discretization but failed please upload discrete data frame as single object")})


                   })



                   print("Data loaded")
                 }


               }
  )


  # Get the data selection from user
  observeEvent(input$structFile,

               {# Get the uploaded file from user
                 inFile <- input$structFile
                 if (is.null(inFile))
                 {
                   print("Structure File is empty")
                 }
                 else
                 {
                   if(is.null(DiscreteData))
                   {
                     print("Please Upload Data File First")
                   }
                   else
                   {
                     tryCatch({
                       bn.hc.boot.average <<- readRDS(inFile$datapath)
                       bn.hc.boot.fit <<- bn.fit(bn.hc.boot.average,DiscreteData[,names(bn.hc.boot.average$nodes)],method = 'bayes')
                       print("Learned Structure loaded")
                       for(elem in 1:length(inserted))
                       {
                         removeUI(
                           ## pass in appropriate div id
                           selector = paste0('#', inserted[elem])
                         )

                       }
                       inserted <<- c()
                       for(elem2 in 1:length(insertedV))
                       {
                         removeUI(
                           ## pass in appropriate div id
                           selector = paste0('#', insertedV[elem2])
                         )

                       }
                       insertedV <<- c()
                       rvs$evidence <<- c()
                       rvs$value <<- c()
                       rvs$evidenceObserve <<- c()
                       rvs$valueObserve <<- c()
                       output$distPlot <<- renderPlot(NULL)
                       NetworkGraph <<- data.frame(directed.arcs(bn.hc.boot.average))
                       nodeNames <<- names(bn.hc.boot.average$nodes)
                       EventNode <<- nodeNames[1]
                       EvidenceNode <<- c()
                       updateSelectInput(session,'event',choices = nodeNames)
                       networkData = NetworkGraph[,1:2]
                       selectedNodes <<- nodeNames
                       src <<- NetworkGraph$from
                       target <<- NetworkGraph$to
                       nodes <<- data.frame(name = nodeNames)
                       nodes$id <- 0:(nrow(nodes) - 1)
                       colnames(networkData) = c("src","target")
                       edges <- networkData %>%
                         left_join(nodes, by = c("src" = "name")) %>%
                         select(-src) %>%
                         rename(source = id) %>%
                         left_join(nodes, by = c("target" = "name")) %>%
                         select(-target) %>%
                         rename(target = id)

                       edges$width <- 1

                       nodes$group <- "not in use"
                       nodes[which(nodes$name %in% EvidenceNode),3] = "Evidence"
                       nodes[which(nodes$name == EventNode),3] = "Event"
                       ColourScale <- 'd3.scaleOrdinal().domain(["not in use","Event","Evidence"]).range(["#0E5AE8", "#50E80E","#FF0000"]);'

                       output$structPlot <- networkD3::renderForceNetwork({
                         networkD3::forceNetwork(Links = edges, Nodes = nodes,
                                                 Source = "source",
                                                 Target = "target",
                                                 NodeID ="name",
                                                 Group = "group",
                                                 Value = "width",
                                                 opacity = 0.9,
                                                 arrows = TRUE,
                                                 opacityNoHover = 0.9,
                                                 legend = T,
                                                 colourScale = JS(ColourScale),
                                                 zoom = TRUE)
                       })
                     },error = function(e){
                       print("error 1")
                       output$structPlot<- renderForceNetwork({validate("Error: in processing your request of structure learning. Possible reasins of error can be unsuited learning algorithm, .Rdata format not used for data or structure upload, inappropriate bnlearn file, thresholds set for pruning returns no results")})

                     })
                   }
                 }
               }
  )



  # Learn the structure of the network
  observeEvent(input$learnBtn, {
    tryCatch({
      print("Structure Learning started")
      if (is.null(DiscreteData))
        return(NULL)

      # Create a Progress object
      progress <- shiny::Progress$new()

      # Make sure it closes when we exit this reactive, even if there's an error
      on.exit(progress$close())
      progress$set(message = "Learning network structure", value = 0)

      # Get the selected learning algorithm from the user and learn the network
      bn.hc.boot <<- boot.strength(data = DiscreteData, R = input$boot, m = ceiling(nrow(DiscreteData)*input$SampleSize), algorithm = input$alg)
      bn.hc.boot.pruned <<- bn.hc.boot[bn.hc.boot$strength > input$edgeStrength & bn.hc.boot$direction > input$directionStrength,]
      bn.hc.boot.average <<- cextend(averaged.network(bn.hc.boot.pruned))
      bn.hc.boot.fit <<- bn.fit(bn.hc.boot.average,DiscreteData[,names(bn.hc.boot.average$nodes)],method = 'bayes')
      print("Structure learning done")
      for(elem in 1:length(inserted))
      {
        removeUI(
          ## pass in appropriate div id
          selector = paste0('#', inserted[elem])
        )

      }
      inserted <<- c()
      for(elem2 in 1:length(insertedV))
      {
        removeUI(
          ## pass in appropriate div id
          selector = paste0('#', insertedV[elem2])
        )

      }
      insertedV <<- c()
      rvs$evidence <<- c()
      rvs$value <<- c()
      rvs$evidenceObserve <<- c()
      rvs$valueObserve <<- c()
      output$distPlot <<- renderPlot(NULL)
      NetworkGraph <<- data.frame(directed.arcs(bn.hc.boot.average))
      nodeNames <<- names(bn.hc.boot.average$nodes)
      EventNode <<- nodeNames[1]
      EvidenceNode <<- c()
      updateSelectInput(session,'event',choices = nodeNames)
      networkData = NetworkGraph[,1:2]
      selectedNodes <<- nodeNames
      src <- NetworkGraph$from
      target <- NetworkGraph$to
      nodes <- data.frame(name = nodeNames)
      nodes$id <- 0:(nrow(nodes) - 1)
      colnames(networkData) = c("src","target")
      edges <- networkData %>%
        left_join(nodes, by = c("src" = "name")) %>%
        select(-src) %>%
        rename(source = id) %>%
        left_join(nodes, by = c("target" = "name")) %>%
        select(-target) %>%
        rename(target = id)

      edges$width <- 1

      nodes$group <- "not in use"
      nodes[which(nodes$name %in% EvidenceNode),3] = "Evidence"
      nodes[which(nodes$name == EventNode),3] = "Event"
      ColourScale <- 'd3.scaleOrdinal().domain(["not in use","Event","Evidence"]).range(["#0E5AE8", "#50E80E","#FF0000"]);'
      output$structPlot <- networkD3::renderForceNetwork({
        networkD3::forceNetwork(Links = edges, Nodes = nodes,
                                Source = "source",
                                Target = "target",
                                NodeID ="name",
                                Group = "group",
                                Value = "width",
                                opacity = 0.9,
                                arrows = TRUE,
                                opacityNoHover = 0.9,
                                legend = T,
                                colourScale = JS(ColourScale),
                                zoom = TRUE)
      })
    },error = function(e){
      print("error 2")
      output$structPlot<- renderForceNetwork({validate("Error: in processing your request of structure learning. Possible reasins of error can be unsuited learning algorithm, .Rdata format not used for data or structure upload, inappropriate bnlearn file, thresholds set for pruning returns no results")})

    })


  })
  observeEvent(input$learnSBtn, {
    tryCatch({
      print("Structure Learning started")
      if (is.null(DiscreteData))
        return(NULL)

      # Create a Progress object
      progress <- shiny::Progress$new()

      # Make sure it closes when we exit this reactive, even if there's an error
      on.exit(progress$close())
      progress$set(message = "Learning network structure", value = 0)

      # Get the selected learning algorithm from the user and learn the network
      if(input$alg == 'hc')
      {
        bn.hc.boot.average <<- bnlearn::hc(DiscreteData)
      }
      else if(input$alg == 'tabu')
      {
        bn.hc.boot.average <<- bnlearn::tabu(DiscreteData)
      }
      else if(input$alg == 'gs')
      {
        bn.hc.boot.average <<- bnlearn::gs(DiscreteData)
      }
      else if(input$alg == 'iamb')
      {
        bn.hc.boot.average <<- bnlearn::iamb(DiscreteData)
      }
      else if(input$alg == 'fast.iamb')
      {
        bn.hc.boot.average <<- bnlearn::fast.iamb(DiscreteData)
      }
      else if(input$alg=='inter.iamb')
      {
        bn.hc.boot.average <<- bnlearn::inter.iamb(DiscreteData)
      }
      else if(input$alg == 'mmhc')
      {
        bn.hc.boot.average <<- bnlearn::mmhc(DiscreteData)
      }
      else if(input$alg == 'rsmax2')
      {
        bn.hc.boot.average <<- bnlearn::rsmax2(DiscreteData)
      }
      else if(input$alg == 'mmpc')
      {
        bn.hc.boot.average <<- bnlearn::mmpc(DiscreteData)
      }
      else if(input$alg == 'si.hiton.pc')
      {
        bn.hc.boot.average <<- bnlearn::si.hiton.pc(DiscreteData)
      }
      else if(input$alg == 'aracne')
      {
        bn.hc.boot.average <<- bnlearn::aracne(DiscreteData)
      }
      else
      {
        bn.hc.boot.average <<- bnlearn::chow.liu(DiscreteData)
      }
      #bn.hc.boot.average <<- bnlearn::hc(DiscreteData)
      bn.hc.boot.fit <<- bn.fit(bn.hc.boot.average,DiscreteData[,names(bn.hc.boot.average$nodes)],method = 'bayes')
      print("Structure learning done")
      for(elem in 1:length(inserted))
      {
        removeUI(
          ## pass in appropriate div id
          selector = paste0('#', inserted[elem])
        )

      }
      inserted <<- c()
      for(elem2 in 1:length(insertedV))
      {
        removeUI(
          ## pass in appropriate div id
          selector = paste0('#', insertedV[elem2])
        )

      }
      insertedV <<- c()
      rvs$evidence <<- c()
      rvs$value <<- c()
      rvs$evidenceObserve <<- c()
      rvs$valueObserve <<- c()
      output$distPlot <<- renderPlot(NULL)
      NetworkGraph <<- data.frame(directed.arcs(bn.hc.boot.average))
      nodeNames <<- names(bn.hc.boot.average$nodes)
      EventNode <<- nodeNames[1]
      EvidenceNode <<- c()
      updateSelectInput(session,'event',choices = nodeNames)
      networkData = NetworkGraph[,1:2]
      selectedNodes <<- nodeNames
      src <- NetworkGraph$from
      target <- NetworkGraph$to
      nodes <- data.frame(name = nodeNames)
      nodes$id <- 0:(nrow(nodes) - 1)
      colnames(networkData) = c("src","target")
      edges <- networkData %>%
        left_join(nodes, by = c("src" = "name")) %>%
        select(-src) %>%
        rename(source = id) %>%
        left_join(nodes, by = c("target" = "name")) %>%
        select(-target) %>%
        rename(target = id)

      edges$width <- 1

      nodes$group <- "not in use"
      nodes[which(nodes$name %in% EvidenceNode),3] = "Evidence"
      nodes[which(nodes$name == EventNode),3] = "Event"
      ColourScale <- 'd3.scaleOrdinal().domain(["not in use","Event","Evidence"]).range(["#0E5AE8", "#50E80E","#FF0000"]);'
      output$structPlot <- networkD3::renderForceNetwork({
        networkD3::forceNetwork(Links = edges, Nodes = nodes,
                                Source = "source",
                                Target = "target",
                                NodeID ="name",
                                Group = "group",
                                Value = "width",
                                opacity = 0.9,
                                arrows = TRUE,
                                opacityNoHover = 0.9,
                                legend = T,
                                colourScale = JS(ColourScale),
                                zoom = TRUE)
      })
    },error = function(e){
      print("error 2")
      output$structPlot<- renderForceNetwork({validate("Error: in processing your request of structure learning. Possible reasins of error can be unsuited learning algorithm, .Rdata format not used for data or structure upload, inappropriate bnlearn file, thresholds set for pruning returns no results")})

    })


  })

  observeEvent(input$insertBtn, {
    tryCatch({
      nodeNames = names(bn.hc.boot.average$nodes)
      btn <<- input$insertBtn
      id <- paste0('Evidence', btn)
      idL <- paste("Evidence", btn)
      idV <- paste0('Value', btn)
      idVL <- paste("Value", btn)
      insertUI(selector = '#placeholder1',
               ui = tags$div(selectInput(id,'Evidence',nodeNames),
                             id = id
               )
      )
      insertUI(selector = '#placeholder2',
               ui = tags$div(selectInput(idV,'Value',levels(DiscreteData[,nodeNames[1]])),
                             id = idV
               )
      )
      inserted <<- c(id, inserted)
      insertedV <<- c(idV,insertedV)
      rvs$evidence <<- c(rvs$evidence,id)
      rvs$value <<- c(rvs$value,id)
      rvs$evidenceObserve <<- c(rvs$evidenceObserve,observeEvent(input[[id]],{
        tryCatch({
          valID = insertedV[which(inserted == id)]
          #print(valID)
          updateSelectInput(session,valID, choices = levels(DiscreteData[,input[[id]]]))
        },error = function(e){
          output$distPlot<-renderPlot({validate("error: Please learn structure or upload structure on new data uploaded to make infrences")})
        })
      }))

    },error = function(e){
      print("error 3")
      output$structPlot<- renderForceNetwork({validate("Error: in processing your request of structure learning. Possible reasins of error can be unsuited learning algorithm, .Rdata format not used for data or structure upload, inappropriate bnlearn file, thresholds set for pruning returns no results")})

    })
  })

  observeEvent(input$removeBtn, {
    removeUI(
      ## pass in appropriate div id
      selector = paste0('#', inserted[length(inserted)])
    )
    inserted <<- inserted[-length(inserted)]
    removeUI(
      ## pass in appropriate div id
      selector = paste0('#', insertedV[length(insertedV)])
    )
    insertedV <<- insertedV[-length(insertedV)]
    rvs$evidence <<- rvs$evidence[-length(inserted)]
    rvs$value <<- rvs$value[-length(insertedV)]
    rvs$evidenceObserve <<- rvs$evidenceObserve[-length(inserted)]
    rvs$valueObserve <<- rvs$valueObserve[-length(insertedV)]
  })
  observeEvent(input$plotBtn,{
    tryCatch({
      str1 <<- ""
      count =1
      for(elem in inserted)
      {
        vid = insertedV[which(inserted == elem)]
        str1 <<- paste0(str1,"(", input[[elem]], "=='", input[[vid]], "')")
        if(count!=length(inserted))
        {
          str1 <<- paste0(str1," & ")
        }
        count = count + 1
      }
      probs = prop.table(table(cpdist(bn.hc.boot.fit,input$event,evidence = eval(parse(text = str1)))))
      output$distPlot = renderPlot({par(mar=c(5,3,3,3))
        par(oma=c(5,3,3,3))
        barplot(probs,
                col = "lightblue",
                main = "Conditional Probabilities",
                border = NA,
                xlab = "",
                ylab = "Probabilities",
                ylim = c(0,1),
                las=2)})

    },error = function(e){
      print("error 4")
      output$distPlot<- renderPlot({validate("Error: in processing your request of inference.Please set an evidence node first")})
    })

  })
  observeEvent(input$plotStrengthBtn,{
    tryCatch({
      probT = c()
      for(i in 1:25)
      {
        str1 <<- ""
        count =1
        for(elem in inserted)
        {
          vid = insertedV[which(inserted == elem)]
          str1 <<- paste0(str1,"(", input[[elem]], "=='", input[[vid]], "')")
          if(count!=length(inserted))
          {
            str1 <<- paste0(str1," & ")
          }
          count = count + 1
        }
        probs = prop.table(table(cpdist(bn.hc.boot.fit,input$event,evidence = eval(parse(text = str1)))))
        probT = rbind(probT,probs)
      }
      ee = 1
      ee$mean = colMeans(probT)
      ee$sd = apply(probT, 2, sd)
      #print(ee)
      #print(probs)
      output$distPlot = renderPlot({par(mar=c(5,3,3,3))
        par(oma=c(5,3,3,3))
        barx <-barplot(ee$mean,
                col = "lightblue",
                main = "Conditional Probabilities",
                border = NA,
                xlab = "",
                ylab = "Probabilities",
                ylim = c(0,1),
                las=2)
        error.bar(barx,ee$mean, 1.96*ee$sd/5)})

    },error = function(e){
      print("error 4")
      output$distPlot<- renderPlot({validate("Error: in processing your request of inference.Please set an evidence node first")})
    })

  })
  observeEvent(input$saveBtn,{
    tryCatch({
      saveRDS(bn.hc.boot.average,file = input$path)

    },error = function(e)
      {
        print("Please add a valid directory")

    })

  })
  observeEvent(input$saveBtn2,{
    tryCatch({
      write.csv(NetworkGraph,file = input$path2,row.names = FALSE)


    },error = function(e)
    {
      print("Please add a valid directory")

    })
  })
  observeEvent(input$graphBtn,{
    #print(DiscreteData)
    for(elem in inserted)
    {
      EvidenceNode = c(EvidenceNode,input[[elem]])
    }
    EventNode = input$event
    networkData <<- NetworkGraph[,1:2]
    src <- NetworkGraph$from
    target <- NetworkGraph$to
    nodes <- data.frame(name = selectedNodes)
    nodes$id <- 0:(nrow(nodes) - 1)
    colnames(networkData) = c("src","target")
    edges <- networkData %>%
      left_join(nodes, by = c("src" = "name")) %>%
      select(-src) %>%
      rename(source = id) %>%
      left_join(nodes, by = c("target" = "name")) %>%
      select(-target) %>%
      rename(target = id)

    edges$width <- 1
    #print(nodes)
    #print(edges)
    nodes$group <- "not in use"
    nodes[which(nodes$name %in% EvidenceNode),3] = "Evidence"
    nodes[which(nodes$name == EventNode),3] = "Event"
    ColourScale <- 'd3.scaleOrdinal().domain(["not in use","Event","Evidence"]).range(["#0E5AE8", "#50E80E","#FF0000"]);'
    output$structPlot <- networkD3::renderForceNetwork({
      networkD3::forceNetwork(Links = edges, Nodes = nodes,
                              Source = "source",
                              Target = "target",
                              NodeID ="name",
                              Group = "group",
                              Value = "width",
                              opacity = 0.9,
                              arrows = TRUE,
                              opacityNoHover = 0.9,
                              zoom = TRUE,
                              legend = T,
                              colourScale = JS(ColourScale))
    })



  })
})
