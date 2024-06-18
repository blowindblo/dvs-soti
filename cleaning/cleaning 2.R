
# Load libraries and data -------------------------------------------------
library(tidyverse)
library(stringr)
library(entity)
library(quanteda)
library(spacyr)
library(stringdist)

df <- read.csv('2021_survey_data.csv')


# Initial extraction of variables -----------------------------------------
inspir <- df %>% 
  select(chronID, DVGoTos__, ToolsForDV_:ToolsForDV_Other__) %>% 
  filter(DVGoTos__ != "") %>% 
  rename(ID = chronID,
         inspiration = DVGoTos__) %>% 
  mutate(type = '') %>% 
  mutate(inspiration = tolower(inspiration)) %>% 
  separate_rows(inspiration, sep = ",|[^r]/|;") %>% 
  filter(inspiration != "") %>% 
  mutate(inspiration = trimws(inspiration),  # remove trailing spaces
         doc_id = 1:nrow(.)) # add unique id for each row (necessary for nlp later)
  # mutate(ToolsForDV_R = case_when(ToolsForDV_ggplot2 != '' ~ 'R/ggplot2',
  #                                 ToolsForDV_R != '' ~ 'R/ggplot2',
  #                                 TRUE ~ ToolsForDV_R)) %>% 
  # select(-ToolsForDV_ggplot2)


# manually separate responses into multiple rows based on puncutations
sep <- inspir %>% 
  separate_rows(inspiration, sep = ",|[^r]/|;|\\. |\\)") %>% 
  filter(inspiration != "") %>% 
  mutate(inspiration = trimws(inspiration),
         length = length(inspiration)) %>% 
  filter(nchar(inspiration) > 1)
# 
# View(sep %>% arrange(-nchar(inspiration)))
# data.frame(unique(sep$inspiration))
# 
# 
# x<-sep %>% filter(grepl(' and ',inspiration))
View(sep %>% filter(grepl('revel',inspiration)))
# 
# df[df$chronID == 136, 'DVGoTos__']




# NLP  --------------------------------------------------------------------
spacy_initialize(model = "en_core_web_sm")

corpus <- corpus(inspir,
                 docid_field = "doc_id",
                 text_field = "inspiration")

# token <- tokens(corpus,remove_punct = TRUE, remove_separators = TRUE, )
# keywords <- kwic(token, pattern =  "*witter")

x <- spacy_parse(corpus, nounphrase = TRUE, entity = TRUE)
x <- x %>% 
  mutate(pos = ifelse(token %in% wrong_pos, 'PROPN', pos)) %>% 
  filter(pos != 'PART') %>% 
  filter(nchar(token) > 1)

# y <- x %>% 
#   as.tokens(include_pos = "pos") %>% 
#   tokens_select(pattern = c('*/PROPN'))


# create new df whereby each row is a single phrase (based on nlp nounphrase var)
z <-
  data.frame(
    doc_id = character(),
    token = character(),
    pos = character(),
    token_id = character(),
    entity = character()
  )
j = 0
for (i in 1:nrow(x)){
  if (x[i,]$nounphrase == "beg"){
    j = j + 1
    z[j,]$doc_id <- x[i,]$doc_id
    z[j,]$token <- x[i,]$token
    z[j,]$token_id <- x[i,]$token_id
    z[j,]$pos <- x[i,]$pos
    z[j,]$entity <- x[i,]$entity
  } else if (x[i,]$nounphrase == "mid"){
    z[j,]$token <- paste(z[j,]$token, x[i,]$token)
    z[j,]$token_id <- paste(z[j,]$token_id, x[i,]$token_id)
    if (z[j,]$pos != x[i,]$pos){
      z[j,]$pos <- paste(z[j,]$pos, x[i,]$pos)
    }
    z[j,]$entity <- paste(z[j,]$entity, x[i,]$entity)
  } else if (x[i,]$nounphrase == "end_root"){
    z[j,]$token <- paste(z[j,]$token, x[i,]$token)
    z[j,]$token_id <- paste(z[j,]$token_id, x[i,]$token_id)
    if (z[j,]$pos != x[i,]$pos){
      z[j,]$pos <- paste(z[j,]$pos, x[i,]$pos)
    }
    z[j,]$entity <- paste(z[j,]$entity, x[i,]$entity)
  } else {
    j = j + 1
    z[j,]$doc_id <- x[i,]$doc_id
    z[j,]$token <- x[i,]$token
    z[j,]$token_id <- x[i,]$token_id
    z[j,]$pos <- x[i,]$pos
    z[j,]$entity <- x[i,]$entity
  }
}



# Manually populating databank of commonly mentioned inspirations ---------
# create df of commonly mentioned websites/journals/blogs, regex to identify them and their category 
{arguments <- data.frame(
  regex = c(
    'dribbble',
    'observable',
    'information is beautiful|candle',
    'behance',
    'pinterest',
    'storytelling|cole|swd',
    'pudding',
    'nyt',
    'new york',
    'economist',
    'nightingale',
    'tableau public|tableau community|tableau gallery',
    'datafam',
    'tidy',
    'twitter',
    # 'ironviz|iron viz',
    'washington|wa post',
    'bloomberg',
    'dvs|society',
    'fivethirtyeight|538',
    'ieee',
    'wrap|dispatch',
    'wsj|wall street journal',
    'flowing|nathan y',
    'geographic'
  ),
  replacement = c(
    'dribbble',
    'observable',
    'information is beautiful (david mccandless)',
    'behance',
    'pinterest',
    'storytelling with data (cole knaflic)',
    'pudding',
    'nyt',
    'nyt',
    'economist',
    'nightingale',
    'tableau public',
    '#datafam',
    '#tidytuesday',
    'twitter',
    # 'ironviz',
    'washington post',
    'bloomberg',
    'datavis society',
    '538',
    'IEEE',
    'datawrapper',
    'wall street journal',
    'flowingwithdata (nathan yau)',
    'national geographic'
  ),
  cat = c(
    'social network',
    'organisation',
    'blog',
    'social network',
    'social network',
    'blog',
    'magazine',
    'magazine',
    'magazine',
    'magazine',
    'magazine',
    'community',
    'community',
    'community',
    'community',
    # 'community',
    'magazine',
    'magazine',
    'community',
    'magazine',
    'organisation',
    'blog',
    'magazine',
    'blog',
    'magazine'
  )
)
}

replace_words <- function(regex, replacement, cat){
  manual_extract <- inspir %>% 
    filter(grepl(regex, inspiration)) %>% 
    mutate(inspiration = replacement,
           type = cat)
}
add_row_fast <- function(data, regex, replace, cat){
  add_row(data, regex = regex, replacement = replace, cat = cat)
}

arguments <- arguments %>% 
  add_row_fast('nature','nature','magazine') %>% 
  add_row_fast('guardian','guardian','magazine') %>% 
  add_row_fast('wapo','washington post','magazine') %>% 
  add_row_fast('d3','d3','blog') %>% 
  add_row_fast('accurat','accurat','organisation') %>% 
  add_row_fast('cap','visual capialist','magazine') %>% 
  add_row_fast('financ|ft','financial times','magazine') %>% 
  add_row_fast('insta| ig ','instagram','social network') %>% 
  add_row_fast('linkedin','linkedin','social network') %>% 
  add_row_fast('fathom|fanthom','fathom','organisation') %>% 
  add_row_fast('kont','kontinentalist','organisation') %>%
  add_row_fast('slack','slack','social network') %>%
  add_row_fast('makeover','#makeovermonday','community') 
  
# create df of influencers/professionals, regex to identify them and their category (person)
people <- data.frame(regex =c('tufte'), replacement=c('edward tufte'), cat=c('person'))
people <- people %>% 
  add_row_fast('evergreen', 'stephanie evergreen','person') %>% 
  add_row_fast('rosling', 'hans rosling','person') %>% 
  add_row_fast('shirley', 'shirley wu','person') %>% 
  add_row_fast('posavec', 'stefanie posavec','person') %>% 
  # add_row_fast('hillary', 'allen hillery','person') %>% 
  # add_row_fast('reougeux','nicholas rougeux','person') %>% 
  add_row_fast('lambrecht',  'maarten lambrecht','person') %>% 
  add_row_fast('cairo','alberto cairo','person') %>% 
  add_row_fast('flerlage|ferlage', 'kevin and ken flerlage','person') %>% 
  add_row_fast('munzner|muzner',  'tamara munzner','person') %>% 
  add_row_fast('bostock',  'mike bostock','person') %>% 
  add_row_fast('muth|charlotte|rost','lisa charlotte muth','person') %>% 
  add_row_fast('j andrew', 'r.j andrews','person') %>% 
  add_row_fast('moritz', 'moritz stefaner','person') %>% 
  add_row_fast('emery', 'ann k. emery','person') %>% 
  add_row_fast('amelia', 'amelia wattenberger','person')  %>% 
  add_row_fast('scherer|cedric', 'cedric scherer','person')  %>% 
  add_row_fast('schwabish', 'johnathan schwabish','person')  %>% 
  add_row_fast('pederson|pedersen', 'thomas lin pedersen','person')  %>% 
  add_row_fast('hullman', 'jessica hullman','person') %>%   
  add_row_fast('cesal', 'amy cesal','person') %>% 
  add_row_fast('cotgreave', 'andy cotgreave','person') %>% 
  add_row_fast('andy kirk', 'andy kirk','person') %>% 
  add_row_fast('nadieh', 'nadieh bremer','person') %>% 
  add_row_fast('torban', 'alli torban','person') %>% 
  add_row_fast('nadieh', 'nadieh bremer','person')  %>% 
  add_row_fast('chalabi', 'mona chalabi','person')   %>% 
  add_row_fast('geere', 'duncan geere','person')   %>% 
  add_row_fast('hadley', 'hadley wickham','person')   %>% 
  add_row_fast('catherine', 'catherine d\'ignazio','person') %>%    
  add_row_fast('navarro', 'danielle navarro','person') %>%    
  add_row_fast('cesal', 'amy cesal','person')    %>% 
  add_row_fast('valentina', 'valentina d\'efilippo','person') %>% 
  add_row_fast('judit', 'judit bekker','person') %>% 
  add_row_fast('zach', 'zach bowders','person') %>% 
  add_row_fast('wattenberger', 'amelia wattenberger','person') 
  


# based on the df of blogs/websites, extract responses that mention those blog/websites
manual_extract <- 
  do.call(Map, c(f = replace_words, arguments)) %>%  # for each blog/website, creates a df of responses that mentions it 
  do.call(rbind.data.frame, .) %>%   # binds all those df into a singular df 
  rbind(inspir %>%
          filter(grepl('beautiful', inspiration),
                 !grepl('information is beautiful',inspiration)) %>% 
          mutate(inspiration = 'r/dataisbeautiful', type = 'social network')) %>% 
  select(ID, inspiration, type, doc_id)


manual_extract_ppl <-
  do.call(Map, c(f = replace_words, people)) %>% 
  do.call(rbind.data.frame, .) %>% 
  select(ID, inspiration, type, doc_id)

View(inspir %>% filter(grepl('pedro',inspiration)))
View(inspir %>% filter(grepl('d3', inspiration)))
View(inspir %>% filter(grepl('esri', inspiration)))
View(inspir %>% filter(grepl('information lab', inspiration)))
View(inspir %>% filter(grepl('nathan y', inspiration)))



# Extract names based on NLP  ---------------------------------------------
pronouns <- z %>% 
  filter(pos == 'PROPN'| pos == 'NOUN') %>% 
  filter(!grepl(paste(arguments[,1], collapse="|"), token)) %>% 
  mutate(doc_id = as.integer(doc_id)) %>% 
  filter(!(token %in% c('tableau','nasa','ny'))) %>% 
  filter(!grepl('tableau', token)) 
id_ref <- inspir %>% select(ID, doc_id)
pronouns <- merge(pronouns, id_ref, by = 'doc_id')

# Collapse names that are still split into multiple rows 
pronouns_count <- pronouns %>% 
  group_by(doc_id) %>% 
  mutate(n = n()) 

names_complete <- pronouns_count %>% 
  filter(n == 1)

names_prog <- pronouns_count %>%
  filter(n > 1)

names_prog_combine <- names_prog %>% 
  filter(nchar(token_id) == 1) %>% 
  group_by(doc_id) %>% 
  summarise(token=paste0(token,collapse=" "),
            pos = 'PROPN',
            token_id = paste0(token_id,collapse=" "),
            entity = paste0(entity,collapse=" "),
            ID = ID) %>% 
  unique(.)

names_complete <- names_prog %>% 
  filter(nchar(token_id) > 1) %>% 
  rbind(names_prog_combine) %>% 
  rbind(names_complete)

# Correct some misspellings or shorterned forms 
names <- names_complete %>% 
  mutate(token = case_when(token == 'few' ~ 'stephen few',
                           grepl('tufte', token) ~ 'edward tufte',
                           grepl('evergreen', token) ~ 'stephanie evergreen',
                           grepl('rosling|gapminder', token) ~ 'hans rosling',
                           grepl('shirley', token) ~ 'shirley wu',
                           grepl('posavec', token) ~ 'stefanie posavec',
                           grepl('hillary', token) ~ 'allen hillery',
                           grepl('reougeux', token) ~ 'nicholas rougeux',
                           grepl('lambrecht', token) ~ 'maarten lambrecht',
                           grepl('cairo', token) ~ 'alberto cairo',
                           grepl('flerlage|ferlage', token) ~ 'kevin and ken flerlage',
                           grepl('munzner|muzner', token) ~ 'tamara munzner',
                           grepl('bostock', token) ~ 'mike bostock',
                           grepl('muth|charlotte|rost', token) ~ 'lisa charlotte muth',
                           grepl('j andrew', token) ~ 'r.j andrews',
                           TRUE ~ token)) %>% 
  mutate(pos = case_when(grepl('flerlage|ferlage', token) ~ 'PROPN',
                         grepl('PERSON', entity) ~ 'PROPN',
                         TRUE ~ pos)) %>% 
  filter(nchar(token) > 2)  # only retain names that are two words or longer
  

# Using stringdist to use most commonly spelled names -----------------------
# just filtering out names which are too similar to other more popular ones
names_dist <- names %>% 
  filter(!(token %in% c('lisa rapp', 'denise')))

clean_words <- expand.grid(raw = unique(names_dist$token), clean = unique(names_dist$token)) %>% 
  mutate(raw = tolower(raw),
         clean = tolower(clean)) %>% 
  filter(grepl('^\\w+\\s\\w+$', raw)) %>% 
  filter(grepl('^\\w+\\s\\w+$', clean)) %>% 
  mutate(dist = stringdist(raw, clean, method = 'lv')) %>% 
  filter(dist <= 3,
         dist > 0) %>% 
  group_by(clean) %>% 
  mutate(count = n()) %>% 
  group_by(raw) %>% 
  summarize(clean = clean[which.max(count)],
            count = max(count)) 

freq_count <- table(names_dist$token) %>% data.frame() %>% 
  rename(clean = Var1,
         clean_count = Freq) %>% 
  mutate(clean = as.character(clean))

freq_count_raw <- table(names_dist$token) %>% data.frame() %>% 
  rename(raw = Var1, 
         raw_count = Freq) %>% 
  mutate(raw = as.character(raw)) 

# dictionary of the most commonly spelled words and all misspellings to be changed
clean_words_dict <- merge(freq_count, clean_words) %>%
  merge(freq_count_raw, by = 'raw') %>% 
  filter(clean_count >= raw_count)

# replacing mispelled names with the most common spelling 
for (i in 1:nrow(names)){
  if (names[i,]$token %in% clean_words_dict[,1]){
    index <- which(clean_words_dict[,1] == names[i,]$token)
    names[i,]$token <- clean_words_dict[index,]$clean
  }
}


# Final cleaning ----------------------------------------------------------
final_names <- names %>% 
  filter(pos == 'PROPN') %>% 
  group_by(token) %>% 
  mutate(count = n()) %>% 
  filter(count>3) %>% 
  filter(grepl('^\\w+\\s\\w+$', token)) %>% 
  select(ID, token, doc_id) %>% 
  mutate(type = 'person') %>% 
  rename(inspiration = token)

ref <- inspir %>% 
  select(ID,ToolsForDV_:ToolsForDV_Other__)

final_data <-
  rbind(final_names, manual_extract_ppl) %>% 
  mutate(inspiration = case_when(grepl('schwabish', inspiration) ~ 'johnathan schwabish',
                           TRUE ~ inspiration)) %>% 
  unique(.) %>% 
  rbind(manual_extract) %>% 
  merge(ref, by = 'ID', all.x = FALSE, all.y = FALSE) %>% 
  unique(.) %>% 
  group_by(inspiration) %>% 
  mutate(total_mentions = n()) %>% 
  mutate(type = str_to_title(type),
         inspiration = str_to_title(inspiration)) %>% 
  mutate(inspiration = case_when(inspiration == 'Nyt' ~ 'New York Times',
                                 inspiration == 'Ieee' ~ 'IEEE',
                                 TRUE ~ inspiration))
  
  
View(final_data %>% group_by(type, inspiration) %>% summarise(count = n()))
View(final_data %>% filter(ToolsForDV_Tableau == 'Tableau') %>% unique(ID))
View(final_data %>% group_by(ID) %>% filter(ToolsForDV_Tableau == 'Tableau') %>% summarise(count = n()))


names_for_df <- names(final_data)[6:37] %>% substring(.,11) %>% paste0('summ',.)
cols <-names(final_data)[6:37]
summary_df<-list()
for (i in 1:length(cols)){
  col <- cols[i]
  summary_df[[i]] <- final_data[final_data[col] != '',] %>% 
    group_by(type, inspiration) %>% 
    summarise(count = n())
  names(summary_df)[i] <- names_for_df[i]
}
list2env(summary_df,envir = .GlobalEnv)



names_for_col <- names(final_data)[6:37] %>% substring(.,12)
cols <-names(final_data)[6:37]

complete_df <- final_data[final_data[cols[1]] != '', ] %>% 
  group_by(type, inspiration, total_mentions) %>% 
  summarise(count = n()) %>% 
  mutate(tool = names_for_col[1])
for (i in 2:length(cols)){
  col <- cols[i]
  complete_df <- final_data[final_data[col] != '', ] %>% 
    group_by(type, inspiration, total_mentions) %>% 
    summarise(count = n()) %>% 
    mutate(tool = names_for_col[i]) %>% 
    rbind(complete_df)
}

# complete_df <- complete_df %>% 
#   mutate(type = str_to_title(type),
#          inspiration = str_to_title(inspiration))
final_data %>% 
  group_by(ID) %>% 
  slice(1) %>% 
  pivot_longer(cols = names(final_data)[6:37]) %>% 
  filter(value != '') %>% 
  group_by(value) %>% 
  count() %>% View()
  ungroup() %>%
  dplyr::slice_max(order_by = n, n = 20) %>% 
  select(value)

# save data as csv
# write.csv(final_data, file = 'dvs_survey_analysis.csv')
# write.csv(complete_df, file = 'dvs_survey_analysis_summary.csv')
# write.csv(total_mentions, file = 'dvs_survey_analysis_mentions.csv')

final_data %>% group_by(ID) %>% count(ID) %>% nrow()
total_mentions <- final_data %>% group_by(type, inspiration) %>% summarise(count = n())

# 
# final_data %>% 
#   mutate(ToolsForDV_R2 = case_when(ToolsForDV_ggplot2 != '' ~ 'R/ggplot2',
#                                   ToolsForDV_R != '' ~ 'R/ggplot2',
#                                   TRUE ~ ToolsForDV_R)) %>% 
#   select(ToolsForDV_R2,ToolsForDV_R,ToolsForDV_ggplot2) %>% 
#   View()
