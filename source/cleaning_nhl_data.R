#! /usr/bin/env Rscript
# cleaning_nhl_data.R
# Aditya, Shayne, Nov 2018
#
# R script for reading and cleaning data from game_teams_stats.csv file.
# The script takes an input file and names of output train and test file as arguments
# The specific team for which the analysis is being done needs to be provided  as the last arguement
# Usage: Rscript source/cleaning_nhl_data.R data/game_teams_stats.csv data/train.csv data/test.csv data/team_id.txt

# loading the required libraries
library(tidyverse)
library(zoo)

# getting cmd arguments into variables
args <- commandArgs(trailingOnly = TRUE)
input_file <- args[1]
output_file_train <- args[2]
output_file_test <- args[3]
team <- args[4]

# reading the input
nhl_data <- read_csv(input_file)

# reading the id of the team for which the analysis is to be performed
team_of_interest <- read_tsv(team)

# getting the columns with missing values
nhl_data_missing <- nhl_data %>%
    select_if(function(x) any(is.na(x))) %>%
    summarise_all(funs(sum(is.na(.))))

# getting the columns with empty values
nhl_data_empty <- nhl_data %>%
    select_if(function(x) any(x == "")) %>%
    summarise_all(funs(sum(. == "")))

# getting information by season
nhl_data_req <- nhl_data %>%
  arrange(game_id) %>%
  mutate(season = str_sub(game_id, start = 1, end = 4),
         reg_season = str_sub(game_id, start = 5, end = 6)) %>%
  group_by(season, reg_season) %>%
  filter(reg_season == "02")

# removing 2012 season as it is too long ago and was shortened by lockout
nhl_data_req <- nhl_data_req %>%
  left_join(nhl_data, by = c("game_id" = "game_id")) %>%
  filter(team_id.x != team_id.y, season != "2012")

# creating new features for the model
nhl_data_ready <- nhl_data_req %>%
  arrange(team_id.x, game_id) %>%
  group_by(team_id.x, season) %>%
  mutate(won_prev1 = rollapply(won.x, mean, align='right', fill=NA, width = list(-1:-1)),
         won_prev3 = rollapply(won.x, mean, align='right', fill=NA, width = list(-3:-1)),
         won_prev5 = rollapply(won.x, mean, align='right', fill=NA, width = list(-5:-1)),
         won_prev10 = rollapply(won.x, mean, align='right', fill=NA, width = list(-10:-1)),

         home_game = HoA.x=="home",

         shots_ratio = shots.x / (shots.x + shots.y),
         goals_ratio = goals.x / (goals.x + goals.y),
         save_ratio = 1 - goals.y / shots.y,

         shots_ratio_prev1 = rollapply(shots_ratio, mean, align='right', fill=NA, width = list(-1:-1)),
         shots_ratio_prev3 = rollapply(shots_ratio, mean, align='right', fill=NA, width = list(-3:-1)),
         shots_ratio_prev5 = rollapply(shots_ratio, mean, align='right', fill=NA, width = list(-5:-1)),
         shots_ratio_prev10 = rollapply(shots_ratio, mean, align='right', fill=NA, width = list(-10:-1)),

         goals_ratio_prev1 = rollapply(goals_ratio, mean, align='right', fill=NA, width = list(-1:-1)),
         goals_ratio_prev3 = rollapply(goals_ratio, mean, align='right', fill=NA, width = list(-3:-1)),
         goals_ratio_prev5 = rollapply(goals_ratio, mean, align='right', fill=NA, width = list(-5:-1)),
         goals_ratio_prev10 = rollapply(goals_ratio, mean, align='right', fill=NA, width = list(-10:-1)),

         save_ratio_prev1 = rollapply(save_ratio, mean, align='right', fill=NA, width = list(-1:-1)),
         save_ratio_prev3 = rollapply(save_ratio, mean, align='right', fill=NA, width = list(-3:-1)),
         save_ratio_prev5 = rollapply(save_ratio, mean, align='right', fill=NA, width = list(-5:-1)),
         save_ratio_prev10 = rollapply(save_ratio, mean, align='right', fill=NA, width = list(-10:-1))) %>%
  drop_na() %>%
  select(game_id, season, team_id = team_id.x, home_game,
         shots_ratio_prev1, shots_ratio_prev3, shots_ratio_prev5, shots_ratio_prev10,
         goals_ratio_prev1, goals_ratio_prev3, goals_ratio_prev5, goals_ratio_prev10,
         won_prev1, won_prev3, won_prev5, won_prev10,
         save_ratio_prev1, save_ratio_prev3, save_ratio_prev5, save_ratio_prev10,
         won = won.x)

# adding opponent information
nhl_data_ready <- nhl_data_ready %>%
  left_join(nhl_data_ready, by = c("game_id" = "game_id")) %>%
  filter(team_id.x != team_id.y) %>%
  filter(team_id.x == as.numeric(team_of_interest$team_id)) %>%
  mutate(won_prev1.diff = won_prev1.x - won_prev1.y,
         won_prev3.diff = won_prev3.x - won_prev3.y,
         won_prev5.diff = won_prev5.x - won_prev5.y,
         won_prev10.diff = won_prev10.x - won_prev10.y,

         shots_ratio_prev1.diff = shots_ratio_prev1.x - shots_ratio_prev1.y,
         shots_ratio_prev3.diff = shots_ratio_prev3.x - shots_ratio_prev3.y,
         shots_ratio_prev5.diff = shots_ratio_prev5.x - shots_ratio_prev5.y,
         shots_ratio_prev10.diff = shots_ratio_prev10.x - shots_ratio_prev10.y,

         goals_ratio_prev1.diff = goals_ratio_prev1.x - goals_ratio_prev1.y,
         goals_ratio_prev3.diff = goals_ratio_prev3.x - goals_ratio_prev3.y,
         goals_ratio_prev5.diff = goals_ratio_prev5.x - goals_ratio_prev5.y,
         goals_ratio_prev10.diff = goals_ratio_prev10.x - goals_ratio_prev10.y,

         save_ratio_prev1.diff = save_ratio_prev1.x - save_ratio_prev1.y,
         save_ratio_prev3.diff = save_ratio_prev3.x - save_ratio_prev3.y,
         save_ratio_prev5.diff = save_ratio_prev5.x - save_ratio_prev5.y,
         save_ratio_prev10.diff = save_ratio_prev10.x - save_ratio_prev10.y) %>%
  group_by(season.x) %>%
  select(-c(won.y, team_id.x, season.y))

# creating training data
nhl_data_train <- nhl_data_ready %>%
  filter(season.x != "2017")

# craeting test data
nhl_data_test <- nhl_data_ready %>%
    filter(season.x == "2017")

# writing the train and the test data to csv files
write_csv(nhl_data_train, output_file_train)
write_csv(nhl_data_test, output_file_test)
